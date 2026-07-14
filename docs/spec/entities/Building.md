# Entity: Building (건물)

> 스크립트: `scenes/building/building.gd` (`class_name Building extends Node2D`)

맵에 배치된 **건물** 인스턴스. 어떤 *종류*인지(`building_type`)에 따라 시야·외형 등의 스펙을
[건물 카탈로그](../data/buildings.md)에서 읽어 온다. **캠프(`"camp"`)·농장(`"farm"`) 등 건물 종류 중 하나**다.

건물은 하나의 [영지(Territory)](Territory.md)에 소속된다. **자원·이름·세력은 건물이 아니라 영지가 보유**한다
(구조: 세력 → 영지 → 건물). 건물이 표시하는 이름/세력/자원은 모두 자기 영지에서 온다.

건물은 **건설 중**(`under_construction`) 또는 **완성** 상태를 가진다. 건설 중에는 생산·시야가 없고, 턴마다 `advance_construction()`으로 진행하다가 `build_turns`만큼 지나면 완성된다([건축](../features/building.md) 참고).

> 게임 시작 시 캠프가 배치되고(즉시 완성), 이후 [건축](../features/building.md)으로 **농장을 건설**할 수 있다(건설 중 → 완성). `production`/`build_turns`/`build_cost`/`demolish_refund` 모두 사용된다([철거](../features/building-info.md#철거) 구현됨 — 완성은 `demolish_refund`, 건설 중은 `build_cost` 진행도 비례 환급).

차지하는 **발자국(footprint)은 종류별**이다([카탈로그](../data/buildings.md) `footprint`). 캠프·농장은 **중심 1헥스 + 주변 6헥스 = 7헥스**, 소형 생산 건물(집·벌목소·채석장)은 **중심 1헥스**만 차지한다. `setup`이 `_spec.footprint`(기본 7)로 점유 셀을 잡는다.
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
| 성벽 단계 | `wall_level` | `int` | `0` | 거점 [성벽](../features/wall.md) 단계. `0`=없음, `≥1`=성벽(적 접근 차단). 마을회관·성만 [성벽 건설](../features/wall.md)로 올린다. `is_walled()`로 조회 |
| 성벽 내구도 | `wall_hp` | `int` | `0` | 거점 [성벽 내구도](../features/wall.md#성벽-내구도-buildingwall_hp--siege). 성벽 건설 시 `Siege.WALL_MAX_HP`(180)로 채우고, [투석](../features/siege-engines.md#투석-공성-성벽)으로 깎여 0이면 붕괴(`wall_level`→0). `is_walled()`는 이 값과 무관(붕괴는 `wall_level`로 처리) |
| 성문 내구도 | `gate_hp` | `int` | `0` | 거점 [성문 내구도](../features/wall.md#성문-gate). 성벽 건설 시 `Siege.GATE_MAX_HP`(120)로 채우고, [충차·투석](../features/wall.md#성문-gate)으로 깎여 0이면 성문 면 통로 개방(성벽은 유지). 성벽 없으면 `0` |
| 생산포인트 | `production_points` | `int` | `0` | [1차 생산 건물](../features/production.md)의 누적 생산포인트. 매 턴 `+= workers`, `≥ 거리`면 자원 산출·차감 |
| 배치 인원 | `workers` | `int` | `0` | [1차 생산 건물](../features/production.md)에 배치한 인원(0-5). 배정 거점 영지 인구에서 차출. 생산력 = `workers ÷ 거리` |
| 배정 거점 | `assigned_center` | `Building` | `null` | [1차 생산 건물](../features/production.md)이 인원 차출·자원 산출·거리 측정하는 대상 거점. 건설 시 최근접 자동, 변경 가능 |

> **수비대는 건물 속성이 아니다.** 거점 방어는 그 거점 중심 타일 위에 있는 [부대](Party.md)가 맡는다([Garrison / 주둔](../features/garrison.md)). 예전 `Building.garrison`(Human 배열)은 폐지됐다.

> 자원은 건물이 아니라 [영지](Territory.md)가 보유한다. 캠프 카탈로그의 `resources`는 **건설 시 생성되는 영지의 초기 자원**으로 쓰인다.

### 배치 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 점유 셀 | `cells: Array[Vector2i]` | 중심 + 이웃 6칸 |
| 중심 셀 | `_center_cell` | 시야 계산 기준점 |
| 지형 참조 | `_terrain: TileMapLayer` | 좌표 변환용 |
| 종류 스펙 | `_spec: Dictionary` | 카탈로그 조회 결과 캐시(공유 읽기 전용) |

## 동작

- `setup(terrain, center_cell, type_id, under_construction := false) -> void` — 종류 스펙을 카탈로그에서 읽어 `building_type`·`vision`을 채우고, 종류의 `footprint`(기본 7)만큼 점유 셀을 설정(`BuildPlanner.footprint`). footprint 7이면 중심+이웃 6칸, 1이면 중심 1칸. `under_construction`이 참이면 건설 중 상태로 두고 `remaining_turns`를 카탈로그 `build_turns`로 채운다(기본값 거짓 = 즉시 완성). 알 수 없는 `type_id`면 빈 스펙(시야 0·라벨 "")이 되고, `_draw`는 중립 회색으로 그린다(캠프로 위장하지 않도록).
- `contains_cell(cell) -> bool` — 해당 셀이 건물 영역에 포함되는지.
- `center_cell() -> Vector2i` — 시야 계산 기준점 반환.
- `label() -> String` — 종류 라벨(예: "캠프"). 카탈로그의 `label`.
- `is_complete() -> bool` — 건설이 끝났으면(건설 중이 아니면) 참.
- `is_walled() -> bool` — `wall_level > 0`. 거점에 [성벽](../features/wall.md)이 있는지(적 접근 차단 판정). 내구도(`wall_hp`)와 무관 — [투석 붕괴](../features/wall.md#성벽-내구도-buildingwall_hp--siege)는 `wall_level`을 0으로 내려 처리한다.
- `gate_cell() -> Vector2i` — 성문이 놓인 ring 한 면(footprint 이웃 6칸 중 결정론적으로 한 칸 — 각도순 정렬 첫 칸). [성문](../features/wall.md#성문-gate) 표적·통로 셀. 성벽 유무와 무관하게 계산(위치 고정).
- `gate_broken() -> bool` — `is_walled() and gate_hp <= 0`. 성문이 부서져 그 면 통로가 열렸는지([성문 돌파](../features/wall.md#성문-gate)).
- `is_primary_production() -> bool` — [1차 생산 건물](../features/production.md)인지(카탈로그 `primary_production`). 배치 규칙(캠프 선행·지형 제한)·생산포인트 경로 게이트.
- `produces() -> String` — 산출 자원 id(카탈로그 `produces`, 아니면 `""`). 벌목소=`"나무"`, 농장=`"밀"`.
- `buildable_terrains() -> Array` — 건설 가능 지형 source_id 리스트(카탈로그 `buildable_terrains`, 없으면 `[]`=제한 없음).
- `tick_production(distance) -> int` — 매 턴 `production_points += workers` 후 `≥ distance`마다 자원 1 산출(PP 차감), 산출 수 반환. `workers≤0`·`distance≤0`·`produces()==""`면 0. → [생산포인트](../features/production.md#생산포인트-메커니즘)
- `production_rate(distance) -> float` — 생산력 표시값 `workers/distance`(distance≤0이면 0).
- `advance_construction() -> bool` — 건설을 1턴 진행. 이미 완성이면 `false`(불변). 건설 중이면 `remaining_turns -= 1`, 0 이하가 되면 완성 처리하고 **이번에 완성됐으면 `true`**, 아직 진행 중이면 `false`.
- `production() -> Dictionary` — 종류의 턴당 생산량(자원명→수량). **건설 중에는 빈 Dictionary**. 완성 후에는 카탈로그의 `production`(없으면 빈 Dictionary, 캠프 등). [턴](../features/turn.md) 종료 시 영지 수입(`Territory.collect_income`)에 쓰인다.
- `planned_production() -> Dictionary` — 완성 시 생산량(카탈로그 `production`). **건설 여부와 무관**하게 항상 반환(`production()`과 달리 건설 중에도 값이 있음). [건물 정보 패널](../features/building-info.md)이 건설 중에도 완성 시 생산량을 보여줄 때 쓴다.
- `pop_cap() -> int` — 이 건물이 영지 [인구 상한](Territory.md#인구-상한population_cap)에 더하는 값. **건설 중에는 0**(완성 건물만 기여), 완성 후 카탈로그 `pop_cap`(없으면 0). 거점 티어별: 캠프 0 · 마을회관 10 · 성 20, 집 +2. `production()`과 같은 건설-게이트 패턴.
- `demolish_refund() -> Dictionary` — **완성 건물** 철거 시 돌려받는 salvage 자재(자원명→수량). 카탈로그 `demolish_refund`(없으면 빈 Dictionary). 순수 카탈로그값(건설 여부 무관).
- `refund_on_demolish() -> Dictionary` — [철거](../features/building-info.md#철거) 시 **실제 환급** 자재. **완성**이면 `demolish_refund()`. **건설 중**이면 낸 `build_cost`를 진행도 비례로 — `floor(build_cost[자원] × remaining_turns ÷ build_turns)`(안 쓴 자재 회수, 0인 자원은 생략). `build_turns ≤ 0`이면 `build_cost` 전액(방어). `Territory.demolish`와 철거 미리보기가 이걸 쓴다.
- `required_pop() -> int` — 이 건물이 고용하는 [노동력](../data/buildings.md#필요인원-required_pop)(인구 수). 카탈로그 `required_pop`(없으면 0). 건설 시 영지 인구에서 소비, 철거 시 반환. 건설 여부와 무관(카탈로그 값).
- `upgrade_to(type_id) -> void` — 거점 [인플레이스 업그레이드](../data/buildings.md#거점-업그레이드). `building_type`·`_spec`·`vision`·`cells`(footprint)를 새 티어로 교체하고 **완성 상태**로 둔다. **위치(center)·영지·`wall_level`·`wall_hp`(성벽·내구도)은 유지**. 모든 거점이 footprint 7이라 점유 셀은 그대로. 주둔 부대는 별도 부대라 업그레이드와 무관하게 그 자리에 남는다. 비용 지불(`Territory.build_pay`)은 호출부([건축](../features/building.md#거점-업그레이드))가 먼저 한다.
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
- [정상] `setup(.., "house")` 후 점유 셀 = **1헥스** (중심만; footprint 1인 소형 건물)
- [정상] `center_cell()`은 `setup`에 넘긴 중심 셀
- [정상] `contains_cell`이 중심·이웃 6칸에 대해 참, 먼 셀에 대해 거짓
- [정상] `"camp"`로 setup 시 `building_type == "camp"`, `vision == 5`, `label() == "캠프"`
- [경계] 알 수 없는 `type_id`로 setup 시 `vision == 0`, `label() == ""`
- [경계] `production()` — 캠프는 빈 Dictionary, 농장은 `{밀:1}` (`test/unit/test_turn.gd`)
- [정상] 완성 농장 `planned_production() == {밀:1}`, 캠프 `planned_production() == {}`
- [정상] `pop_cap()` — 완성 캠프 0, 마을회관 10, 성 20, 집 2, 농장 0; **건설 중** 집은 0(완성 후 2)
- [정상] 생성 직후 `wall_level == 0`·`is_walled()` 거짓·`wall_hp == 0`; `wall_level = 1` → `is_walled()` 참; `wall_hp` 설정 가능
- [정상] `upgrade_to("town_hall")` — 캠프를 마을회관으로: `building_type == "town_hall"`, `vision == 6`, `pop_cap() == 10`, `is_complete()`, 점유 셀 7 유지, `wall_level`·`wall_hp` 유지
- [정상] `demolish_refund()` — 농장 `{목재1}`, 집 `{목재2}`; **건설 중**에도 동일(순수 카탈로그값)
- [정상] `refund_on_demolish()` **완성** = `demolish_refund()`(카탈로그 salvage)
- [정상] `refund_on_demolish()` **건설 중 진행도 비례** — 농장(build_turns 3, build_cost 목재5·밀5): 갓 시작(remaining 3) → `{목재5,밀5}`(전액); 1턴 진행(remaining 2) → `{목재3,밀3}`(floor 5×2/3)
- [경계] `refund_on_demolish()` 건설 중 진행이 많아 어떤 자원의 몫이 0이면 그 자원은 결과에서 생략
- [정상] `required_pop()` — 농장 2, 벌목소 1, 채석장 1, 집·캠프 0
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
