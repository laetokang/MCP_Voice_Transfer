import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'whisper_flutter_new.dart';
import '../../presentation/repositories/stt_interface.dart';

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

    // none(""),

    //   /// tiny model for all languages
    //   tiny("tiny"),
    //   tinyQ5_1("tiny-q5_1"),
    //   tinyQ8_0("tiny-q8_0"),
    //   tinyEn("tiny.en"),
    //   tinyEnQ5_1("tiny.en-q5_1"),
    //   tinyEnQ8_0("tiny.en-q8_0"),

    //   /// base model for all languages
    //   base("base"),
    //   baseQ5_1("base-q5_1"),
    //   baseQ8_0("base-q8_0"),
    //   baseEn("base.en"),
    //   baseEnQ5_1("base.en-q5_1"),
    //   baseEnQ8_0("base.en-q8_0"),

    //   /// small model for all languages
    //   small("small"),
    //   smallQ5_1("small-q5_1"),
    //   smallQ8_0("small-q8_0"),
    //   smallEn("small.en"),
    //   smallEnQ5_1("small.en-q5_1"),
    //   smallEnQ8_0("small.en-q8_0"),
    //   smallEnTdrz("small.en-tdrz"),

    //   /// medium model for all languages
    //   medium("medium"),
    //   mediumQ5_0("medium-q5_0"),
    //   mediumQ8_0("medium-q8_0"),
    //   mediumEn("medium.en"),
    //   mediumEnQ5_0("medium.en-q5_0"),
    //   mediumEnQ8_0("medium.en-q8_0"),

    //   /// large model for all languages
    //   largeV1("large-v1"),
    //   largeV2("large-v2"),
    //   largeV2Q5_0("large-v2-q5_0"),
    //   largeV2Q8_0("large-v2-q8_0"),
    //   largeV3("large-v3"),
    //   largeV3Q5_0("large-v3-q5_0"),
    //   largeV3Turbo("large-v3-turbo"),
    //   largeV3TurboQ5_0("large-v3-turbo-q5_0"),
    //   largeV3TurboQ8_0("large-v3-turbo-q8_0");

    whisper = Whisper(
      // 하단에 WhisperModel.어쩌고로 바꾸기
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
