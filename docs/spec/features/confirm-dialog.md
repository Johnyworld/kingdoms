# Feature: Confirm Dialog (확인 다이얼로그)

> 스크립트: `scenes/game/confirm_dialog.gd` (`class_name ConfirmDialog extends CanvasLayer`)

되돌리기 어려운 동작 전에 사용자에게 확인받는 **범용 모달**. 메시지 + `[확인]`·`[취소]` 버튼을 띄운다.
chrome(딤 배경·제목 바 "확인"·X·ESC·지도 입력 차단)은 **공용 [Modal](modal.md)에 위임**하고, 콘텐츠(메시지 + 버튼 행)만 `set_content`로 주입한다.

첫 사용처는 [건물 철거](building-info.md#철거)이며, 이후 다른 확인 상황(캠프 철거 등)에도 재사용한다.

## 동작

- `open(message, confirm_label := "확인", on_confirm := Callable(), on_cancel := Callable()) -> void` — 메시지를 채우고 모달을 연다. 확인 버튼 라벨은 `confirm_label`(예: 철거는 `"철거"`), 취소 버튼은 항상 `"취소"`. **`on_confirm`/`on_cancel`(Callable)을 넘기면 확인/취소 시 그 콜백을 호출**한다 — 호출부별 동작을 open으로 넘기므로 **영구 시그널 연결 없이 재사용해도 안전**하다(다른 확인이 서로 간섭 안 함).
- **`[확인]`** → `confirmed` 방출 + `on_confirm` 호출(있으면) + 닫기(확인 처리 중에는 `_confirming` 가드로 취소 라우팅을 차단).
- **`[취소]`·X 버튼·배경 좌클릭·ESC** → 전부 `Modal.closed`로 수렴 → `cancelled` 방출 + `on_cancel` 호출(있으면). 콜백은 닫힌 뒤 1회만 호출하고 비운다(다음 open까지 남지 않음).
- `is_open() -> bool` — 내부 Modal 위임.
- **레이어**: Modal이 `ModalStack` 깊이로 부여 — 캠프 메뉴 같은 **다른 Modal 위에서 열려도 항상 맨 위**에 그려진다(예: 캠프 철거 확인은 캠프 메뉴 Modal 위). 한 번에 하나의 확인만 연다(연속 호출 시 마지막 것으로 갱신 — `Modal.open`은 열림 중 no-op, 내용·콜백만 교체).

- `signal confirmed` / `signal cancelled` — 관찰·테스트용. 실제 라우팅은 `open`의 콜백으로 한다.

## 테스트 시나리오

`test/unit/test_confirm_dialog.gd`.

- [정상] 생성 직후 `is_open() == false`
- [정상] `open("정말?")` 후 `is_open() == true`, 메시지 라벨 텍스트 = `"정말?"`
- [정상] `open(msg, "철거")` → 확인 버튼 텍스트 `"철거"`, 취소 버튼 `"취소"`
- [정상] 확인 버튼 `pressed` → `confirmed` 방출(+`cancelled` 미방출), 닫힘
- [정상] 취소 버튼 `pressed` → `cancelled` 방출, 닫힘
- [정상] Modal 닫힘(X·배경·ESC 경로) → `cancelled` 방출 + `on_cancel` 콜백 1회 호출
- [정상] `open(msg, "확인", on_confirm)` 후 확인 → `on_confirm` 콜백 1회 호출
- [정상] 취소 시 `on_confirm` 콜백 미호출

## 미구현 / 주의

- 다이얼로그 등장 애니메이션, 키보드 단축 Enter=확인. (Esc=취소는 Modal chrome으로 구현됨.)
- **free ≠ 취소**: 열린 채로 노드가 free되면(씬 전환 등) `cancelled`·`on_cancel`이 호출되지 않는다(Modal `_exit_tree`는 스택 정리만). `on_cancel`로 대기 상태를 정리하는 호출부를 만들 때 주의.

## 관련

- chrome·스택은 [Modal](modal.md). 사용처: [Building Info (철거)](building-info.md#철거) · [Camp Menu (캠프 철거)](camp-menu.md#동작).
