#!/usr/bin/env bash
# ============================================================
# uninstall.sh — my-harness 전역 설치 제거
# ============================================================
# 목적: setup.sh로 추가된 전역 설정을 안전하게 제거한다
# ============================================================

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
GLOBAL_CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
GLOBAL_SETTINGS="${CLAUDE_DIR}/settings.json"
IMPORT_LINE="@${HARNESS_DIR}/CLAUDE.md"

# 색상
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

info()    { echo -e "${GREEN}[uninstall]${NC} $*"; }
warn()    { echo -e "${YELLOW}[uninstall]${NC} $*"; }
success() { echo -e "${GREEN}[uninstall] ✓${NC} $*"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        my-harness 전역 설치 제거                    ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: ~/.claude/CLAUDE.md에서 @import 제거 ─────────────
info "Step 1: ~/.claude/CLAUDE.md @import 제거 중..."

if [ ! -f "${GLOBAL_CLAUDE_MD}" ]; then
  warn "CLAUDE.md 없음 — 건너뜀"
elif grep -qF "${IMPORT_LINE}" "${GLOBAL_CLAUDE_MD}"; then
  # @import 줄 삭제 (grep -v 방식)
  TEMP=$(mktemp)
  grep -vF "${IMPORT_LINE}" "${GLOBAL_CLAUDE_MD}" > "${TEMP}"
  mv "${TEMP}" "${GLOBAL_CLAUDE_MD}"
  success "@import 제거 완료"
else
  warn "@import가 없음 — 건너뜀"
fi

# ── Step 2: ~/.claude/settings.json에서 하네스 훅 제거 ───────
info "Step 2: ~/.claude/settings.json 훅 제거 중..."

if [ ! -f "${GLOBAL_SETTINGS}" ]; then
  warn "settings.json 없음 — 건너뜀"
else
  HARNESS_ESCAPED="${HARNESS_DIR//\//\\/}"

  # jq로 하네스 관련 훅만 필터링하여 제거
  UPDATED=$(jq \
    --arg harness "${HARNESS_DIR}" \
    '
    # SessionStart에서 하네스 훅 제거
    if .hooks.SessionStart then
      .hooks.SessionStart = [
        .hooks.SessionStart[] |
        .hooks = [.hooks[] | select(.command | contains($harness) | not)] |
        select(.hooks | length > 0)
      ] |
      if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
    else . end |

    # PreToolUse에서 하네스 훅 제거
    if .hooks.PreToolUse then
      .hooks.PreToolUse = [
        .hooks.PreToolUse[] |
        .hooks = [.hooks[] | select(.command | contains($harness) | not)] |
        select(.hooks | length > 0)
      ] |
      if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end
    else . end |

    # Stop에서 하네스 훅 제거
    if .hooks.Stop then
      .hooks.Stop = [
        .hooks.Stop[] |
        .hooks = [.hooks[] | select(.command | contains($harness) | not)] |
        select(.hooks | length > 0)
      ] |
      if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
    else . end |

    # hooks 객체가 비어있으면 제거
    if .hooks == {} then del(.hooks) else . end
    ' \
    "${GLOBAL_SETTINGS}")

  echo "${UPDATED}" > "${GLOBAL_SETTINGS}"
  success "settings.json 훅 제거 완료"
fi

# ── 완료 ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        제거 완료                                     ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  • ~/.claude/CLAUDE.md: @import 제거됨              ║"
echo "║  • ~/.claude/settings.json: 하네스 훅 제거됨        ║"
echo "║                                                      ║"
echo "║  my-harness 디렉터리는 유지됩니다.                  ║"
echo "║  재설치: bash ${HARNESS_DIR}/setup.sh               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

exit 0
