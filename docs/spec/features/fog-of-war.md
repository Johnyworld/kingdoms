# Feature: Fog of War (전장의 안개)

> 스크립트: `scenes/game/fog.gd` (`extends Node2D`, z_index 10)

맵 전체를 검정으로 덮되, 시야/탐험 상태에 따라 3단계로 표현한다.

## 3단계 표현

| 상태 | 표현 | 색상 |
| --- | --- | --- |
| 탐험 안 됨 | 불투명 검정 (아무것도 안 보임) | `Color(0,0,0,1.0)` |
| 탐험됨 + 현재 시야 밖 | 반투명 검정 (지형만 보임) | `Color(0,0,0,0.5)` |
| 현재 시야 안 | 그리지 않음 (완전히 보임) | — |

## 시야 계산 (`game.gd` `_update_fog`)

- 주인공 [부대](../entities/Party.md) 시야원 + **모든 완성 건물**(캠프·농장 등) 시야원을 합쳐 현재 시야 셀을 구한다.
- 각 시야원은 `HexGrid.cells_within(terrain, start, radius, ...)` — BFS로 헥스 거리 반경 내 셀 (이동 범위 계산과 같은 헬퍼 공유).
  - 부대: `party.vision()` 반경 — 아키타입 lang 클래스 시야([UnitTypes](../data/unit-types.md)).
  - 건물: `BuildPlanner.buildings_vision(terrain, BuildingManager.buildings, ...)` — 맵의 모든 건물 중 **완성된 것**만 `center_cell()` 기준 `building.vision` 반경으로 합친다. 건설 중 건물은 시야에 기여하지 않는다.
- 시작 시, 턴 종료 시(건설이 진행돼 농장이 완성되면 그 시야를 반영), 그리고 **플레이어 이동 애니메이션 중 토큰이 각 칸에 도착할 때마다** 갱신한다 — 걸어가는 동안 안개가 점진적으로 걷힌다([Selection & Movement](selection-and-movement.md)).

## NPC 부대 표시 (안개 반영)

NPC [부대](../entities/Party.md) 토큰은 플레이어의 시야에 따라 보이거나 숨는다.

- NPC 토큰은 플레이어의 **현재 시야 안에 있을 때만** 보인다. 시야 밖 셀에 있으면 안개에 가려 숨긴다(`Node2D.visible = false`).
- NPC 부대는 플레이어의 시야를 **밝히지 않는다** — 적 부대이므로 `_update_fog`의 시야 합산에 기여하지 않는다.
- 판정은 `fog.is_cell_visible(cell)` — 셀이 현재 시야(`_visible`)에 있으면 true. **탐험만 된 셀**(과거에 봤지만 지금은 시야 밖)은 false → NPC가 떠난 자리에 마지막 위치 잔상이 남지 않는다.
- `game.gd` `_update_npc_visibility`가 `_update_fog` 갱신 직후 각 NPC 부대의 `visible`을 토글한다(시작 시·이동 후·턴 종료 시).

## NPC 거점 표시 (안개 반영)

NPC [거점](npc-bases.md)(캠프)은 부대와 달리 **탐험됨** 기준으로 표시된다 — 한 번 발견하면 시야를 벗어나도 계속 보인다(정적 구조물).

- 판정은 `fog.is_cell_explored(cell)` — 셀이 `_explored`에 있으면(현재 시야이거나 **과거에 봤던** 셀) true.
- `game.gd` `_update_npc_building_visibility`가 각 거점의 7칸 중 하나라도 탐험됐으면 `visible = true`로 토글한다(미발견이면 안개에 가림).
- NPC 거점도 플레이어 시야를 밝히지 않는다(`buildings_vision`은 플레이어 `BuildingManager.buildings`만 합산).

## 상태 (`fog.gd`)

- `_visible` — 현재 시야에 들어온 셀 집합.
- `_explored` — 한 번이라도 시야에 들어온 셀 집합 (영구 기록).
- `update_visible(cells)` — 시야 갱신 + 새 셀을 탐험됨으로 기록 + 다시 그림.
- `is_cell_visible(cell) -> bool` — 셀이 **현재 시야**(`_visible`)에 있는지. NPC 부대 표시 판정에 사용(탐험만 된 셀은 false).
- `is_cell_explored(cell) -> bool` — 셀이 한 번이라도 시야에 든 적 있는지(`_explored`). NPC 거점 표시 판정에 사용(발견 후 상시).

## 성능 최적화

맵 전체를 매 갱신마다 다시 그리면 낭비다(현재 50×50).

- **카메라에 보이는 셀 범위만** 계산해 그린다 (`_visible_cell_bounds`).
  - 뷰포트 네 모서리를 월드→셀 좌표로 역변환해 최소/최대 범위를 구하고 여유 마진 3칸.
- 그 범위가 바뀔 때만(`_last_bounds` 비교) 다시 그린다 (카메라 이동/줌 감지).

## 테스트 시나리오

`test/unit/test_fog.gd`.

- [정상] `update_visible`에 넘긴 셀이 현재 시야(`_visible`)에 기록됨
- [정상] 새 `update_visible` 호출 시 현재 시야는 **교체**됨 (이전 시야 셀은 빠짐)
- [정상] 한 번 본 셀은 탐험 기록(`_explored`)에 **누적**됨
- [경계] 시야가 완전히 사라져도(`{}`) 탐험 기록은 **줄어들지 않음**
- [정상] `is_cell_visible`은 현재 시야에 있는 셀에 대해 `true`
- [예외] 한 번도 시야에 든 적 없는 셀은 `is_cell_visible`이 `false`
- [경계] 봤다가 시야에서 벗어난 셀(탐험됨·현재 시야 밖)은 `is_cell_visible`이 `false`
- [정상] 현재 시야 셀·탐험만 된 셀 모두 `is_cell_explored`가 `true`; 한 번도 본 적 없는 셀은 `false`
