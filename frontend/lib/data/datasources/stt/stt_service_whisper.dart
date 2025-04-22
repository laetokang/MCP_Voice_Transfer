import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../stt/whisper_flutter_new.dart';
import '../../../domain/interfaces/stt_interface.dart';

class SttServiceWhisper implements SttInterface {
  Whisper? whisper;
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    onStatus("initializing");
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

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      onError("마이크 권한이 없습니다");
      return false;
    }

    return true;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 5),
    String localeId = 'ko_KR',
    void Function(String status)? onStatus,
  }) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String filePath = '${dir.path}/recorded.wav';

    // 🔄 기존 파일 제거
    if (await File(filePath).exists()) {
      await File(filePath).delete();
    }
    onStatus?.call("recording");
    // 🎙️ 녹음 시작
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 16000,
      ),
      path: filePath,
    );

    print("🎙️ 녹음 중... 저장 위치: $filePath");
    await Future.delayed(listenFor); // 녹음 시간만큼 기다림

    final String? recordedPath = await _recorder.stop();
    print("🛑 녹음 종료. 파일: $recordedPath");

    if (recordedPath == null || !File(recordedPath).existsSync()) {
      throw Exception("❌ 녹음된 파일이 존재하지 않습니다.");
    }
    onStatus?.call("transcribing");
    final transcription = await whisper!.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: recordedPath,
        isTranslate: false,
        isNoTimestamps: true,
        splitOnWord: true,
      ),
    );

    print("📜 Whisper 결과: ${transcription.text}");
    onResult(transcription.text, true);
    onStatus?.call("unloading");
  }

  @override
  void stop() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }
}
