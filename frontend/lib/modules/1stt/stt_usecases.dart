import 'dart:async';

import 'package:voicetransfer/modules/1stt/stt_interface.dart';

class ListenAndTranscribe {
  final SttInterface stt;

  ListenAndTranscribe(this.stt);

  Future<String> call({
    void Function(String)? onPartial,
    void Function(String)? onStatus,
    void Function(String)? onError,
  }) async {
    final buffer = StringBuffer();

    final available = await stt.initialize(
      onStatus: (status) {
        print("✅ STT 상태: $status");
        onStatus?.call(status); // ✅ ViewModel로 전달
      },
      onError: (error) {
        print("❌ STT 오류: $error");
        onError?.call(error); // ✅ ViewModel로 전달
      },
    );

    if (!available) return '';
    final completer = Completer<String>();

    await stt.listen(
      onResult: (text, isFinal) {
        buffer
          ..clear()
          ..write(text);

        onPartial?.call(text);
        if (isFinal) {
          completer.complete(buffer.toString());
        }
      },
      onStatus: onStatus,
    );

    return completer.future;
  }

  void stop() {
    stt.stop(); // <- STT 중단
  }
}
