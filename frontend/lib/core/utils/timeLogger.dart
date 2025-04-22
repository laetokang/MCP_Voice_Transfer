class TimelineLogger {
  int? appStart;
  int? micStart;
  int? wavSaved;
  int? inferenceStart;
  int? inferenceDone;
  int? screenOutput;

  void printTimeline() {
    print("⏱️ [타임라인 요약]");
    if (appStart != null) print("🟢 앱 시작: $appStart ms");

    if (appStart != null && micStart != null) {
      print("🎙 마이크 시작: $micStart ms (+${micStart! - appStart!}ms)");
    } else if (micStart != null) {
      print("🎙 마이크 시작: $micStart ms");
    }

    if (micStart != null && wavSaved != null) {
      print("💾 WAV 저장: $wavSaved ms (+${wavSaved! - micStart!}ms)");
    } else if (wavSaved != null) {
      print("💾 WAV 저장: $wavSaved ms");
    }

    if (wavSaved != null && inferenceStart != null) {
      print("🧠 추론 시작: $inferenceStart ms (+${inferenceStart! - wavSaved!}ms)");
    } else if (inferenceStart != null) {
      print("🧠 추론 시작: $inferenceStart ms");
    }

    if (inferenceStart != null && inferenceDone != null) {
      print(
        "✅ 추론 완료: $inferenceDone ms (+${inferenceDone! - inferenceStart!}ms)",
      );
    } else if (inferenceDone != null) {
      print("✅ 추론 완료: $inferenceDone ms");
    }

    if (inferenceDone != null && screenOutput != null) {
      print(
        "📱 결과 출력: $screenOutput ms (+${screenOutput! - inferenceDone!}ms)",
      );
    } else if (screenOutput != null) {
      print("📱 결과 출력: $screenOutput ms");
    }
  }
}

final timelineLogger = TimelineLogger(); // 전역 선언 or 의존성 주입
