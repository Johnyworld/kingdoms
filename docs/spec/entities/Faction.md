# Entity: Faction (세력)

> 스크립트: `scenes/faction/faction.gd` (`class_name Faction extends RefCounted`)

건물이 소속되는 **세력**. 예: "프랑스". 하나의 세력은 여러 건물을 거느릴 수 있다.

시각 요소가 없는 **순수 데이터 엔티티**라 씬(`.tscn`) 없이 스크립트만 둔다.
(폴더 규칙 "각 폴더에 `.tscn` + `.gd`"의 소수 예외 — 데이터 전용 엔티티라 씬이 불필요.)

## Properties

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 이름 | `name` | `String` | `""` | 세력 이름 (예: "프랑스") |
| 색상 | `color` | `Color` | `Color.WHITE` | 세력 대표색 (UI 표기용) |
| 소속 건물 | `buildings` | `Array` | `[]` | 이 세력에 속한 [Building](Building.md) 목록 |

`RefCounted`라 `name`은 노드 이름과 무관하게 자유롭게 쓸 수 있다.

## 동작

- `_init(name := "", color := Color.WHITE)` — 이름·색상을 받아 생성. `buildings`는 빈 배열로 시작.
- `add_building(building) -> void` — 건물을 `buildings`에 추가하고 **동시에** `building.faction = self`로 설정한다(양방향 동기화). 이미 포함된 건물은 중복 추가하지 않는다.

## 테스트 시나리오

`test/unit/test_faction.gd`.

- [정상] `_init("프랑스", 파랑)` 후 `name == "프랑스"`, `color == 파랑`
- [정상] 생성 직후 `buildings`는 빈 배열
- [정상] `add_building(building)` 후 `buildings`에 그 건물이 들어가고, `building.faction`이 이 세력을 가리킨다 (양방향)
- [경계] 같은 건물을 두 번 `add_building` 해도 `buildings` 크기는 1 (중복 방지)

## 관련

- 건물은 [Building 엔티티](Building.md)의 `faction` 필드로 자기 세력을 참조한다.
- 세력 이름은 [Camp Menu](../features/camp-menu.md) 우측 패널에 건물 이름과 함께 표시된다.
