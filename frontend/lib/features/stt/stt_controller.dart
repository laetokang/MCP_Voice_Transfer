import 'package:flutter/material.dart';
import 'stt_interface.dart';
import 'stt_service.dart';

class SttController {
  final SttInterface _sttService;

  final TextEditingController textController;
  final void Function(String) onSubmit;
  final void Function(String) onUserMessage;
  final void Function(VoidCallback) setState;
  final void Function() scrollToBottom;
  final bool Function() autoSend;

  bool isListening = false;

  SttController({
    required this.textController,
    required this.onSubmit,
    required this.onUserMessage,
    required this.setState,
    required this.scrollToBottom,
    required this.autoSend,
    SttInterface? customService,
  }) : _sttService = customService ?? SttServiceSystem();

  Future<void> startListening() async {
    final available = await _sttService.initialize(
      onStatus: (status) => print("STT 상태: $status"),
      onError: (error) => print("STT 오류: $error"),
    );

    if (!available) return;

    isListening = true;

    _sttService.listen(
  onResult: (text, isFinal) {
    final int screenRenderTime = DateTime.now().millisecondsSinceEpoch;
    print("📱 [Screen Output] $screenRenderTime ms");

    setState(() {
      textController.text = text;
      textController.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    });

    if (isFinal) {
      stopListening();

      if (autoSend()) {
        onSubmit(text);
        textController.clear();

        Future.delayed(const Duration(milliseconds: 500), () {
          if (autoSend()) startListening();
        });
      } else {
        onUserMessage(text); // 🔥 View에서 메시지 처리하도록 위임
        textController.clear();
        scrollToBottom();
      }
    }
  },
);

  }

  void stopListening() {
    _sttService.stop();
    isListening = false;
  }
}
