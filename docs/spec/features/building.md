# Feature: Construction (건축)

> 스크립트: `scenes/building/build_planner.gd` (`class_name BuildPlanner`) · `scenes/territory/territory.gd` · `scenes/building/building.gd` · `scenes/turn/turn_manager.gd`

캠프 메뉴의 **"건축"**으로 새 건물을 짓는 기능. 흐름은 다음과 같다:

1. 캠프 메뉴에서 **건축** → 건설 가능 건물 리스트에서 농장 선택([캠프 메뉴](camp-menu.md)) → 건설 모드 진입.
2. 맵에서 배치할 위치를 고른다. **영지 시야 안**이고 빈 땅이어야 배치할 수 있다.
3. 배치하면 영지 자원에서 **건설 비용(`build_cost`)을 즉시 차감**하고, 그 자리에 **건설 중** 건물이 생긴다.
4. 턴이 종료될 때마다 건설이 **1턴씩 진행**되고, `build_turns`만큼 지나면 **완성**된다.
5. 완성된 건물부터 생산(`production`)·시야가 동작한다.

이번 슬라이스는 **농장(`farm`)** 건설만 다룬다. 캠프 건설(새 영지 생성)은 이후로 미룬다.

## 구현 범위 (슬라이스)

| 슬라이스 | 내용 | 상태 |
| --- | --- | --- |
| **1 — 코어 로직** | 자원 검사·차감 · 건설 중 상태 · 턴 진행 · 배치 유효성 판정 | **구현됨** |
| **2a — 건물 리스트 UI** | "건축" 버튼 → [캠프 메뉴](camp-menu.md) 우측 패널에 건설 가능 건물 리스트(농장, 비용, 부족 시 비활성) → 선택 시 `build_selected` 시그널 | **구현됨** |
| **2b — 건설 모드 배치** | 시그널 수신 → 건설 모드 진입 → 맵 hover 미리보기 → 클릭 배치 → 자원 차감·건물 생성·영지 편입 | **구현됨** |

> 슬라이스 1(코어 로직)·2a(리스트 UI)·2b(건설 모드 배치)가 모두 구현됐다. 남은 건 완성 농장의 시야를 [안개](fog-of-war.md)에 반영하는 작업, 캠프 건설(새 영지 생성), 철거다.

## 건설 모드 (`game.gd`)

캠프 메뉴의 `build_selected(type_id, territory)`를 게임이 받아 **건설 모드**로 들어간다.

- 진입: `_build_mode = true`, 건설할 종류·비용 지불 영지를 기억한다. **건설 가능 영역**(영지 시야) 윤곽선을 계산해 표시한다(아래 `BuildArea`).
- **마우스 이동**: 커서 아래 셀을 중심으로 footprint 7헥스 **미리보기**를 그린다(`BuildPreview`). 배치 가능하면 초록, 불가하면 빨강.
  - 배치 가능 판정 = `BuildPlanner.can_place(...)`. 시야 = `BuildPlanner.territory_vision(영지)`, 점유 = `BuildPlanner.occupied_cells(맵의 모든 건물)`.
- **좌클릭**: 배치 가능한 자리면 → 영지에서 `build_cost` 차감(`spend`) → 그 자리에 **건설 중** 건물 생성(`Building.setup(.., true)`) → 영지에 편입(`add_building`) → 건설 모드 종료. 불가한 자리면 무시(모드 유지).
- **우클릭 / ESC**: 건설 모드 취소(미리보기·영역 윤곽선 제거).
- 건설 모드 중에는 유닛 선택·이동·캠프 메뉴 열기 등 일반 클릭이 동작하지 않는다.

## 건설 가능 영역 표시 (`BuildArea` 오버레이)

> 스크립트: `scenes/game/build_area_overlay.gd` (`extends Node2D`). 다른 오버레이처럼 `terrain.map_to_local`로 월드 좌표에 그린다. `z_index`를 안개(10)보다 높고 미리보기(20)보다 낮게 두어(15) 안개 위·footprint 아래에 표시한다.

건설 모드에서 **어디에 건물을 지을 수 있는지**를 한눈에 보이도록, "건물을 지을 수 있는 영역"의 **바깥 윤곽선만 파랑 선**으로 그린다.

- "건물을 지을 수 있는 영역" = 비용을 지불하는 **영지의 시야**(`BuildPlanner.territory_vision`) 전체. 개별 자리의 겹침·가장자리(footprint 유효성)는 이 영역이 아니라 hover 미리보기(초록/빨강)가 담당한다.
- 시야는 배치하는 동안 변하지 않으므로 **건설 모드 진입 시 한 번** 계산해 그리고, 종료(배치/우클릭/ESC) 시 지운다. Node2D 월드 좌표라 카메라 이동·줌에는 자동으로 따라간다.
- 윤곽선은 안개(z=10)보다 위(z=15)라 **안개 영역에서도 보인다**(어디에 지을 수 있는지 항상 표시). 다만 완성 농장 시야는 아직 [안개](fog-of-war.md)에 반영되지 않으므로, 캠프 시야를 벗어나 지은 완성 농장의 buildable 영역 경계가 안개 낀 곳에 파랑 선으로 보일 수 있다(농장 시야→안개 반영은 별도 TODO).
- `setup(terrain)` · `show_area(cells)`(영역 셀 집합 → 윤곽선 계산 후 그림) · `clear()`.
- 윤곽선은 `HexGrid.region_outline(terrain, cells)`로 계산한 경계 변들을 `draw_line`으로 그린다(파랑, 굵기 3).

### 영역 윤곽선 계산 (`HexGrid`)

> `HexGrid`(`scenes/game/hex_grid.gd`)에 순수 지오메트리 헬퍼로 추가한다. 반경/BFS와 같은 성격의 static 함수.

- `hex_polygon(terrain, cell) -> PackedVector2Array` — 셀의 헥스 6꼭짓점(뾰족한 위/아래, 타일셋 `tile_size` 기준). 오버레이가 그리는 헥스와 동일한 모양.
- `region_outline(terrain, cells) -> Array` — 영역(`{cell: true}` 또는 셀 배열)의 **바깥 윤곽선**을 이루는 변 목록. 각 셀의 6개 변 중 **이웃 셀과 공유하지 않는 변만** 남긴다(내부 변은 두 번 나와 상쇄). 반환 항목은 각각 `[시작점, 끝점]`인 `PackedVector2Array`(월드 좌표). 인접 헥스의 공유 변은 두 꼭짓점이 정확히 일치하므로(정수 반올림 키로 비교) 내부 변이 깔끔히 제거된다.

> 완성 농장의 시야는 아직 [안개](fog-of-war.md)에 반영되지 않는다(안개는 주인공+캠프만 계산). 캠프 시야(5)를 벗어나 지은 농장은 안개에 가려 보일 수 있다 — 별도 TODO.

## 미리보기 오버레이 (`BuildPreview`)

> 스크립트: `scenes/game/build_preview.gd` (`extends Node2D`). 다른 오버레이(RangeOverlay·Fog)처럼 `terrain.map_to_local`로 헥스를 그린다. `z_index`를 안개보다 높게 두어 위에 표시한다.

- `setup(terrain)` · `show_preview(cells, valid)`(초록/빨강) · `clear()`.

## 자원 검사·차감 (`Territory`)

- `Territory.can_afford(cost: Dictionary) -> bool` — `cost`의 모든 자원에 대해 `resources.get(자원, 0) >= 수량`이면 참. `cost`가 비면 항상 참.
- `Territory.spend(cost: Dictionary) -> void` — `cost`의 각 자원을 `resources`에서 뺀다(`resources[자원] = resources.get(자원, 0) - 수량`). 음수 방지는 하지 않으므로 호출 전에 `can_afford`로 확인한다.

건설 비용의 출처는 [건물 카탈로그](../data/buildings.md)의 `build_cost`다. 파는 자원은 **캠프 메뉴를 연 건물의 영지**(`building.territory`)에서 차감한다.

## 건설 중 상태 (`Building`)

건물은 **건설 중** 또는 **완성** 상태를 가진다.

- `under_construction: bool`(기본 `false`) · `remaining_turns: int`(기본 `0`).
- `setup(terrain, center_cell, type_id, under_construction := false)` — `under_construction`이 참이면 상태를 건설 중으로 두고 `remaining_turns`를 카탈로그의 `build_turns`로 채운다. 기본값(거짓)이면 **즉시 완성** 상태(기존 동작과 동일).
- `is_complete() -> bool` — 건설 중이 아니면 참.
- `advance_construction() -> bool` — 건설을 1턴 진행한다. 이미 완성이면 아무 일도 안 하고 `false`. 건설 중이면 `remaining_turns -= 1`, 0 이하가 되면 완성 처리(`under_construction = false`, `remaining_turns = 0`)하고 **이번에 완성됐으면 `true`** 반환, 아직 진행 중이면 `false`.
- `production() -> Dictionary` — **건설 중에는 빈 Dictionary**(생산 없음). 완성 후에만 카탈로그 `production`을 반환.
- 시야: 건설 중 건물은 시야에 기여하지 않는다(배치 유효성의 `territory_vision`이 완성 건물만 센다). `vision` 값 자체는 종류 스펙 그대로 유지.
- 렌더: 건설 중이면 반투명하게 그리고 중심 근처에 **"건설 중 N"**(남은 턴)을 표시한다.

## 턴 진행 (`TurnManager` · `Territory`)

턴 종료 시 건설을 진행한다. **수입 정산 뒤에 건설을 진행**하므로, 이번 턴에 완성된 건물은 **다음 턴부터** 생산한다.

- `Territory.advance_construction() -> void` — 소속 건물들의 `advance_construction()`을 호출한다.
- `TurnManager.end_turn(units, territories)` 순서: ① `number += 1` → ② 유닛 `reset_turn` → ③ 영지 `collect_income` → ④ 영지 `advance_construction`.

## 배치 유효성 (`BuildPlanner`)

> `class_name BuildPlanner extends RefCounted` — 시각 요소 없는 static 헥스 유틸(`scenes/game/hex_grid.gd`의 `HexGrid`와 같은 성격, `HexGrid`를 재사용).

- `footprint(terrain, center) -> Array[Vector2i]` — 중심 + 이웃 6칸(총 7헥스). [Building](../entities/Building.md)의 점유 셀과 같은 규칙.
- `territory_vision(terrain, territory, map_w, map_h) -> Dictionary` — 영지의 **완성 건물**들에 대해 각 `center_cell` 기준 `vision` 반경 안 셀을 합집합으로 모은 `{cell: true}`. 건설 중 건물은 제외한다.
- `occupied_cells(buildings) -> Dictionary` — 건물 목록의 점유 셀(`building.cells`) 합집합 `{cell: true}`. 겹침 검사에 쓴다.
- `can_place(terrain, center, map_w, map_h, vision_cells, occupied) -> bool` — 중심 `center`에 건물을 놓을 수 있는지. footprint 7헥스가 **모두**:
  1. 맵 범위 `[0, map_w) × [0, map_h)` 안이고,
  2. `vision_cells`(영지 시야) 안이고,
  3. `occupied`(이미 건물이 점유한 셀 집합)와 겹치지 않으면
  참. 하나라도 위반하면 거짓. 맵 가장자리라 이웃이 범위를 벗어나면(footprint < 7 in-bounds) 배치 불가.

## 테스트 시나리오

- `test/unit/test_territory.gd` (자원 검사·차감)
  - [정상] `can_afford({목재:5})` — 자원이 충분하면 참, 부족하면 거짓
  - [경계] `can_afford({})` — 빈 비용은 항상 참
  - [경계] 없는 자원 키를 요구하면(`{철:1}`, 보유 없음) 거짓
  - [정상] `spend({목재:5, 밀:5})` 후 해당 자원이 정확히 줄어든다
- `test/unit/test_building.gd` (건설 중 상태)
  - [정상] `setup(.., "farm", true)` 후 `is_complete() == false`, `remaining_turns == 3`(=build_turns), `production() == {}`
  - [정상] `setup(.., "farm")`(기본) 후 `is_complete() == true`, `production() == {밀:1}`
  - [정상] `advance_construction()`을 build_turns회 호출하면 완성되고, 완성되는 호출만 `true` 반환
  - [경계] 완성된 건물에 `advance_construction()` → `false`, 상태 불변
  - [정상] 완성 후 `production() == {밀:1}`
- `test/unit/test_turn.gd` (턴 진행)
  - [정상] 건설 중 농장을 가진 영지를 `end_turn` → 건설 1턴 진행(`remaining_turns` 감소), 완성 전엔 `밀` 수입 없음
  - [정상] build_turns회 `end_turn` 후 농장 완성, 그 **다음** 턴 종료부터 `밀` 수입 발생
- `test/unit/test_build_planner.gd` (배치 유효성, 신규)
  - [정상] 시야 안 + 빈 땅 + 맵 내부 중심 → `can_place` 참
  - [예외] footprint 일부가 시야 밖 → 거짓
  - [예외] footprint가 기존 건물과 겹침 → 거짓
  - [예외] 맵 가장자리라 이웃이 범위를 벗어남 → 거짓
  - [정상] `territory_vision`은 완성 건물만 반영(건설 중 건물은 시야에 기여 안 함)
  - [정상] `footprint`는 7헥스(중심+이웃 6)
  - [정상] `occupied_cells`는 건물들의 점유 셀 합집합(건물 1개면 7셀, 겹치지 않는 2개면 14셀)
- `test/unit/test_hex_grid.gd` (영역 윤곽선, `HexGrid.region_outline`)
  - [정상] 단일 셀 → 경계 변 6개(헥스의 모든 변)
  - [정상] 인접한 두 셀 → 경계 변 10개(총 12변 중 공유 변 1개 제외)
  - [정상] 반경 1 디스크(7셀) → 경계 변 18개(바깥 링 6셀 × 바깥 변 3)
  - [정상] `hex_polygon`은 꼭짓점 6개

## 관련

- 종류별 `build_cost`·`build_turns`·`production`은 [buildings.md](../data/buildings.md).
- 건설 중 상태를 가지는 건물은 [Building 엔티티](../entities/Building.md).
- 자원을 보유·차감하는 [Territory 엔티티](../entities/Territory.md).
- 턴 종료 처리 순서는 [Turn](turn.md).
- 건설 모드 UI(슬라이스 2)는 [Camp Menu](camp-menu.md)의 건축 버튼에서 진입 예정(미구현).
