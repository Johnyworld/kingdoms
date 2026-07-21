# Feature: Modal (공용 모달 기반)

> 스크립트: `scenes/modal/modal.gd` (`class_name Modal`, `extends CanvasLayer`)
> 싱글턴: `autoload/modal_stack.gd` (`ModalStack`) — 열린 모달 스택 관리

게임의 여러 오버레이(캠프 메뉴·구성원·장비·약탈·확인 등)가 공통으로 쓰는 **모달 기반**.
딤 백드롭 + 제목 바 + 우측 상단 X 버튼의 chrome을 제공하고, 콘텐츠는 **호출자가 주입**(컴포지션).
열려 있는 동안 지도 조작 등 뒤 화면 입력을 막는다.

소비자: [구성원 메뉴](members-menu.md)·[캠프 메뉴](camp-menu.md)·[확인 다이얼로그](confirm-dialog.md). 남은 자체 chrome 오버레이(결과 화면 등)는 점진적으로 전환한다.

## Modal (`scenes/modal/modal.gd`)

코드로 chrome을 구성한다(별도 `.tscn` 없음). `CanvasLayer`라 게임 월드 위에 그려진다.

### 속성

- `title := ""` — 제목 바에 표시할 텍스트.
- `dismissible := true` — `true`면 배경 좌클릭·`ESC`·X 버튼으로 닫힌다. `false`면 X 버튼(또는 콘텐츠의 버튼)으로만 닫힌다(선택을 강제하는 모달용, 예: 확인 다이얼로그).

### 구조 (chrome)

- **백드롭** — 전면 `ColorRect`(`0,0,0,0.45`), `MOUSE_FILTER_STOP`으로 뒤 UI로 클릭·휠이 새지 않게 소비. `dismissible`이면 **좌클릭** 시 닫힘(휠·우클릭 무시).
- **패널** — 중앙 정렬 `PanelContainer` 안에 세로로:
  - **제목 바**(HBox) — 제목 `Label` + 늘어나는 spacer + **X `Button`**(우측 상단). X는 항상 닫는다.
  - `HSeparator`.
  - **콘텐츠 영역** — `set_content`로 주입된 Control 한 개.

### 메서드

- `set_content(control: Control) -> void` — 콘텐츠 영역의 자식을 교체한다(기존 콘텐츠 제거 후 새것 추가). `open` 전/후 모두 호출 가능.
- `open() -> void` — 표시하고 `ModalStack`에 자신을 push한다. layer는 스택 깊이에 따라 부여(뒤 모달 위). 표시 상태로 시작.
- `close() -> void` — 숨기고 `ModalStack`에서 pop한 뒤 `closed`를 방출한다. 이미 닫혀 있으면 아무것도 안 한다.
- `is_open() -> bool` — 현재 표시(스택에 있음) 여부.

### 시그널

- `opened` — `open` 시 방출.
- `closed` — `close` 시 방출(X·배경·ESC·프로그램 호출 모두 이 경로로 수렴).

### 닫기 입력

- **X 버튼** — 언제나 `close`.
- **배경 좌클릭** — `dismissible`일 때만 `close`.
- **`ESC`** — `dismissible`이고 **스택 최상단**(`ModalStack.top() == self`)일 때만 `close`. 중첩 시 맨 위 모달만 반응한다.

## ModalStack (`autoload/modal_stack.gd`)

열린 모달을 스택으로 관리하는 싱글턴. [SceneManager](scene-transition.md)처럼 `project.godot`의 `[autoload]`에 등록한다.

- `push(modal) -> void` / `pop(modal) -> void` — 열림/닫힘 시 Modal이 호출.
- `top()` — 최상단 모달(없으면 `null`).
- `blocking() -> bool` — 열린 모달이 하나라도 있으면 `true`. 뒤 화면(지도) 입력 차단 판단에 쓴다.
- `depth() -> int` — 열린 모달 수(레이어 부여용).

## 게임 연동 (`game.gd`)

- 지도 카메라 입력 차단을 **모달 일반**으로 바꾼다: `_process`(WASD·엣지 스크롤)·`_unhandled_input`(클릭·줌)이 `ModalStack.blocking()`이면 즉시 반환한다. 기존의 `members_menu.is_open()` 확인을 대체한다.

## 구성원 메뉴 전환 ([members-menu.md](members-menu.md))

- `MembersMenu`는 자체 백드롭·중앙 정렬·닫기 처리를 없애고 **내부에 `Modal`을 두어** 명단+상세 콘텐츠를 `set_content`로 넣는다.
- 좌측 하단 `"구성원"` 상시 버튼과 `open_requested`, 세력 멤버 수집(`collect_faction_members`)·첫 행 자동 선택·포커스는 그대로 유지한다.
- `open(members)` → 콘텐츠 구성 후 `modal.open()`. `close()` → `modal.close()`. `is_open()`은 `modal.is_open()` 위임.

## 테스트 시나리오

`test/unit/test_modal.gd` (Modal·ModalStack), 구성원 전환분은 [members-menu.md](members-menu.md)의 시나리오를 갱신.

- [정상] `set_content(c)` 후 콘텐츠 영역 자식 = c 한 개, 재호출 시 교체
- [정상] `open()` → `is_open()` true, `ModalStack.blocking()` true, `opened` 방출
- [정상] `close()` → `is_open()` false, `ModalStack.blocking()` false, `closed` 방출
- [정상] `title` 설정 → 제목 바 라벨에 반영
- [정상] X 버튼 누르면 `dismissible` 여부와 무관하게 닫힘
- [정상] `dismissible=true` 배경 좌클릭 → 닫힘 / [경계] 우클릭·휠 → 유지
- [경계] `dismissible=false` 배경 좌클릭 → 닫히지 않음
- [정상] ESC + 스택 최상단이면 닫힘 / [경계] 최상단이 아니면(다른 모달이 위) 무시
- [정상] 모달 2개 push → `depth()==2`, `top()`은 나중에 연 것 / 하나 pop → `top()` 갱신

## 관련

- 소비자: [Members Menu](members-menu.md)·[Camp Menu](camp-menu.md)(제목=영지 이름)·[Confirm Dialog](confirm-dialog.md)(닫힘=취소 수렴, 다른 Modal 위 중첩).
