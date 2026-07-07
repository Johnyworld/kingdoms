# Data: Buildings (건물 종류)

> 스크립트: `scenes/building/building_types.gd` (`class_name BuildingTypes`)

게임에 존재하는 **건물 종류 카탈로그**. 각 종류의 스펙을 데이터로 정의한다.
[Building 엔티티](../entities/Building.md)가 `setup(.., type_id)` 시 여기서 시야·외형을 읽는다.
캠프의 초기 `resources`는 건설 시 생성되는 [영지](../entities/Territory.md)의 **초기 자원**으로 복사된다(건물이 아니라 영지가 자원을 보유).

## 카탈로그 (`CATALOG`)

키 = 종류 id. 값 = 스펙 Dictionary.

### 기본 · 외형

| id | `label` | `vision` | 초기 `resources` (→ 생성 영지 초기 자원) | 외형 색상 |
| --- | --- | --- | --- | --- |
| `camp` | 캠프 | 5 | 인구 10 / 밀 50 / 빵 20 / 나무 20 / 목재 20 / 철 10 / 철괴 10 | 흙색 계열 |
| `farm` | 농장 | 2 | (없음 — 영지를 새로 만들지 않음) | 녹색(밭) 계열 |

### 건설 · 경제 (Phase 2에서 사용 · 현재 소비 로직 없음)

아래 필드는 데이터로만 기록되며, 이를 소비하는 **턴/건설/생산 시스템은 Phase 2 미구현**이다.

| id | `build_turns` | `build_cost` | `demolish_refund` | `production` | 특수 효과 |
| --- | --- | --- | --- | --- | --- |
| `camp` | 8 | 목재 10 / 밀 10 | 목재 2 | (없음) | 건설 완료 시 **새 영지 생성** |
| `farm` | 3 | 인구 2 / 목재 5 / 밀 5 | 인구 2 / 목재 1 | 밀 1 (턴당) | (없음) |

- **초기 자원 순서** = 캠프 메뉴 표시 순서. `인구`를 맨 앞에 둔다.
- 외형 색상 필드: `fill_color`(부지) · `edge_color`(테두리) · `tent_color`(중심 표식).
  - 농장 전용 렌더링(작물 표현 등)은 배치가 생기는 **Phase 2**에서 다듬는다.
- `build_cost`·`demolish_refund`·`production`은 자원명→수량 Dictionary. `build_turns`는 건설 소요 턴.
- **캠프 건설 → 새 영지 생성** 효과, 농장 턴당 생산 등 특수 효과의 실제 동작은 **Phase 2**다.
- 발자국(footprint)은 현재 카탈로그에 없다 — 모든 종류가 **중심+6=7헥스** 공통. 종류별 footprint는 **미구현(TODO)**.

## 동작

- `BuildingTypes.CAMP` — 캠프 종류 id 상수(`"camp"`).
- `BuildingTypes.FARM` — 농장 종류 id 상수(`"farm"`).
- `BuildingTypes.get_type(type_id) -> Dictionary` — 종류 스펙 반환. 없는 id면 빈 Dictionary.

## 테스트 시나리오

`test/unit/test_building_types.gd`.

- [정상] `get_type("camp")`에 `label`·`vision`·`resources`·외형 색상 키가 모두 존재
- [정상] `get_type("camp").vision == 5`, `label == "캠프"`, 자원 7종(인구 10 포함)
- [정상] `get_type("farm").label == "농장"`, `vision == 2`, 외형 색상 키 존재, 초기 `resources` 없음(빈/미정의)
- [정상] `get_type("farm")`의 `build_turns == 3`, `build_cost == {인구2, 목재5, 밀5}`, `demolish_refund == {인구2, 목재1}`, `production == {밀1}`
- [정상] `get_type("camp")`의 `build_turns == 8`, `build_cost == {목재10, 밀10}`, `demolish_refund == {목재2}`
- [경계] `get_type("없는id")`는 빈 Dictionary

## 관련

- 종류를 배치·사용하는 주체: [Building 엔티티](../entities/Building.md)
- 자원 목록: [resources.md](resources.md)
- 건설(자원 소비·배치)·철거·생산 로직은 **Phase 2 · 미구현**. [추천 스펙](../SPEC.md#추천-스펙-미구현--제안) 참고.
