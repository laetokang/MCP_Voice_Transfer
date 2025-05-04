import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> ChatApi({
  required List<Map<String, String>> messages,
  required void Function(String text) onPartialResponse,
  required void Function(String error) onError,
}) async {
  final chatHistory =
      messages.map((msg) {
        return {
          "role": msg["type"] == "user" ? "user" : "assistant",
          "content": msg["text"]!,
        };
      }).toList();

  final request = http.Request(
    "POST",
    Uri.parse("https://api.openai.com/v1/chat/completions"),
  );
  request.headers.addAll({
    'Authorization': 'Bearer YOUR_API_KEY_HERE',
    'Content-Type': 'application/json',
  });

  request.body = jsonEncode({
    "model": "gpt-3.5-turbo",
    "messages": chatHistory,
    "temperature": 0.7,
    "max_tokens": 500,
    "stream": true,
  });

  try {
    final response = await request.send();
    if (response.statusCode == 200) {
      String replyText = "";

      response.stream
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              final lines = chunk.split("\n");
              for (var line in lines) {
                if (line.startsWith("data:")) {
                  final jsonStr = line.substring(5).trim();
                  if (jsonStr.isNotEmpty && jsonStr != "[DONE]") {
                    try {
                      final jsonData = jsonDecode(jsonStr);
                      final delta =
                          jsonData['choices'][0]['delta']['content'] as String?;
                      if (delta != null) {
                        replyText += delta;
                        onPartialResponse(replyText);
                      }
                    } catch (e) {
                      onError("JSON 파싱 오류: $e");
                    }
                  }
                }
              }
            },
            onError: (error) {
              onError("네트워크 오류: $error");
            },
          );
    } else {
      onError("API 응답 오류: ${response.statusCode}");
    }
  } catch (e) {
    onError("예외 발생: $e");
  }
}
