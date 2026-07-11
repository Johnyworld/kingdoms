# Data: Buildings (건물 종류)

> 스크립트: `scenes/building/building_types.gd` (`class_name BuildingTypes`)

게임에 존재하는 **건물 종류 카탈로그**. 각 종류의 스펙을 데이터로 정의한다.
[Building 엔티티](../entities/Building.md)가 `setup(.., type_id)` 시 여기서 시야·외형을 읽는다.
캠프의 초기 `resources`는 건설 시 생성되는 [영지](../entities/Territory.md)의 **초기 자원**으로 복사된다(건물이 아니라 영지가 자원을 보유).

## 카탈로그 (`CATALOG`)

키 = 종류 id. 값 = 스펙 Dictionary.

### 기본 · 외형

`footprint`은 건물이 차지하는 헥스 수(테이블 "필요헥스"). `7`이면 중심+이웃 6칸, `1`이면 중심 1칸만.
캠프·마을회관·성·농장은 7헥스, 소형 생산 건물(집·벌목소·채석장)은 1헥스.

| id | `label` | `vision` | `footprint` | 초기 `resources` (→ 생성 영지 초기 자원) | 외형 색상 |
| --- | --- | --- | --- | --- | --- |
| `camp` | 캠프 | 5 | 7 | 인구 10 / 밀 50 / 빵 20 / 나무 20 / 목재 20 / 철 10 / 철괴 10 | 흙색 계열 |
| `town_hall` | 마을회관 | 6 | 7 | (없음) | 밝은 목조·기와 계열 |
| `castle` | 성 | 8 | 7 | (없음) | 회청색 석조 계열 |
| `farm` | 농장 | 4 | 7 | (없음 — 영지를 새로 만들지 않음) | 녹색(밭) 계열 |
| `house` | 집 | 2 | 1 | (없음) | 따뜻한 흙색(목조) 계열 |
| `lumberjack` | 벌목소 | 3 | 1 | (없음) | 짙은 녹갈색 계열 |
| `quarry` | 채석장 | 3 | 1 | (없음) | 회색(석재) 계열 |

### 건설 · 경제

`production`은 [턴](../features/turn.md) 종료 시 영지 수입으로 **사용된다**(`Building.production` → `Territory.collect_income`).
`build_cost`(자원 차감)와 `build_turns`(건설 소요 턴) 소비 로직은 [건축](../features/building.md) 슬라이스 1에서 **구현됨**(단 게임 플로우 배선은 슬라이스 2). `demolish_refund`(철거 시 자재 회수)는 [건물 정보 패널의 철거](../features/building-info.md#철거)에서 **구현됨**(캠프 제외).

| id | `build_turns` | `build_cost` | `demolish_refund` | `production` | 특수 효과 |
| --- | --- | --- | --- | --- | --- |
| `camp` | 8 | 목재 10 / 밀 10 | 목재 2 | (없음) | 건설 완료 시 **새 영지 생성**. 인구 상한 `pop_cap 10`(기본) |
| `town_hall` | 8 | 목재 10 / 석재 10 / 밀 20 | 목재 2 / 석재 2 | (없음) | 대부분 건물의 선행 조건. 상인 방문은 **미구현** |
| `castle` | 12 | 석재 50 / 밀 30 | 석재 10 | (없음) | 영지 최종 단계. 고급 건물 해금은 **미구현** |
| `farm` | 3 | 인구 2 / 목재 5 / 밀 5 | 인구 2 / 목재 1 | 밀 1 (턴당) | (없음) |
| `house` | 4 | 목재 8 / 석재 4 | 목재 2 | (없음) | **인구 상한 `pop_cap +2`**(생산 아님) |
| `lumberjack` | 3 | 목재 5 / 석재 5 | 목재 1 | 나무 2 (턴당) | (없음) |
| `quarry` | 4 | 목재 10 | 목재 2 | 석재 2 (턴당) | (없음) |

> **마을회관 값은 테이블에서 조정됨(플레이성/부트스트랩)**: 테이블 원본은 `build_turns 15 / 목재30·석재20·밀20`. 시작 자원(목재 20, 석재 0)만으로는 도달 불가하므로, 시작 → 채석장으로 석재 확보 → 마을회관 건설이 가능하도록 `build_turns 8 / 목재10·석재10·밀20`으로 낮췄다. 경제 밸런스가 갖춰지면 재조정한다.
> **성 값도 테이블에서 조정됨**: 테이블 원본은 `build_turns 30 / 석재80·목재40·철괴20·금50`. 현재 경제엔 **금 생산원이 없고**(금광 미구현) 목재도 시작 20에서 늘지 않아 도달 불가하다. 재생 가능한 석재(채석장)와 시작 밀만으로 지을 수 있도록 `build_turns 12 / 석재50·밀30`으로 낮췄다. 금·철괴 경제가 갖춰지면 재조정한다.

- **초기 자원 순서** = 캠프 메뉴 표시 순서. `인구`를 맨 앞에 둔다.
- 외형 색상 필드: `fill_color`(부지) · `edge_color`(테두리) · `tent_color`(중심 표식).
  - 농장 전용 렌더링(작물 표현 등)은 배치가 생기는 **Phase 2**에서 다듬는다.
- `build_cost`·`demolish_refund`·`production`은 자원명→수량 Dictionary. `build_turns`는 건설 소요 턴.
- **턴당 생산(`production`)은 [턴](../features/turn.md) 종료 시 영지 수입으로 동작한다.** **캠프 건설 → 새 영지 생성** 효과는 아직 **미구현**이다(캠프 외 건물 건설만 다룸, [건축](../features/building.md) 참고).
- **`footprint`은 [배치 유효성](../features/building.md#배치-유효성-buildplanner)에 반영된다** — `BuildPlanner.footprint`/`can_place`가 종류별 헥스 수로 판정하고, `Building.setup`이 그만큼 점유 셀을 잡는다.
- **인구 상한(`pop_cap`)**: 종류가 영지 [인구 상한](../entities/Territory.md#인구-상한population_cap)에 더하는 값(없으면 0). 캠프 `pop_cap 10`(기본), 집 `pop_cap 2`. 완성 건물만 상한에 기여한다(`Building.pop_cap()`은 건설 중이면 0). 매 턴 종료 시 영지 인구가 상한까지 +1씩 [자연 증가](turn.md)한다. 집은 이제 인구를 **생산**하지 않고 **상한을 올린다**(이전 슬라이스의 `production {인구:2}` 근사를 대체).
- **신규 소형 건물은 석재를 요구**한다. 영지 초기 자원에 석재가 없으므로(위 캠프 `resources`) **채석장(목재만)으로 석재를 확보한 뒤** 벌목소·집을 짓는 순서가 된다. 새 자원 키(`석재`)는 `Territory.collect_income`/`can_afford`가 자동으로 처리한다.

### 선행건물 (`prerequisite`)

각 종류는 `prerequisite`(선행 건물 종류 id, 없으면 `""`)를 가진다. **그 영지에 선행 종류의 완성 건물이 있어야** 건축할 수 있다([건축 게이트](../features/building.md#선행건물-게이트), [캠프 메뉴](../features/camp-menu.md)).

| id | `prerequisite` | 비고 |
| --- | --- | --- |
| `camp` | `""` | 선행 없음 |
| `quarry` | `camp` | **테이블(마을회관)과 다름** — 석재 부트스트랩용. 캠프만 있으면 지어 석재를 확보 |
| `town_hall` | `camp` | 캠프가 곧 영지의 중심이라 항상 충족 |
| `castle` | `town_hall` | 마을회관 완성 후 해금(지휘소 최종 단계) |
| `farm` | `town_hall` | 마을회관 완성 후 해금 |
| `house` | `town_hall` | 〃 |
| `lumberjack` | `town_hall` | 〃 |

- 체인: **캠프 → 채석장(석재) · 마을회관 → 성 · 농장 · 집 · 벌목소**.
- 성(`castle`)은 지휘소 최종 단계(선행 2단 깊이: 캠프→마을회관→성). **성을 선행으로 하는 고급 건물(마법사의 탑·성벽 등)은 아직 없다** — 이번 슬라이스는 체인 최상단만.
- 병영 등 군사 체인, 필요직업/인원 조건은 아직 **미구현**(다음 슬라이스).

## 동작

- `BuildingTypes.CAMP` — 캠프 종류 id 상수(`"camp"`).
- `BuildingTypes.FARM` — 농장 종류 id 상수(`"farm"`).
- `BuildingTypes.BUILDABLE_IDS` — **건축(캠프 메뉴)에서 지을 수 있는 종류 id 목록**. 현재 `["town_hall", "quarry", "farm", "house", "lumberjack", "castle"]`. 캠프는 새 영지 생성이라 제외(미구현). 선행 미충족 종류는 리스트에 뜨되 **비활성**이다([건축](../features/building.md)).
- `BuildingTypes.get_type(type_id) -> Dictionary` — 종류 스펙 반환. 없는 id면 빈 Dictionary.

## 테스트 시나리오

`test/unit/test_building_types.gd`.

- [정상] `get_type("camp")`에 `label`·`vision`·`resources`·외형 색상 키가 모두 존재
- [정상] `get_type("camp").vision == 5`, `label == "캠프"`, `footprint == 7`, 자원 7종(인구 10 포함)
- [정상] `get_type("farm").label == "농장"`, `vision == 4`, `footprint == 7`, 외형 색상 키 존재, 초기 `resources` 없음(빈/미정의)
- [정상] `get_type("farm")`의 `build_turns == 3`, `build_cost == {인구2, 목재5, 밀5}`, `demolish_refund == {인구2, 목재1}`, `production == {밀1}`
- [정상] `get_type("camp")`의 `build_turns == 8`, `build_cost == {목재10, 밀10}`, `demolish_refund == {목재2}`
- [정상] `get_type("house")` — `label == "집"`, `vision == 2`, `footprint == 1`, `build_turns == 4`, `build_cost == {목재8, 석재4}`, `pop_cap == 2`, `production` 없음(생산 아님), 외형 색상 키 존재
- [정상] `get_type("camp").pop_cap == 10`(기본 인구 상한)
- [정상] `get_type("lumberjack")` — `label == "벌목소"`, `vision == 3`, `footprint == 1`, `build_turns == 3`, `build_cost == {목재5, 석재5}`, `production == {나무2}`
- [정상] `get_type("quarry")` — `label == "채석장"`, `vision == 3`, `footprint == 1`, `build_turns == 4`, `build_cost == {목재10}`, `production == {석재2}`, `prerequisite == "camp"`
- [정상] `get_type("town_hall")` — `label == "마을회관"`, `vision == 6`, `footprint == 7`, `build_turns == 8`, `build_cost == {목재10, 석재10, 밀20}`, `prerequisite == "camp"`, `production` 없음(빈/미정의)
- [정상] `get_type("castle")` — `label == "성"`, `vision == 8`, `footprint == 7`, `build_turns == 12`, `build_cost == {석재50, 밀30}`, `demolish_refund == {석재10}`, `prerequisite == "town_hall"`, `production` 없음
- [정상] 선행 필드 — `get_type("camp").prerequisite == ""`, `farm`·`house`·`lumberjack`의 `prerequisite == "town_hall"`
- [경계] `get_type("없는id")`는 빈 Dictionary
- [정상] `BUILDABLE_IDS`가 `["town_hall", "quarry", "farm", "house", "lumberjack", "castle"]`(캠프 미포함)

## 관련

- 종류를 배치·사용하는 주체: [Building 엔티티](../entities/Building.md)
- 자원 목록: [resources.md](resources.md)
- 생산(`production`) 로직은 [턴](../features/turn.md)에서 구현됨. 건설 코어 로직(자원 소비·건설 중 상태·배치 유효성)은 [건축](../features/building.md) 슬라이스 1에서 구현됨. **철거**는 [건물 정보 패널](../features/building-info.md#철거)에서 구현됨(캠프 제외). 캠프 건설(새 영지 생성)은 아직 **미구현**.
