import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import "whisper_flutter_new.dart";
import '../../presentation/repositories/stt_interface.dart';
import 'package:voicetransfer/utils/utils/timeLogger.dart';

class SttServiceWhisperStream implements SttInterface {
  SttServiceWhisperStream();
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
      model: WhisperModel.baseQ8_0,
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
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    Duration pauseFor = const Duration(seconds: 1),
    Duration listenFor = const Duration(seconds: 2),
    String localeId = 'ko_KR',
    void Function(String status)? onStatus,
  }) async {
    if (_isRecording) return;
    _isRecording = true;
    _audioBuffer.clear();

    final streamController = StreamController<Uint8List>();
    _audioStreamSub = streamController.stream.listen((buffer) {
      _audioBuffer.addAll(buffer);
    });

    // 🧠 2초마다 버퍼 복사해서 Whisper 추론하는 Timer
    Timer? periodicTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      if (_audioBuffer.isEmpty || !_isRecording) return;

      final currentBuffer = List<int>.from(_audioBuffer); // 복사
      _audioBuffer.clear(); // 🔁 혹은 일부만 제거해도 됨

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/partial.wav';
      final file = File(filePath);
      await _writeWavFile(Uint8List.fromList(currentBuffer), file.path);

      print("📤 Whisper에 보낼 오디오 길이: ${currentBuffer.length}");

      try {
        final result = await whisper!.transcribe(
          transcribeRequest: TranscribeRequest(
            audio: file.path,
            isTranslate: false,
            isNoTimestamps: true,
            splitOnWord: true,
          ),
        );
        onResult(result.text, false); // 실시간 스트리밍 느낌
      } catch (e) {
        print("❌ Whisper 오류: $e");
      }
    });

    await _recorder.startRecorder(
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
      toStream: streamController.sink,
    );

    timelineLogger.micStart = DateTime.now().millisecondsSinceEpoch;

    // 🎯 일정 시간 후 종료
    Future.delayed(listenFor, () async {
      await stop();
      periodicTimer.cancel();

      if (_audioBuffer.isNotEmpty) {
        final finalBuffer = List<int>.from(_audioBuffer);
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/final.wav';
        await _writeWavFile(Uint8List.fromList(finalBuffer), filePath);

        try {
          final result = await whisper!.transcribe(
            transcribeRequest: TranscribeRequest(
              audio: filePath,
              isTranslate: false,
              isNoTimestamps: true,
              splitOnWord: true,
            ),
          );
          onResult(result.text, true); // ✅ 마지막은 isFinal = true
        } catch (e) {
          print("❌ 최종 Whisper 오류: $e");
        }
      }
      ;

      periodicTimer.cancel();
    });
  }

  @override
  Future<void> stop() async {
    _isRecording = false;
    await _recorder.stopRecorder();
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
