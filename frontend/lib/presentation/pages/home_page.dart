// lib/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicetransfer/modules/2nlu/nlu_provider.dart';
import 'package:voicetransfer/modules/1stt/stt_provider.dart';
import 'package:voicetransfer/presentation/viewmodels/nlu_viewmodel.dart';
import 'package:voicetransfer/presentation/viewmodels/stt_viewmodel.dart';

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

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

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
      messages.add({"text": "", "type": "system"}); // ✅ 빈 시스템 응답 추가
      _scrollToBottom();
    });

    final chatbotIndex = messages.length - 1; // ✅ 마지막 system 메시지 위치

    try {
      print("📨 NLU 요청 시작: $text");
      final nlu = ref.read(nluViewModelProvider);

      await nlu.generate(
        text,
        (String finalReply) {
          setState(() {
            messages[chatbotIndex]["text"] = finalReply; // ✅ 최종 덮어쓰기
            _scrollToBottom();
          });
          print("🧠 생성된 응답: $finalReply");
        },
        onUpdate: (partial) {
          setState(() {
            messages[chatbotIndex]["text"] = partial; // ✅ 중간결과 누적 갱신
            _scrollToBottom();
          });
        },
      );
    } catch (e, stack) {
      print("❌ _handleSubmitted 예외: $e");
      print(stack);
      setState(() {
        messages[chatbotIndex] = {"text": "오류가 발생했어요", "type": "system"};
      });
    }
  }

  String getStateText({
    required SttUiState sttState,
    required NluUiState nluState,
    required int timestamp,
    int? previousTimestamp,
    int? now,
    String? nluResponse,
    String? nluError,
  }) {
    final current = now ?? DateTime.now().millisecondsSinceEpoch;
    final elapsed = current - timestamp;
    final sinceLast =
        previousTimestamp != null ? timestamp - previousTimestamp : null;

    String label = '';

    // 1. NLU 상태 우선 처리 (성공 or 오류 시 즉시 출력)
    if (nluState == NluUiState.success &&
        nluResponse != null &&
        nluResponse.isNotEmpty) {
      return '✅ 응답: $nluResponse';
    } else if (nluState == NluUiState.error && nluError != null) {
      return '❌ 오류: $nluError';
    }

    // 2. NLU 진행 중 상태 표시
    switch (nluState) {
      case NluUiState.downloadingModel:
        label = "📥 NLU 모델 다운로드 중...";
        break;
      case NluUiState.loadingModel:
        label = "🔧 NLU 모델 로딩 중...";
        break;
      case NluUiState.analyzing:
        label = "🧠 텍스트 분석 중...";
        break;
      default:
        break; // 진행 없음 → STT 상태로 넘어감
    }

    // 3. STT 상태 메시지 출력
    switch (sttState) {
      case SttUiState.downloadingModel:
        label = "📥 STT 모델 다운로드 중...";
        break;
      case SttUiState.initializingModel:
        label = "🔧 STT 모델 초기화 중...";
        break;
      case SttUiState.recording:
        label = "🎙️ 마이크 녹음 중...";
        break;
      case SttUiState.transcribing:
        label = "🧠 음성 → 텍스트 추론 중...";
        break;
      case SttUiState.unloadingModel:
        label = "📤 STT 모델 언로딩 중...";
        break;
      case SttUiState.error:
        label = "❌ STT 오류 발생!";
        break;
      case SttUiState.idle:
      default:
        label = "";
    }

    // 4. 시간 정보 추가
    if (sttState != SttUiState.idle && label.isNotEmpty) {
      label += " (${elapsed}ms 경과";
      if (sinceLast != null) {
        label += ", 이전 상태로부터 +${sinceLast}ms)";
      } else {
        label += ")";
      }
    }

    return label;
  }

  @override
  Widget build(BuildContext context) {
    final sttViewModel = ref.watch(sttViewModelProvider);
    final nluViewModel = ref.watch(nluViewModelProvider);
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
                          print("📨 STT 결과 자동 제출: ${sttViewModel.resultText}");
                          _handleSubmitted(sttViewModel.resultText);
                        }
                      } else {
                        sttViewModel.stopListening();
                      }
                    },
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final sttViewModel = ref.watch(sttViewModelProvider);
                      final now = DateTime.now().millisecondsSinceEpoch;
                      return Text(
                        getStateText(
                          sttState: sttViewModel.state,
                          nluState: nluViewModel.state,
                          timestamp: sttViewModel.stateChangedAt,
                          previousTimestamp:
                              sttViewModel.previousStateChangedAt,
                          now: now,
                          nluResponse: nluViewModel.response,
                          nluError: nluViewModel.errorMessage,
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
