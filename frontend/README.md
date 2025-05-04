# 🗣️ MCP Voice Transfer System

Flutter 기반 음성 송금 인터페이스 시스템입니다.  
사용자의 음성을 인식하고, 의도와 슬롯을 추출하여 인증 및 송금을 처리하고 음성으로 응답합니다.

---

### 모바일 연동 및 OS 확장

- **[10] Android STT + TTS 연동**

  - STT: 사용자 발화 → 텍스트 변환
  - TTS: 서버 응답 → 음성 안내로 출력

- **[11] FastAPI 연동 Android 클라이언트**

  - Retrofit 등으로 `/intent`, `/transfer` 호출
  - 챗 UI 또는 음성 기반 UI 제공

- **[12] OS 서비스로 확장**
  - `VoiceInteractionService` 활용
  - 웨이크업 키워드 ("아라야") → 바로 송금 대화 시작 가능

## ✅ 1. 프로젝트 아키텍처

### 🎯 구성 원칙

- Clean Architecture + MVVM 기반

```
[UI 페이지]
    ↓             (provider 통해 연결)
[SttViewModel]
    ↓             (도메인 유스케이스 실행)
[ListenAndTranscribe]
    ↓             (인터페이스 의존성)
[SttInterface]
    ↓             (실제 구현체 - Whisper 등)
[SttServiceWhisper]
```

---

### ✅ 2. 폴더 구조

```
lib/
├── modules/ #(AI 모델 전용)
│   ├── 1stt/
│   │   ├── stt_service.dart                 # STT 추상 클래스 (interface)
│   │   ├── stt_service_whisper.dart         # Whisper 모델로 비동기 STT 처리 (비스트리밍)
│   │   ├── stt_service_whisper_stream.dart  # Whisper 모델로 실시간 스트리밍 처리
│   │   ├── stt_interface.dart               # STT 기능 인터페이스 정의 (의존성 주입용)
│   │   ├── stt_usecases.dart                # STT 유스케이스 (transcribe, stream 등 정의)
│   │   ├── stt_provider.dart                # STT 상태관리, Riverpod 등 의존성 관리
│   │   ├── whisper_flutter_new.dart         # Whisper.cpp FFI 연동 (네이티브 연동 담당)
│   │   └── download_model.dart                  # Whisper 모델 다운로드/복사 유틸리티

│   ├── nlu/
│   │   ├── dialog_manager.dart         # 다이얼로그 흐름 관리
│   │   ├── nlu_model.dart              # 추론용 NLU 모델 정의 또는 래퍼
│   │   ├── nlu_preprocessor.dart       # 텍스트 전처리기 (소문자화, 정제 등)
│   │   ├── nlu_provider.dart           # 상태관리용 Provider (Riverpod 등)
│   │   ├── nlu_service.dart            # 실제 NLU 처리 서비스 (모델 호출 포함)
│   │   └── slot_filler.dart            # 의도에 따른 슬롯 채우기 로직

│   ├── dialog_manager/

│   ├── tts/

│   ├── auth/
│
│   └── transfer/
│
├── presentation/                      # ViewModel, UI 상태관리(프론트엔드 전용)
│   ├── constants/
│   ├── logger.dart
│   ├── app_config.dart
│   └── app_theme.dart
│
├── utils/                     # 공통 유틸 함수 (프론트엔드 전용)
│   ├── network/
│   │   └── api.dart
│   └── helpers/
│       └── deviceInfo.dart
│       └── timeLogger.dart
│
└── main.dart                  # 앱 진입점


```

## 📂 3. 사용 방법

1. Flutter 환경 구성: flutter doctor로 기본 셋업 확인

```bash
flutter doctor
```

2. llama.cpp 서브모듈 설치

```bash
cd $(git rev-parse --show-toplevel)
git submodule sync
git submodule update --init --recursive --force
```

3. pubspec.yaml에 의존성 확인 후:

```bash
cd frontend
flutter pub get
flutter run
```

## 📂 4. STT 방식 교체 방법

- frontend\lib\modules\1stt\stt_provider.dart 내

```
final sttViewModelProvider = ChangeNotifierProvider<SttViewModel>((ref) {
  //(1)Google API : SttService (2)Whisper API : SttServiceWhisper로 고치기
  final useCase = ListenAndTranscribe(SttServiceWhisper());
  return SttViewModel(useCase);
});
```

(1) Google API

```
final sttViewModelProvider = ChangeNotifierProvider<SttViewModel>((ref) {
  //(1)Google API : SttService (2)Whisper API : SttServiceWhisper로 고치기
  final useCase = ListenAndTranscribe(SttService());
  return SttViewModel(useCase);
});
```

(2) Whisper 배치 처리 구현

```
final sttViewModelProvider = ChangeNotifierProvider<SttViewModel>((ref) {
  //(1)Google API : SttService (2)Whisper API : SttServiceWhisper로 고치기
  final useCase = ListenAndTranscribe(SttServiceWhisper());
  return SttViewModel(useCase);
});
```

## 📂 5. Whisper 모델 교체 방법(현재 baseQ8_0)

- frontend\lib\modules\1stt\stt_service_whisper.dart 내

```
 whisper = Whisper(
      // 하단에 WhisperModel.어쩌고로 바꾸기
      model: WhisperModel.baseQ8_0,
      downloadHost: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main",
);
```

## 📂 6. sLMs 모델 교체 방법1 (현재 Qwen2.5-0.5B-Instruct-GGUF)

- frontend\lib\modules\1stt\stt_service_whisper.dart 내

```
 // Hugging Face 모델 URL 교체체
  final url =
      "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/$modelName";

```

- frontend\lib\modules\1stt\stt_service_whisper.dart 내

```
//언어모델 프롬프트 수정정
class QwenPromptFormat extends PromptFormat {
  QwenPromptFormat()
    : super(
        PromptFormatType.chatml,
        inputSequence: "<|im_start|>user\n",
        outputSequence: "<|im_end|>\n<|im_start|>assistant\n",
        systemSequence: "<|im_start|>system\n",
        stopSequence: "<|im_end|>",
      );

  @override
  String formatPrompt(String prompt) {
    return """
<|im_start|>system
You are a helpful assistant.
<|im_end|>
<|im_start|>user
$prompt
<|im_end|>
<|im_start|>assistant
""";
  }
}

```

## 📞 문의 및 기여

본 프로젝트는 연구/개발 목적의 음성 인터페이스 설계 기반으로 작성되었습니다.

관심 있으신 분은 자유롭게 PR 또는 Issue로 피드백 주셔도 좋습니다.

seonmin8284@gmail.com
