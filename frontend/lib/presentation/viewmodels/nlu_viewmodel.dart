import 'package:flutter/foundation.dart';
import 'package:voicetransfer/modules/2nlu/nlu_service.dart';
import 'dart:convert';

enum NluUiState {
  idle,
  downloadingModel,
  loadingModel,
  analyzing,
  success,
  error,
}

class NluViewModel extends ChangeNotifier {
  final NluService _nluService;

  String _response = '';
  String _errorMessage = '';
  NluUiState _state = NluUiState.idle;

  String get response => _response;
  String get errorMessage => _errorMessage;
  NluUiState get state => _state;
  bool get isLoading =>
      _state == NluUiState.analyzing || _state == NluUiState.loadingModel;

  NluViewModel(this._nluService);

  void _setState(NluUiState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  Future<void> generate(
    String inputText,
    void Function(String) onComplete, {
    void Function(String)? onUpdate, // ✅ 중간 응답 콜백 추가
  }) async {
    _response = '';
    _errorMessage = '';
    _setState(NluUiState.analyzing);

    final List<int> _byteBuffer = [];

    try {
      final streamSub = _nluService.stream.listen((chunk) {
        if (chunk.isNotEmpty) {
          final bytes = latin1.encode(chunk);
          _byteBuffer.addAll(bytes);

          try {
            final decoded = const Utf8Decoder(
              allowMalformed: true,
            ).convert(_byteBuffer);
            _response = decoded;
            notifyListeners();
            if (onUpdate != null) onUpdate(_response); // ✅ 중간 응답 전송
          } catch (_) {}
        }
      });

      final completionSub = _nluService.completions.listen((_) {
        try {
          final decoded = const Utf8Decoder(
            allowMalformed: true,
          ).convert(_byteBuffer);
          _response = decoded;
          notifyListeners();
        } catch (_) {
          _response = '디코딩 에러 발생';
          _setState(NluUiState.error);
        }
        _byteBuffer.clear();
        _setState(NluUiState.success);
        onComplete(_response);
      });

      _nluService.ask(inputText);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(NluUiState.error);
    }
  }

  void reset() {
    _response = '';
    _errorMessage = '';
    _setState(NluUiState.idle);
  }
}
