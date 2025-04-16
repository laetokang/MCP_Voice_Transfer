import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:voicetransfer/features/stt/stt_service.dart';
import 'package:voicetransfer/features/stt/stt_controller.dart';
import 'package:voicetransfer/features/nlu/nlu_preprocessor.dart';
import 'package:voicetransfer/features/nlu/nlu_service.dart';

final int appStartTime = DateTime.now().millisecondsSinceEpoch;
print("🟢 [App Start] $appStartTime ms");

void main() {
  runApp(const MyApp());
}

void _requestPermission() async {
  var status = await Permission.microphone.status;
  if (!status.isGranted) {
    await Permission.microphone.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STT Chatbot Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final SttController _sttController;
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> messages = [
    {"text": "안녕하세요. 김선민님!\n오늘은 무엇을 도와드릴까요?", "type": "system"},
  ];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermission(); // 퍼미션 요청
    _sttController = SttController(
      textController: _textController,
      onSubmit: (recognizedText) async {
        setState(() {
          messages.add({"text": recognizedText, "type": "user"});
          messages.add({"text": "", "type": "system"});
          _scrollToBottom();
        });
        final cleanedText = postprocessText(recognizedText);

        // ✅ NLU 분석 요청
        final result = await NluService.analyze(cleanedText);

        // 예시: { intent: '송금', slots: { to: '엄마', amount: 10000 } }
        print("🎯 분석 결과: ${result.intent}, ${result.slots}");
        setState(() {
          messages.add({
            "text": "🎯 분석 결과: ${result.intent}, ${result.slots}",
            "type": "system",
          });
          _scrollToBottom();
        });
      },
      onUserMessage: (text) {
        setState(() {
          messages.add({"text": text, "type": "user"});
        });
      },
      setState: setState,
      scrollToBottom: _scrollToBottom,
      autoSend: () => autoSend,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) async {
    setState(() {
      messages.add({"text": text, "type": "user"});
      messages.add({"text": "", "type": "system"});
      _scrollToBottom();
    });

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
      'Authorization': 'Bearer YOUR_API_KEY_HERE', // 🔐 OpenAI API 키 넣기!
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
        int chatbotIndex = messages.length - 1;

        response.stream
            .transform(utf8.decoder)
            .listen(
              (chunk) {
                final lines = chunk.split("\n");
                for (var line in lines) {
                  if (line.startsWith("data:")) {
                    String jsonStr = line.substring(5).trim();
                    if (jsonStr.isNotEmpty && jsonStr != "[DONE]") {
                      try {
                        final jsonData = jsonDecode(jsonStr);
                        final delta =
                            jsonData['choices'][0]['delta']['content']
                                as String?;
                        if (delta != null) {
                          replyText += delta;
                          setState(() {
                            messages[chatbotIndex] = {
                              "text": replyText,
                              "type": "system",
                            };
                          });
                          _scrollToBottom();
                        }
                      } catch (e) {
                        log("JSON 파싱 오류: $e");
                      }
                    }
                  }
                }
              },
              onError: (error) {
                setState(() {
                  messages[chatbotIndex] = {
                    "text": "네트워크 오류 발생: $error",
                    "type": "system",
                  };
                });
              },
            );
      } else {
        setState(() {
          messages.last = {
            "text": "Error: ${response.statusCode}",
            "type": "system",
          };
        });
      }
    } catch (e) {
      setState(() {
        messages.last = {"text": "네트워크 오류 발생: $e", "type": "system"};
      });
    }
  }

  bool autoSend = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text("음성 인식 후 자동 전송"),
                    value: autoSend,
                    onChanged: (value) {
                      setState(() {
                        autoSend = value;
                      });
                      if (value) {
                        _sttController.startListening();
                      } else {
                        _sttController
                            .stopListening(); // 꺼졌을 땐 STT 중지도 추가해도 좋아요
                      }
                    },
                  ),
                  for (var message in messages)
                    Align(
                      alignment:
                          message['type'] == 'user'
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              message['type'] == 'user'
                                  ? Colors.brown
                                  : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          message['text']!,
                          style: TextStyle(
                            color:
                                message['type'] == 'user'
                                    ? Colors.white
                                    : Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 하단 텍스트 입력창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5.0,
                    offset: Offset(1.5, 1.5),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: '궁금한 것을 물어보세요',
                  hintStyle: const TextStyle(color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.amber),
                    onPressed: () {
                      if (_textController.text.isNotEmpty) {
                        _handleSubmitted(_textController.text);
                        _textController.clear();
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
