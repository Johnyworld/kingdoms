# Feature: Confirm Dialog (확인 다이얼로그)

> 스크립트: `scenes/game/confirm_dialog.gd` (`class_name ConfirmDialog extends CanvasLayer`)

되돌리기 어려운 동작 전에 사용자에게 확인받는 **범용 모달**. 화면 중앙에 메시지 + `[확인]`·`[취소]` 버튼을 띄운다. 코드로 구성한다(`result_overlay`·`loot_menu`와 같은 패턴, 별도 `.tscn` 없음).

첫 사용처는 [건물 철거](building-info.md#철거)이며, 이후 다른 확인 상황에도 재사용한다.

## 동작

- `open(message, confirm_label := "확인", on_confirm := Callable(), on_cancel := Callable()) -> void` — 메시지를 채우고 모달을 연다. 확인 버튼 라벨은 `confirm_label`(예: 철거는 `"철거"`), 취소 버튼은 항상 `"취소"`. 반투명 배경으로 화면을 덮는다. **`on_confirm`/`on_cancel`(Callable)을 넘기면 확인/취소 시 그 콜백을 호출**한다 — 호출부별 동작을 open으로 넘기므로 **영구 시그널 연결 없이 재사용해도 안전**하다(다른 확인이 서로 간섭 안 함).
- **`[확인]`** → `confirmed` 방출 + `on_confirm` 호출(있으면) + 닫기. **`[취소]`** 또는 **배경 좌클릭** → `cancelled` 방출 + `on_cancel` 호출(있으면) + 닫기. 콜백은 닫힌 뒤 1회만 호출하고 비운다(다음 open까지 남지 않음).
- `layer`는 다른 패널(캠프 메뉴 64 등)보다 위. 한 번에 하나의 확인만 연다(연속 호출 시 마지막 것으로 갱신).

- `signal confirmed` / `signal cancelled` — 관찰·테스트용. 실제 라우팅은 `open`의 콜백으로 한다.

## 테스트 시나리오

`test/unit/test_confirm_dialog.gd`.

- [정상] `open("정말?")` 후 `visible == true`, 메시지 라벨 텍스트 = `"정말?"`
- [정상] `open(msg, "철거")` → 확인 버튼 텍스트 `"철거"`, 취소 버튼 `"취소"`
- [정상] 확인 버튼 `pressed` → `confirmed` 방출, `visible == false`
- [정상] 취소 버튼 `pressed` → `cancelled` 방출, `visible == false`
- [정상] `open(msg, "확인", on_confirm)` 후 확인 → `on_confirm` 콜백 1회 호출
- [정상] 취소 시 `on_confirm` 콜백 미호출

## 미구현

- 다이얼로그 등장 애니메이션, 키보드 단축(Enter=확인 / Esc=취소).

## 관련

- 사용처: [Building Info (철거)](building-info.md#철거).
