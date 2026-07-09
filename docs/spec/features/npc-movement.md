# Feature: NPC Movement (NPC 이동 AI)

> 스크립트: `scenes/game/npc_ai.gd` (`class_name NpcAi extends RefCounted`) · `scenes/game/game.gd` (`_move_npcs`)

턴 종료 시 각 [NPC 부대](parties.md)가 스스로 이동한다. 목표 지향 판단 없이 **자기 이동력으로 도달 가능한 가장 먼 칸들 중 하나로 무작위** 이동하는 단순 AI다.

## 동작

- **시점**: 플레이어가 턴 종료를 누르면([Turn](turn.md)), 유닛 리셋·자원 수입·건설 진행 뒤에 NPC들이 이동한다.
- **목적지 선택**(`NpcAi.choose_destination`):
  1. `HexGrid.movement_ranges(terrain, start, move_range, ..., blocked_cells)`로 이동 가능한 목적지 집합(`move`)과 거리 맵(`dist`)을 구한다. 지형 규칙(산 진입 불가·숲 `ceil`·습지 `floor` 반감)·맵 경계·**다른 부대 점유 칸**([유닛 점유](selection-and-movement.md))은 이 헬퍼가 반영한다.
  2. 이동 칸 중 **거리가 가장 먼(최대 `dist`) 칸들**만 후보로 추린다.
  3. 후보에서 `RandomNumberGenerator`로 하나를 무작위 선택한다.
  - **도달 가능한 이동 칸이 없으면**(이동력 0, 사방이 산/맵 밖 등) 시작 칸을 그대로 반환한다(제자리).
- **이동 반영**(`game.gd` `_move_npcs`): 각 NPC를 선택된 칸까지 **경로를 따라 애니메이션**으로 이동시킨다(아래).

## 이동 애니메이션

NPC는 순간이동하지 않고 시작 칸에서 목적지 칸까지 **헥스 최단 경로를 칸 단위로 걸어가는 모습**을 보여준다.

- **경로 재구성**(`HexGrid.reconstruct_path`): 시작→목적지 최단 헥스 경로(칸 목록, 양끝 포함)를 BFS로 구한다. 지형(산)·경계를 반영하며, 도달 불가면 빈 배열, 제자리(start==dest)면 `[start]`.
- **공용 이동 헬퍼**(`game.gd` `_animate_path`): 부대를 경로의 칸을 차례로 지나도록 Tween으로 이동시키고, 각 칸 도착 시 콜백을 실행한다. NPC(자기 시야 표시 토글)와 플레이어([이동 애니메이션](selection-and-movement.md), 시야 열림)가 공유한다.
- **속도**: 칸당 `MOVE_STEP_TIME`(0.12초, 플레이어 이동과 공유). 이동력 4칸이면 약 0.5초.
- **재생 순서**:
  - **세력 간 순차** — 한 세력의 모든 부대 애니메이션이 끝나야 다음 세력이 시작한다.
  - **세력 내 동시(스태거)** — 같은 세력의 여러 부대는 동시에 움직이되 `NPC_PARTY_STAGGER`(0.2초)씩 시작을 늦춘다. *(현재는 세력당 NPC가 1부대라 스태거는 부대가 늘면 나타난다.)*
- **비차단**: 애니메이션이 도는 동안에도 플레이어는 카메라 이동·클릭을 할 수 있다(입력 잠금 없음).
- **이동 중 안개 표시**: 토큰이 지나는 각 칸에서 `fog.is_cell_visible(cell)`로 `visible`을 토글한다 — 시야 밖 칸을 지날 땐 숨고, 시야 안 칸에서 다시 보인다([Fog of War](fog-of-war.md)).
- **재진입**: 애니메이션 도중 플레이어가 다시 턴 종료를 누르면, 진행 중이던 이동은 **목적지로 즉시 스냅**한 뒤 새 이동을 시작한다(상태가 어긋나지 않도록).

## 범위 밖 (미구현)

- **목표 지향 AI** — 플레이어·자원·영지를 향한 판단 없이 순수 무작위. *(다음 단계)*
- **전투** — NPC가 플레이어/서로 만나도 아무 일도 없다. *(미구현)*
- **유닛 충돌·점유** — 다른 부대가 점유한 칸은 통과·정지 불가([유닛 점유](selection-and-movement.md)). 단 **동시 계획 한계**: 턴 종료 시 모든 NPC 목적지를 각자의 현재 위치 기준으로 한 번에 계산하므로, 두 NPC가 같은 빈 칸을 목표로 삼을 수 있다(예약 시스템 없음). *(다음 단계)*
- **건물 통행** — 건물 위로는 계속 겹쳐 지날 수 있다(유닛만 서로 막음).
- **이동 상태(`moved_this_turn`)** — NPC 이동은 이 플래그를 건드리지 않는다(흐림 표시는 플레이어 조작용 신호라서). 턴 리셋에 NPC가 포함돼 있어도 무해한 no-op.

## 테스트 시나리오

목적지 선택은 `test/unit/test_npc_ai.gd`, 경로 재구성은 `test/unit/test_hex_grid.gd`에서 검증한다.
실제 헥스 타일셋 `TileMapLayer`로 검증한다(엔진 인접 동작 의존). 애니메이션(Tween·타이밍·세력 순서)은 `game.gd` 오케스트레이션이라 실제 실행으로 확인한다.

### 목적지 선택 (`test_npc_ai.gd`)

- [정상] 초원에서 목적지는 이동 가능 집합(`movement_ranges["move"]`)에 속한다
- [정상] 목적지는 도달 가능한 **최대 거리** 칸이다(평지 이동력 r → 거리 r)
- [경계] 이동력 0이면 목적지 = 시작 칸(제자리)
- [정상] 같은 시드의 `RandomNumberGenerator` → 같은 목적지(결정적)
- [지형] 산으로 둘러싸인 경우 목적지가 산 칸이 아니다(도달 가능 칸만)
- [점유] `blocked_cells`로 준 점유 칸은 목적지로 고르지 않는다
- [점유] 도달 가능한 칸이 전부 점유되면(이동력 1 + 이웃 전부 점유) 목적지 = 시작 칸(제자리)

### 경로 재구성 (`HexGrid.reconstruct_path` — `test_hex_grid.gd`)

- [정상] 초원 start→dest(거리 3): 경로 길이 4, 양끝이 start·dest, 이웃끼리 인접, 거리 단조 증가
- [경계] start == dest → `[start]`
- [경계] 인접 칸(거리 1) → 경로 길이 2
- [예외] 도달 불가한 dest(산으로 격리) → `[]`
- [지형] 경로에 산 칸이 없다

## 관련

- 이동 목적지·지형 규칙은 [Selection & Movement](selection-and-movement.md)의 `HexGrid.movement_ranges`.
- 이동 후 표시는 [Fog of War](fog-of-war.md), 이동 시점은 [Turn](turn.md).
- NPC 부대 생성·배치는 [Parties](parties.md).
