# Entity: Building (건물)

> 스크립트: `scenes/building/building.gd` (`class_name Building extends Node2D`)

맵에 배치된 **건물** 인스턴스. 어떤 *종류*인지(`building_type`)에 따라 시야·외형 등의 스펙을
[건물 카탈로그](../data/buildings.md)에서 읽어 온다. **캠프(`"camp"`)·농장(`"farm"`) 등 건물 종류 중 하나**다.

건물은 하나의 [영지(Territory)](Territory.md)에 소속된다. **자원·이름·세력은 건물이 아니라 영지가 보유**한다
(구조: 세력 → 영지 → 건물). 건물이 표시하는 이름/세력/자원은 모두 자기 영지에서 온다.

건물은 **건설 중**(`under_construction`) 또는 **완성** 상태를 가진다. 건설 중에는 생산·시야가 없고, 턴마다 `advance_construction()`으로 진행하다가 `build_turns`만큼 지나면 완성된다([건축](../features/building.md) 참고).

> 게임 시작 시 캠프가 배치되고(즉시 완성), 이후 [건축](../features/building.md)으로 **농장을 건설**할 수 있다(건설 중 → 완성). `production`/`build_turns`/`build_cost`는 사용되며, `demolish_refund`(철거)는 아직 **미구현**이다.

**중심 1헥스 + 주변 6헥스 = 총 7헥스**를 차지한다(현재 모든 종류 공통 발자국. 종류별 footprint는 **미구현**).
헥스 중 하나라도 클릭되면 게임 쪽에서 종류에 따라 UI를 연다: **캠프**는 [캠프 메뉴](../features/camp-menu.md)(자원·건축), **그 외 건물(농장)**은 [건물 정보 패널](../features/building-info.md).
`_draw()`로 종류별 색으로 부지 + 중심 텐트를 그린다.

## Properties

### 정체성 (Identity)

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 종류 | `building_type` | `String` | `""` | 건물 종류 id (예: `"camp"`). [카탈로그](../data/buildings.md) 키 |
| 소속 영지 | `territory` | `Territory` | `null` | 소속 [영지](Territory.md). `Territory.add_building`로 연결. 변경 시 `queue_redraw` |

### 종류에서 오는 값 (setup 시 카탈로그에서 읽음)

| 속성 | 변수 | 타입 | 설명 |
| --- | --- | --- | --- |
| 시야 | `vision` | `int` | 종류의 시야. 안개 밝힘 반경 (건설 중에는 시야에 기여 안 함) |

### 건설 상태 (Runtime)

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 건설 중 | `under_construction` | `bool` | `false` | 참이면 건설 중(생산·시야 없음). 완성되면 거짓 |
| 남은 턴 | `remaining_turns` | `int` | `0` | 완성까지 남은 턴. `setup`에서 `build_turns`로 채워짐. 완성 시 0 |

> 자원은 건물이 아니라 [영지](Territory.md)가 보유한다. 캠프 카탈로그의 `resources`는 **건설 시 생성되는 영지의 초기 자원**으로 쓰인다.

### 배치 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 점유 셀 | `cells: Array[Vector2i]` | 중심 + 이웃 6칸 |
| 중심 셀 | `_center_cell` | 시야 계산 기준점 |
| 지형 참조 | `_terrain: TileMapLayer` | 좌표 변환용 |
| 종류 스펙 | `_spec: Dictionary` | 카탈로그 조회 결과 캐시(공유 읽기 전용) |

## 동작

- `setup(terrain, center_cell, type_id, under_construction := false) -> void` — 종류 스펙을 카탈로그에서 읽어 `building_type`·`vision`을 채우고, 중심 셀 + 이웃 6칸을 점유 셀로 설정. `under_construction`이 참이면 건설 중 상태로 두고 `remaining_turns`를 카탈로그 `build_turns`로 채운다(기본값 거짓 = 즉시 완성). 알 수 없는 `type_id`면 빈 스펙(시야 0·라벨 "")이 되고, `_draw`는 중립 회색으로 그린다(캠프로 위장하지 않도록).
- `contains_cell(cell) -> bool` — 해당 셀이 건물 영역에 포함되는지.
- `center_cell() -> Vector2i` — 시야 계산 기준점 반환.
- `label() -> String` — 종류 라벨(예: "캠프"). 카탈로그의 `label`.
- `is_complete() -> bool` — 건설이 끝났으면(건설 중이 아니면) 참.
- `advance_construction() -> bool` — 건설을 1턴 진행. 이미 완성이면 `false`(불변). 건설 중이면 `remaining_turns -= 1`, 0 이하가 되면 완성 처리하고 **이번에 완성됐으면 `true`**, 아직 진행 중이면 `false`.
- `production() -> Dictionary` — 종류의 턴당 생산량(자원명→수량). **건설 중에는 빈 Dictionary**. 완성 후에는 카탈로그의 `production`(없으면 빈 Dictionary, 캠프 등). [턴](../features/turn.md) 종료 시 영지 수입(`Territory.collect_income`)에 쓰인다.
- `planned_production() -> Dictionary` — 완성 시 생산량(카탈로그 `production`). **건설 여부와 무관**하게 항상 반환(`production()`과 달리 건설 중에도 값이 있음). [건물 정보 패널](../features/building-info.md)이 건설 중에도 완성 시 생산량을 보여줄 때 쓴다.
- `map_label_lines() -> Array` — 맵에 표시할 텍스트 줄 목록. 각 원소는 `{text, color}`. **영지에서 가져온다.**
  - 영지가 없으면(`territory == null`) 빈 배열.
  - 영지 이름이 있으면 첫 줄 = `{territory.name, 흰색}`.
  - 영지의 세력이 있으면 다음 줄 = `{territory.faction.name, territory.faction.color}`.

## 맵 표시

`_draw()`가 중심 텐트 **위쪽 중앙**에 `map_label_lines()`의 줄들을 위→아래로 그린다.
영지명은 흰색, 세력명은 세력 색상. 월드 좌표라 카메라 줌에 따라 함께 확대·축소된다.
(영지에 속한 건물은 각자 영지 라벨을 그리므로, 같은 영지의 농장도 영지명/세력명을 표시한다. 여러 건물이 겹쳐 라벨이 중복돼 보이는 정리는 **미구현 · TODO**.)

## 테스트 시나리오

`test/unit/test_building.gd`.

- [정상] `setup(.., "camp")` 후 점유 셀 = **7헥스** (중심 + 이웃 6)
- [정상] `center_cell()`은 `setup`에 넘긴 중심 셀
- [정상] `contains_cell`이 중심·이웃 6칸에 대해 참, 먼 셀에 대해 거짓
- [정상] `"camp"`로 setup 시 `building_type == "camp"`, `vision == 5`, `label() == "캠프"`
- [경계] 알 수 없는 `type_id`로 setup 시 `vision == 0`, `label() == ""`
- [경계] `production()` — 캠프는 빈 Dictionary, 농장은 `{밀:1}` (`test/unit/test_turn.gd`)
- [정상] 완성 농장 `planned_production() == {밀:1}`, 캠프 `planned_production() == {}`
- [정상] **건설 중** 농장도 `planned_production() == {밀:1}` (반면 `production() == {}`)
- [정상] `setup(.., "farm", true)` → `is_complete() == false`, `remaining_turns == build_turns`, `production() == {}`
- [정상] `advance_construction()`를 build_turns회 → 완성(`is_complete()`), 완성되는 호출만 `true`; 완성 후 `production() == {밀:1}`
- [경계] 완성된 건물에 `advance_construction()` → `false`, 상태 불변
- [정상] 기본 `territory == null`
- [정상] 영지(이름·세력 포함)에 편입되면 `map_label_lines()` = [영지명(흰색), 세력명(세력색)] 2줄
- [경계] `territory == null`이면 `map_label_lines()`는 빈 배열

## 관련

- 종류별 스펙은 [data/buildings.md](../data/buildings.md) 참고.
- 소속 영지·세력은 [Territory](Territory.md) / [Faction](Faction.md) 엔티티 참고.
- 시야는 [Fog of War](../features/fog-of-war.md)에서 주인공 시야와 합산된다.
- 영지명·세력은 [Camp Menu](../features/camp-menu.md)(캠프)·[Building Info](../features/building-info.md)(그 외 건물)에 표시된다.
