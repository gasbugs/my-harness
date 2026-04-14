# my-harness

Claude Code 장시간 실행 에이전트를 위한 하네스 설정 저장소입니다. 한 번의 설치로 모든 Claude Code 세션에 에이전트 지침과 자동화 훅이 전역 적용됩니다.

## 설치

프로젝트 루트에서 다음을 실행합니다:

```bash
bash setup.sh
```

## 작동 방식

1. `setup.sh`는 `~/.claude/CLAUDE.md`에 `@import`를 추가하여 이 프로젝트의 에이전트 지침을 전역으로 로드합니다.
2. `~/.claude/settings.json`에 SessionStart 훅을 등록하여 모든 Claude Code 세션이 시작될 때 `init.sh`를 자동으로 실행합니다.
3. `init.sh`는 프로젝트 환경을 검증하고(필수 도구 확인, 파일 무결성 확인, git 상태 확인) 준비된 상태를 보장합니다.
4. PreToolUse 훅은 `feature-list.json`을 보호하여 에이전트가 실수로 기능 레지스트리를 손상시키지 못하게 합니다.

## 파일 구조

| 파일/디렉터리 | 목적 |
|---|---|
| `setup.sh` | 한 번 실행하여 전역 설치 |
| `CLAUDE.md` | 에이전트 지침 및 프로토콜 (전역 로드됨) |
| `init.sh` | 세션 시작 시 자동으로 실행되는 환경 검증 스크립트 |
| `feature-list.json` | 기능 레지스트리 (passes 필드만 수정 가능) |
| `claude-progress.txt` | 세션 간 진행 로그 |
| `hooks/session-start` | SessionStart 훅 (init.sh 자동 실행) |
| `hooks/pre-tool-guard` | PreToolUse 훅 (feature-list.json 보호) |
| `tests/e2e/` | E2E 테스트 스크립트 |

## 장기 프로젝트에서 사용하기

`feature-list.json`의 각 기능마다 `"passes": false`부터 시작합니다. 에이전트는 각 기능을 구현 및 검증한 후 해당 필드를 `"passes": true`로 변경합니다. 이는 진행 상황을 추적하고 회귀를 방지합니다. `claude-progress.txt`는 세션 간 진행 상황을 기록하는 장기 프로젝트 로그입니다. 각 세션마다 새로운 SESSION 블록을 추가하고, 세션 끝에 "다음 세션 시작 지점" 섹션을 작성하여 다음 에이전트가 정확히 어디서 계속할지 알 수 있게 합니다.

## 개선이 필요한 시점 (Top 10)

하네스를 고쳐야 할 상황이 생겼을 때 참고하세요. 아래 시나리오가 발생하면 해당 파일을 수정하면 됩니다.

| # | 증상 / 이슈 | 수정할 파일 |
|---|---|---|
| 1 | **my-harness 디렉터리를 옮겼더니 훅이 모두 깨짐** — `~/.claude/settings.json`과 `~/.claude/CLAUDE.md`에 절대경로가 하드코딩되어 있음. 이동 후 `bash setup.sh`를 다시 실행하면 해결됨. | `setup.sh` |
| 2 | **`claude-progress.txt`가 수백 KB로 불어나 컨텍스트 창을 잠식** — 에이전트가 파일 전체를 읽어야 하므로 토큰 낭비가 심해짐. 오래된 SESSION 블록을 `archive/`로 이동하는 로테이션 로직이 필요함. | `init.sh`, `hooks/session-stop` |
| 3 | **`feature-list.json` 항목 자체를 수정해야 하는 상황** — pre-tool-guard가 `id/name/description/notes` 변경을 막으므로 직접 편집이 불가능. 임시로 `bash uninstall.sh` → 편집 → `bash setup.sh` 순서로 우회하거나, 화이트리스트 메커니즘을 추가해야 함. | `hooks/pre-tool-guard` |
| 4 | **동일 프로젝트에서 Claude 세션을 두 개 이상 동시에 실행하면 `claude-progress.txt` 충돌** — 두 에이전트가 동시에 같은 파일에 SESSION 블록을 기록하면 블록이 뒤섞임. 파일 잠금(flock) 또는 세션 ID 기반 분리 로직이 필요함. | `hooks/session-stop`, `init.sh` |
| 5 | **init.sh 스모크 테스트가 늘어나면서 세션 시작이 느려짐** — 스모크 테스트가 10초 이상 걸리기 시작하면 `--fast` 플래그나 캐싱 레이어를 추가해야 함. | `init.sh` |
| 6 | **bash-guard가 정상 명령을 오탐(false positive)으로 막음** — 예: `echo "feature-list.json"` 같은 문자열 출력도 차단될 수 있음. 패턴을 좁히거나 `HARNESS_SKIP_BASH_GUARD=1` 환경 변수 우회 경로를 추가해야 함. | `hooks/bash-guard` |
| 7 | **Windows / WSL 환경에서 훅이 작동하지 않음** — `#!/usr/bin/env bash` 경로, `\r\n` 줄 끝, `chmod +x` 동작이 다름. WSL2 전용 분기 처리와 `dos2unix` 전처리가 필요함. | `setup.sh`, 전체 hooks |
| 8 | **`feature-list.json` 항목이 200개를 초과해 jq 처리가 눈에 띄게 느려짐** — 파일을 기능 그룹별로 분할하거나 SQLite 같은 경량 DB로 교체하는 것을 고려해야 함. | `feature-list.json`, `init.sh`, `hooks/pre-tool-guard` |
| 9 | **`session-stop` 훅이 열린 SESSION 블록을 잘못 감지** — `grep -c "^=== SESSION"` 방식은 주석이나 예시 텍스트에 포함된 `=== SESSION`도 카운트함. 고유 구분자(예: UUID 포함)로 형식을 변경해야 함. | `hooks/session-stop`, `claude-progress.txt` 형식 |
| 10 | **새 Claude Code 버전에서 훅 JSON 스키마가 바뀜** — `hookSpecificOutput.additionalContext` 필드명이나 훅 이벤트명이 변경되면 전체 훅이 무음 실패함. 릴리스 노트 확인 후 필드명 업데이트가 필요함. | 전체 hooks |

> **개선 추가 방법:** 위 표에 행을 추가하고 해당 파일을 수정한 뒤 `bash check.sh`로 검증하세요.

## 참고

이 하네스는 Anthropic의 "Effective Harnesses for Long-Running Agents" 가이드를 기반으로 합니다.
