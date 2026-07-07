# Entity: Building (건물)

> 스크립트: `scenes/building/building.gd` (`class_name Building extends Node2D`)

맵에 배치된 **건물** 인스턴스. 어떤 *종류*인지(`building_type`)에 따라 시야·초기 자원·외형 등의 스펙을
[건물 카탈로그](../data/buildings.md)에서 읽어 온다. **캠프(`"camp"`)는 건물 종류 중 하나**다.

**중심 1헥스 + 주변 6헥스 = 총 7헥스**를 차지한다(현재 모든 종류 공통 발자국. 종류별 footprint는 **미구현**).
헥스 중 하나라도 클릭되면 게임 쪽에서 [캠프 메뉴](../features/camp-menu.md)를 연다.
`_draw()`로 종류별 색으로 부지 + 중심 텐트를 그린다.

## Properties

### 정체성 (Identity)

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 종류 | `building_type` | `String` | `""` | 건물 종류 id (예: `"camp"`). [카탈로그](../data/buildings.md) 키 |
| 이름 | `building_name` | `String` | `""` | 인스턴스 고유 이름 (예: "파리"). 변경 시 `queue_redraw` |
| 소속 세력 | `faction` | `Faction` | `null` | 소속 [세력](Faction.md). `Faction.add_building`로 연결. 변경 시 `queue_redraw` |

### 종류에서 오는 값 (setup 시 카탈로그에서 복사)

| 속성 | 변수 | 타입 | 설명 |
| --- | --- | --- | --- |
| 보유 자원 | `resources` | `Dictionary` | 종류의 초기 자원을 **복사**해 인스턴스가 보유. 삽입 순서 = 메뉴 표시 순서 |
| 시야 | `vision` | `int` | 종류의 시야. 안개 밝힘 반경 |

### 배치 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 점유 셀 | `cells: Array[Vector2i]` | 중심 + 이웃 6칸 |
| 중심 셀 | `_center_cell` | 시야 계산 기준점 |
| 지형 참조 | `_terrain: TileMapLayer` | 좌표 변환용 |
| 종류 스펙 | `_spec: Dictionary` | 카탈로그 조회 결과 캐시 |

## 동작

- `setup(terrain, center_cell, type_id) -> void` — 종류 스펙을 카탈로그에서 읽어 `building_type`·`vision`·`resources`(복사)를 채우고, 중심 셀 + 이웃 6칸을 점유 셀로 설정. 알 수 없는 `type_id`면 빈 스펙(시야 0·자원 없음·라벨 "")이 되고, `_draw`는 중립 회색으로 그린다(캠프로 위장하지 않도록).
- `contains_cell(cell) -> bool` — 해당 셀이 건물 영역에 포함되는지.
- `center_cell() -> Vector2i` — 시야 계산 기준점 반환.
- `label() -> String` — 종류 라벨(예: "캠프"). 카탈로그의 `label`.
- `map_label_lines() -> Array` — 맵에 표시할 텍스트 줄 목록. 각 원소는 `{text, color}`.
  - 이름이 있으면 첫 줄 = `{building_name, 흰색}`.
  - 세력이 있으면 다음 줄 = `{faction.name, faction.color}`.
  - 이름·세력이 모두 없으면 빈 배열.

## 맵 표시

`_draw()`가 중심 텐트 **위쪽 중앙**에 `map_label_lines()`의 줄들을 위→아래로 그린다.
이름은 흰색, 세력명은 세력 색상. 월드 좌표라 카메라 줌에 따라 함께 확대·축소된다.

## 테스트 시나리오

`test/unit/test_building.gd`.

- [정상] `setup(.., "camp")` 후 점유 셀 = **7헥스** (중심 + 이웃 6)
- [정상] `center_cell()`은 `setup`에 넘긴 중심 셀
- [정상] `contains_cell`이 중심·이웃 6칸에 대해 참, 먼 셀에 대해 거짓
- [정상] `"camp"`로 setup 시 초기 자원 6종이 카탈로그와 일치 (밀 50 / 빵·나무·목재 20 / 철·철괴 10)
- [정상] `"camp"`로 setup 시 `building_type == "camp"`, `vision == 5`, `label() == "캠프"`
- [정상] `resources`는 카탈로그 원본과 **다른 인스턴스**(복사본) — 수정해도 카탈로그 불변
- [경계] 알 수 없는 `type_id`로 setup 시 `vision == 0`, `resources` 비어 있음, `label() == ""`
- [정상] 기본 `building_name == ""`, 기본 `faction == null`
- [정상] 이름·세력이 있으면 `map_label_lines()` = [이름(흰색), 세력명(세력색)] 2줄
- [경계] 이름만 있고 세력 없으면 1줄, 둘 다 없으면 빈 배열

## 관련

- 종류별 스펙은 [data/buildings.md](../data/buildings.md) 참고.
- 소속 세력은 [Faction 엔티티](Faction.md) 참고.
- 시야는 [Fog of War](../features/fog-of-war.md)에서 주인공 시야와 합산된다.
- 이름·세력은 [Camp Menu](../features/camp-menu.md)에 표시된다.
