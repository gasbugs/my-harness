#!/usr/bin/env bash
# ============================================================
# setup.sh — my-harness 전역 설치 스크립트
# ============================================================
# 목적: ~/.claude/CLAUDE.md와 ~/.claude/settings.json에
#       하네스 설정을 자동으로 추가한다
# 멱등성: 여러 번 실행해도 중복 추가 없이 안전하다
# ============================================================

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
GLOBAL_CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
GLOBAL_SETTINGS="${CLAUDE_DIR}/settings.json"
IMPORT_LINE="@${HARNESS_DIR}/CLAUDE.md"

# 색상 출력
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

info()    { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[setup]${NC} $*"; }
error()   { echo -e "${RED}[setup]${NC} $*" >&2; }
success() { echo -e "${GREEN}[setup] ✓${NC} $*"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        my-harness 전역 설치 시작                    ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  하네스 경로: %-38s ║\n" "${HARNESS_DIR}"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 필수 도구 확인 ────────────────────────────────────────────
info "필수 도구 확인 중..."
for tool in jq; do
  if ! command -v "${tool}" &>/dev/null; then
    error "필수 도구가 없습니다: ${tool}"
    error "brew install ${tool} 으로 설치 후 다시 실행하세요."
    exit 1
  fi
done
success "필수 도구 확인됨"

# ── ~/.claude 디렉터리 확인 ──────────────────────────────────
if [ ! -d "${CLAUDE_DIR}" ]; then
  error "${CLAUDE_DIR} 디렉터리가 없습니다. Claude Code를 먼저 설치하세요."
  exit 1
fi

# ── Step 1: ~/.claude/CLAUDE.md에 @import 추가 ───────────────
info "Step 1: ~/.claude/CLAUDE.md @import 설정 중..."

if [ ! -f "${GLOBAL_CLAUDE_MD}" ]; then
  warn "CLAUDE.md 없음 — 새로 생성합니다"
  echo "${IMPORT_LINE}" > "${GLOBAL_CLAUDE_MD}"
  success "CLAUDE.md 생성 및 @import 추가 완료"
elif grep -qF "${IMPORT_LINE}" "${GLOBAL_CLAUDE_MD}"; then
  success "@import 이미 존재 — 건너뜀"
else
  # 파일 상단에 추가 (기존 내용 보존)
  EXISTING=$(cat "${GLOBAL_CLAUDE_MD}")
  printf '%s\n%s\n' "${IMPORT_LINE}" "${EXISTING}" > "${GLOBAL_CLAUDE_MD}"
  success "@import 추가 완료: ${IMPORT_LINE}"
fi

# ── Step 2: ~/.claude/settings.json에 훅 병합 ────────────────
info "Step 2: ~/.claude/settings.json 훅 설정 중..."

HOOK_SESSION_START=$(cat <<'HOOKEOF'
[{"hooks":[{"type":"command","command":"bash \"HARNESS_PLACEHOLDER/hooks/session-start\""}]}]
HOOKEOF
)
HOOK_SESSION_START="${HOOK_SESSION_START/HARNESS_PLACEHOLDER/${HARNESS_DIR}}"

HOOK_PRE_TOOL=$(cat <<'HOOKEOF'
[{"matcher":"Write|Edit|MultiEdit","hooks":[{"type":"command","command":"bash \"HARNESS_PLACEHOLDER/hooks/pre-tool-guard\""}]}]
HOOKEOF
)
HOOK_PRE_TOOL="${HOOK_PRE_TOOL/HARNESS_PLACEHOLDER/${HARNESS_DIR}}"

if [ ! -f "${GLOBAL_SETTINGS}" ]; then
  warn "settings.json 없음 — 새로 생성합니다"
  echo '{}' > "${GLOBAL_SETTINGS}"
fi

# jq로 기존 설정을 보존하면서 hooks 키만 추가/업데이트
UPDATED_SETTINGS=$(jq \
  --argjson session_start "${HOOK_SESSION_START}" \
  --argjson pre_tool "${HOOK_PRE_TOOL}" \
  '.hooks.SessionStart = $session_start | .hooks.PreToolUse = $pre_tool' \
  "${GLOBAL_SETTINGS}")

echo "${UPDATED_SETTINGS}" > "${GLOBAL_SETTINGS}"
success "settings.json 훅 설정 완료"

# ── Step 3: hooks/ 실행 권한 확인 ────────────────────────────
info "Step 3: hooks/ 실행 권한 설정 중..."
chmod +x "${HARNESS_DIR}/init.sh"
chmod +x "${HARNESS_DIR}/hooks/session-start"
chmod +x "${HARNESS_DIR}/hooks/pre-tool-guard"
success "실행 권한 설정 완료"

# ── 완료 요약 ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        설치 완료!                                    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  다음 Claude Code 세션부터 하네스가 활성화됩니다.   ║"
echo "║                                                      ║"
echo "║  적용 내용:                                          ║"
echo "║  • ~/.claude/CLAUDE.md: @import 추가됨              ║"
echo "║  • ~/.claude/settings.json: SessionStart 훅 추가됨  ║"
echo "║  • ~/.claude/settings.json: PreToolUse 훅 추가됨    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

exit 0
