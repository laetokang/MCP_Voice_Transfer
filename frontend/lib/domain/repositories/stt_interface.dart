abstract class SttInterface {
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    Duration pauseFor,
    Duration listenFor,
    String localeId,
    void Function(String status)? onStatus,
  });

  void stop();
}
