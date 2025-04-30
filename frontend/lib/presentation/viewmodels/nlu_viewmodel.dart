import 'package:flutter/foundation.dart';
import 'package:voicetransfer/data/datasources/nlu/nlu_service.dart';
import 'dart:convert';

enum NluUiState { idle, analyzing, success, error }

class NluViewModel extends ChangeNotifier {
  final NluService _nluService;
  String _response = '';
  String _error = '';
  bool _loading = false;

  String get response => _response;
  String get error => _error;
  bool get isLoading => _loading;

  NluViewModel(this._nluService);

  Future<void> generate(
    String inputText,
    void Function(String) onComplete,
  ) async {
    _loading = true;
    _response = '';
    _error = '';
    notifyListeners();

    final buffer = StringBuffer();
    final List<int> _byteBuffer = [];

    try {
      // 스트리밍 응답 받아오기
      final streamSub = _nluService.stream.listen((chunk) {
        if (chunk.isNotEmpty) {
          // 1. chunk를 일단 Latin1(ISO-8859-1)로 bytes화
          final bytes = latin1.encode(chunk);
          _byteBuffer.addAll(bytes);

          try {
            // 2. 그 bytes를 UTF-8로 다시 decode
            final decoded = utf8.decode(_byteBuffer);
            _response = decoded;
            notifyListeners();
          } catch (e) {
            // 아직 조립이 안 끝난 중간 상태일 수 있으니 무시
          }
        }
      });

      final completionSub = _nluService.completions.listen((_) {
        try {
          final decoded = utf8.decode(_byteBuffer);
          _response = decoded;
        } catch (e) {
          _response = '디코딩 에러 발생';
        }
        _byteBuffer.clear();
        _loading = false;
        notifyListeners();
        onComplete(_response);
      });

      _nluService.ask(inputText);

      // cleanup: 옵션. 필요시 둘 다 await + cancel 가능
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _response = '';
    _error = '';
    _loading = false;
    notifyListeners();
  }
}
