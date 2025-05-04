import 'package:flutter/material.dart';
import 'package:voicetransfer/modules/1stt/stt_usecases.dart';

enum SttUiState {
  idle, // 아무 동작 안하는 중
  downloadingModel, // 모델 다운로드 중
  initializingModel, // 모델 초기화 중
  recording, // 사용자의 음성을 듣는 중
  transcribing, // 음성 → 텍스트 변환 중
  unloadingModel, // 모델 제거 중
  error, // 오류 발생
}

class SttViewModel extends ChangeNotifier {
  final ListenAndTranscribe useCase;

  String resultText = '';
  String errorMessage = '';

  // 내부 상태 관리
  SttUiState _state = SttUiState.idle;
  int _lastStateTimestamp = DateTime.now().millisecondsSinceEpoch;
  int? _previousStateTimestamp;

  // Getter
  SttUiState get state => _state;
  int get stateChangedAt => _lastStateTimestamp;
  int? get previousStateChangedAt => _previousStateTimestamp;

  SttViewModel(this.useCase);

  void _setState(SttUiState newState) {
    if (_state != newState) {
      _previousStateTimestamp = _lastStateTimestamp; // 이전 시각 저장
      _state = newState;
      _lastStateTimestamp = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
    }
  }

  Future<void> startListening() async {
    resultText = '';
    errorMessage = '';
    _setState(SttUiState.initializingModel); // 초기 상태로 지정

    resultText = await useCase(
      onPartial: (text) {
        resultText = text;
        notifyListeners(); // 🔁 중간 결과 실시간 반영
      },
      onStatus: (status) {
        debugPrint("💡 [STT 상태 업데이트] 받은 상태: $status");

        final lower = status.toLowerCase();

        if (lower.contains('initializing')) {
          _setState(SttUiState.initializingModel);
        } else if (lower.contains('download')) {
          _setState(SttUiState.downloadingModel);
        } else if (lower.contains('record')) {
          _setState(SttUiState.recording);
        } else if (lower.contains('transcrib')) {
          _setState(SttUiState.transcribing);
        } else if (lower.contains('unload')) {
          _setState(SttUiState.unloadingModel);
        } else {
          debugPrint("⚠️ 알 수 없는 상태 문자열: $status");
        }
      },

      onError: (error) {
        errorMessage = error;
        _setState(SttUiState.error);
      },
    );

    notifyListeners();
  }

  void stopListening() {
    useCase.stop();
    notifyListeners();
  }
}
