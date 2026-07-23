# Feature: Turn (턴)

> 스크립트: `scenes/turn/turn_manager.gd` (`class_name TurnManager extends RefCounted`) · `scenes/turn/turn_hud.gd` (`extends CanvasLayer`)

게임을 **턴** 단위로 진행한다. 플레이어는 [부대](../entities/Party.md)를 움직인 뒤 **턴 종료**를 눌러 다음 턴으로 넘어간다.
턴이 종료되면 ① 턴 번호가 1 증가하고 ② 모든 부대의 이동력이 리셋되며 ③ 모든 영지의 인구가 상한까지 +1 자연 증가하고 ④ 모든 영지의 건설이 1턴 진행된 뒤, ⑤ **자원 생산**([1차 생산](production.md), `game.gd`)·**세력 소멸 유예 판정**([승패](victory.md))을 하고, ⑥ **NPC 부대가 이동**한다([NPC Movement](npc-movement.md)).

## 규칙

- **부대는 턴당 이동력 풀을 여러 번에 나눠 소진 + 공격 1회.** (문명/에오원4식) 부대는 매 턴 **이동력(`move_points`)** 을 갖고, 범위 안 칸을 클릭할 때마다 경로 누적비용만큼 차감된다. 이동력이 남아 있으면 **같은 턴에 계속 이동**할 수 있고(작게 여러 번 클릭), 0이 되면 그 턴 이동이 끝난다([Selection & Movement](selection-and-movement.md)). 이동 중 **ESC로 현재 칸에서 멈추면** 간 만큼만 소모하고 남은 이동력으로 재경로가 가능하다.
  - 공격은 **턴당 1회**(`attacked_this_turn`)이며 **이동력과 독립**이다 — 공격해도 이동력이 남으면 계속 이동할 수 있고, 이동을 다 써도 공격은 할 수 있다([행동 통합](party-action-menu.md#공격-통합-적-클릭)). `can_move() = move_points > 0`, `can_attack() = not attacked_this_turn`.
  - 턴 종료 시 상태(`move_points`는 `movement()`로, `attacked_this_turn`는 `false`로)가 모두 리셋된다.
- **건물 건설 시작은 턴 제한을 받지 않는다.** 턴당 1회 제한은 **부대 이동에만** 적용된다. 단 건설 자체는 시작 후 `build_turns`만큼 턴이 지나야 완성된다([건축](building.md) 참고).
- 턴 번호는 **1부터** 시작한다.

## 턴 매니저 (`turn_manager.gd`)

> `class_name TurnManager extends RefCounted` — 시각 요소 없는 순수 데이터/로직.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 턴 번호 | `number` | `int` | `1` | 현재 턴. `end_turn` 시 +1 |

- `end_turn(units: Array, territories: Array) -> void` — 한 번의 턴 종료 처리를 모아서 실행한다. `units`에는 [부대](../entities/Party.md)가 들어간다.
  1. `number += 1`
  2. 각 `unit`(부대)에 대해 `unit.reset_turn()` — **이동력을 `movement()`로 채우고** 공격 상태를 리셋.
  3. 각 `territory`에 대해 `territory.grow_population()` — 인구를 상한까지 +1(자연 증가).
  4. 각 `territory`에 대해 `territory.advance_construction()` — 건설 중 건물을 1턴 진행.
  - 새로 완성된 집의 인구 상한은 **다음 턴부터** 인구 증가(3)에 반영된다(건설 진행 4가 인구 증가 뒤).
  - **자원 생산은 `end_turn` 밖**에서 처리한다 — [1차 생산포인트](production.md)는 지형·거리·거점 의존이라 `game.gd`가 턴 종료 시 `BuildingManager.tick_production`으로 실행한다. (예전 flat `collect_income`·2차 가공은 폐지.)

## 자원 생산 (턴 종료, `game.gd`)

- flat 생산(`Territory.collect_income`/`Building.production`)과 2차 가공(`_tick_processing`)은 **폐지**됐다. 모든 건물 생산이 [1차 생산(생산포인트, 거리 기반)](production.md)으로 단일화됐고, `BuildingManager.tick_production`이 턴 종료 시(game.gd가 위임 호출) 배정 거점 영지 자원에 반영한다.

## 턴 종료 버튼 (`turn_hud.gd`)

> `extends CanvasLayer` — [캠프 메뉴](camp-menu.md)처럼 UI를 코드로 구성한다(별도 `.tscn` 없음).

- 화면 **우측 아래**에 "턴 종료" 버튼과 현재 턴 번호("턴 N")를 표시한다.
- 버튼을 누르면 게임 루트(`game.gd`)의 턴 종료 처리를 호출하고, 표시 턴 번호를 갱신한다.
- **턴 종료 버튼 왼쪽에 "명령 남음 N" 표시**를 둔다 — 이번 턴 아직 **명령이 남은 플레이어 부대 수**. 누르면 그 부대들을 순서대로 순환 포커스한다(아래 [다음 유닛]).
  - **판정**: "명령 남음" = **[소진(E) 표시](selection-and-movement.md#소진-표시-e)의 반대**. 살아있는(`soldiers > 0`) 플레이어 부대 중 **실제 갈 수 있는 이동 칸이 있거나**(이동력이 남아도 아군 정지·지형·적으로 막혀 갈 칸이 없으면 제외 — `_has_move_cell`) 현재 칸에서 칠 수 있는 적이 있는(= E가 아닌) 부대. `game.gd`의 `_refresh_exhausted`가 E 배지를 갱신하는 같은 순회에서 함께 집계해 HUD에 넘긴다(단일 출처, `_update_fog` 정착 체인).
  - **0이면 숨긴다** — 모두 소진했으면 "턴 종료"만 보인다.
  - **NPC 턴 중엔 숨긴다**(`_npc_turn_active`) — 턴 종료 시 `end_turn`이 플레이어 부대 이동력을 이미 리셋하므로, NPC가 움직이는 동안 카운터를 띄우면 "명령 남음 N"이 잘못 노출된다. `_npc_turn_active`를 리셋보다 먼저 세워 이 노출을 막고, 플레이어 턴 복귀 시(`_begin_player_turn`) 다시 계산해 표시한다.
- **[다음 유닛]**: "명령 남음 N"을 클릭하면 명령 남은 부대 중 **현재 활성 부대 다음** 부대로 이동한다 — 카메라를 그 부대로 포커스하고 선택(이동 범위·정보 패널 표시, 부대 클릭 전환과 동일). 마지막 다음은 처음으로 순환한다. NPC 턴 진행 중(`_npc_turn_active`)엔 무시한다.
- `set_turn(number: int) -> void` — 표시 턴 번호를 갱신한다.
- `set_commands_left(count: int) -> void` — "명령 남음 N" 표시를 갱신한다. 0이면 숨긴다.
- `ended` 시그널 — "턴 종료"를 누르면 방출. `game.gd`가 받아 `TurnManager.end_turn(...)`을 실행한다.
- `next_unit` 시그널 — "명령 남음 N"을 누르면 방출. `game.gd`가 받아 다음 명령 가능 부대로 포커스·선택한다.

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
- [정상] `end_turn`에 넘긴 부대의 `move_points`가 소진(0)돼 있었다면 호출 후 `movement()`로 리셋
- [정상] 건설 중 농장을 가진 영지를 `end_turn` → 건설 1턴 진행(remaining −1); build_turns회 후 완성
- [정상] 인구 상한(집 완성으로 12) > 현재 인구(10) 영지를 `end_turn` → 인구 11로 증가; 상한 도달 후엔 유지
- (자원 생산은 `end_turn` 밖 `game.gd`가 처리 — 검증은 [production.md](production.md) 및 헤드리스)

### 턴 배너 — `test/unit/test_turn_banner.gd`

- [정상] `set_faction("암흑 제국", Color(0.5,0,0))` → 라벨 텍스트에 `"암흑 제국"` 포함, `visible == true`
- [정상] `clear()` → `visible == false`
- (입력 잠금·NPC 페이즈 await·세력 배너 전환 타이밍은 `game.gd` 배선이라 실제 실행으로 확인.)

### 명령 남음 표시 — `test/unit/test_turn_hud.gd`

- [정상] `set_commands_left(3)` → 표시 텍스트에 `"3"` 포함, `visible == true`
- [경계] `set_commands_left(0)` → 표시 숨김(`visible == false`)
- [정상] "명령 남음" 클릭 → `next_unit` 시그널 방출
- (다음 유닛 순환·카메라 포커스·선택은 `game.gd` 배선이라 실제 실행으로 확인)

## 관련

- 부대 이동력 풀·다중 클릭·ESC 정지·흐림 표시는 [Selection & Movement](selection-and-movement.md). 부대 이동 상태(`move_points` 등)의 상세 테스트는 `test/unit/test_party.gd`.
- 자원 생산은 [1차 생산](production.md)(턴 종료 시 `game.gd`).
- 영지 자원은 [Territory](../entities/Territory.md), [Camp Menu](camp-menu.md)에 표시.
