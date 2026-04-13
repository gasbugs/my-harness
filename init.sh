#!/usr/bin/env bash
# ============================================================
# init.sh — Claude Code 에이전트 하네스 초기화 스크립트
# ============================================================
# 목적: 에이전트 세션 시작 시 작업 환경을 검증하고 준비한다
# 멱등성: 여러 번 실행해도 동일한 결과를 보장한다
# 종료 코드: 0 = 환경 준비 완료, 1 = 치명적 오류(작업 중단 필요)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 환경변수 PROJECT_ROOT가 설정되어 있으면 그것을 사용, 없으면 스크립트 위치 사용
PROJECT_ROOT="${PROJECT_ROOT:-${SCRIPT_DIR}}"
PROGRESS_FILE="${PROJECT_ROOT}/claude-progress.txt"
FEATURE_LIST="${PROJECT_ROOT}/feature-list.json"
LOG_PREFIX="[init.sh]"
INIT_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# 터미널 색상 (터미널이 아닐 경우 비활성화)
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

info()  { echo "${LOG_PREFIX} ${GREEN}INFO${NC}  $*"; }
warn()  { echo "${LOG_PREFIX} ${YELLOW}WARN${NC}  $*"; }
error() { echo "${LOG_PREFIX} ${RED}ERROR${NC} $*" >&2; }

# ── 1단계: 작업 디렉터리 검증 ────────────────────────────────
info "Step 1: 프로젝트 루트 확인 중..."
if [ ! -f "${FEATURE_LIST}" ]; then
  error "feature-list.json을 찾을 수 없습니다: ${FEATURE_LIST}"
  error "이 하네스는 프로젝트 루트에서 실행해야 합니다."
  exit 1
fi
info "프로젝트 루트 확인됨: ${PROJECT_ROOT}"

# ── 2단계: 필수 도구 검증 ────────────────────────────────────
info "Step 2: 필수 도구 확인 중..."
MISSING_TOOLS=()
for tool in git jq bash; do
  if ! command -v "${tool}" &>/dev/null; then
    MISSING_TOOLS+=("${tool}")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  error "필수 도구가 없습니다: ${MISSING_TOOLS[*]}"
  exit 1
fi
info "필수 도구 확인됨: git, jq, bash"

# ── 3단계: feature-list.json 검증 ───────────────────────────
info "Step 3: feature-list.json 검증 중..."
if ! jq empty "${FEATURE_LIST}" 2>/dev/null; then
  error "feature-list.json이 유효한 JSON이 아닙니다 — 파일이 손상되었을 수 있습니다"
  exit 1
fi

FEATURE_COUNT=$(jq '.features | length' "${FEATURE_LIST}")
PASSED_COUNT=$(jq '[.features[] | select(.passes == true)] | length' "${FEATURE_LIST}")
PENDING_COUNT=$(jq '[.features[] | select(.passes == false)] | length' "${FEATURE_LIST}")

info "기능 목록: 전체 ${FEATURE_COUNT}개, 완료 ${PASSED_COUNT}개, 대기 ${PENDING_COUNT}개"

# ── 4단계: git 저장소 초기화(없을 경우) ─────────────────────
info "Step 4: git 저장소 확인 중..."
if [ ! -d "${PROJECT_ROOT}/.git" ]; then
  warn "git 저장소 없음 — 초기화 중..."
  git -C "${PROJECT_ROOT}" init
  git -C "${PROJECT_ROOT}" add .
  git -C "${PROJECT_ROOT}" commit -m "harness: init.sh에 의한 초기 커밋

Feature: n/a
Tests: not-applicable
Progress: git 저장소가 init.sh에 의해 초기화됨"
  info "git 저장소 초기화 완료"
else
  BRANCH=$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  LAST_COMMIT=$(git -C "${PROJECT_ROOT}" log -1 --pretty=format:"%h %s" 2>/dev/null || echo "커밋 없음")
  info "git 정상 — 브랜치: ${BRANCH}, 마지막 커밋: ${LAST_COMMIT}"
fi

# ── 5단계: 진행 로그 읽기 ────────────────────────────────────
info "Step 5: 진행 로그 읽는 중..."
if [ -f "${PROGRESS_FILE}" ]; then
  SESSION_COUNT=$(grep -c "^=== SESSION" "${PROGRESS_FILE}" 2>/dev/null || echo "0")
  LAST_SESSION_BLOCK=$(awk '/^=== SESSION/{block=$0; next} {block=block"\n"$0} /^=== END SESSION/{print block; block=""}' "${PROGRESS_FILE}" | tail -25)
  info "이전 세션 ${SESSION_COUNT}개 발견"
  echo ""
  echo "─── 마지막 세션 요약 ─────────────────────────────────"
  echo "${LAST_SESSION_BLOCK}"
  echo "────────────────────────────────────────────────────"
  echo ""
else
  warn "claude-progress.txt 없음 — 첫 번째 세션으로 판단됨 (Initializer Agent 모드)"
fi

# ── 6단계: 최근 git 히스토리 표시 ──────────────────────────
info "Step 6: 최근 git 히스토리 확인 중..."
if [ -d "${PROJECT_ROOT}/.git" ]; then
  echo ""
  echo "─── 최근 커밋 히스토리 (최대 10개) ──────────────────"
  git -C "${PROJECT_ROOT}" log --oneline -10 2>/dev/null || echo "  (커밋 없음)"
  echo "────────────────────────────────────────────────────"
  echo ""
else
  warn "git 저장소 없음 — 히스토리 표시 생략"
fi

# ── 7단계: 스모크 테스트 실행 ────────────────────────────────
info "Step 7: 스모크 테스트 실행 중..."

SMOKE_PASS=true
SMOKE_RESULTS=()

# 스모크 테스트: null ID를 가진 기능이 없어야 함
NULL_IDS=$(jq '[.features[] | select(.id == null)] | length' "${FEATURE_LIST}")
if [ "${NULL_IDS}" -eq 0 ]; then
  SMOKE_RESULTS+=("PASS: 모든 기능 ID가 null이 아님")
else
  SMOKE_RESULTS+=("FAIL: ${NULL_IDS}개 기능의 ID가 null임")
  SMOKE_PASS=false
fi

# 스모크 테스트: passes 필드가 모두 boolean이어야 함
NON_BOOL=$(jq '[.features[] | select(.passes | type != "boolean")] | length' "${FEATURE_LIST}")
if [ "${NON_BOOL}" -eq 0 ]; then
  SMOKE_RESULTS+=("PASS: 모든 passes 필드가 boolean 타입")
else
  SMOKE_RESULTS+=("FAIL: ${NON_BOOL}개 기능의 passes 필드가 boolean이 아님")
  SMOKE_PASS=false
fi

# 스모크 테스트: tests/e2e 디렉터리 존재 확인(없으면 생성)
if [ -d "${PROJECT_ROOT}/tests/e2e" ]; then
  SMOKE_RESULTS+=("PASS: tests/e2e 디렉터리 존재")
else
  warn "tests/e2e 디렉터리 없음 — 생성 중..."
  mkdir -p "${PROJECT_ROOT}/tests/e2e"
  SMOKE_RESULTS+=("PASS: tests/e2e 디렉터리 생성됨")
fi

# ── 프로젝트별 스모크 테스트 추가 위치 ──────────────────────
# 여기에 프로젝트 고유의 스모크 테스트를 추가하세요:
#   if <테스트 명령어>; then
#     SMOKE_RESULTS+=("PASS: <설명>")
#   else
#     SMOKE_RESULTS+=("FAIL: <설명>")
#     SMOKE_PASS=false
#   fi
# ── 프로젝트별 스모크 테스트 끝 ─────────────────────────────

echo ""
echo "─── 스모크 테스트 결과 ──────────────────────────────"
for result in "${SMOKE_RESULTS[@]}"; do
  echo "  ${result}"
done
echo "────────────────────────────────────────────────────"
echo ""

if [ "${SMOKE_PASS}" = false ]; then
  error "스모크 테스트 실패. 위 문제를 해결한 후 진행하세요."
  exit 1
fi

info "모든 스모크 테스트 PASS"

# ── 8단계: 환경 요약 출력 ────────────────────────────────────
info "Step 8: 환경 요약"
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           하네스 환경 준비 완료                      ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  시각       : %-38s ║\n" "${INIT_TIMESTAMP}"
printf "║  루트       : %-38s ║\n" "${PROJECT_ROOT}"
printf "║  기능 상태  : %-38s ║\n" "대기 ${PENDING_COUNT}개 / 완료 ${PASSED_COUNT}개"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

exit 0
