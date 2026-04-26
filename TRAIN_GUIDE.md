# ms-swift 학습 가이드

## 목차
1. [프로젝트 구조](#1-프로젝트-구조)
2. [컨테이너 실행](#2-컨테이너-실행)
3. [데이터 추가 방법](#3-데이터-추가-방법)
4. [데이터 구조](#4-데이터-구조)
5. [YAML 설정 파일 작성법](#5-yaml-설정-파일-작성법)
6. [학습 실행 방법](#6-학습-실행-방법)
7. [명령어 정리](#7-명령어-정리)

---

## 1. 프로젝트 구조

```
ms-swift/
├── data/                        # 학습 데이터 파일
│   └── my_dataset.json
├── models/                      # 로컬 모델 저장 위치 (볼륨 마운트, 이미지 제외)
│   └── Qwen3.5-4B/
├── saves/                       # 학습 완료 체크포인트 저장 위치 (볼륨 마운트, 이미지 제외)
├── yaml/                        # 학습 설정 파일 모음
│   └── qwen2.5_7b_full_sft.yaml
├── logs/                        # 학습 로그 저장 위치
├── train.sh                     # 학습 실행 스크립트
├── docker/
│   └── docker-cuda/
│       ├── Dockerfile
│       └── docker-compose.yml
└── examples/                    # 참고용 예시 파일 모음
    └── train/
```

---

## 2. 컨테이너 실행

### docker-compose로 실행

```bash
# 컨테이너 시작
docker compose -f docker/docker-cuda/docker-compose.yml up -d

# 컨테이너 중지
docker compose -f docker/docker-cuda/docker-compose.yml down

# 컨테이너 접속
docker exec -it ms-swift bash
```

### docker-compose.yml 전체 내용

```yaml
services:
  ms-swift:
    build:
      dockerfile: ./docker/docker-cuda/Dockerfile
      context: ../..
      args:
        PIP_INDEX: https://pypi.org/simple
    container_name: ms-swift
    ipc: host
    tty: true
    stdin_open: true
    command: bash -c "tail -f /dev/null"
    environment:
      - WANDB_API_KEY=<본인의 wandb API 키를 입력하세요>
      - WANDB_ENTITY=<본인의 wandb 팀 또는 조직명>
    deploy:
      resources:
        reservations:
          devices:
          - driver: nvidia
            count: "all"
            capabilities: [ gpu ]
    volumes:
      - ../..:/app          # 프로젝트 루트를 컨테이너 /app에 마운트
    restart: unless-stopped
```

### 주요 설정 항목

| 항목 | 설명 |
|---|---|
| `WANDB_API_KEY` | wandb.ai/settings 에서 발급한 API 키 |
| `WANDB_ENTITY` | wandb 팀 또는 조직명 |
| `count: "all"` | 서버의 모든 GPU 사용. 특정 GPU만 사용 시 숫자로 지정 |
| `volumes` | 호스트 프로젝트 루트 → 컨테이너 `/app` 마운트 |
| `restart: unless-stopped` | 컨테이너 비정상 종료 시 자동 재시작 |

> **볼륨 마운트**: 호스트의 `models/`, `data/`, `yaml/`, `saves/`, `logs/` 등이 컨테이너 내부 `/app/`에 실시간으로 반영됩니다.

> **환경변수 변경 시 주의**: `WANDB_API_KEY` 등 docker-compose.yml의 환경변수를 수정한 경우, 컨테이너를 반드시 재시작해야 반영됩니다.
> ```bash
> docker compose -f docker/docker-cuda/docker-compose.yml down
> docker compose -f docker/docker-cuda/docker-compose.yml up -d
> ```

---

## 3. 데이터 추가 방법

학습 데이터 파일(`.json`)을 `data/` 폴더에 넣습니다.

```
data/
└── my_dataset.json
```

yaml 파일의 `dataset` 항목에 경로를 지정합니다.

```yaml
dataset:
  - data/my_dataset.json
```

ModelScope Hub 또는 HuggingFace Hub의 데이터셋도 직접 사용할 수 있습니다.

```yaml
dataset:
  - AI-ModelScope/alpaca-gpt4-data-zh#500   # ModelScope Hub (샘플 수 제한)
  - swift/self-cognition                     # ms-swift 공식 데이터셋
```

---

## 4. 데이터 구조

ms-swift는 다양한 포맷을 지원합니다.

### Alpaca 포맷 (기본)

```json
[
  {
    "instruction": "다음 문장을 영어로 번역하세요.",
    "input": "오늘 날씨가 맑습니다.",
    "output": "The weather is clear today."
  }
]
```

### ShareGPT 포맷 (멀티턴)

```json
[
  {
    "conversations": [
      {"role": "user", "content": "안녕하세요!"},
      {"role": "assistant", "content": "안녕하세요! 무엇을 도와드릴까요?"}
    ]
  }
]
```

### CoT (Chain-of-Thought) 포맷

`<think>` 태그를 포함한 추론 데이터입니다.

```json
[
  {
    "instruction": "1+1은 무엇인가요?",
    "output": "<think>\n1과 1을 더하면 2입니다.\n</think>\n\n답은 2입니다."
  }
]
```

---

## 5. YAML 설정 파일 작성법

yaml 파일은 `yaml/` 폴더에 저장합니다.

```yaml
### model
model: models/Qwen3.5-4B          # 로컬 경로 또는 Hub ID
torch_dtype: bfloat16

### method
tuner_type: full                   # full / lora / freeze / adalora

### dataset
dataset:
  - data/my_dataset.json
max_length: 2048                   # 최대 토큰 길이
dataset_num_proc: 4

### output
output_dir: saves/qwen3.5-4b/full/sft
logging_steps: 10
save_steps: 100                    # 단일 정수: N 스텝마다 저장
save_total_limit: 5                # 최대 저장 체크포인트 수
report_to: none                    # none / wandb / tensorboard / swanlab

### train
num_train_epochs: 3
per_device_train_batch_size: 1
per_device_eval_batch_size: 1
learning_rate: 1.0e-5
gradient_accumulation_steps: 2
lr_scheduler_type: cosine          # cosine / linear / constant
warmup_ratio: 0.05
dataloader_num_workers: 4
deepspeed: zero3                   # zero0 / zero1 / zero2 / zero3 / zero2_offload
```

### save_steps 설정

#### 단일 정수 (기본) — N 스텝마다 주기적으로 저장

```yaml
save_steps: 500
```

#### 리스트 — 특정 스텝에서만 저장

```yaml
save_steps:
  - 100
  - 300
  - 500
```

리스트로 지정하면 해당 스텝에서만 체크포인트를 저장합니다. 학습 종료 시점에는 항상 저장됩니다.

### wandb 로깅 설정

```yaml
report_to: wandb
```

wandb를 사용하려면 `docker/docker-cuda/docker-compose.yml`에 API 키를 먼저 설정해야 합니다.

```yaml
environment:
  - WANDB_API_KEY=실제_API_키_입력
  - WANDB_ENTITY=wandb_팀_또는_조직명
```

> **주의**: API 키를 변경한 후 반드시 컨테이너를 재시작해야 반영됩니다.
> wandb API 키는 [wandb.ai/settings](https://wandb.ai/settings)에서 발급합니다.

### tuner_type 비교

| 타입 | 설명 | 메모리 | 권장 상황 |
|---|---|---|---|
| `full` | 전체 파라미터 업데이트 | 높음 | 데이터가 충분할 때 |
| `lora` | LoRA 어댑터만 학습 | 낮음 | 빠른 실험, 리소스 부족 |
| `freeze` | 일부 레이어만 학습 | 중간 | 특정 레이어만 튜닝할 때 |

### DeepSpeed 설정 비교

| 설정 | 설명 | 권장 상황 |
|---|---|---|
| `zero0` | DeepSpeed 미사용 | 단일 GPU |
| `zero1` | 옵티마이저 상태만 분산 | 메모리 여유 있을 때 |
| `zero2` | 옵티마이저 + 그래디언트 분산 | 일반적인 다중 GPU |
| `zero3` | 파라미터까지 완전 분산 | 대형 모델, 메모리 부족 |
| `zero2_offload` | zero2 + CPU 오프로드 | GPU 메모리 매우 부족 |

### LoRA 사용 시 추가 설정

```yaml
tuner_type: lora
lora_rank: 8
lora_alpha: 32
target_modules: all-linear
```

### 체크포인트에서 재개

```yaml
resume_from_checkpoint: saves/qwen3.5-4b/full/sft/checkpoint-300
```

---

## 6. 학습 실행 방법

### train.sh 설정

`train.sh` 상단의 변수를 수정하여 학습을 설정합니다.

```bash
YAML_FILE="yaml/qwen2.5_7b_full_sft.yaml"   # 학습 설정 yaml 파일 경로
CUDA_DEVICES="0,1,2,3"                        # 사용할 GPU 번호 (쉼표 구분)
LOG_NAME="qwen2.5_7b_full_sft"               # 로그 파일명 (logs/LOG_NAME.log)
```

`CUDA_DEVICES`에 GPU 번호를 지정하면 `NUM_GPUS`는 자동으로 계산됩니다.

| 예시 | 설명 |
|---|---|
| `CUDA_DEVICES="0"` | GPU 0번 1개 사용 |
| `CUDA_DEVICES="0,1"` | GPU 0,1번 2개 사용 |
| `CUDA_DEVICES="0,1,2,3"` | GPU 0~3번 4개 사용 |

### 컨테이너 내부에서 학습 실행

```bash
# 컨테이너 접속
docker exec -it ms-swift bash

# /app 디렉토리로 이동
cd /app

# 포그라운드 실행 (터미널 종료 시 중단됨)
./train.sh

# 백그라운드 실행 (터미널 종료 후에도 지속)
nohup ./train.sh &

# 학습 로그 실시간 확인
tail -f logs/qwen2.5_7b_full_sft.log
```

### swift CLI 직접 실행 (단일 GPU)

```bash
CUDA_VISIBLE_DEVICES=0 swift sft yaml/qwen2.5_7b_full_sft.yaml
```

### swift CLI 직접 실행 (다중 GPU)

```bash
CUDA_VISIBLE_DEVICES=0,1,2,3 NPROC_PER_NODE=4 swift sft yaml/qwen2.5_7b_full_sft.yaml
```

---

## 7. 명령어 정리

### Docker

```bash
# 컨테이너 시작
docker compose -f docker/docker-cuda/docker-compose.yml up -d

# 컨테이너 중지 및 제거
docker compose -f docker/docker-cuda/docker-compose.yml down

# 컨테이너 재시작 (환경변수 변경 후 필수)
docker compose -f docker/docker-cuda/docker-compose.yml down && \
docker compose -f docker/docker-cuda/docker-compose.yml up -d

# 컨테이너 접속
docker exec -it ms-swift bash

# 이미지 빌드
docker build -f docker/docker-cuda/Dockerfile -t ms-swift:latest .

# 실행 중인 컨테이너 확인
docker ps

# 이미지 목록 확인
docker images
```

### 학습

```bash
# 포그라운드 실행
./train.sh

# 백그라운드 실행
nohup ./train.sh &

# 로그 실시간 확인
tail -f logs/qwen2.5_7b_full_sft.log

# 학습 프로세스 확인
ps aux | grep swift

# 학습 중단
kill <PID>
```

### GPU 상태 확인

```bash
# GPU 사용량 실시간 모니터링
watch -n 1 nvidia-smi

# GPU 메모리 사용량 확인
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

### LoRA 모델 병합 (학습 후)

```bash
swift merge-lora --model models/Qwen3.5-4B --adapter_path saves/qwen3.5-4b/lora/sft/checkpoint-500
```
