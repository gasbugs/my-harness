# Claude Code 에이전트 하네스 — 프로젝트 지침

## 에이전트 역할

### Initializer Agent (첫 번째 세션만 — claude-progress.txt가 없을 때)

`claude-progress.txt`가 프로젝트 루트에 **없으면** 당신은 Initializer Agent입니다.

책임:
1. 다른 작업 전에 즉시 `bash init.sh`를 실행한다.
2. 아래 진행 로그 형식으로 `claude-progress.txt`에 SESSION 1 항목을 작성한다.
3. `feature-list.json`이 유효한 JSON이고 모든 기능의 `"passes"`가 `false`인지 확인한다.
4. 초기 git 커밋 생성: `git commit -m "harness: 프로젝트 스캐폴드 초기화"`
5. E2E 테스트 스위트 전체 실행 (아래 테스트 요구사항 참고).
6. `claude-progress.txt`에 결과를 기록하고 두 번째 커밋 생성.
7. `claude-progress.txt` 하단에 "다음 세션 시작 지점" 블록을 작성하여 Coding Agent에 인계.

### Coding Agent (이후 모든 세션)

`claude-progress.txt`가 **이미 존재하면** 당신은 Coding Agent입니다.

세션 시작 시 필수 수행 순서 (절대 건너뛰지 말 것):
1. `bash init.sh` 실행 — 환경이 정상적이라고 판단해도 반드시 실행.
2. `claude-progress.txt` 전체 읽기 — 이전 세션이 어디서 끝났는지 정확히 파악.
3. `feature-list.json` 읽기 — `"passes": false`인 기능과 우선순위 파악.
4. `git log --oneline -10` 실행 — 최근 커밋 히스토리로 진행 맥락 파악.
5. `init.sh`에 정의된 스모크 테스트 실행 후 환경이 정상임을 확인.
6. 1~5단계 완료 후에만 다음 미완료 기능 작업 시작.

---

## 세션 시작 프로토콜 (두 에이전트 공통)

```
필수 시작 순서 — 절대 건너뛰지 말 것
1. 작업 디렉터리 확인
2. bash init.sh 실행 (git 히스토리 포함 자동 출력됨)
3. claude-progress.txt 읽기 (존재할 경우)
4. feature-list.json 읽기 — passes: false인 기능 파악
5. git log --oneline -10 실행 — 최근 작업 맥락 파악
6. 스모크 테스트 실행
7. 이후에만 생산적 작업 시작
```

`init.sh`가 0이 아닌 종료 코드로 종료되면 **중단**하고 진단하세요.

---

## 기능 목록 규칙

`feature-list.json`은 **보호 파일**입니다. 규칙은 절대적입니다:

- **`"passes"` 필드만 수정할 수 있습니다**
- `"id"`, `"name"`, `"description"`, `"notes"` 필드는 **수정 금지**
- 기능 객체를 **추가하거나 삭제하지 마세요**
- 다음 **다섯 가지 조건이 모두 충족될 때까지** `"passes": true`로 설정하지 마세요:
  1. 기능 구현이 완료됨
  2. 해당 기능의 E2E 테스트가 작성됨
  3. E2E 테스트를 실행하여 종료 코드 0으로 통과함
  4. 증거를 `claude-progress.txt`에 기록함
  5. 구현과 테스트를 모두 포함한 git 커밋이 생성됨

---

## 커밋 규칙

모든 커밋은 다음 형식을 따라야 합니다:

```
<타입>(<범위>): <제목>

Feature: <feature-list.json의 feature-id>
Tests: <passed|not-applicable>
Progress: <세션 상태 한 줄 요약>
```

타입: `feat`, `fix`, `test`, `harness`, `docs`, `refactor`

---

## E2E 테스트 요구사항

기능을 `"passes": true`로 표시하기 전에:

1. `tests/e2e/test_<feature-id>.sh`에 E2E 테스트 작성.
2. 성공 시 종료 코드 0, 실패 시 0이 아닌 코드.
3. stdout에 명확한 PASS/FAIL 줄 출력.
4. 테스트 실행 후 **정확한 출력을 증거로** `claude-progress.txt`에 붙여넣기.

**피해야 할 안티패턴:** 테스트 실행 없이 `"passes": true`로 표시하는 것.

---

## 진행 로그 형식

`claude-progress.txt`는 추가 전용 로그입니다. 이전 항목을 삭제하거나 편집하지 마세요.

```
=== SESSION <번호> — <ISO-8601 날짜> ===
Agent: <Initializer|Coding>
Goal: <이번 세션의 목표>
Completed:
  - <항목 1>
Blocked:
  - <차단 사항, 없으면 "없음">
Test Results:
  <실제 테스트 출력>
Next Session Must:
  - <구체적인 지시>
  - 다음 기능 진행: <feature-id>
=== END SESSION <번호> ===
```

---

## 금지 사항

1. E2E 테스트 실행 없이 `"passes": true`로 표시
2. 세션 시작 시 `init.sh` 건너뛰기
3. `feature-list.json`에서 `"passes"` 외 필드 수정
4. 스모크 테스트 실패 시 기능 작업 진행
5. 세션 종료 시 진행 로그 항목 생략
6. 필수 푸터 필드(Feature, Tests, Progress) 없이 커밋
