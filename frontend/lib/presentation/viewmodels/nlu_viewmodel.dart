import 'package:flutter/foundation.dart';
import 'package:voicetransfer/data/datasources/nlu/nlu_service.dart';

enum NluUiState { idle, analyzing, success, error }

class NluViewModel extends ChangeNotifier {
  String _response = '';
  String _error = '';
  bool _loading = false;

  String get response => _response;
  String get error => _error;
  bool get isLoading => _loading;

  Future<void> generate(String inputText) async {
    _loading = true;
    notifyListeners();

    try {
      final result = await NluService.generateText(inputText);
      _response = result;
      _error = '';
    } catch (e) {
      _response = '';
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  void reset() {
    _response = '';
    _error = '';
    _loading = false;
    notifyListeners();
  }
}
