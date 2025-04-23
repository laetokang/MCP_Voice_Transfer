import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicetransfer/core/network/api.dart';
import 'package:voicetransfer/data/datasources/nlu/nlu_service.dart';
import 'package:voicetransfer/data/datasources/nlu/nlu_preprocessor.dart';

import 'package:voicetransfer/core/utils/timeLogger.dart';
import 'package:voicetransfer/presentation/providers/stt_provider.dart';
import 'package:voicetransfer/presentation/viewmodels/stt_viewmodel.dart';
// import 'package:voicetransfer/utils/deviceInfo.dart';

void main() {
  timelineLogger.appStart = DateTime.now().millisecondsSinceEpoch;
  print("🟢 [App Start] ${timelineLogger.appStart} ms");
  runApp(
    ProviderScope(
      // 👈 Riverpod 상태 관리 범위
      child: MyApp(),
    ),
  );
}

String getStateText(
  SttUiState state,
  int timestamp,
  int? previousTimestamp,
  int? now,
) {
  final current = now ?? DateTime.now().millisecondsSinceEpoch;
  final elapsed = current - timestamp;
  final sinceLast =
      previousTimestamp != null ? timestamp - previousTimestamp : null;

  String label;
  switch (state) {
    case SttUiState.downloadingModel:
      label = "📥 모델 다운로드 중...";
      break;
    case SttUiState.initializingModel:
      label = "🔧 모델 초기화 중...";
      break;
    case SttUiState.recording:
      label = "🎙️ 마이크 녹음 중...";
      break;
    case SttUiState.transcribing:
      label = "🧠 추론 중...";
      break;
    case SttUiState.unloadingModel:
      label = "📤 모델 언로딩 중...";
      break;
    case SttUiState.error:
      label = "❌ 오류 발생!";
      break;
    default:
      label = "";
  }
  if (state != SttUiState.idle) {
    label += " (${elapsed}ms 경과";
    if (sinceLast != null) {
      label += ", 이전 상태로부터 +${sinceLast}ms)";
    } else {
      label += ")";
    }
  }

  return label;
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

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> messages = [
    {"text": "안녕하세요. 김선민님!\n오늘은 무엇을 도와드릴까요?", "type": "system"},
  ];

  bool autoSend = false;

  late final ProviderSubscription<SttViewModel> _listener;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _listener.close();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final sttViewModel = ref.watch(sttViewModelProvider);

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
                    onChanged: (value) async {
                      setState(() {
                        autoSend = value;
                      });
                      if (value) {
                        await sttViewModel.startListening();

                        if (sttViewModel.resultText.isNotEmpty) {
                          if (autoSend) {
                            _handleSubmitted(
                              sttViewModel.resultText,
                            ); // 자동 전송도 같이!
                          }
                        }
                      } else {
                        sttViewModel.stopListening(); // 꺼졌을 땐 STT 중지도 추가해도 좋아요
                      }
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final sttViewModel = ref.watch(sttViewModelProvider);
                      final now = DateTime.now().millisecondsSinceEpoch;
                      return Text(
                        getStateText(
                          sttViewModel.state,
                          sttViewModel.stateChangedAt,
                          sttViewModel.previousStateChangedAt,
                          now,
                        ),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      );
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
