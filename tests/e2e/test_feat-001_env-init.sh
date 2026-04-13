#!/usr/bin/env bash
# tests/e2e/test_feat-001_env-init.sh
# feat-001 (환경 초기화) E2E 테스트
# 목적: init.sh가 정상적으로 실행되고 모든 검증을 통과하는지 확인

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=true

echo "=== feat-001 E2E 테스트: 환경 초기화 ==="

# 테스트 1: init.sh가 존재하고 실행 가능한지 확인
if [ -x "${PROJECT_ROOT}/init.sh" ]; then
  echo "PASS: init.sh 존재 및 실행 가능"
else
  echo "FAIL: init.sh가 없거나 실행 권한 없음"
  PASS=false
fi

# 테스트 2: init.sh가 종료 코드 0으로 실행되는지 확인
INIT_OUTPUT=$(bash "${PROJECT_ROOT}/init.sh" 2>&1)
INIT_EXIT=$?
if [ "${INIT_EXIT}" -eq 0 ]; then
  echo "PASS: init.sh 종료 코드 0"
else
  echo "FAIL: init.sh 종료 코드 ${INIT_EXIT}"
  PASS=false
fi

# 테스트 3: 출력에 환경 준비 완료 메시지 포함 여부 확인
if echo "${INIT_OUTPUT}" | grep -q "하네스 환경 준비 완료\|HARNESS ENVIRONMENT READY"; then
  echo "PASS: 환경 준비 완료 메시지 출력됨"
else
  echo "FAIL: 환경 준비 완료 메시지가 출력에 없음"
  PASS=false
fi

# 테스트 4: feature-list.json이 유효한 JSON인지 확인
if jq empty "${PROJECT_ROOT}/feature-list.json" 2>/dev/null; then
  echo "PASS: feature-list.json 유효한 JSON"
else
  echo "FAIL: feature-list.json이 유효한 JSON이 아님"
  PASS=false
fi

echo ""
echo "=== 테스트 결과 ==="
if [ "${PASS}" = true ]; then
  echo "PASS: feat-001 모든 테스트 통과"
  exit 0
else
  echo "FAIL: feat-001 일부 테스트 실패"
  exit 1
fi
