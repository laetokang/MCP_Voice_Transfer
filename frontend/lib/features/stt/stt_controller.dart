// STT 서비스와 Flutter UI 간 중재 역할
import 'package:flutter/material.dart';
import 'stt_interface.dart';
import 'stt_service_whisper_stream.dart';
import 'package:voicetransfer/utils/timeLogger.dart';

class SttController {
  final SttInterface _sttService;

  final void Function(String) onSubmit;
  final void Function(String) onUserMessage;
  final void Function(VoidCallback) setState;
  final void Function() scrollToBottom;
  final bool Function() autoSend;

  bool isListening = false;

  SttController({
    required this.onSubmit,
    required this.onUserMessage,
    required this.setState,
    required this.scrollToBottom,
    required this.autoSend,
    SttInterface? customService,
  }) : _sttService = customService ?? SttServiceWhisperStream();

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
        timelineLogger.screenOutput = screenRenderTime;
        print("🗣️ Whisper 결과 수신: $text / 최종 여부: $isFinal");

        if (isFinal) {
          stopListening();

          if (autoSend()) {
            // onSubmit(text);
            setState(() {
              onUserMessage(text);
            });
            // 🕐 자동 반복 시 500ms 후 재시작
            Future.delayed(const Duration(milliseconds: 500), () {
              if (autoSend()) startListening();
            });
          }
        }
      },
    );
  }

  void stopListening() {
    print("🛑 STT 중단 호출됨");
    _sttService.stop();
    isListening = false;
  }
}
