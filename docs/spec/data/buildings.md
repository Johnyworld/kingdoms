# Data: Buildings (건물 종류)

> 스크립트: `scenes/building/building_types.gd` (`class_name BuildingTypes`)

게임에 존재하는 **건물 종류 카탈로그**. 각 종류의 스펙을 데이터로 정의한다.
[Building 엔티티](../entities/Building.md)가 `setup(.., type_id)` 시 여기서 시야·외형을 읽는다.
캠프의 초기 `resources`는 건설 시 생성되는 [영지](../entities/Territory.md)의 **초기 자원**으로 복사된다(건물이 아니라 영지가 자원을 보유).

## 카탈로그 (`CATALOG`)

키 = 종류 id. 값 = 스펙 Dictionary.

### 기본 · 외형

`footprint`은 건물이 차지하는 헥스 수(테이블 "필요헥스"). `7`이면 중심+이웃 6칸, `1`이면 중심 1칸만.
캠프·마을회관·성은 7헥스, 소형 건물(집·벌목소·농장·채석장)은 1헥스.

| id | `label` | `vision` | `footprint` | 초기 `resources` (→ 생성 영지 초기 자원) | 외형 색상 |
| --- | --- | --- | --- | --- | --- |
| `camp` | 캠프 | 5 | 7 | 인구 10 / 밀 50 / 빵 20 / 나무 20 / 목재 40 / 석재 30 / 철 10 / 철괴 10 / 금 0 | 흙색 계열 |
| `town_hall` | 마을회관 | 6 | 7 | (없음) | 밝은 목조·기와 계열 |
| `castle` | 성 | 8 | 7 | (없음) | 회청색 석조 계열 |
| `farm` | 농장 | 4 | 1 | (없음 — 영지를 새로 만들지 않음) | 녹색(밭) 계열 |
| `house` | 집 | 2 | 1 | (없음) | 따뜻한 흙색(목조) 계열 |
| `lumberjack` | 벌목소 | 3 | 1 | (없음) | 짙은 녹갈색 계열 |
| `quarry` | 채석장 | 3 | 1 | (없음) | 회색(석재) 계열 |
| `siege_workshop` | 공성 작업장 | 3 | 1 | (없음) | 어두운 목·철 계열 |

### 건설 · 경제

`production`은 [턴](../features/turn.md) 종료 시 영지 수입으로 **사용된다**(`Building.production` → `Territory.collect_income`).
`build_cost`(자원 차감)와 `build_turns`(건설 소요 턴) 소비 로직은 [건축](../features/building.md) 슬라이스 1에서 **구현됨**(단 게임 플로우 배선은 슬라이스 2). `demolish_refund`(철거 시 자재 회수)는 [건물 정보 패널의 철거](../features/building-info.md#철거)에서 **구현됨**(캠프 제외).

`required_pop`(필요인원)은 건물이 고용하는 **노동력**(인구 수). 건설 시 영지 인구에서 그만큼 소비하고, 철거 시 되돌려준다(자재 `demolish_refund`와 별개). → [노동력](#필요인원-required_pop)

거점(캠프·마을회관·성)은 [**인플레이스 업그레이드**](#거점-업그레이드) 티어다 — 별도로 짓지 않고 캠프→마을회관→성으로 제자리 상승한다(그래서 `BUILDABLE_IDS`에 없다). 업그레이드 비용 = 다음 티어의 `build_cost`.

| id | `build_turns` | `build_cost`(업그레이드 비용) | `demolish_refund` | `required_pop` | `pop_cap` | `production` | 특수 효과 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `camp` | 8 | 목재 10 / 밀 10 | 목재 2 | 0 | **0** | (없음) | 거점 tier 0. [캠프 건설](../features/building.md#캠프-건설-새-영지-확장)로 새 영지의 시작 티어가 된다 |
| `town_hall` | 8 | 목재 10 / 석재 10 / 밀 20 | 목재 2 / 석재 2 | 0 | **10** | (없음) | 거점 tier 1. 인구 상한 10. 대부분 건물의 선행. 상인 방문 **미구현** |
| `castle` | 12 | 석재 50 / 밀 30 | 석재 10 | 0 | **20** | (없음) | 거점 tier 2(최종). 인구 상한 20. 고급 건물 해금 **미구현** |
| `farm` | 3 | 목재 5 / 밀 5 | 목재 1 | 0 | — | (없음) | **[1차 생산](../features/production.md)** — `produces 밀`, `buildable_terrains [초원]`, footprint 1. 생산포인트(인원÷거리) |
| `house` | 4 | 목재 8 / 석재 4 | 목재 2 | 0 | 2 | (없음) | **인구 상한 `pop_cap +2`**(생산 아님) |
| `lumberjack` | 3 | 목재 5 / 석재 5 | 목재 1 | 0 | — | (없음) | **[1차 생산](../features/production.md)** — `produces 나무`, `buildable_terrains [숲]`, footprint 1. 생산포인트 |
| `quarry` | 4 | 목재 10 | 목재 2 | 1 | — | 석재 2 (턴당) | 채석꾼 1명(노동력). **flat 유지**(슬라이스 2에서 1차 생산 전환) |
| `siege_workshop` | 6 | 목재 20 / 석재 20 | 목재 4 / 석재 4 | 2 | — | (없음) | 장인 2명(노동력). 완성 시 그 영지 거점에서 [투석기 생산](../features/siege-engines.md) 해금 |

> **마을회관 값은 테이블에서 조정됨(플레이성/부트스트랩)**: 테이블 원본은 `build_turns 15 / 목재30·석재20·밀20`. 시작 자원(목재 20, 석재 0)만으로는 도달 불가하므로, 시작 → 채석장으로 석재 확보 → 마을회관 건설이 가능하도록 `build_turns 8 / 목재10·석재10·밀20`으로 낮췄다. 경제 밸런스가 갖춰지면 재조정한다.
> **성 값도 테이블에서 조정됨**: 테이블 원본은 `build_turns 30 / 석재80·목재40·철괴20·금50`. 현재 경제엔 **금 생산원이 없고**(금광 미구현) 목재도 시작 20에서 늘지 않아 도달 불가하다. 재생 가능한 석재(채석장)와 시작 밀만으로 지을 수 있도록 `build_turns 12 / 석재50·밀30`으로 낮췄다. 금·철괴 경제가 갖춰지면 재조정한다.

- **초기 자원 순서** = 캠프 메뉴 표시 순서. `인구`를 맨 앞에 둔다.
- 외형 색상 필드: `fill_color`(부지) · `edge_color`(테두리) · `tent_color`(중심 표식).
  - 농장 전용 렌더링(작물 표현 등)은 배치가 생기는 **Phase 2**에서 다듬는다.
- `build_cost`·`demolish_refund`·`production`은 자원명→수량 Dictionary. `build_turns`는 건설 소요 턴.
- **턴당 생산(`production`)은 [턴](../features/turn.md) 종료 시 영지 수입으로 동작한다.** **캠프 건설 → 새 영지 생성**은 [캠프 건설](../features/building.md#캠프-건설-새-영지-확장)에서 구현됨(활성 부대 시야에 배치, 새 영지 자원 0).
- **`footprint`은 [배치 유효성](../features/building.md#배치-유효성-buildplanner)에 반영된다** — `BuildPlanner.footprint`/`can_place`가 종류별 헥스 수로 판정하고, `Building.setup`이 그만큼 점유 셀을 잡는다.
- **인구 상한(`pop_cap`)**: 종류가 영지 [인구 상한](../entities/Territory.md#인구-상한population_cap)에 더하는 값(없으면 0). **거점 티어에서 나온다** — 캠프 `0`, 마을회관 `10`, 성 `20`(집 `+2`로 보조). 완성 건물만 상한에 기여한다(`Building.pop_cap()`은 건설 중이면 0). 매 턴 종료 시 영지 인구가 상한까지 +1씩 [자연 증가](turn.md)한다. **캠프 티어는 인구 상한 0** — 마을회관으로 업그레이드해야 인구가 생긴다.
- **소형 건물·성벽·업그레이드는 석재를 요구**한다. 영지 초기 자원에 **석재 30**이 있어(위 캠프 `resources`) 시작부터 [성벽](../features/wall.md)·마을회관 업그레이드·일부 건물을 지을 수 있고, 이후 채석장으로 석재를 보충한다.

### 필요인원 (`required_pop`)

생산 건물은 **노동력**(인구)을 고용한다. `required_pop`은 그 건물이 필요로 하는 인구 수(없으면 0). [인구(상한·자연 증가)](../entities/Territory.md#인구-상한population_cap)가 곧 노동력 풀이다.

- **건설 게이트**([건축](../features/building.md#필요인원-게이트)): 그 영지의 현재 인구 ≥ `required_pop`이어야 짓는다(선행·자재와 함께 판정 `BuildPlanner.can_build`).
- **고용/반환**: 건설 시 인구를 `required_pop`만큼 소비(`Territory.build_pay`), 철거 시 되돌려준다(`Territory.demolish`). 자재(`build_cost`/`demolish_refund`)와 별개로 처리된다.
- 농장 원래 `build_cost`의 `인구 2`는 이제 `required_pop 2`(노동력)로 재분류됐다 — 농장 순 비용은 동일. **벌목소·채석장은 새로 인구를 1씩 고용**한다(신규 제약).
- **직업 클래스**(농부·나뭇꾼 등 특정 직업 구분)와 **인구 부족 시 가동 중단**은 아직 **미구현** — 현재는 인원수 게이트만. 특징 칸의 직업 이름은 참고용.

### 거점 업그레이드 (인플레이스 티어)

거점은 **캠프(tier 0) → 마을회관(tier 1) → 성(tier 2)** 로 **제자리 업그레이드**한다. 별도 건물이 아니라 같은 거점의 티어가 오른다(위치·footprint·수비대·영지 유지).

- `BuildingTypes.center_tier(id) -> int` — camp 0 / town_hall 1 / castle 2, 거점 아니면 -1.
- `BuildingTypes.next_center(id) -> String` — 다음 티어 id(camp→town_hall, town_hall→castle), 최종/비거점이면 `""`.
- 업그레이드 **비용 = 다음 티어의 `build_cost`**(마을회관 목재10·석재10·밀20, 성 석재50·밀30). 거점의 영지가 지불(`Territory.build_pay`). **즉시** 티어업(건설 시간 적용은 미구현).
- 실행: [캠프 메뉴](../features/camp-menu.md)의 **업그레이드 버튼** → `Building.upgrade_to(next)`. → [건축](../features/building.md#거점-업그레이드).
- 마을회관·성은 `BUILDABLE_IDS`에 **없다**(별도로 못 짓고 업그레이드로만 도달).

### 선행건물 (`prerequisite`) — 거점 티어 기준

각 [건축 가능 종류](../features/building.md#선행건물-게이트)는 `prerequisite`(거점 티어 id)를 가진다. **그 영지의 거점 티어가 선행 티어 이상**이어야 짓는다(`BuildPlanner.prerequisite_met` — 건물 존재가 아니라 **티어 비교**. 성으로 더 올려도 선행이 유지된다).

| id | `prerequisite` | 필요 거점 티어 |
| --- | --- | --- |
| `quarry` | `camp` | 거점 tier ≥ 0 (거점만 있으면. 석재 부트스트랩) |
| `farm` | `camp` | 거점 tier ≥ 0 ([1차 생산](../features/production.md)은 캠프부터) |
| `lumberjack` | `camp` | 거점 tier ≥ 0 (〃) |
| `house` | `town_hall` | 거점 tier ≥ 1 (마을회관 이상) |

- 거점 자신(`camp`/`town_hall`/`castle`)의 `prerequisite` 필드는 업그레이드 경로(`next_center`)로 대체되어 게이트에는 쓰이지 않는다(카탈로그엔 남아 있음).
- 체인: **캠프 →(업그레이드) 마을회관 →(업그레이드) 성**. **1차 생산(농장·벌목소·채석장)은 캠프 티어부터** 해금. 집 등 나머지는 마을회관 티어부터.
- **배치 규칙**([1차 생산](../features/production.md#배치-규칙-build_planner--gamegd)): 1차 생산 = 지형 제한(`buildable_terrains`) + 건물∪부대 시야. 기타 건물 = 마을회관 인접.
- 병영 등 군사 체인, 필요직업/인원(직업 클래스)은 아직 **미구현**.

### 성벽 (`WALL_COST`)

거점 [성벽](../features/wall.md)은 카탈로그 건물이 아니라 거점에 붙는 값(`Building.wall_level`)이지만, 건설 비용은 여기 `BuildingTypes.WALL_COST` 상수로 둔다.

- `WALL_COST := {목재: 15, 석재: 10}` — 성벽 1단계 건설 비용(자재 Dictionary). *이번 슬라이스 단일 단계.*
- `can_build_wall(territory, building) -> bool` — **거점 tier ≥ town_hall**(마을회관·성) + **성벽 없음**(`not building.is_walled()`) + `territory.can_afford(WALL_COST)`면 참. 캠프·이미 성벽·자재 부족·영지 없음이면 거짓.

## 동작

- `BuildingTypes.CAMP` — 캠프 종류 id 상수(`"camp"`).
- `BuildingTypes.FARM` — 농장 종류 id 상수(`"farm"`).
- `BuildingTypes.BUILDABLE_IDS` — **건축(캠프 메뉴)에서 지을 수 있는 종류 id 목록**. 현재 `["quarry", "farm", "house", "lumberjack"]`. **거점(캠프·마을회관·성)은 제외** — 캠프는 [새 영지 건설](../features/building.md#캠프-건설-새-영지-확장)(별도 버튼), 마을회관·성은 [업그레이드](#거점-업그레이드)로만 도달. 선행 미충족 종류는 리스트에 뜨되 **비활성**이다([건축](../features/building.md)).
- `BuildingTypes.get_type(type_id) -> Dictionary` — 종류 스펙 반환. 없는 id면 빈 Dictionary.
- `BuildingTypes.CENTER_IDS` — **거점(center)** 종류 목록 `["camp", "town_hall", "castle"]`(티어 순). 세력의 전략 앵커. **승리·점령·수비대·[캠프 메뉴](../features/camp-menu.md) 판정이 이 세트를 기준**으로 한다.
- `BuildingTypes.is_center(type_id) -> bool` — 그 종류가 거점인지(`type_id in CENTER_IDS`). 세 티어 중 하나라도 세력이 가지면 유지된다([승패](../features/victory.md)).
- `BuildingTypes.center_tier(type_id) -> int` — 거점 티어(camp 0 / town_hall 1 / castle 2), 거점 아니면 -1.
- `BuildingTypes.next_center(type_id) -> String` — [업그레이드](#거점-업그레이드) 다음 티어 id(camp→town_hall, town_hall→castle), 최종(성)·비거점이면 `""`.

## 테스트 시나리오

`test/unit/test_building_types.gd`.

- [정상] `get_type("camp")`에 `label`·`vision`·`resources`·외형 색상 키가 모두 존재
- [정상] `get_type("camp").vision == 5`, `label == "캠프"`, `footprint == 7`, 자원 7종(인구 10 포함)
- [정상] `get_type("farm").label == "농장"`, `vision == 4`, `footprint == 1`, 외형 색상 키 존재, 초기 `resources` 없음(빈/미정의)
- [정상] `get_type("farm")`의 `build_turns == 3`, `build_cost == {목재5, 밀5}`, `demolish_refund == {목재1}`, `required_pop == 0`, `production == {}`(flat 없음 — [1차 생산](../features/production.md))
- [정상] 1차 생산 — `farm`: `primary_production==true`, `produces=="밀"`, `buildable_terrains==[초원]`; `lumberjack`: `primary_production==true`, `produces=="나무"`, `buildable_terrains==[숲]`, `production=={}`
- [정상] 필요인원 — `farm.required_pop == 0`, `lumberjack.required_pop == 0`(1차 생산은 가변 배치), `quarry.required_pop == 1`(flat 유지), `house`·`camp`·`town_hall`·`castle`는 0
- [경계] 비-생산 건물 — `house`·`quarry`·`camp`: `primary_production` false/미정의, `produces==""`, `buildable_terrains==[]`
- [정상] `get_type("camp")`의 `build_turns == 8`, `build_cost == {목재10, 밀10}`, `demolish_refund == {목재2}`
- [정상] `get_type("house")` — `label == "집"`, `vision == 2`, `footprint == 1`, `build_turns == 4`, `build_cost == {목재8, 석재4}`, `pop_cap == 2`, `production` 없음(생산 아님), 외형 색상 키 존재
- [정상] 인구 상한 티어 — `camp.pop_cap == 0`, `town_hall.pop_cap == 10`, `castle.pop_cap == 20`, `house.pop_cap == 2`
- [정상] `center_tier` — camp 0, town_hall 1, castle 2; 비거점(farm 등)·없는id는 -1
- [정상] `next_center` — camp→"town_hall", town_hall→"castle", castle→"", 비거점→""
- [정상] `get_type("lumberjack")` — `label == "벌목소"`, `vision == 3`, `footprint == 1`, `build_turns == 3`, `build_cost == {목재5, 석재5}`, `production == {나무2}`
- [정상] `get_type("quarry")` — `label == "채석장"`, `vision == 3`, `footprint == 1`, `build_turns == 4`, `build_cost == {목재10}`, `production == {석재2}`, `prerequisite == "camp"`
- [정상] `get_type("town_hall")` — `label == "마을회관"`, `vision == 6`, `footprint == 7`, `build_turns == 8`, `build_cost == {목재10, 석재10, 밀20}`, `prerequisite == "camp"`, `production` 없음(빈/미정의)
- [정상] `get_type("castle")` — `label == "성"`, `vision == 8`, `footprint == 7`, `build_turns == 12`, `build_cost == {석재50, 밀30}`, `demolish_refund == {석재10}`, `prerequisite == "town_hall"`, `production` 없음
- [정상] `WALL_COST == {목재15, 석재10}`(자재 Dictionary)
- [정상] `can_build_wall` — 마을회관 거점 + 자재 충분 → 참; [경계] 캠프(tier 0) → 거짓, 이미 성벽(`wall_level=1`) → 거짓, 자재 부족 → 거짓
- [정상] 선행 필드 — `get_type("camp").prerequisite == ""`, `farm`·`house`·`lumberjack`의 `prerequisite == "town_hall"`
- [경계] `get_type("없는id")`는 빈 Dictionary
- [정상] `BUILDABLE_IDS`가 `["quarry", "farm", "house", "lumberjack"]`(거점 3종 모두 미포함)
- [정상] `is_center` — `camp`·`town_hall`·`castle`는 참; `farm`·`house`·`lumberjack`·`quarry`·`없는id`는 거짓
- [정상] `CENTER_IDS == ["camp", "town_hall", "castle"]`

## 관련

- 종류를 배치·사용하는 주체: [Building 엔티티](../entities/Building.md)
- 자원 목록: [resources.md](resources.md)
- 생산(`production`) 로직은 [턴](../features/turn.md)에서 구현됨. 건설 코어 로직(자원 소비·건설 중 상태·배치 유효성)은 [건축](../features/building.md) 슬라이스 1에서 구현됨. **철거**는 [건물 정보 패널](../features/building-info.md#철거)에서 구현됨(거점 제외). **캠프 건설(새 영지)**은 [건축](../features/building.md#캠프-건설-새-영지-확장)에서 구현됨.
