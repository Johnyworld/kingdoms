# Feature: Turn (턴)

> 스크립트: `scenes/turn/turn_manager.gd` (`class_name TurnManager extends RefCounted`) · `scenes/turn/turn_hud.gd` (`extends CanvasLayer`)

게임을 **턴** 단위로 진행한다. 플레이어는 유닛을 움직인 뒤 **턴 종료**를 눌러 다음 턴으로 넘어간다.
턴이 종료되면 ① 턴 번호가 1 증가하고 ② 모든 유닛의 이동 상태가 리셋되며 ③ 모든 영지가 자원 수입을 받는다.

## 규칙

- **유닛 이동은 턴당 1회.** 이동한 유닛은 그 턴에는 다시 선택·이동할 수 없다([Selection & Movement](selection-and-movement.md) 참고).
- **건물 건설은 턴 제한을 받지 않는다.** 턴당 1회 제한은 **유닛 이동에만** 적용된다.
  - (건설 흐름 자체는 아직 **미구현 · Phase 2**다. 여기서는 "건설은 턴에 구애받지 않는다"는 규칙만 명시한다.)
- 턴 번호는 **1부터** 시작한다.

## 턴 매니저 (`turn_manager.gd`)

> `class_name TurnManager extends RefCounted` — 시각 요소 없는 순수 데이터/로직.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 턴 번호 | `number` | `int` | `1` | 현재 턴. `end_turn` 시 +1 |

- `end_turn(units: Array, territories: Array) -> void` — 한 번의 턴 종료 처리를 모아서 실행한다.
  1. `number += 1`
  2. 각 `unit`에 대해 `unit.reset_turn()` — 이동 상태 리셋.
  3. 각 `territory`에 대해 `territory.collect_income()` — 건물 생산을 자원에 합산.

## 자원 수입 (`Territory.collect_income` + `Building.production`)

턴 종료 시 각 영지의 **건물 생산량**(`production`)을 영지 자원에 더한다.

- `Building.production() -> Dictionary` — 종류 카탈로그의 `production`(자원명→수량). 없으면 빈 Dictionary.
- `Territory.collect_income() -> void` — 소속 건물들의 `production()`을 순회하며 `resources[자원] += 수량`. 영지에 없던 자원 키는 새로 만들어 더한다.
- 현재 배치된 건물은 **캠프뿐이고 캠프는 `production`이 없다** → 실제 증가 0. 농장 등 생산 건물이 배치되면(건설은 Phase 2) 자동으로 턴당 수입이 발생한다.

## 턴 종료 버튼 (`turn_hud.gd`)

> `extends CanvasLayer` — [캠프 메뉴](camp-menu.md)처럼 UI를 코드로 구성한다(별도 `.tscn` 없음).

- 화면 **우측 아래**에 "턴 종료" 버튼과 현재 턴 번호("턴 N")를 표시한다.
- 버튼을 누르면 게임 루트(`game.gd`)의 턴 종료 처리를 호출하고, 표시 턴 번호를 갱신한다.
- `set_turn(number: int) -> void` — 표시 턴 번호를 갱신한다.
- `ended` 시그널 — 버튼을 누르면 방출. `game.gd`가 받아 `TurnManager.end_turn(...)`을 실행한다.

## 게임 연동 (`game.gd`)

- 게임 시작 시 `TurnManager`를 생성하고, 유닛 목록(주인공)·영지 목록(파리)을 보유한다.
- 턴 종료 버튼(`ended`) → `turn_manager.end_turn(units, territories)` → 유닛 강조/흐림 갱신 · HUD 턴 번호 갱신.

## 테스트 시나리오

`test/unit/test_turn.gd`.

- [정상] 생성 직후 `TurnManager.number == 1`
- [정상] `end_turn([], [])` 후 `number == 2`, 두 번 호출하면 `3`
- [정상] `end_turn`에 넘긴 유닛의 `moved_this_turn`이 `true`였다면 호출 후 `false`로 리셋
- [정상] 농장 건물을 가진 영지를 `end_turn`에 넘기면 `resources["밀"]`가 생산량(1)만큼 증가
- [정상] 캠프만 가진 영지는 `end_turn` 후 자원 변화 없음(`production` 없음)
- [경계] `Building.production()` — 캠프는 빈 Dictionary, 농장은 `{밀:1}`
- [경계] `Territory.collect_income()` — 영지에 없던 자원 키도 생산되면 새로 생겨 더해짐

## 관련

- 유닛 이동 1회 제한·흐림 표시는 [Selection & Movement](selection-and-movement.md).
- 생산량 데이터는 [buildings.md](../data/buildings.md)의 `production`.
- 영지 자원은 [Territory](../entities/Territory.md), [Camp Menu](camp-menu.md)에 표시.
