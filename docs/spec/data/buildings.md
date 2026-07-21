# Data: Buildings (건물 종류)

> 스크립트: `scenes/building/building_types.gd` (`class_name BuildingTypes`)

게임에 존재하는 **건물 종류 카탈로그**. 각 종류의 스펙을 데이터로 정의한다.
[Building 엔티티](../entities/Building.md)가 `setup(.., type_id)` 시 여기서 시야·외형을 읽는다.
캠프의 초기 `resources`는 건설 시 생성되는 [영지](../entities/Territory.md)의 **초기 자원**으로 복사된다(건물이 아니라 영지가 자원을 보유).

## 카탈로그 (`CATALOG`)

키 = 종류 id. 값 = 스펙 Dictionary.

### 기본 · 외형

`footprint`은 건물이 차지하는 헥스 수(테이블 "필요헥스"). `7`이면 중심+이웃 6칸, `1`이면 중심 1칸만.
캠프·마을회관·성은 7헥스, 소형 건물(집·벌목소·농장·철광·금광)은 1헥스.

| id | `label` | `vision` | `footprint` | 초기 `resources` (→ 생성 영지 초기 자원) | 외형 색상 |
| --- | --- | --- | --- | --- | --- |
| `camp` | 캠프 | 5 | 7 | 목재 40 / 식량 50 / 철 10 / 금 0 / 인구 10 | 흙색 계열 |
| `town_hall` | 마을회관 | 6 | 7 | (없음) | 밝은 목조·기와 계열 |
| `castle` | 성 | 8 | 7 | (없음) | 회청색 석조 계열 |
| `farm` | 농장 | 4 | 1 | (없음 — 영지를 새로 만들지 않음) | 녹색(밭) 계열 |
| `house` | 집 | 2 | 1 | (없음) | 따뜻한 흙색(목조) 계열 |
| `lumberjack` | 벌목소 | 3 | 1 | (없음) | 짙은 녹갈색 계열 |
| `iron_mine` | 철광 | 3 | 1 | (없음) | 회청색(철) 계열 |
| `gold_mine` | 금광 | 3 | 1 | (없음) | 황금색 계열 |

### 건설 · 경제

(flat `production` 열은 **폐지** — 모든 생산이 [1차 생산](../features/production.md)으로 이관. 2차 생산(가공)은 [자원 4종 축소](resources.md)와 함께 **제거**됐다.)
`build_cost`(자원 차감)와 `build_turns`(건설 소요 턴) 소비 로직은 [건축](../features/building.md) 슬라이스 1에서 **구현됨**(단 게임 플로우 배선은 슬라이스 2). `demolish_refund`(철거 시 자재 회수)는 [건물 정보 패널의 철거](../features/building-info.md#철거)에서 **구현됨**(캠프 제외).

**`required_pop`(필요인원, 노동력 인구 소비)는 폐지됐다** — `인구`는 [병력 전용 예약](resources.md#인구-병력-예약)이라 건물이 고용하지 않는다. 모든 건물 `required_pop == 0`. 건설비는 **자원 4종(목재·식량·철·금)**만 쓴다.

거점(캠프·마을회관·성)은 [**인플레이스 업그레이드**](#거점-업그레이드) 티어다 — 별도로 짓지 않고 캠프→마을회관→성으로 제자리 상승한다(그래서 `BUILDABLE_IDS`에 없다). 업그레이드 비용 = 다음 티어의 `build_cost`.

| id | `build_turns` | `build_cost`(업그레이드 비용) | `demolish_refund` | `pop_cap` | 특수 효과 |
| --- | --- | --- | --- | --- | --- |
| `camp` | 8 | 목재 10 / 식량 10 | 목재 2 | **0** | 거점 tier 0. [캠프 건설](../features/building.md#캠프-건설-새-영지-확장)로 새 영지의 시작 티어가 된다 |
| `town_hall` | 8 | 목재 20 / 식량 20 | 목재 2 | **10** | 거점 tier 1. 인구 상한 10. 대부분 건물의 선행. 상인 방문 **미구현** |
| `castle` | 12 | 목재 40 / 식량 30 / 철 20 | 목재 4 / 철 2 | **20** | 거점 tier 2(최종). 인구 상한 20. 고급 건물 해금 **미구현** |
| `farm` | 3 | 목재 5 | 목재 1 | — | **[1차 생산](../features/production.md)** — `produces 식량`, `buildable_terrains [초원]`, footprint 1 |
| `house` | 4 | 목재 8 / 식량 4 | 목재 2 | 2 | **인구 상한 `pop_cap +2`**(생산 아님) |
| `lumberjack` | 3 | 목재 5 | 목재 1 | — | **[1차 생산](../features/production.md)** — `produces 목재`, `buildable_terrains [숲]`, footprint 1 |
| `iron_mine` | 5 | 목재 15 | 목재 2 | — | **[1차 생산](../features/production.md)** — `produces 철`, `buildable_terrains [철맥]` |
| `gold_mine` | 6 | 목재 15 / 철 5 | 목재 2 / 철 1 | — | **[1차 생산](../features/production.md)** — `produces 금`, `buildable_terrains [금맥]` |

> **건설비 수치는 플레이성/부트스트랩용 초안**이다. 캠프 시작 자원(목재 40·식량 50·철 10·금 0)만으로 마을회관 업그레이드·초기 생산 건물을 지을 수 있게 잡았다. 성은 목재·철을 생산으로 모아야 도달한다. 경제 밸런스가 갖춰지면 재조정한다.

- **초기 자원 순서** = 캠프 메뉴 표시 순서. `목재·식량·철·금·인구` 순.
- 외형 색상 필드: `fill_color`(부지) · `edge_color`(테두리) · `tent_color`(중심 표식).
  - 농장 전용 렌더링(작물 표현 등)은 배치가 생기는 **Phase 2**에서 다듬는다.
- `build_cost`·`demolish_refund`는 자원명→수량 Dictionary(자원 4종만). `build_turns`는 건설 소요 턴.
- **캠프 건설 → 새 영지 생성**은 [캠프 건설](../features/building.md#캠프-건설-새-영지-확장)에서 구현됨(활성 부대 시야에 배치, 새 영지 자원 0). (flat 턴당 생산은 폐지 — 생산은 [1차 생산](../features/production.md) 참조.)
- **`footprint`은 [배치 유효성](../features/building.md#배치-유효성-buildplanner)에 반영된다** — `BuildPlanner.footprint`/`can_place`가 종류별 헥스 수로 판정하고, `Building.setup`이 그만큼 점유 셀을 잡는다.
- **인구 상한(`pop_cap`)**: 종류가 영지 [인구 상한](../entities/Territory.md#인구-상한population_cap)에 더하는 값(없으면 0). **거점 티어에서 나온다** — 캠프 `0`, 마을회관 `10`, 성 `20`(집 `+2`로 보조). 완성 건물만 상한에 기여한다(`Building.pop_cap()`은 건설 중이면 0). 매 턴 종료 시 영지 인구가 상한까지 +1씩 [자연 증가](turn.md)한다. **캠프 티어는 인구 상한 0** — 마을회관으로 업그레이드해야 인구가 생긴다. 인구의 소비처(병력 충원)는 [미구현(후속)](resources.md#인구-병력-예약).
- **소형 건물·업그레이드는 목재/철을 요구**한다. 캠프 시작 자원(목재 40·철 10)으로 마을회관 업그레이드·초기 생산 건물을 지을 수 있고, 이후 벌목소·철광으로 목재·철을 보충한다.

### 필요인원 (`required_pop`) — 폐지

이전에는 생산 건물이 노동력(`인구`)을 고용했으나, [자원 4종 축소](resources.md)에서 **`인구`가 병력 전용으로 예약**되면서 `required_pop`은 폐지됐다.

- 모든 건물 `required_pop == 0`. 건설·철거 시 인구를 소비/반환하지 않는다.
- 1차 생산 건물은 [거리 기반 생산포인트](../features/production.md)로 자원을 캐고 **인원(노동력)을 쓰지 않는다**(인원 모델 자체가 폐지 — 자원 4종 축소 슬라이스).
- 병력 충원(인구 소비) 시스템은 **미구현(후속 슬라이스)**.

### 거점 업그레이드 (인플레이스 티어)

거점은 **캠프(tier 0) → 마을회관(tier 1) → 성(tier 2)** 로 **제자리 업그레이드**한다. 별도 건물이 아니라 같은 거점의 티어가 오른다(위치·footprint·수비대·영지 유지).

- `BuildingTypes.center_tier(id) -> int` — camp 0 / town_hall 1 / castle 2, 거점 아니면 -1.
- `BuildingTypes.next_center(id) -> String` — 다음 티어 id(camp→town_hall, town_hall→castle), 최종/비거점이면 `""`.
- 업그레이드 **비용 = 다음 티어의 `build_cost`**(마을회관 목재20·식량20, 성 목재40·식량30·철20). 거점의 영지가 지불(`Territory.build_pay`). **즉시** 티어업(건설 시간 적용은 미구현).
- 실행: [캠프 메뉴](../features/camp-menu.md)의 **업그레이드 버튼** → `Building.upgrade_to(next)`. → [건축](../features/building.md#거점-업그레이드).
- 마을회관·성은 `BUILDABLE_IDS`에 **없다**(별도로 못 짓고 업그레이드로만 도달).

### 선행건물 (`prerequisite`) — 거점 티어 기준

각 [건축 가능 종류](../features/building.md#선행건물-게이트)는 `prerequisite`(거점 티어 id)를 가진다. **그 영지의 거점 티어가 선행 티어 이상**이어야 짓는다(`BuildPlanner.prerequisite_met` — 건물 존재가 아니라 **티어 비교**. 성으로 더 올려도 선행이 유지된다).

| id | `prerequisite` | 필요 거점 티어 |
| --- | --- | --- |
| `farm` | `camp` | 거점 tier ≥ 0 ([1차 생산](../features/production.md)은 캠프부터) |
| `lumberjack` | `camp` | 거점 tier ≥ 0 (〃) |
| `iron_mine` | `camp` | 거점 tier ≥ 0 (〃) |
| `gold_mine` | `camp` | 거점 tier ≥ 0 (〃) |
| `house` | `town_hall` | 거점 tier ≥ 1 (마을회관 이상) |

- 거점 자신(`camp`/`town_hall`/`castle`)의 `prerequisite` 필드는 업그레이드 경로(`next_center`)로 대체되어 게이트에는 쓰이지 않는다(카탈로그엔 남아 있음).
- 체인: **캠프 →(업그레이드) 마을회관 →(업그레이드) 성**. **1차 생산(농장·벌목소·철광·금광)은 캠프 티어부터** 해금. 집은 마을회관 티어부터.
- **배치 규칙**([1차 생산](../features/production.md#배치-규칙-build_planner--gamegd)): 1차 생산 = 지형 제한(`buildable_terrains`) + 건물∪부대 시야. 기타 건물 = 마을회관 인접.
- 병영 등 군사 체인, 병력 충원(인구 소비)은 아직 **미구현**.

## 동작

- `BuildingTypes.CAMP` — 캠프 종류 id 상수(`"camp"`).
- `BuildingTypes.FARM` — 농장 종류 id 상수(`"farm"`).
- `BuildingTypes.BUILDABLE_IDS` — **건축(캠프 메뉴)에서 지을 수 있는 종류 id 목록**. 현재 `["farm", "lumberjack", "iron_mine", "gold_mine", "house"]`. **거점(캠프·마을회관·성)은 제외** — 캠프는 [새 영지 건설](../features/building.md#캠프-건설-새-영지-확장)(별도 버튼), 마을회관·성은 [업그레이드](#거점-업그레이드)로만 도달. 선행 미충족 종류는 리스트에 뜨되 **비활성**이다([건축](../features/building.md)).
- `BuildingTypes.get_type(type_id) -> Dictionary` — 종류 스펙 반환. 없는 id면 빈 Dictionary.
- `BuildingTypes.CENTER_IDS` — **거점(center)** 종류 목록 `["camp", "town_hall", "castle"]`(티어 순). 세력의 전략 앵커. **승리·점령·수비대·[캠프 메뉴](../features/camp-menu.md) 판정이 이 세트를 기준**으로 한다.
- `BuildingTypes.is_center(type_id) -> bool` — 그 종류가 거점인지(`type_id in CENTER_IDS`). 세 티어 중 하나라도 세력이 가지면 유지된다([승패](../features/victory.md)).
- `BuildingTypes.center_tier(type_id) -> int` — 거점 티어(camp 0 / town_hall 1 / castle 2), 거점 아니면 -1.
- `BuildingTypes.next_center(type_id) -> String` — [업그레이드](#거점-업그레이드) 다음 티어 id(camp→town_hall, town_hall→castle), 최종(성)·비거점이면 `""`.

## 테스트 시나리오

`test/unit/test_building_types.gd`.

- [정상] `get_type("camp")`에 `label`·`vision`·`resources`·외형 색상 키가 모두 존재
- [정상] `get_type("camp").vision == 5`, `label == "캠프"`, `footprint == 7`, 자원 5종(`{목재:40, 식량:50, 철:10, 금:0, 인구:10}`)
- [경계] 캠프 초기 자원에 제거된 키 없음: `밀`·`석재`·`철괴`·`나무`·`빵` 등 미포함
- [정상] `get_type("farm").label == "농장"`, `vision == 4`, `footprint == 1`, 외형 색상 키 존재, 초기 `resources` 없음(빈/미정의)
- [정상] `get_type("farm")`의 `build_turns == 3`, `build_cost == {목재5}`, `demolish_refund == {목재1}`, `production == {}`(flat 없음 — [1차 생산](../features/production.md))
- [정상] 1차 생산 — `farm`: `primary_production==true`, `produces=="식량"`, `buildable_terrains==[초원]`; `lumberjack`: `produces=="목재"`, `[숲]`; `iron_mine`: `produces=="철"`, `[철맥]`; `gold_mine`: `produces=="금"`, `[금맥]`
- [정상] 필요인원 폐지 — 모든 건물 `required_pop == 0`(키 없거나 0)
- [경계] 비-생산 건물 — `house`·`camp`: `primary_production` false/미정의, `produces==""`, `buildable_terrains==[]`
- [경계] 제거된 종류는 빈 Dictionary: `get_type("quarry")`·`get_type("silver_mine")`·`get_type("sawmill")`·`get_type("smelter")` 등 == `{}`
- [정상] `get_type("camp")`의 `build_turns == 8`, `build_cost == {목재10, 식량10}`, `demolish_refund == {목재2}`
- [정상] `get_type("house")` — `label == "집"`, `vision == 2`, `footprint == 1`, `build_turns == 4`, `build_cost == {목재8, 식량4}`, `pop_cap == 2`, `production` 없음(생산 아님), 외형 색상 키 존재
- [정상] 인구 상한 티어 — `camp.pop_cap == 0`, `town_hall.pop_cap == 10`, `castle.pop_cap == 20`, `house.pop_cap == 2`
- [정상] `center_tier` — camp 0, town_hall 1, castle 2; 비거점(farm 등)·없는id는 -1
- [정상] `next_center` — camp→"town_hall", town_hall→"castle", castle→"", 비거점→""
- [정상] `get_type("lumberjack")` — `label == "벌목소"`, `vision == 3`, `footprint == 1`, `build_turns == 3`, `build_cost == {목재5}`, `primary_production==true`, `produces=="목재"`
- [정상] `get_type("iron_mine")` — `label == "철광"`, `build_cost == {목재15}`, `produces == "철"`, `buildable_terrains == [철맥]`, `prerequisite == "camp"`
- [정상] `get_type("gold_mine")` — `label == "금광"`, `build_cost == {목재15, 철5}`, `produces == "금"`, `buildable_terrains == [금맥]`
- [정상] `get_type("town_hall")` — `label == "마을회관"`, `vision == 6`, `footprint == 7`, `build_turns == 8`, `build_cost == {목재20, 식량20}`, `prerequisite == "camp"`, `production` 없음(빈/미정의)
- [정상] `get_type("castle")` — `label == "성"`, `vision == 8`, `footprint == 7`, `build_turns == 12`, `build_cost == {목재40, 식량30, 철20}`, `demolish_refund == {목재4, 철2}`, `prerequisite == "town_hall"`, `production` 없음
- [정상] 선행 필드 — `get_type("camp").prerequisite == ""`, `farm`·`lumberjack`·`iron_mine`·`gold_mine`의 `prerequisite == "camp"`, `house`의 `prerequisite == "town_hall"`
- [경계] `get_type("없는id")`는 빈 Dictionary
- [정상] `BUILDABLE_IDS`가 `["farm", "lumberjack", "iron_mine", "gold_mine", "house"]`(거점 3종 미포함, 제거된 종류 미포함)
- [정상] `is_center` — `camp`·`town_hall`·`castle`는 참; `farm`·`house`·`lumberjack`·`iron_mine`·`없는id`는 거짓
- [정상] `CENTER_IDS == ["camp", "town_hall", "castle"]`

## 관련

- 종류를 배치·사용하는 주체: [Building 엔티티](../entities/Building.md)
- 자원 목록: [resources.md](resources.md)
- 생산(`production`) 로직은 [턴](../features/turn.md)에서 구현됨. 건설 코어 로직(자원 소비·건설 중 상태·배치 유효성)은 [건축](../features/building.md) 슬라이스 1에서 구현됨. **철거**는 [건물 정보 패널](../features/building-info.md#철거)에서 구현됨(거점 제외). **캠프 건설(새 영지)**은 [건축](../features/building.md#캠프-건설-새-영지-확장)에서 구현됨.
