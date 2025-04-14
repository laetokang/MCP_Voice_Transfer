import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'stt_interface.dart';

class SttServiceSystem implements SttInterface {
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    return await _speech.initialize(
      onStatus: (val) => onStatus(val),
      onError: (val) => onError(val.errorMsg),
    );
  }

  @override
  void listen({
    required void Function(String text, bool isFinal) onResult,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(minutes: 1),
    String localeId = 'ko_KR',
  }) {
    _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      pauseFor: pauseFor,
      listenFor: listenFor,
      onResult: (val) {
        onResult(val.recognizedWords, val.finalResult);
      },
    );
  }

  @override
  void stop() {
    _speech.stop();
  }
}
