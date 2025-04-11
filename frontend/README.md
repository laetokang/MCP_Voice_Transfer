# 🗣️ MCP Voice Transfer System

Flutter 기반 음성 송금 인터페이스 시스템입니다.  
사용자의 음성을 인식하고, 의도와 슬롯을 추출하여 인증 및 송금을 처리하고 음성으로 응답합니다.

---

## ✅ 1. 프로젝트 아키텍처

### 🎯 구성 원칙

- Clean Architecture 기반
- Feature-first modular 구조
- View ↔ Controller ↔ Service 계층 분리
- 추상화(`Interface`) 기반으로 유연한 구현체 교체 가능

---

### 🔁 전체 흐름 요약

```plaintext
사용자 음성 입력
    ↓
[features/stt]         : 음성 → 텍스트 변환
    ↓
[features/nlu]         : 의도(Intent), 슬롯(Slot) 추출
    ↓
[features/dialog]      : 대화 상태 관리, 슬롯 채움
    ↓
[features/voice_auth]  : 화자 인증 여부 판단 (Voiceprint 비교 등)
    ↓
[features/tts]         : 응답 텍스트를 음성으로 변환 (TTS)
```

### ✅ 2. 폴더 구조

```
lib/
├── features/
│   ├── stt/                    # STT 기능 (음성 인식)
│   │   ├── stt_interface.dart
│   │   ├── stt_service.dart
│   │   └── stt_controller.dart
│
│   ├── nlu/                    # 자연어 이해 (의도 및 슬롯 분석)
│   │   ├── nlu_model.dart
│   │   └── nlu_service.dart
│
│   ├── dialog/                 # 대화 흐름 관리 (DM)
│   │   ├── dialog_manager.dart
│   │   └── slot_filler.dart
│
│   ├── voice_auth/             # 화자 인증 모듈
│   │   ├── voice_auth_interface.dart
│   │   ├── voice_auth_service.dart
│   │   └── voice_auth_controller.dart
│
│   ├── tts/                    # TTS 기능 (음성 응답)
│   │   └── tts_service.dart
│
└── main.dart                   # 앱 진입점 (UI 및 Controller 연결)
```

## 📂 사용 방법

```bash
flutter pub get
flutter run
```

## 📞 문의 및 기여

본 프로젝트는 연구/개발 목적의 음성 인터페이스 설계 기반으로 작성되었습니다.

관심 있으신 분은 자유롭게 PR 또는 Issue로 피드백 주셔도 좋습니다.

seonmin8284@gmail.com
