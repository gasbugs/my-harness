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

## 참고

이 하네스는 Anthropic의 "Effective Harnesses for Long-Running Agents" 가이드를 기반으로 합니다.
