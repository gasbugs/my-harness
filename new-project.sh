#!/usr/bin/env bash
# ============================================================
# new-project.sh — 새 장기 프로젝트에 하네스 설정 추가
# ============================================================
# 사용법: bash /Users/gasbugs/my-harness/new-project.sh [프로젝트_디렉터리]
# 인수 없이 실행 시 현재 디렉터리에 설정
# ============================================================

set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-${PWD}}"
TARGET_DIR="$(cd "${TARGET_DIR}" && pwd)"

# 색상
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; CYAN=''; NC=''
fi

info()    { echo -e "${GREEN}[new-project]${NC} $*"; }
warn()    { echo -e "${YELLOW}[new-project]${NC} $*"; }
error()   { echo -e "${RED}[new-project]${NC} $*" >&2; }
success() { echo -e "${GREEN}[new-project] ✓${NC} $*"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        새 하네스 프로젝트 설정                      ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  대상 디렉터리: %-36s ║\n" "${TARGET_DIR}"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 대상 디렉터리 확인 ────────────────────────────────────────
if [ ! -d "${TARGET_DIR}" ]; then
  error "디렉터리가 존재하지 않습니다: ${TARGET_DIR}"
  exit 1
fi

# ── 이미 설정되어 있는지 확인 ────────────────────────────────
if [ -f "${TARGET_DIR}/feature-list.json" ]; then
  warn "이미 feature-list.json이 존재합니다."
  warn "덮어쓰려면 기존 파일을 먼저 삭제하세요."
  exit 1
fi

# ── 프로젝트 이름 추출 ────────────────────────────────────────
PROJECT_NAME="$(basename "${TARGET_DIR}")"
TODAY="$(date +%Y-%m-%d)"

# ── Step 1: feature-list.json 생성 ───────────────────────────
info "Step 1: feature-list.json 생성 중..."

cat > "${TARGET_DIR}/feature-list.json" <<FEATUREOF
{
  "schema_version": "1.0",
  "project": "${PROJECT_NAME}",
  "last_updated": "${TODAY}",
  "features": [
    {
      "id": "feat-001",
      "name": "첫 번째 기능",
      "description": "이 기능이 무엇을 하는지 명확하게 설명하세요.",
      "priority": "high",
      "passes": false,
      "notes": "검증 방법: ... / 증거 필요: ..."
    },
    {
      "id": "feat-002",
      "name": "두 번째 기능",
      "description": "이 기능이 무엇을 하는지 명확하게 설명하세요.",
      "priority": "medium",
      "passes": false,
      "notes": "검증 방법: ... / 증거 필요: ..."
    }
  ]
}
FEATUREOF

success "feature-list.json 생성 완료"

# ── Step 2: claude-progress.txt 생성 ─────────────────────────
info "Step 2: claude-progress.txt 생성 중..."

cat > "${TARGET_DIR}/claude-progress.txt" <<PROGRESSEOF
# claude-progress.txt — ${PROJECT_NAME}
# ============================================================
# 추가 전용 세션 로그 — 이전 항목을 편집하거나 삭제하지 마세요
# ============================================================

=== SESSION 0 — 템플릿 ===
Agent: 템플릿
Goal: 이것은 형식 참조입니다. 새 세션마다 이 블록을 복사하세요.
Completed:
  - (항목을 대시-공백 접두사로 나열)
Blocked:
  - 없음
Test Results:
  (실제 테스트 출력 붙여넣기)
Next Session Must:
  - (구체적인 지시 1)
  - 다음 기능 진행: feat-001
=== END SESSION 0 ===
PROGRESSEOF

success "claude-progress.txt 생성 완료"

# ── Step 3: tests/e2e 디렉터리 생성 ──────────────────────────
info "Step 3: tests/e2e 디렉터리 생성 중..."
mkdir -p "${TARGET_DIR}/tests/e2e"
success "tests/e2e 디렉터리 생성 완료"

# ── Step 4: .gitignore에 claude-progress.txt 추가 ─────────────
info "Step 4: .gitignore에 claude-progress.txt 추가 중..."
GITIGNORE="${TARGET_DIR}/.gitignore"
if [ ! -f "${GITIGNORE}" ]; then
  printf '# 하네스 세션 로그 — 개인 작업 기록이므로 공유하지 않음\nclaude-progress.txt\n' > "${GITIGNORE}"
  success ".gitignore 생성 및 claude-progress.txt 추가 완료"
elif grep -qF 'claude-progress.txt' "${GITIGNORE}"; then
  success "claude-progress.txt가 이미 .gitignore에 있습니다"
else
  printf '\n# 하네스 세션 로그 — 개인 작업 기록이므로 공유하지 않음\nclaude-progress.txt\n' >> "${GITIGNORE}"
  success ".gitignore에 claude-progress.txt 추가 완료"
fi

# ── 완료 안내 ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        하네스 설정 완료!                             ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  생성된 파일:                                        ║"
printf "║    • %-47s ║\n" "feature-list.json  (기능 목록 편집 필요)"
printf "║    • %-47s ║\n" "claude-progress.txt (gitignore됨)"
printf "║    • %-47s ║\n" "tests/e2e/          (E2E 테스트 위치)"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  다음 단계:                                          ║"
echo "║  1. feature-list.json을 열어 실제 기능 목록 작성    ║"
echo "║  2. Claude Code로 이 디렉터리 열기                  ║"
echo "║  3. 하네스가 자동으로 Initializer Agent 모드로 시작 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo -e "${CYAN}  feature-list.json 편집:${NC} ${TARGET_DIR}/feature-list.json"
echo ""

exit 0
