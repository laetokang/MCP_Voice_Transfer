import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:voicetransfer/features/api/api.dart';
import 'package:voicetransfer/features/stt/stt_controller.dart';
import 'package:voicetransfer/features/nlu/nlu_preprocessor.dart';
import 'package:voicetransfer/features/nlu/nlu_service.dart';
import 'package:voicetransfer/features/stt/stt_service_whisper.dart';
import 'package:voicetransfer/features/stt/stt_service_whisper_stream.dart';
import 'package:voicetransfer/utils/timeLogger.dart';
import 'package:voicetransfer/utils/deviceInfo.dart';

void main() {
  timelineLogger.appStart = DateTime.now().millisecondsSinceEpoch;
  print("🟢 [App Start] ${timelineLogger.appStart} ms");
  runApp(const MyApp());
}

// 마이크 권한 요청
void _requestPermission() async {
  var status = await Permission.microphone.status;
  var geoStatus = await Permission.location.status;
  if (geoStatus.isDenied) {
    await Permission.location.request();
  }
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
    collectDeviceInfo();
    _sttController = SttController(
      onSubmit: (recognizedText) async {
        final cleanedText = postprocessText(recognizedText);
        final result = await NluService.analyze(cleanedText);
        setState(() {
          messages.add({"text": recognizedText, "type": "user"});
          messages.add({"text": "", "type": "system"});
          // messages.add({
          //   "text": "🎯 분석 결과: ${result.intent}, ${result.slots}",
          //   "type": "system",
          // });
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
      customService: SttServiceWhisper(),
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

    final chatbotIndex = messages.length - 1;

    await ChatApi(
      messages: messages,
      onPartialResponse: (replyText) {
        setState(() {
          messages[chatbotIndex] = {"text": replyText, "type": "system"};
        });
        _scrollToBottom();
      },
      onError: (errorMsg) {
        setState(() {
          messages[chatbotIndex] = {"text": errorMsg, "type": "system"};
        });
      },
    );
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
