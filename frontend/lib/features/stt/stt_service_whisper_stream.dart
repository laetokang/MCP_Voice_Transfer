import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'stt_interface.dart';
import 'package:voicetransfer/utils/log_timestamps.dart';

class SttServiceWhisper implements SttInterface {
  final LogTimestamps? log;
  SttServiceWhisper({this.log});
  Whisper? whisper;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final List<int> _audioBuffer = [];
  bool _isRecording = false;
  StreamSubscription? _audioStreamSub;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    if (whisper != null) {
      onStatus("already initialized");
      return true;
    }

    whisper = Whisper(
      model: WhisperModel.tiny,
      downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
    );
    final version = await whisper!.getVersion();
    print("🧠 Whisper Version: $version");

    await _recorder.openRecorder();
    final hasPermission = await _recorder.isEncoderSupported(
      Codec.pcm16, // raw PCM
    );
    if (!hasPermission) {
      onError("녹음 권한이 없거나 지원되지 않는 포맷입니다.");
      return false;
    }

    return true;
  }

  @override
void listen({
  required void Function(String text, bool isFinal) onResult,
  Duration pauseFor = const Duration(seconds: 1),
  Duration listenFor = const Duration(seconds: 5),
  String localeId = 'ko_KR',
}) async {
  if (_isRecording) return;
  _isRecording = true;
  _audioBuffer.clear();

  final streamController = StreamController<Uint8List>();

  // 1. 스트림 리스너 등록
  streamController.stream.listen((buffer) async {
    _audioBuffer.addAll(buffer);

    if (_audioBuffer.length >= 16000 * 2 * 2) {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/streamed_audio.wav';
      final file = File(filePath);

      // 💾 WAV 저장 시간 기록
      await _writeWavFile(Uint8List.fromList(_audioBuffer), file.path);
      final int wavSaveTime = DateTime.now().millisecondsSinceEpoch;
      print("💾 [WAV Saved] $wavSaveTime ms");

      _audioBuffer.clear();

      // 🧠 추론 시작 시간
      final int inferenceStartTime = DateTime.now().millisecondsSinceEpoch;
      print("🧠 [Inference Start] $inferenceStartTime ms");
      log?.inferenceStart = DateTime.now();

      try {
        final result = await whisper!.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: file.path,
            isTranslate: false,
            isNoTimestamps: true,
            splitOnWord: true,
          ),
        );

        // ✅ 추론 완료 시간 및 전체 소요 시간
        final int inferenceEndTime = DateTime.now().millisecondsSinceEpoch;
        print("✅ [Inference Done] $inferenceEndTime ms (+${inferenceEndTime - inferenceStartTime}ms)");
        print("⏱️ Total STT duration: ${inferenceEndTime - log!.micStart!.millisecondsSinceEpoch}ms");

        log?.inferenceEnd = DateTime.now();
        log?.printAll();

        print("📜 Whisper 결과: ${result.text}");
        onResult(result.text, true);
      } catch (e) {
        print("❌ Whisper 오류: $e");
      }
    }
  });

  // 2. Recorder 시작
  await _recorder.startRecorder(
    codec: Codec.pcm16,
    sampleRate: 16000,
    numChannels: 1,
    toStream: streamController.sink,
  );

  // 🎙 마이크 시작 시간 기록
  final int micStartTime = DateTime.now().millisecondsSinceEpoch;
  print("🎙 [Mic Start] $micStartTime ms");
  log?.micStart = DateTime.now();

  await Future.delayed(listenFor);
  await stop();
}


  @override
  Future<void> stop() async {
    _isRecording = false;
    await _recorder.stopRecorder();
    log?.wavWrite = DateTime.now();
    await _audioStreamSub?.cancel();
    _audioBuffer.clear();
  }
}

Future<void> _writeWavFile(Uint8List pcmData, String path) async {
  const sampleRate = 16000;
  const bitsPerSample = 16;
  const channels = 1;
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataLength = pcmData.length;
  final totalLength = 44 + dataLength;

  final header = BytesBuilder();
  header.add(ascii.encode('RIFF'));
  header.add(_intToBytes(totalLength - 8, 4)); // chunk size
  header.add(ascii.encode('WAVE'));
  header.add(ascii.encode('fmt '));
  header.add(_intToBytes(16, 4)); // subchunk1 size
  header.add(_intToBytes(1, 2)); // audio format = PCM
  header.add(_intToBytes(channels, 2));
  header.add(_intToBytes(sampleRate, 4));
  header.add(_intToBytes(byteRate, 4));
  header.add(_intToBytes(blockAlign, 2));
  header.add(_intToBytes(bitsPerSample, 2));
  header.add(ascii.encode('data'));
  header.add(_intToBytes(dataLength, 4));
  header.add(pcmData);

  await File(path).writeAsBytes(header.toBytes(), flush: true);
}

List<int> _intToBytes(int value, int byteCount) {
  final result = <int>[];
  for (int i = 0; i < byteCount; i++) {
    result.add((value >> (8 * i)) & 0xFF);
  }
  return result;
}
