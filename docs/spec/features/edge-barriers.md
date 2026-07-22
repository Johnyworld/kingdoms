# Feature: Edge Barriers (경계 장벽 — 강·벽)

> 데이터: `scenes/game/barriers.gd` (`class_name Barriers`, `@tool extends Node2D`)
> 이동 로직: `scenes/game/hex_grid.gd` (`edge_key`·`cost_distances`의 `blocked_edges`)
> 에디터 툴: `addons/edge_barrier/` (EditorPlugin)

강·벽은 **칸이 아니라 두 칸 사이 경계(edge)** 에 있는 이동 장벽이다. 양옆 칸은 통행 가능한 채로, **그 경계만 못 건넌다**(칸 통행불가인 산·물·불가 건물과 다른 축). LaPetiteTile에서 강은 Ocean underlay가 Ground 틈으로 비쳐 **칸 사이 선**으로 보이므로, 칸 단위 통행불가로는 못 막아 경계 단위가 필요하다.

## 데이터 모델 (`Barriers` 노드)

`game.tscn`의 `Barriers`(Node2D)가 authored 장벽을 보관한다.

- 저장: `@export var data: PackedInt32Array` — 장벽당 `[ax, ay, bx, by, kind]`(STRIDE=5) 반복(flat).
- **종류(kind)**:
  | 상수 | 값 | 의미 | 상호작용(후속) |
  | --- | --- | --- | --- |
  | `KIND_RIVER` | 0 | 강 | 다리 건설 시 그 경계 해제 |
  | `KIND_WALL` | 1 | 벽 | 철거 시 제거 |
  | `KIND_WALL_PERMANENT` | 2 | 영구 벽 | 허물 수 없음 |
- API: `add_edge(a,b,kind)`(있으면 kind 교체)·`remove_edge(a,b)`·`has_edge(a,b)`·`kind_of(a,b)`·`count()`·`at(i)`·`blocked_edge_set()`. 경계는 순서 무관(`HexGrid.edge_key`로 정규화).
- `blocked_edge_set() -> { edge_key: kind }` — 이동 BFS가 그대로 쓰는 차단 경계 집합.
- **에디터 렌더**(`_draw`, `Engine.is_editor_hint()` 한정): 설정된 장벽을 kind 색선(강=파랑·벽=밝은회색·영구=진회색)으로 표시. **게임 화면엔 안 나온다**(강은 Ocean 타일로 보임).

## 이동 차단 (`HexGrid`)

- `edge_key(a, b) -> String` — 두 인접 칸 경계의 정규 키(순서 무관).
- `cost_distances`/`movement_ranges`/`reconstruct_path`/`follow_destination`은 선택 인자 **`blocked_edges: Dictionary`**(`{edge_key: ...}`)를 받는다. 이웃으로 확장할 때 그 경계가 집합에 있으면 **건너뛴다**(칸은 열려 있으므로 우회는 가능). `reconstruct_path` 역추적도 차단 경계를 선행 후보에서 제외한다.
- `edge_segment(terrain, a, b) -> PackedVector2Array` — 두 칸 공유 변의 두 끝점(월드). 렌더·편집 툴 공용.
- **최종 차단 집합 합성**(`game.gd.barrier_edges()`): 현재는 `Barriers.blocked_edge_set()`뿐. 앞으로 `(authored 장벽 ∪ 건설된 벽) − (건설된 다리)`로 출처를 더한다(다리·철거·건설벽은 후속 — 합성 구조라 재설계 없이 추가). 플레이어·NPC 이동이 `world.barrier_edges()`로 같은 집합을 공유(소속 무관).

## 에디터 툴 (`addons/edge_barrier`)

`Barriers` 노드를 선택하면 활성화되는 EditorPlugin.

- 툴바(강/벽/영구벽 kind 선택). 2D 캔버스에 **클릭 가능한 헥스 경계 그리드**(옅게, 보이는 범위만·과도한 줌아웃 시 생략)를 그린다.
- 경계 **클릭 → 그 장벽 토글**(현재 kind로 추가 / 이미 있으면 제거). 커서 아래 칸 + 6이웃 중 공유 변 중점이 가장 가까운 경계를 고른다. Undo/Redo 지원(`EditorUndoRedoManager`).
- 다른 노드 선택 시엔 그리드를 안 그린다(설정된 장벽은 `Barriers._draw`가 항상 표시).
- 제작 흐름: `game.tscn` 열기 → `Barriers` 선택 → kind 고르고 경계 클릭 → 저장 → 실행하면 부대가 그 경계를 못 건넌다.

## 한계 / 후속

- **다리**(강 경계 해제)·**철거**(벽 제거)·**건설 벽**(런타임 경계 추가)은 미구현 — `barrier_edges()` 합성에 출처만 더하면 된다.
- 공격·시야는 경계에 막히지 않는다(이동 BFS에만 `blocked_edges` 적용). 강 너머 사격 가능.
- 툴은 헤드리스 테스트 불가(에디터 UI) — 데이터(`Barriers`)·경계 차단(`HexGrid`)·`edge_segment`만 단위 테스트한다.

## 테스트

- `test/unit/test_barriers.gd` — `add_edge`/`remove_edge`/`has_edge`/`kind_of`(순서 무관·중복 시 kind 교체), `blocked_edge_set` 키가 `HexGrid.edge_key`와 일치.
- `test/unit/test_hex_grid.gd` — `edge_key` 대칭, 경계 차단 시 직행 불가·우회 도달, `reconstruct_path`가 차단 경계 안 건넘, `edge_segment`가 두 헥스 공유 꼭짓점.
