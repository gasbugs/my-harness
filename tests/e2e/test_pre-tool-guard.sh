#!/usr/bin/env bash
# tests/e2e/test_pre-tool-guard.sh
# pre-tool-guard 플레이스홀더 감지 테스트
# 목적: 플레이스홀더 상태에서는 보호 필드 수정이 허용되고,
#       실제 기능 상태에서는 차단되는지 확인

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="${PROJECT_ROOT}/hooks/pre-tool-guard"
PASS=true

echo "=== pre-tool-guard E2E 테스트: 플레이스홀더 감지 ==="

TMPDIR=$(mktemp -d)
TMPDIR2=$(mktemp -d)
trap 'rm -rf "${TMPDIR}" "${TMPDIR2}"' EXIT

# 테스트 1: 플레이스홀더 상태 → 보호 필드 수정 허용
printf '%s' '{
  "features": [
    {"id":"feat-001","name":"첫 번째 기능","description":"desc","notes":"","passes":false},
    {"id":"feat-002","name":"두 번째 기능","description":"desc","notes":"","passes":false}
  ]
}' > "${TMPDIR}/feature-list.json"

NEW='{"features":[{"id":"feat-001","name":"실제 기능 A","description":"실제 설명","notes":"","passes":false},{"id":"feat-002","name":"실제 기능 B","description":"실제 설명","notes":"","passes":false}]}'
TOOL_INPUT=$(printf '{"tool_input":{"file_path":"%s/feature-list.json","new_string":%s}}' "${TMPDIR}" "${NEW}")
EXIT_CODE=0
echo "${TOOL_INPUT}" | (cd "${TMPDIR}" && bash "${GUARD}") > /dev/null 2>&1 || EXIT_CODE=$?

if [ "${EXIT_CODE}" = "0" ]; then
  echo "PASS: 플레이스홀더 상태 → 보호 필드 수정 허용됨"
else
  echo "FAIL: 플레이스홀더 상태인데 차단됨 (exit ${EXIT_CODE})"
  PASS=false
fi

# 테스트 2: 실제 기능 상태 → 보호 필드 수정 차단 (별도 디렉터리)
printf '%s' '{
  "features": [
    {"id":"feat-001","name":"실제 기능 A","description":"실제 설명","notes":"","passes":false},
    {"id":"feat-002","name":"실제 기능 B","description":"실제 설명","notes":"","passes":false}
  ]
}' > "${TMPDIR2}/feature-list.json"

NEW2='{"features":[{"id":"feat-001","name":"변경 시도","description":"변경된 설명","notes":"","passes":false},{"id":"feat-002","name":"실제 기능 B","description":"실제 설명","notes":"","passes":false}]}'
TOOL_INPUT2=$(printf '{"tool_input":{"file_path":"%s/feature-list.json","new_string":%s}}' "${TMPDIR2}" "${NEW2}")
EXIT_CODE2=0
echo "${TOOL_INPUT2}" | (cd "${TMPDIR2}" && bash "${GUARD}") > /dev/null 2>&1 || EXIT_CODE2=$?

if [ "${EXIT_CODE2}" = "2" ]; then
  echo "PASS: 실제 기능 상태 → 보호 필드 수정 차단됨"
else
  echo "FAIL: 실제 기능 상태인데 차단 안됨 (exit ${EXIT_CODE2})"
  PASS=false
fi

# 테스트 3: passes만 변경 → 항상 허용
NEW3='{"features":[{"id":"feat-001","name":"실제 기능 A","description":"실제 설명","notes":"","passes":true},{"id":"feat-002","name":"실제 기능 B","description":"실제 설명","notes":"","passes":false}]}'
TOOL_INPUT3=$(printf '{"tool_input":{"file_path":"%s/feature-list.json","new_string":%s}}' "${TMPDIR2}" "${NEW3}")
EXIT_CODE3=0
echo "${TOOL_INPUT3}" | (cd "${TMPDIR2}" && bash "${GUARD}") > /dev/null 2>&1 || EXIT_CODE3=$?

if [ "${EXIT_CODE3}" = "0" ]; then
  echo "PASS: passes 필드만 변경 → 허용됨"
else
  echo "FAIL: passes 필드 변경인데 차단됨 (exit ${EXIT_CODE3})"
  PASS=false
fi

echo ""
echo "=== 테스트 결과 ==="
if [ "${PASS}" = true ]; then
  echo "PASS: pre-tool-guard 모든 테스트 통과"
  exit 0
else
  echo "FAIL: pre-tool-guard 일부 테스트 실패"
  exit 1
fi
