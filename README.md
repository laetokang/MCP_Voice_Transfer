# MCP_Voice_Transfer

MCP_Voice_Transfer는 **모바일 음성 명령 기반 송금 시스템**을 목표로 합니다.  

## 주요 특징

* **음성 기반 인터페이스**: Android/Flutter 환경에서 Wakeword 감지. STT + TTS를 통한 자연스러운 사용자 경험 제공
* **효율적인 백엔드**: FastAPI 기반의 비동기 처리 및 모듈화 아키텍처 설계
* **LLM**: LLM 기반 의도 분석 및 RAG 연계
* **이상탐지**: 이상거래 탐지 및 음성 인증 탑재
* **실시간 처리**: 실시간 추론 및 온디바이스 경량 모델 적용을 통해 빠른 응답 제공

- **[9] 인증 단계 모킹**
  - 예시: 지문 인증 or 인증 코드 입력 흐름을 가짜 토큰으로 대체

---

### [3단계] 모바일 연동 및 OS 확장

- **[10] Android STT + TTS 연동**
  - STT: 사용자 발화 → 텍스트 변환
  - TTS: 서버 응답 → 음성 안내로 출력

- **[11] FastAPI 연동 Android 클라이언트**
  - Retrofit 등으로 `/intent`, `/transfer` 호출
  - 챗 UI 또는 음성 기반 UI 제공

- **[12] OS 서비스로 확장**
  - `VoiceInteractionService` 활용
  - 웨이크업 키워드 ("아라야") → 바로 송금 대화 시작 가능


<br>

## 2. 모델 성능 검증

###  1. STT 모듈 (음성 → 텍스트 변환)

- **검증 목표**: 음성 입력에 대해 정확한 텍스트 변환 수행 여부 확인

- **평가 지표**:
  - `WER (Word Error Rate, 어절 오류율)`: 띄어쓰기 단위의 오류율. NLU 등 후속 처리 성능과 연관성 파악에 용이.
    - 계산 공식: `WER = (S + I + D) / N`
      - `S`: 대체된 어절 수 (Substitutions)
      - `I`: 잘못 삽입된 어절 수 (Insertions)
      - `D`: 누락된 어절 수 (Deletions)
      - `N`: 원문(정답)의 총 어절 수 (Number of words in reference)
  - `CER (Character Error Rate, 음절/글자 오류율)`: 글자 단위의 오류율. 띄어쓰기 오류에 덜 민감하며 순수 음향 모델 성능 평가에 유용.
    - 계산 공식: `CER = (S + I + D) / N`
      - `S`: 대체된 글자 수 (Substitutions)
      - `I`: 잘못 삽입된 글자 수 (Insertions)
      - `D`: 누락된 글자 수 (Deletions)
      - `N`: 원문(정답)의 총 글자 수 (Number of characters in reference)

- **예시**:
| 실제 문장              | STT 결과                         | WER |
|------------------------|----------------------------------|-----|
| 엄마한테 오만원 보내줘 | 엄마 한테 5만 원 보내 줘         | ? |


## 전체 시스템 흐름 
![dLLVQnfF57sVJt7nQGMJ_7wlWYMM8WJI6h3jKryMtJPIkygwba8fsCG4gHPCeoYfiGPCOe81DNzg8P-cZpkptw7NyRfsOgL_V36vS-wPS-wS6LUpjcxPkLSffiVjj0LYgoSEpaIhmZ9OJyQJ6TsqmHT9vMpRmENQ0BGdQo0A7T6k-NsWPo6SoQZWi9cmqia4n0phTJ9kI13zhGBNrnyYKvCF2w15zAmTtbYRKEA](https://github.com/user-attachments/assets/50a5d7e4-082b-4570-92b2-db86f93f86d5)
1.  **음성 명령**: 사용자가 앱에서 "헤이 플러터, 철수한테 만 원 보내줘" 라고 말합니다.
2.  **Wakeword & STT**: Android 서비스가 Wakeword("헤이 플러터")를 감지하고 음성 인식을 시작하여 텍스트로 변환합니다.
3.  **NLU (의도 분석)**: 변환된 텍스트를 백엔드 LLM 서버로 전달하여 `송금` 의도와 `대상: 철수`, `금액: 10000` 등의 정보를 추출합니다.
4.  **FDS (이상거래 탐지)**: 추출된 송금 정보를 기반으로 이상 거래 여부를 탐지합니다.
5.  **음성 인증**: 등록된 사용자의 목소리가 맞는지 화자 인증을 수행합니다.
6.  **송금 실행**: 모든 검증이 완료되면, 송금 서버에 API를 호출하여 (시뮬레이션) 송금을 실행합니다.
7.  **결과 안내 (TTS)**: 송금 결과를 "철수에게 1만 원 송금했습니다" 와 같이 음성으로 안내합니다.
8.  **UI 업데이트**: 앱 화면에 송금 내역을 표시하고 저장합니다.

</br>


## 🛠️ 기술 스택

* **Backend**: FastAPI (Python), SQLite (기본), Redis (캐싱/세션 관리용 고려)
* **LLM & NLU**: Ollama (phi3-mini 등 sLM 기반), EXAONE-DEEP (LG AI Research) 연동 고려
* **Frontend**: Flutter (Cross-platform), Android Native (음성 처리 연동)
* **Voice**: Android STT/TTS API, On-Device STT 모델 (연구/개발 중)
* **FDS/Auth**: Rule-based FDS, ECAPA-TDNN 등 경량 화자 인식 모델
* **Infra**: Docker, (추후 MLOps 파이프라인 구축 예정)
* **MCP**: 표준 모델 호출 인터페이스 규약 기반 REST API 설계

</br>

## 📊 시스템 아키텍처 개요
![image](https://github.com/user-attachments/assets/719b81a1-08b0-47b4-9286-baf9e49149e6)


</br>

## 📑 상세 문서 보기

- [모델 성능 테스트 (STT, NLU, FDS)](./backend/README.md)
- [백엔드 API 설명서](./backend/README.md)
- [모바일 앱 구조](./frontend/README.md)


</br>



---

## 👥 팀 역할 분담

| 이름     | 역할                        | 주요 업무                                                                | 연락처 | 
|----------|-----------------------------|----------------------------------------------------------------------------------------|--|
| 김선민   | 🧭 총괄 / 시스템 아키텍처 / 풀스택 개발  | 전체 시스템 설계, FastAPI 기반 백엔드 및 Flutter 앱 전체 개발, 폴더 구조/도커화, 음성 송금 기능 구성 |seonmin8284@gmail.com|
| 임은서   | 🔍 이상거래탐지(FDS)         | 이상거래 알고리즘 조사, 금융권 기준 탐지 룰 정리, FDS 회의 주도                      |cmdysp@naver.com|
| 김서령   | 🔍 이상거래탐지(FDS)         | FDS 알고리즘 공동 담당, KYC 기반 설계 구상 중, 내부 테스트 협의 예정                 ||
| 강병하   | 🧠 음성 AI (STT / TTS)   | STT/TTS API 성능 테스트, 온디바이스 STT 담당, 음성 전,후처리,                       |kbh0287@gmail.com|
| 하진     | 🤖 경량 LLM (sLMs / NLU)     | phi3-mini 기반 NLU 처리, 의도 분석/슬롯 추출 설계, RAG 연동 고려                    |hajin0717@gmail.com|
| 백두현   | 🔐 보이스 인증 / 화자인식    | ecapa-tdnn 등 경량 음성 인증 모델 탐색, 안티스푸핑 대응 검토                         ||
| 변민찬   | 💡 RAG 흐름  | 서버 기반 RAG 흐름 제안, 의도별 발화 시나리오 설계, LLM 연동 구조 논의              ||
| 강혜리   | ⚙️ MLOps / 배포 환경 설계   | 서비스 배포 및 운영 자동화 파이프라인 구축 예정, 클라우드 구조 논의 예정             ||



## 🛡️ 보안 주의

> 본 시스템은 실제 금융기관 API를 사용하지 않으며,  
> 모든 송금 처리와 인증은 **더미 데이터 기반 시뮬레이션**으로 동작합니다.
