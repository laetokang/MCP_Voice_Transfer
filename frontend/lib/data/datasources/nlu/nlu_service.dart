class NluResult {
  final String intent;
  final Map<String, dynamic> slots;

  NluResult({required this.intent, required this.slots});
}

class NluService {
  static Future<NluResult> analyze(String text) async {
    // 실제 모델 분석 or Mock
    if (text.contains("보내 줘")) {
      return NluResult(intent: "송금", slots: {"to": "엄마", "amount": 10000});
    }

    return NluResult(intent: "기타", slots: {});
  }
}
