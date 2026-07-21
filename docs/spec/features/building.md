# Feature: Construction (건축)

> 스크립트: `scenes/building/build_planner.gd` (`class_name BuildPlanner`) · `scenes/territory/territory.gd` · `scenes/building/building.gd` · `scenes/turn/turn_manager.gd`

캠프 메뉴의 **"건축"**으로 새 건물을 짓는 기능. 흐름은 다음과 같다:

1. 캠프 메뉴에서 **건축** → 건설 가능 건물 리스트에서 농장 선택([캠프 메뉴](camp-menu.md)) → 건설 모드 진입.
2. 맵에서 배치할 위치를 고른다. **영지 시야 안**이고 빈 땅이어야 배치할 수 있다.
3. 배치하면 영지 자원에서 **건설 비용(`build_cost`)을 즉시 차감**하고, 그 자리에 **건설 중** 건물이 생긴다.
4. 턴이 종료될 때마다 건설이 **1턴씩 진행**되고, `build_turns`만큼 지나면 **완성**된다.
5. 완성된 [1차 생산](production.md) 건물부터 자원 채취·시야가 동작한다.

건설 가능한 종류는 `BuildingTypes.BUILDABLE_IDS` — **농장 · 벌목소 · 철광 · 금광 · 집**([buildings.md](../data/buildings.md)). **거점(캠프·마을회관·성)은 건축 리스트에 없다** — 마을회관·성은 [거점 업그레이드](#거점-업그레이드)로만 도달하고, 캠프 건설(새 영지)은 별도 버튼. 종류마다 발자국(`footprint`)이 다르다 — 소형 건물(농장·벌목소·철광·금광·집)은 1헥스.

**선행 = 거점 티어**: 각 종류는 [`prerequisite`](../data/buildings.md#선행건물-prerequisite--거점-티어-기준)(거점 티어)를 가진다. 1차 생산(농장·벌목소·철광·금광)은 거점 tier 0(캠프)부터, 집은 tier 1(마을회관)부터. 선행 미충족 종류는 건축 리스트에 뜨되 비활성이다(아래 [선행건물 게이트](#선행건물-게이트)).

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
- **마우스 이동**: 커서 아래 셀을 중심으로 **종류의 footprint만큼**(7헥스 또는 1헥스) **미리보기**를 그린다(`BuildPreview`). 배치 가능하면 초록, 불가하면 빨강.
  - 배치 가능 판정 = `BuildPlanner.can_place(..., hexes)`. `hexes`는 건설할 종류의 카탈로그 `footprint`. 시야 = `BuildPlanner.territory_vision(영지)`, 점유 = `BuildPlanner.occupied_cells(맵의 모든 건물)` — 플레이어 건물(`BuildingManager.buildings`) + [NPC 거점](npc-bases.md)(`BuildingManager.npc_buildings`)을 합쳐 적 캠프 발자국 위에 겹쳐 짓지 못하게 한다.
- **좌클릭**: 배치 가능한 자리(`can_place`)이고 **조건 충족**(`BuildPlanner.can_build` — 선행·자재)이면 → `territory.build_pay(type_id)`(자재 차감) → 그 자리에 **건설 중** 건물 생성(`Building.setup(.., true)`) → 영지에 편입(`add_building`) → 건설 모드 종료. 불가한 자리면 무시(모드 유지).
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
- 생산: 건설 중에는 [1차 생산](production.md)이 동작하지 않는다(`tick_production`은 완성 건물만 game이 부른다). (flat `production()`은 폐지.)
- 시야: 건설 중 건물은 시야에 기여하지 않는다(배치 유효성의 `territory_vision`이 완성 건물만 센다). `vision` 값 자체는 종류 스펙 그대로 유지.
- 렌더: 건설 중이면 반투명하게 그리고 중심 근처에 **"건설 중 N"**(남은 턴)을 표시한다.

## 턴 진행 (`TurnManager` · `Territory`)

턴 종료 시 건설을 진행한다. 이번 턴에 완성된 건물은 **다음 턴부터** 생산한다(자원 생산은 `end_turn` 밖 `game.gd`가 처리 — [1차 생산](production.md)).

- `Territory.advance_construction() -> void` — 소속 건물들의 `advance_construction()`을 호출한다.
- `TurnManager.end_turn(units, territories)` 순서: ① `number += 1` → ② 유닛 `reset_turn` → ③ 영지 `grow_population` → ④ 영지 `advance_construction`. (flat `collect_income`은 폐지.)

## 배치 유효성 (`BuildPlanner`)

> `class_name BuildPlanner extends RefCounted` — 시각 요소 없는 static 헥스 유틸(`scenes/game/hex_grid.gd`의 `HexGrid`와 같은 성격, `HexGrid`를 재사용).

- `footprint(terrain, center, hexes := 7) -> Array[Vector2i]` — 건물이 차지하는 셀. `hexes <= 1`이면 중심 1칸(`[center]`), 아니면 중심 + 이웃 6칸(총 7헥스). [Building](../entities/Building.md)의 점유 셀과 같은 규칙. `hexes`는 종류의 [카탈로그](../data/buildings.md) `footprint`.
- `buildings_vision(terrain, buildings, map_w, map_h) -> Dictionary` — 건물 목록의 **완성 건물**들에 대해 각 `center_cell` 기준 `vision` 반경 안 셀을 합집합으로 모은 `{cell: true}`. 건설 중 건물은 제외한다. 배치 유효성(영지 건물)과 [전장의 안개](fog-of-war.md)(맵의 모든 건물)가 공유한다.
- `territory_vision(terrain, territory, map_w, map_h) -> Dictionary` — 영지의 완성 건물 시야 합집합. `buildings_vision`을 영지의 건물 목록(`territory.buildings`)으로 부른다.
- `occupied_cells(buildings) -> Dictionary` — 건물 목록의 점유 셀(`building.cells`) 합집합 `{cell: true}`. 겹침 검사에 쓴다.
- `can_place(terrain, center, map_w, map_h, vision_cells, occupied, hexes := 7) -> bool` — 중심 `center`에 종류의 `hexes`만큼 건물을 놓을 수 있는지. `footprint(terrain, center, hexes)`의 모든 셀이 **모두**:
  1. 맵 범위 `[0, map_w) × [0, map_h)` 안이고,
  2. `vision_cells`(영지 시야) 안이고,
  3. `occupied`(이미 건물이 점유한 셀 집합)와 겹치지 않으면
  참. 하나라도 위반하면 거짓. 맵 가장자리라 이웃이 범위를 벗어나면 배치 불가(1헥스 건물은 중심만 판정하므로 가장자리 제약이 완화됨).
- `prerequisite_met(territory, type_id) -> bool` — `type_id`의 [`prerequisite`](../data/buildings.md#선행건물-prerequisite--거점-티어-기준)(거점 티어 id)가 그 영지에서 충족됐는지. 선행이 `""`(없음)이면 항상 참. 아니면 **영지의 거점 티어가 선행 티어 이상**이면 참 — `territory.buildings` 중 **완성**(`is_complete()`)이고 `is_center`이고 `center_tier >= center_tier(선행)`인 건물이 하나라도 있으면 참. **건물 존재가 아니라 티어 비교**라, 캠프→마을회관→성으로 올려도 하위 티어 선행이 계속 충족된다(성이어도 town_hall 선행 만족).
- `can_build(territory, type_id) -> bool` — 그 영지에 `type_id`를 지을 수 있는지 종합 판정: **① 선행 충족**(`prerequisite_met`) **② 자재 충분**(`territory.can_afford(build_cost)`). 둘 다 참이어야 참. (`required_pop` 폐지 — 인구 게이트 없음.) 배치 유효성(`can_place`, 지형·시야·겹침)과는 별개 — 이건 "자원/조건" 게이트다. [캠프 메뉴](camp-menu.md) 리스트 활성 여부와 `game.gd`의 배치 시점 판정이 공유한다.

## 선행건물 게이트

건축 리스트의 각 종류는 [`prerequisite`](../data/buildings.md#선행건물-prerequisite)(선행 건물)가 그 영지에서 충족돼야 지을 수 있다.

- 판정 = `BuildPlanner.prerequisite_met(territory, type_id)`. 영지에 선행 종류의 **완성** 건물이 있어야 참.
- [캠프 메뉴](camp-menu.md) 건축 리스트: 각 종류 버튼은 **자원 부족 또는 선행 미충족**이면 비활성. 선행 미충족이면 라벨에 `(선행: <라벨> 필요)`를 덧붙여 이유를 보인다.
- 예: 시작 영지는 캠프(tier 0)이므로 **1차 생산(농장·벌목소·철광·금광)은 활성**, 집은 마을회관 업그레이드 전까지 비활성.

## 캠프 건설 (새 영지 확장)

기존 거점(캠프 메뉴)에서 **새 캠프**를 세워 **새 영지**를 만든다 — 내 군대가 있는 곳에 전초기지를 개척한다.

- **진입**: 캠프 메뉴의 **"캠프 건설 (새 영지)"** 버튼(`camp_menu`) → `found_camp_requested(territory)` 방출 → `game.gd`가 캠프 건설 모드로 진입. 버튼은 여는 영지가 캠프 비용(목재10·식량10)을 감당하면(`BuildPlanner.can_build(territory, "camp")`) 활성.
- **배치 = 활성 부대 시야**: 일반 건물은 영지 시야 안에 짓지만, **캠프는 활성 [부대](../entities/Party.md)의 시야 반경**(`party.vision()`, 부대 위치 기준) 안에 짓는다(`game.gd`가 `_build_type == "camp"`면 배치 영역·`can_place` 시야를 부대 시야로 바꾼다). footprint 7.
- **부대 필요**: 활성 부대가 비어(멤버 0) 있으면 시야가 없어 배치가 불가능하므로, 건설 모드에 **진입하지 않고** 안내 토스트("캠프를 세우려면 부대가 필요하다")를 띄운다(`_on_found_camp_requested`).
- **새 영지 생성(`BuildingManager.found_camp` — game.gd가 건설 모드에서 위임 호출)**: 여는 영지가 `build_pay("camp")`로 비용 지불 → 새 `Territory`(이름 `"전초기지 N"`, **자원 0·인구 0**) 생성 → 플레이어 세력 편입 → **건설 중** 캠프 배치(`Building.setup(.., true)`) → 새 영지에 편입 → BuildingManager의 `buildings`·`territories`(턴 수입 대상)에 등록 → [안개](fog-of-war.md) 갱신.
- 새 캠프는 **수비대가 없다**(무방비) — [캠프 메뉴 편성](camp-menu.md)으로 부대 병력을 옮겨 방어한다. 완성되면 시야 5. 캠프라 [승리·점령](victory.md)에 기여(거점 tier 0).
- **악용 방지**: 새 영지 시작 자원 0(싼 캠프로 자원을 복사하지 못함). 캠프 티어는 [인구 상한](../entities/Territory.md#인구-상한population_cap) 0이라 인구도 0에서 시작.
- **유예(미구현)**: 새 전초기지의 **경제 개발**(마을회관 업그레이드로 인구 확보)은 영지 자원이 0이고 **영지 간 자원 이전이 없어** 아직 불가 — 이번 슬라이스는 시야·영토 클레임·부대 수비까지. NPC의 캠프 건설도 미구현.

## 거점 업그레이드

거점은 [캠프→마을회관→성 인플레이스 티어](../data/buildings.md#거점-업그레이드)로 올린다(별도 건물이 아님).

- **판정** `BuildPlanner.can_upgrade(territory, building) -> bool` — 그 거점의 `next_center`가 있고(최종 성이 아니고), 영지가 **다음 티어의 `build_cost`를 감당**하면 참. (선행은 거점 업그레이드에 없음.)
- **UI**: [캠프 메뉴](camp-menu.md)에 **업그레이드 버튼** — 현재 거점의 다음 티어와 비용을 표시(예: `"마을회관으로 업그레이드  목재 20 · 식량 20"`). `can_upgrade`면 활성, 누르면 `upgrade_requested(building)` 방출.
- **실행(`game.gd` `_on_upgrade_requested`)**: `next = next_center(building.building_type)` → `territory.build_pay(next)`(자재 차감) → `building.upgrade_to(next)` → 시야 갱신(`_update_fog`, 티어별 vision 변화)·캠프 메뉴 갱신. **즉시** 티어업(건설 시간 미구현).
- 업그레이드로 [인구 상한](../entities/Territory.md#인구-상한population_cap)이 오른다(캠프 0 → 마을회관 10 → 성 20). 수비대·위치·영지는 유지.

## 테스트 시나리오

- `test/unit/test_territory.gd` (자원 검사·차감)
  - [정상] `can_afford({목재:5})` — 자원이 충분하면 참, 부족하면 거짓
  - [경계] `can_afford({})` — 빈 비용은 항상 참
  - [경계] 없는 자원 키를 요구하면(`{철:99}`, 보유 부족) 거짓
  - [정상] `spend({목재:5, 식량:5})` 후 해당 자원이 정확히 줄어든다
- `test/unit/test_building.gd` (건설 중 상태)
  - [정상] `setup(.., "farm", true)` 후 `is_complete() == false`, `remaining_turns == 3`(=build_turns)
  - [정상] `setup(.., "farm")`(기본) 후 `is_complete() == true`
  - [정상] `advance_construction()`을 build_turns회 호출하면 완성되고, 완성되는 호출만 `true` 반환
  - [경계] 완성된 건물에 `advance_construction()` → `false`, 상태 불변
- `test/unit/test_turn.gd` (턴 진행)
  - [정상] 건설 중 농장을 가진 영지를 `end_turn` → 건설 1턴 진행(`remaining_turns` 감소)
  - [정상] build_turns회 `end_turn` 후 농장 완성
- `test/unit/test_build_planner.gd` (배치 유효성, 신규)
  - [정상] 시야 안 + 빈 땅 + 맵 내부 중심 → `can_place` 참
  - [예외] footprint 일부가 시야 밖 → 거짓
  - [예외] footprint가 기존 건물과 겹침 → 거짓
  - [예외] 맵 가장자리라 이웃이 범위를 벗어남 → 거짓
  - [정상] `territory_vision`은 완성 건물만 반영(건설 중 건물은 시야에 기여 안 함)
  - [정상] `buildings_vision`은 완성 건물의 시야 합집합(캠프 반경5=91셀·농장 반경4=61셀), 건설 중 건물은 제외, 빈 목록은 빈 시야
  - [정상] `footprint`는 기본 7헥스(중심+이웃 6); `hexes=1`이면 중심 1칸만; `hexes=7`은 기본과 동일
  - [정상] `can_place(..., 1)`(1헥스)는 중심 1칸만 판정 — 이웃이 시야 밖/점유여도 중심이 유효하면 참
  - [정상] `occupied_cells`는 건물들의 점유 셀 합집합(건물 1개면 7셀, 겹치지 않는 2개면 14셀)
  - [정상] `prerequisite_met`(티어 기준) — **캠프**(tier 0) 거점 영지: `farm`·`lumberjack`(선행 camp)은 참, `house`(선행 town_hall)는 거짓
  - [정상] `prerequisite_met` — 거점이 **마을회관**(tier 1)이면 `house` 참으로 전환; **성**(tier 2)이어도 계속 참(티어 비교라 상위 티어도 만족)
  - [경계] `prerequisite_met` — 거점이 **건설 중**이면 아직 거짓(완성돼야 충족)
  - [정상] `can_build` — 캠프 거점 + 목재 충분 영지에서 `farm`(선행 camp·목재5)는 참
  - [예외] `can_build` — 선행 미충족이면 거짓; 자재 부족이면 거짓
  - [정상] `can_upgrade` — 캠프 거점 + 마을회관 비용 충분 → 참; 성 거점(최종)은 항상 거짓(next 없음); 비용 부족이면 거짓
  - [정상] `center_tier`/`next_center` — camp 0/→town_hall, town_hall 1/→castle, castle 2/→""
- `test/unit/test_hex_grid.gd` (영역 윤곽선, `HexGrid.region_outline`)
  - [정상] 단일 셀 → 경계 변 6개(헥스의 모든 변)
  - [정상] 인접한 두 셀 → 경계 변 10개(총 12변 중 공유 변 1개 제외)
  - [정상] 반경 1 디스크(7셀) → 경계 변 18개(바깥 링 6셀 × 바깥 변 3)
  - [정상] `hex_polygon`은 꼭짓점 6개

## 관련

- 종류별 `build_cost`·`build_turns`·`produces`(1차 생산)는 [buildings.md](../data/buildings.md).
- 건설 중 상태를 가지는 건물은 [Building 엔티티](../entities/Building.md).
- 자원을 보유·차감하는 [Territory 엔티티](../entities/Territory.md).
- 턴 종료 처리 순서는 [Turn](turn.md).
- 건설 모드 UI(슬라이스 2)는 [Camp Menu](camp-menu.md)의 건축 버튼에서 진입 예정(미구현).
