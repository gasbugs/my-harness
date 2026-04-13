#!/usr/bin/env bash
# ============================================================
# check.sh — my-harness 설치 상태 진단
# ============================================================
# 목적: 전역 설치가 올바른지 빠르게 확인한다
# ============================================================

set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
GLOBAL_CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
GLOBAL_SETTINGS="${CLAUDE_DIR}/settings.json"

# 색상
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

PASS=0
FAIL=0

ok()   { echo -e "  ${GREEN}✓${NC} $*"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${NC} $*"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        my-harness 설치 상태 진단                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 필수 도구 ─────────────────────────────────────────────────
echo "[ 필수 도구 ]"
for tool in bash git jq; do
  if command -v "${tool}" &>/dev/null; then
    ok "${tool} 설치됨: $(command -v ${tool})"
  else
    fail "${tool} 없음 — brew install ${tool}"
  fi
done
echo ""

# ── 하네스 파일 및 권한 ───────────────────────────────────────
echo "[ 하네스 파일 ]"

# 검사할 파일 목록 정의
for file in init.sh "hooks/session-start" "hooks/session-stop" "hooks/pre-tool-guard" setup.sh new-project.sh CLAUDE.md feature-list.json; do
  FULL_PATH="${HARNESS_DIR}/${file}"
  if [ ! -f "${FULL_PATH}" ]; then
    fail "${file} — 파일 없음"
  elif [[ "${file}" == hooks/* ]] || [[ "${file}" == *.sh ]]; then
    if [ -x "${FULL_PATH}" ]; then
      ok "${file} — 존재, 실행 가능"
    else
      fail "${file} — 존재하나 실행 권한 없음 (chmod +x ${FULL_PATH})"
    fi
  else
    ok "${file} — 존재"
  fi
done
echo ""

# ── 전역 CLAUDE.md @import ────────────────────────────────────
echo "[ ~/.claude/CLAUDE.md @import ]"
IMPORT_LINE="@${HARNESS_DIR}/CLAUDE.md"
if [ ! -f "${GLOBAL_CLAUDE_MD}" ]; then
  fail "~/.claude/CLAUDE.md 없음 — setup.sh를 실행하세요"
elif grep -qF "${IMPORT_LINE}" "${GLOBAL_CLAUDE_MD}"; then
  ok "@import 등록됨: ${IMPORT_LINE}"
else
  fail "@import 없음 — setup.sh를 실행하세요"
fi
echo ""

# ── 전역 settings.json 훅 ─────────────────────────────────────
echo "[ ~/.claude/settings.json 훅 ]"
if [ ! -f "${GLOBAL_SETTINGS}" ]; then
  fail "settings.json 없음 — setup.sh를 실행하세요"
else
  # any() 패턴으로 여러 훅 중 하나라도 해당하면 통과
  check_hook() {
    local event="$1" keyword="$2"
    jq -e --arg event "$event" --arg kw "$keyword" \
      '[.hooks[$event][]?.hooks[]?.command? // ""] | any(contains($kw))' \
      "${GLOBAL_SETTINGS}" &>/dev/null
  }

  # SessionStart 훅
  if check_hook "SessionStart" "session-start"; then
    ok "SessionStart 훅 등록됨"
  else
    fail "SessionStart 훅 없음 — setup.sh를 실행하세요"
  fi

  # PreToolUse pre-tool-guard 훅
  if check_hook "PreToolUse" "pre-tool-guard"; then
    ok "PreToolUse(pre-tool-guard) 훅 등록됨"
  else
    fail "PreToolUse(pre-tool-guard) 훅 없음 — setup.sh를 실행하세요"
  fi

  # PreToolUse bash-guard 훅
  if check_hook "PreToolUse" "bash-guard"; then
    ok "PreToolUse(bash-guard) 훅 등록됨"
  else
    warn "PreToolUse(bash-guard) 훅 없음 (선택 사항)"
  fi

  # Stop 훅
  if check_hook "Stop" "session-stop"; then
    ok "Stop 훅 등록됨"
  else
    fail "Stop 훅 없음 — setup.sh를 실행하세요"
  fi
fi
echo ""

# ── init.sh 실행 테스트 ───────────────────────────────────────
echo "[ init.sh 실행 테스트 ]"
if bash "${HARNESS_DIR}/init.sh" &>/dev/null; then
  ok "init.sh 정상 실행 (종료 코드 0)"
else
  fail "init.sh 실패 — bash ${HARNESS_DIR}/init.sh 로 직접 실행해 오류 확인"
fi
echo ""

# ── 최종 결과 ─────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "────────────────────────────────────────────────────"
if [ "${FAIL}" -eq 0 ]; then
  echo -e "  ${GREEN}모두 통과 (${PASS}/${TOTAL})${NC} — 하네스가 올바르게 설치되어 있습니다."
else
  echo -e "  ${RED}실패 ${FAIL}건 (통과 ${PASS}/${TOTAL})${NC} — setup.sh를 다시 실행하세요."
  echo -e "  ${YELLOW}→ bash ${HARNESS_DIR}/setup.sh${NC}"
fi
echo ""

[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
