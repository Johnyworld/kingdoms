# Feature: Turn (턴)

> 스크립트: `scenes/turn/turn_manager.gd` (`class_name TurnManager extends RefCounted`) · `scenes/turn/turn_hud.gd` (`extends CanvasLayer`)

게임을 **턴** 단위로 진행한다. 플레이어는 [부대](../entities/Party.md)를 움직인 뒤 **턴 종료**를 눌러 다음 턴으로 넘어간다.
턴이 종료되면 ① 턴 번호가 1 증가하고 ② 모든 부대의 이동 상태가 리셋되며 ③ 모든 영지가 자원 수입을 받고 ④ 모든 영지의 건설이 1턴 진행된 뒤, ⑤ **NPC 부대가 이동**한다([NPC Movement](npc-movement.md)).

## 규칙

- **부대는 턴당 이동 1회 + 공격 1회.** 이동한 부대는 그 턴에 다시 이동할 수 없지만 공격은 아직 가능하고, 공격/휴식하면 행동이 끝난다([Selection & Movement](selection-and-movement.md)·[Battle](battle.md)·[행동 메뉴](party-action-menu.md)). 턴 종료 시 상태(`moved_this_turn`·`attacked_this_turn`·`rested_this_turn`)가 모두 리셋된다.
- **건물 건설 시작은 턴 제한을 받지 않는다.** 턴당 1회 제한은 **부대 이동에만** 적용된다. 단 건설 자체는 시작 후 `build_turns`만큼 턴이 지나야 완성된다([건축](building.md) 참고).
- 턴 번호는 **1부터** 시작한다.

## 턴 매니저 (`turn_manager.gd`)

> `class_name TurnManager extends RefCounted` — 시각 요소 없는 순수 데이터/로직.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 턴 번호 | `number` | `int` | `1` | 현재 턴. `end_turn` 시 +1 |

- `end_turn(units: Array, territories: Array) -> void` — 한 번의 턴 종료 처리를 모아서 실행한다. `units`에는 [부대](../entities/Party.md)가 들어간다.
  1. `number += 1`
  2. 각 `unit`(부대)에 대해 `unit.reset_turn()` — 이동·공격 상태 리셋.
  3. 각 `territory`에 대해 `territory.collect_income()` — 건물 생산을 자원에 합산.
  4. 각 `territory`에 대해 `territory.advance_construction()` — 건설 중 건물을 1턴 진행.
  - **수입 정산(3) 뒤에 건설 진행(4)** 하므로, 이번 턴에 완성된 건물은 다음 턴부터 생산한다.

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

- 게임 시작 시 `TurnManager`를 생성하고, 유닛 목록(맵의 모든 부대 — 플레이어 + NPC)·영지 목록(창천성)을 보유한다. 턴 종료 시 NPC 부대의 이동 상태도 함께 리셋된다.
- 턴 종료 버튼(`ended`) → `turn_manager.end_turn(units, territories)` → **NPC 이동**(`_move_npcs`) → 안개·HUD 턴 번호 갱신. NPC 이동은 `TurnManager` 밖(`game.gd`)에서 처리한다(씬 트리·터레인 의존이라 순수 데이터 계층인 `TurnManager`에 넣지 않는다).
- NPC 이동은 **경로를 따라가는 애니메이션(비차단)**으로 재생된다([NPC Movement](npc-movement.md)) — 재생 중에도 플레이어는 조작할 수 있다.

## 테스트 시나리오

`test/unit/test_turn.gd`.

- [정상] 생성 직후 `TurnManager.number == 1`
- [정상] `end_turn([], [])` 후 `number == 2`, 두 번 호출하면 `3`
- [정상] `end_turn`에 넘긴 부대의 `moved_this_turn`이 `true`였다면 호출 후 `false`로 리셋
- [정상] 농장 건물을 가진 영지를 `end_turn`에 넘기면 `resources["밀"]`가 생산량(1)만큼 증가
- [정상] 캠프만 가진 영지는 `end_turn` 후 자원 변화 없음(`production` 없음)
- [경계] `Building.production()` — 캠프는 빈 Dictionary, 농장은 `{밀:1}`
- [경계] `Territory.collect_income()` — 영지에 없던 자원 키도 생산되면 새로 생겨 더해짐
- [정상] 건설 중 농장을 가진 영지를 `end_turn` → 건설 1턴 진행, 완성 전엔 밀 수입 없음
- [정상] build_turns회 `end_turn` 후 농장 완성, 그 **다음** 턴 종료부터 밀 수입 발생

## 관련

- 부대 이동 1회 제한·흐림 표시는 [Selection & Movement](selection-and-movement.md). 부대 이동 상태(`moved_this_turn` 등)의 상세 테스트는 `test/unit/test_party.gd`.
- 생산량 데이터는 [buildings.md](../data/buildings.md)의 `production`.
- 영지 자원은 [Territory](../entities/Territory.md), [Camp Menu](camp-menu.md)에 표시.
