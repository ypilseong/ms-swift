#!/bin/bash

YAML_FILE="yaml/qwen2.5_7b_full_sft.yaml"
CUDA_DEVICES="0,1,2,3"
LOG_NAME="qwen2.5_7b_full_sft"

NUM_GPUS=$(echo $CUDA_DEVICES | tr ',' '\n' | wc -l)
mkdir -p logs
CUDA_VISIBLE_DEVICES=$CUDA_DEVICES NPROC_PER_NODE=$NUM_GPUS swift sft $YAML_FILE 2>&1 | tee logs/${LOG_NAME}.log
