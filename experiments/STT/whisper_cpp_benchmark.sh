#!/bin/bash

# whisper.cpp 벤치마크 테스트 스크립트
# 한국어 음성 인식 성능 및 속도 테스트

set -e  # 오류 발생 시 스크립트 중단

echo "==============================================="
echo "whisper.cpp 한국어 음성 인식 벤치마크 테스트 시작"
echo "==============================================="

# 시스템 정보 출력
echo "시스템 정보:"
echo "OS: $(uname -s)"
echo "프로세서: $(uname -p)"
lscpu | grep "CPU(s)" | head -n 1
free -h | grep Mem
echo "-------------------------------------------"

# 현재 디렉토리 확인
CURRENT_DIR=$(pwd)
echo "현재 작업 디렉토리: $CURRENT_DIR"

# 작업 디렉토리 설정
WORK_DIR="/tmp/whisper_cpp_test"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 오디오 파일 설정 (절대 경로 사용)
AUDIO_FILE="$CURRENT_DIR/ElevenLabs_sample.mp3"
echo "오디오 파일 경로: $AUDIO_FILE"

if [ ! -f "$AUDIO_FILE" ]; then
    echo "오류: $AUDIO_FILE 파일을 찾을 수 없습니다."
    exit 1
fi
cp $AUDIO_FILE $WORK_DIR/audio.mp3
echo "오디오 파일 복사 완료: $WORK_DIR/audio.mp3"

# 필요한 패키지 설치 확인
echo "필요한 패키지 확인 중..."
for pkg in git make cmake g++ bc; do
    if ! command -v $pkg &> /dev/null; then
        echo "경고: $pkg 명령을 찾을 수 없습니다. 설치가 필요할 수 있습니다."
    fi
done

# whisper.cpp 설치
if [ ! -d "whisper.cpp" ]; then
    echo "whisper.cpp 저장소 클론..."
    git clone https://github.com/ggerganov/whisper.cpp.git
    cd whisper.cpp
    
    echo "whisper.cpp 빌드 중..."
    make
else
    echo "이미 존재하는 whisper.cpp 저장소 사용"
    cd whisper.cpp
    git pull
    
    # clean 없이 바로 빌드
    echo "whisper.cpp 빌드 중..."
    make
fi

# 테스트할 모델 목록 (한국어 지원)
MODELS=("tiny" "base" "small" "medium" "large-v1" "large-v2" "large-v3" "large-v3-turbo")

# 결과 저장 파일
RESULTS_FILE="$WORK_DIR/whisper_cpp_results_all_ko.txt"
echo "# Whisper.cpp 벤치마크 결과 ($(date))" > $RESULTS_FILE
echo "오디오 파일: $AUDIO_FILE" >> $RESULTS_FILE
echo "-------------------------------------------" >> $RESULTS_FILE

# 각 모델 다운로드 및 테스트
for MODEL in "${MODELS[@]}"; do
    echo "-------------------------------------------"
    echo "모델 테스트: $MODEL"

    # 모델 파일 경로 설정
    MODEL_PATH="models/ggml-$MODEL.bin"
    MODEL_DIR="$(dirname "$MODEL_PATH")"
    mkdir -p "$MODEL_DIR" # 모델 디렉토리 생성 확인
    
    # 모델 다운로드 (기본 FP32 모델)
    if [ ! -f "$MODEL_PATH" ]; then
        echo "모델 다운로드 중: $MODEL"
        bash ./models/download-ggml-model.sh $MODEL
        
        # 다운로드 확인
        if [ ! -f "$MODEL_PATH" ]; then
            echo "오류: 모델 $MODEL 다운로드 실패"
            # 추가 다운로드 시도 로직 (필요시)
        fi
    else
        echo "기존 모델 사용: $MODEL"
    fi
    
    # 실행 파일 확인 (이전 로직 유지)
    if [ -f "./whisper-cli" ]; then
        MAIN_EXEC="./whisper-cli"
    elif [ -f "./build/bin/whisper-cli" ]; then
        MAIN_EXEC="./build/bin/whisper-cli"
    else
        echo "오류: whisper-cli 실행 파일을 찾을 수 없습니다."
        find . -name "whisper-cli" -type f
        exit 1
    fi
    
    # --- FP32 모델 테스트 ---
    echo "[$MODEL] FP32 모델 테스트 중..."
    start_time=$(date +%s.%N)
    RESULT=$("${MAIN_EXEC}" -m "$MODEL_PATH" -f ../audio.mp3 -l ko -nt -np)
    end_time=$(date +%s.%N)
    runtime=$(echo "$end_time - $start_time" | bc)
    OUTPUT_TEXT=$(echo "$RESULT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\n')
    echo "[$MODEL] FP32 모델 처리 시간: $runtime 초"
    echo "[$MODEL] 출력 텍스트: $OUTPUT_TEXT"
    echo "$MODEL (FP32): ${runtime}초 - \"$OUTPUT_TEXT\"" >> $RESULTS_FILE
    
    # --- 8-bit 양자화 모델 테스트 ---
    MODEL_8BIT_PATH="models/ggml-$MODEL-q8_0.bin"
    if [[ "$MODEL" == "large-v1" || "$MODEL" == "large-v3" ]]; then
        echo "[$MODEL] 8-bit 양자화 모델은 제공되지 않으므로 건너뛰도록 수정되었습니다."
        echo "$MODEL (8-bit): N/A" >> $RESULTS_FILE
    else
        if [ ! -f "$MODEL_8BIT_PATH" ]; then
            echo "8-bit 양자화 모델 다운로드 중: $MODEL-q8_0"
            bash ./models/download-ggml-model.sh $MODEL-q8_0
            # 다운로드 확인 로직 (필요시)
        else
            echo "기존 8-bit 양자화 모델 사용: $MODEL-q8_0"
        fi
        
        echo "[$MODEL] 8-bit 양자화 모델 테스트 중..."
        start_time=$(date +%s.%N)
        RESULT=$("${MAIN_EXEC}" -m "$MODEL_8BIT_PATH" -f ../audio.mp3 -l ko -nt -np)
        end_time=$(date +%s.%N)
        runtime=$(echo "$end_time - $start_time" | bc)
        OUTPUT_TEXT=$(echo "$RESULT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\n')
        echo "[$MODEL] 8-bit 양자화 모델 처리 시간: $runtime 초"
        echo "[$MODEL] 출력 텍스트: $OUTPUT_TEXT"
        echo "$MODEL (8-bit): ${runtime}초 - \"$OUTPUT_TEXT\"" >> $RESULTS_FILE
    fi

    # --- 5-bit 양자화 모델 테스트 ---
    QUANT_MODEL_SUFFIX=""
    if [[ "$MODEL" == "tiny" || "$MODEL" == "base" || "$MODEL" == "small" ]]; then
        QUANT_MODEL_SUFFIX="q5_1"
    elif [[ "$MODEL" == "medium" || "$MODEL" == "large-v2" || "$MODEL" == "large-v3" || "$MODEL" == "large-v3-turbo" ]]; then
        QUANT_MODEL_SUFFIX="q5_0"
    fi

    if [[ -z "$QUANT_MODEL_SUFFIX" ]]; then # large-v1 등 5bit 모델 없는 경우
        echo "[$MODEL] 5-bit 양자화 모델은 제공되지 않으므로 건너뛰도록 수정되었습니다."
        echo "$MODEL (5-bit): N/A" >> $RESULTS_FILE
    else
        MODEL_5BIT_PATH="models/ggml-$MODEL-${QUANT_MODEL_SUFFIX}.bin"
        if [ ! -f "$MODEL_5BIT_PATH" ]; then
            echo "5-bit 양자화 모델 다운로드 중: $MODEL-${QUANT_MODEL_SUFFIX}"
            bash ./models/download-ggml-model.sh $MODEL-${QUANT_MODEL_SUFFIX}
            # 다운로드 확인 로직 (필요시)
        else
            echo "기존 5-bit 양자화 모델 사용: $MODEL-${QUANT_MODEL_SUFFIX}"
        fi
        
        echo "[$MODEL] 5-bit 양자화 모델 (${QUANT_MODEL_SUFFIX}) 테스트 중..."
        start_time=$(date +%s.%N)
        RESULT=$("${MAIN_EXEC}" -m "$MODEL_5BIT_PATH" -f ../audio.mp3 -l ko -nt -np)
        end_time=$(date +%s.%N)
        runtime=$(echo "$end_time - $start_time" | bc)
        OUTPUT_TEXT=$(echo "$RESULT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\n')
        echo "[$MODEL] 5-bit 양자화 모델 (${QUANT_MODEL_SUFFIX}) 처리 시간: $runtime 초"
        echo "[$MODEL] 출력 텍스트: $OUTPUT_TEXT"
        echo "$MODEL (5-bit, ${QUANT_MODEL_SUFFIX}): ${runtime}초 - \"$OUTPUT_TEXT\"" >> $RESULTS_FILE
    fi
    
    echo "-------------------------------------------"
done

echo "==============================================="
echo "테스트 완료! 결과 파일: $RESULTS_FILE"
echo "==============================================="

# 결과 출력
cat $RESULTS_FILE
# 원본 디렉토리로 결과 복사
cp $RESULTS_FILE "$CURRENT_DIR/"
echo "결과 파일이 원본 디렉토리($CURRENT_DIR)에 복사되었습니다." 