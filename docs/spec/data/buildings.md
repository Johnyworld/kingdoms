# Data: Buildings (건물 종류)

> 스크립트: `scenes/building/building_types.gd` (`class_name BuildingTypes`)

게임에 존재하는 **건물 종류 카탈로그**. 각 종류의 스펙을 데이터로 정의한다.
[Building 엔티티](../entities/Building.md)가 `setup(.., type_id)` 시 여기서 스펙을 읽어 자기 값을 채운다.

## 카탈로그 (`CATALOG`)

키 = 종류 id. 값 = 스펙 Dictionary.

| id | `label` | `vision` | 초기 `resources` | 외형 색상 |
| --- | --- | --- | --- | --- |
| `camp` | 캠프 | 5 | 밀 50 / 빵 20 / 나무 20 / 목재 20 / 철 10 / 철괴 10 | 부지(흙색)·테두리·텐트색 |

- **초기 자원 순서** = 캠프 메뉴 표시 순서.
- 외형 색상 필드: `fill_color`(부지) · `edge_color`(테두리) · `tent_color`(텐트).
- 발자국(footprint)은 현재 카탈로그에 없다 — 모든 종류가 **중심+6=7헥스** 공통. 종류별 footprint는 **미구현(TODO)**.

## 동작

- `BuildingTypes.CAMP` — 캠프 종류 id 상수(`"camp"`).
- `BuildingTypes.get_type(type_id) -> Dictionary` — 종류 스펙 반환. 없는 id면 빈 Dictionary.

## 테스트 시나리오

`test/unit/test_building_types.gd`.

- [정상] `get_type("camp")`에 `label`·`vision`·`resources`·외형 색상 키가 모두 존재
- [정상] `get_type("camp").vision == 5`, `label == "캠프"`, 자원 6종
- [경계] `get_type("없는id")`는 빈 Dictionary

## 관련

- 종류를 배치·사용하는 주체: [Building 엔티티](../entities/Building.md)
- 자원 목록: [resources.md](resources.md)
- 건설(자원 소비·배치) 로직은 **Phase 2 · 미구현**. [추천 스펙](../SPEC.md#추천-스펙-미구현--제안) 참고.
