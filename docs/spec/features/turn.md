# Feature: Turn (턴)

> 스크립트: `scenes/turn/turn_manager.gd` (`class_name TurnManager extends RefCounted`) · `scenes/turn/turn_hud.gd` (`extends CanvasLayer`)

게임을 **턴** 단위로 진행한다. 플레이어는 [부대](../entities/Party.md)를 움직인 뒤 **턴 종료**를 눌러 다음 턴으로 넘어간다.
턴이 종료되면 ① 턴 번호가 1 증가하고 ② 모든 부대의 이동 상태가 리셋되며 ③ 모든 영지의 인구가 상한까지 +1 자연 증가하고 ④ 모든 영지의 건설이 1턴 진행된 뒤, ⑤ **자원 생산**([1차 생산](production.md), `game.gd`)·**세력 소멸 유예 판정**([승패](victory.md))을 하고, ⑥ **NPC 부대가 이동**한다([NPC Movement](npc-movement.md)).

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
  3. 각 `territory`에 대해 `territory.grow_population()` — 인구를 상한까지 +1(자연 증가).
  4. 각 `territory`에 대해 `territory.advance_construction()` — 건설 중 건물을 1턴 진행.
  - 새로 완성된 집의 인구 상한은 **다음 턴부터** 인구 증가(3)에 반영된다(건설 진행 4가 인구 증가 뒤).
  - **자원 생산은 `end_turn` 밖**에서 처리한다 — [1차 생산포인트](production.md)는 지형·거리·거점 의존이라 `game.gd`가 턴 종료 시(`_tick_production`) 실행한다. (예전 flat `collect_income`·2차 가공은 폐지.)

## 자원 생산 (턴 종료, `game.gd`)

- flat 생산(`Territory.collect_income`/`Building.production`)과 2차 가공(`_tick_processing`)은 **폐지**됐다. 모든 건물 생산이 [1차 생산(생산포인트, 거리 기반)](production.md)으로 단일화됐고, `game.gd._tick_production`이 턴 종료 시 배정 거점 영지 자원에 반영한다.

## 턴 종료 버튼 (`turn_hud.gd`)

> `extends CanvasLayer` — [캠프 메뉴](camp-menu.md)처럼 UI를 코드로 구성한다(별도 `.tscn` 없음).

- 화면 **우측 아래**에 "턴 종료" 버튼과 현재 턴 번호("턴 N")를 표시한다.
- 버튼을 누르면 게임 루트(`game.gd`)의 턴 종료 처리를 호출하고, 표시 턴 번호를 갱신한다.
- `set_turn(number: int) -> void` — 표시 턴 번호를 갱신한다.
- `ended` 시그널 — 버튼을 누르면 방출. `game.gd`가 받아 `TurnManager.end_turn(...)`을 실행한다.

## 게임 연동 (`game.gd`)

- 게임 시작 시 `TurnManager`를 생성하고, 유닛 목록(맵의 모든 부대 — 플레이어 + NPC)·영지 목록(창천성)을 보유한다. 턴 종료 시 NPC 부대의 이동 상태도 함께 리셋된다.
- 턴 종료 버튼(`ended`) → `turn_manager.end_turn(units, territories)` → **NPC 이동**(`_move_npcs`) → 안개·HUD 턴 번호 갱신. NPC 이동은 `TurnManager` 밖(`game.gd`)에서 처리한다(씬 트리·터레인 의존이라 순수 데이터 계층인 `TurnManager`에 넣지 않는다).

## 턴 진행 순서 (세력 턴, `game.gd`)

한 "턴"(라운드) = **플레이어 세력 행동 → 턴 종료 → NPC 세력들이 정해진 순서로 차례차례 행동 → 다시 플레이어**. 라운드 번호는 하나(`TurnManager.number`).

- **플레이어 턴**: 플레이어가 부대를 조작(이동·공격·작전)하고 `[턴 종료]`로 넘긴다.
- **NPC 턴 — 입력 잠금**: 턴 종료 후 NPC 세력들이 순서대로 이동·공격하는 **동안 플레이어 입력(맵 좌클릭·턴 종료)을 잠근다**(`_npc_turn_active`). NPC 행동이 모두 끝나야 플레이어 턴으로 돌아온다. 카메라 이동·줌은 잠그지 않는다.
  - (기존엔 NPC 이동이 **비차단**이라 NPC가 움직이는 동안에도 플레이어가 조작할 수 있었다 — 세력 턴이 뒤섞여 보이던 문제를 막는다. 이제 `_on_turn_ended`가 NPC 페이즈를 `await`하고, 그 사이 입력 게이트가 `_npc_turn_active`로 막힌다.)
- **세력 배너**([`turn_banner.gd`](#턴-배너-turn_bannergd)): **NPC 세력이 자기 차례를 시작할 때만** 화면 상단에 그 세력 이름을 **세력색**으로 표시한다("○○ 진행 중…"). **플레이어 차례로 돌아오면 배너를 `clear()`**해 감춘다(`_begin_player_turn`) — 플레이어 조작 중에는 진행 배너를 띄우지 않는다. **게임 오버**(`_trigger_game_over`) 시에도 배너를 `clear()`한다(결과 오버레이 위에 안 남게).

**NPC 턴 — 영웅그룹마다 [이동 → 공격]**(Slice B·C): NPC 세력의 턴은 **영웅그룹(영웅+하위부대) 단위**로, 한 그룹이 **이동을 마친 뒤 곧바로 공격**(영웅 먼저·하위 순서로 1유닛씩, 전투 완료 후 다음 유닛)하고 다음 그룹으로 넘어간다. 그룹·교전이 플레이어 시야 안이면 **카메라 포커스 + 토큰 하이라이트**(공격자·대상 1초)로 누가 누굴 치는지 보여주고, 시야 밖이면 즉시 처리한다. **NPC↔NPC 전투는 씬 없이** 헤드리스 결산(시야 안이면 포커스+하이라이트까지만). → [NPC Movement](npc-movement.md#npc-공격-그룹-이동-직후).

## 턴 배너 (`turn_banner.gd`)

> `extends CanvasLayer` — 현재 행동 중인 세력을 화면 상단 중앙에 표시(코드 구성, 입력 통과).

- `set_faction(text: String, color: Color) -> void` — 배너 라벨을 그 세력 이름·색으로 채우고 보인다.
- `clear() -> void` — 배너를 감춘다.

## 테스트 시나리오

`test/unit/test_turn.gd`.

- [정상] 생성 직후 `TurnManager.number == 1`
- [정상] `end_turn([], [])` 후 `number == 2`, 두 번 호출하면 `3`
- [정상] `end_turn`에 넘긴 부대의 `moved_this_turn`이 `true`였다면 호출 후 `false`로 리셋
- [정상] 건설 중 농장을 가진 영지를 `end_turn` → 건설 1턴 진행(remaining −1); build_turns회 후 완성
- [정상] 인구 상한(집 완성으로 12) > 현재 인구(10) 영지를 `end_turn` → 인구 11로 증가; 상한 도달 후엔 유지
- (자원 생산은 `end_turn` 밖 `game.gd`가 처리 — 검증은 [production.md](production.md) 및 헤드리스)

### 턴 배너 — `test/unit/test_turn_banner.gd`

- [정상] `set_faction("암흑 제국", Color(0.5,0,0))` → 라벨 텍스트에 `"암흑 제국"` 포함, `visible == true`
- [정상] `clear()` → `visible == false`
- (입력 잠금·NPC 페이즈 await·세력 배너 전환 타이밍은 `game.gd` 배선이라 실제 실행으로 확인.)

## 관련

- 부대 이동 1회 제한·흐림 표시는 [Selection & Movement](selection-and-movement.md). 부대 이동 상태(`moved_this_turn` 등)의 상세 테스트는 `test/unit/test_party.gd`.
- 자원 생산은 [1차 생산](production.md)(턴 종료 시 `game.gd`).
- 영지 자원은 [Territory](../entities/Territory.md), [Camp Menu](camp-menu.md)에 표시.
