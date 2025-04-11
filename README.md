# MCP_Voice_Transfer

MCP_Voice_Transfer는 **모바일 음성 명령 기반 송금 시스템**을 목표로 합니다.  
사용자는 음성으로 송금을 요청하고, 시스템은 음성 인식(STT) → 의도 분석(NLU) → 이상거래 탐지(FDS) → 인증 → 송금을 수행합니다.

- **주요 특징**:
  - Android/Flutter 기반 음성 UI (Wakeword + STT + TTS)
  - FastAPI 기반 백엔드 & 모듈화 아키텍처
  - LLM 기반 의도 분석 및 RAG 연계
  - 이상거래 탐지 및 음성 인증 탑재
  - 실시간 스트리밍 추론 + 온디바이스 경량화 모델 실험


## 전체 흐름 예시
![dLLVQnfF57sVJt7nQGMJ_7wlWYMM8WJI6h3jKryMtJPIkygwba8fsCG4gHPCeoYfiGPCOe81DNzg8P-cZpkptw7NyRfsOgL_V36vS-wPS-wS6LUpjcxPkLSffiVjj0LYgoSEpaIhmZ9OJyQJ6TsqmHT9vMpRmENQ0BGdQo0A7T6k-NsWPo6SoQZWi9cmqia4n0phTJ9kI13zhGBNrnyYKvCF2w15zAmTtbYRKEA](https://github.com/user-attachments/assets/50a5d7e4-082b-4570-92b2-db86f93f86d5)
1. 플러터 앱 내 음성 송금 기능 ON 설정
2. 사용자: "헤이 플러터, 철수한테 만 원 보내줘"
3. Android Service가 웨이크워드 감지 + 음성 인식 시작
4. 음성 텍스트 → LLM 서버로 전달
5. LLM 서버: 의도 감지 → { intent: 송금, 대상: 철수, 금액: 10000 }
6. 이상거래탐지 내 송금 내역 전달
7. 음성 인증
8. 앱 or Android Service가 송금 서버에 API 호출
9. 송금 성공 → 결과를 Android TTS로 읽어줌 ("철수에게 1만 원 송금했습니다")
10. 앱이 있다면 → 송금 내역 저장 + UI로 보여줌

</br>


## 📌 기술 스택

- **백엔드**: FastAPI, SQLite or Redis
- **LLM 연동**: ???Ollama + EXAONE-DEEP
- **모바일**: Flutter or Android(Java/Kotlin)
- **음성 처리**: ???Android STT / TTS API
- **MCP**: 모델 호출 인터페이스 규약 기반 REST API

</br>

## 📊 시스템 아키텍처 개요
![image](https://github.com/user-attachments/assets/43f9beb7-c5c7-4e42-bec5-8de5b2c4c924)

</br>

## 📑 상세 문서 보기

- [모델 성능 테스트 (STT, NLU, FDS)](./docs/model_evaluation.md)
- [백엔드 API 설명서](./backend/README.md)
- [모바일 앱 구조](./mobile/README.md)


</br>



---

## 👥 팀 역할 분담표

| 이름     | 역할                        | 주요 업무                                                                | 연락처 | 
|----------|-----------------------------|----------------------------------------------------------------------------------------|--|
| 김선민   | 🧭 총괄 / 시스템 아키텍처 / 풀스택 개발  | 전체 시스템 설계, FastAPI 기반 백엔드 및 Flutter 앱 전체 개발, 폴더 구조/도커화, 음성 송금 기능 구성 |seonmin8284@gmail.com|
| 임은서   | 🔍 이상거래탐지(FDS)         | 이상거래 알고리즘 조사, 금융권 기준 탐지 룰 정리, FDS 회의 주도                      ||
| 김서령   | 🔍 이상거래탐지(FDS)         | FDS 알고리즘 공동 담당, KYC 기반 설계 구상 중, 내부 테스트 협의 예정                 ||
| 병하     | 🧠 음성 인식 (STT / TTS)     | Whisper 기반 STT 성능 테스트, WER/CER 측정, 온디바이스 모델 전환 고려               ||
| 하진     | 🤖 경량 LLM (sLMs / NLU)     | phi3-mini 기반 NLU 처리, 의도 분석/슬롯 추출 설계, RAG 연동 고려                    ||
| 백두현   | 🔐 보이스 인증 / 화자인식    | ecapa-tdnn 등 경량 음성 인증 모델 탐색, 안티스푸핑 대응 검토                         ||
| 변민찬   | 💡 RAG 흐름  | 서버 기반 RAG 흐름 제안, 의도별 발화 시나리오 설계, LLM 연동 구조 논의              ||
| 강혜리   | ⚙️ MLOps / 배포 환경 설계   | 서비스 배포 및 운영 자동화 파이프라인 구축 예정, 클라우드 구조 논의 예정             ||



## 🛡️ 보안 주의

> 본 시스템은 실제 금융기관 API를 사용하지 않으며,  
> 모든 송금 처리와 인증은 **더미 데이터 기반 시뮬레이션**으로 동작합니다.
