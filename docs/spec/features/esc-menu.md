# Feature: ESC 메뉴 (시스템/일시정지 메뉴)

> 스크립트: `scenes/game/esc_menu.gd` (`class_name EscMenu extends CanvasLayer`)

게임 화면에서 **취소할 게 없을 때 ESC를 누르면 열리는 시스템 메뉴**. 계속하기·저장·불러오기·설정·타이틀 복귀·종료를 세로 버튼 목록으로 띄운다.
chrome(딤 배경·제목 바 "메뉴"·X·ESC·지도 입력 차단)은 **공용 [Modal](modal.md)에 위임**하고, 콘텐츠(버튼 VBox)만 `set_content`로 주입한다.

## 열림 조건 (취소 우선)

`game.gd`의 ESC 입력은 **취소를 먼저** 시도하고, 취소할 게 없을 때만 메뉴를 연다(`_cancel_or_stop()`이 `false`를 반환할 때 `esc_menu.open()`). → [selection-and-movement.md](selection-and-movement.md)

- 이동 애니메이션 중 → 향하던 칸에서 정지(메뉴 안 열림).
- 부대 선택 중(정지 상태) → 선택 해제(메뉴 안 열림).
- 건설 모드 중 → 건설 취소(메뉴 안 열림 — build 입력에서 선처리).
- 위 어느 것도 아니면 → **ESC 메뉴 오픈**.
- **우클릭은 취소 전용** — 메뉴를 열지 않는다(`_cancel_or_stop()` 호출만).
- 메뉴가 열려 있으면 `ModalStack.blocking()`으로 지도 입력이 차단되고, ESC/배경 좌클릭/X/`[계속하기]`로 닫힌다(= 계속하기).

## 항목별 동작

버튼(위→아래)과 동작:

- **계속하기** — 메뉴를 닫는다(내부 `Modal.close()`, 시그널 없음).
- **게임 저장** — `disabled`(미구현, 자리표시).
- **게임 불러오기** — `disabled`(미구현, 자리표시).
- **설정** — `disabled`(미구현, 자리표시).
- **타이틀로** — `action_selected("title")` 방출 → 호출부(`game.gd _on_esc_action`)가 [확인 다이얼로그](confirm-dialog.md)("나가기")를 거쳐 `SceneManager.change_scene(TITLE_SCENE)`.
- **게임 종료** — `action_selected("quit")` 방출 → 확인 다이얼로그("종료")를 거쳐 `get_tree().quit()`. **모바일(iOS·Android)에서는 버튼을 숨긴다**(iOS 정책·모바일 UX 관례, [title.gd](title.md)와 동일).

확인 다이얼로그는 `ModalStack` 깊이로 ESC 메뉴 위에 그려지고, 취소하면 ESC 메뉴로 복귀한다.

## API

- `open() -> void` / `close() -> void` / `is_open() -> bool` — 내부 Modal 위임.
- `signal action_selected(id: String)` — `id ∈ {"title", "quit"}`. 계속하기·유예(저장·불러오기·설정) 버튼은 방출하지 않는다.

## 테스트 시나리오

`test/unit/test_esc_menu.gd`.

- [정상] 생성 직후 `is_open() == false`
- [정상] `open()` 후 `is_open() == true`
- [정상] `[계속하기]` `pressed` → 닫힘, `action_selected` 미방출
- [정상] `[타이틀로]` `pressed` → `action_selected("title")` 방출
- [정상] `[게임 종료]` `pressed`(데스크톱) → `action_selected("quit")` 방출
- [정상] `[게임 저장]`·`[게임 불러오기]`·`[설정]` 버튼 `disabled == true`

## 미구현 / 주의

- **저장·불러오기·설정 시스템 자체가 미구현** — 버튼만 자리표시(`disabled`). 시스템 구현 시 해당 버튼 활성화 + 배선.
- 진짜 일시정지(`get_tree().paused`)는 도입하지 않는다 — 기존 모달과 동일하게 `ModalStack.blocking()`로 지도 입력만 차단(프로젝트 관례). NPC 턴 진행 중에도 ESC 메뉴는 열 수 있다(오버레이일 뿐, 턴 시퀀스에 개입하지 않음).
- 메뉴 등장 애니메이션·게임패드 포커스 이동은 미구현.

## 관련

- chrome·스택은 [Modal](modal.md). 확인 이탈은 [Confirm Dialog](confirm-dialog.md). 씬 전환은 [SceneManager](scene-transition.md). 취소 우선 로직은 [Selection & Movement](selection-and-movement.md).
