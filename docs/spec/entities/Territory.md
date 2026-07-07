# Entity: Territory (영지)

> 스크립트: `scenes/territory/territory.gd` (`class_name Territory extends RefCounted`)

세력이 보유하는 **영지**. 예: "파리". 하나의 [세력](Faction.md)은 여러 영지를 거느리고,
하나의 영지는 **중심 캠프 + 그 안의 건물들**을 가지며 **모든 자원(인구 포함)을 보유**한다.

구조: **[세력](Faction.md) → 영지(Territory) → [건물](Building.md)**.
캠프를 건설하면 새 영지가 생기고(**건설 로직은 Phase 2**), 영지의 초기 자원은 캠프 종류의
[카탈로그](../data/buildings.md) `resources`에서 복사된다.

시각 요소가 없는 **순수 데이터 엔티티**라 씬(`.tscn`) 없이 스크립트만 둔다.

## Properties

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 이름 | `name` | `String` | `""` | 영지 이름 (예: "파리") |
| 보유 자원 | `resources` | `Dictionary` | `{}` | **모든 자원**(인구·밀·빵·나무·목재·철·철괴). 삽입 순서 = 메뉴 표시 순서 |
| 소속 세력 | `faction` | `Faction` | `null` | 이 영지를 보유한 세력. `Faction.add_territory`로 연결 |
| 소속 건물 | `buildings` | `Array` | `[]` | 이 영지에 속한 [건물](Building.md) 목록(중심 캠프 + 그 안의 건물들) |

## 동작

- `_init(name := "", resources := {})` — 이름과 자원(복사본 권장)을 받아 생성. `buildings`는 빈 배열로 시작.
- `add_building(building) -> void` — 건물을 `buildings`에 추가하고 **동시에** `building.territory = self`로 설정한다(양방향). 이미 포함된 건물은 중복 추가하지 않는다.

## 테스트 시나리오

`test/unit/test_territory.gd`.

- [정상] `_init("파리", {인구:10, ...})` 후 `name == "파리"`, `resources`가 넘긴 값과 일치
- [정상] 생성 직후 `buildings`는 빈 배열, `faction`은 `null`
- [정상] `add_building(b)` 후 `buildings`에 `b`가 들어가고 `b.territory`가 이 영지를 가리킨다(양방향)
- [경계] 같은 건물을 두 번 `add_building` 해도 `buildings` 크기는 1 (중복 방지)

## 관련

- 세력↔영지 연결은 [Faction 엔티티](Faction.md)의 `add_territory` 참고.
- 영지의 자원·이름·세력은 [Camp Menu](../features/camp-menu.md)에 표시된다.
- 영지 초기 자원의 출처(캠프 카탈로그)는 [buildings.md](../data/buildings.md) 참고.
