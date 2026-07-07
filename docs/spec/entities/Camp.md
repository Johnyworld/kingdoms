# Entity: Camp (캠프)

> 스크립트: `scenes/camp/camp.gd` (`class_name Camp extends Node2D`)

맵 중앙에 위치한 캠프. **중심 1헥스 + 주변 6헥스 = 총 7헥스**를 차지한다.
헥스 중 하나라도 클릭되면 게임 쪽에서 [캠프 메뉴](../features/camp-menu.md)를 연다.
`_draw()`로 흙색 부지 + 중심 텐트 표시를 직접 그린다.
캠프는 **이름**(예: "파리")을 가지며, 하나의 [세력(Faction)](Faction.md)에 소속된다.

## Properties

### 정체성 (Identity)

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 이름 | `camp_name` | `String` | `""` | 캠프 이름 (예: "파리"). `Node.name`과 충돌을 피해 `camp_name` 사용 |
| 소속 세력 | `faction` | `Faction` | `null` | 이 캠프가 속한 [세력](Faction.md). `Faction.add_camp`로 연결 |

### 보유 자원 (Resources)

`resources: Dictionary` — **삽입 순서가 곧 메뉴 표시 순서**다.

| 자원 | 초기값 |
| --- | --- |
| 밀 | 50 |
| 빵 | 20 |
| 나무 | 20 |
| 목재 | 20 |
| 철 | 10 |
| 철괴 | 10 |

### 능력치

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 시야 | `vision` | 5 | 캠프 중심 기준 안개를 밝히는 반경 |

### 배치 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 점유 셀 | `cells: Array[Vector2i]` | 중심 + 이웃 6칸 |
| 중심 셀 | `_center_cell` | 시야 계산 기준점 |
| 지형 참조 | `_terrain: TileMapLayer` | 좌표 변환용 |

## 동작

- `setup(terrain, center_cell)` — 중심 셀과 이웃 6칸을 점유 셀로 설정.
- `contains_cell(cell) -> bool` — 해당 셀이 캠프 영역에 포함되는지.
- `center_cell() -> Vector2i` — 시야 계산 기준점 반환.
- `map_label_lines() -> Array` — 맵에 표시할 텍스트 줄 목록을 반환한다. 각 원소는 `{text: String, color: Color}`.
  - 이름이 있으면 첫 줄 = `{camp_name, 흰색}`.
  - 세력이 있으면 다음 줄 = `{faction.name, faction.color}`.
  - 이름·세력이 모두 없으면 빈 배열.

## 맵 표시

`_draw()`가 캠프 중심 텐트 **위쪽 중앙**에 `map_label_lines()`의 줄들을 위→아래로 그린다.
캠프명은 흰색, 세력명은 세력 색상. 텍스트는 월드 좌표에 그려지므로 카메라 줌에 따라 함께 확대·축소된다.

## 테스트 시나리오

`test/unit/test_camp.gd`.

- [정상] `setup` 후 점유 셀 = **7헥스** (중심 + 이웃 6)
- [정상] `center_cell()`은 `setup`에 넘긴 중심 셀
- [정상] `contains_cell`이 중심·이웃 6칸에 대해 참
- [경계] 먼 셀에 대해 `contains_cell` 거짓
- [정상] 초기 자원 6종 값이 스펙과 일치 (밀 50 / 빵·나무·목재 20 / 철·철괴 10)
- [정상] 기본 시야 `vision == 5`
- [정상] 기본 `camp_name == ""`, 기본 `faction == null`
- [정상] 이름·세력이 있으면 `map_label_lines()` = [이름(흰색), 세력명(세력색)] 2줄
- [정상] `map_label_lines()`의 세력 줄 색상 = 세력 색상
- [경계] 이름만 있고 세력이 없으면 `map_label_lines()`는 이름 1줄
- [경계] 이름·세력 모두 없으면 `map_label_lines()`는 빈 배열

## 관련

- 보유 자원 목록은 [data/resources.md](../data/resources.md) 참고.
- 시야는 [Fog of War](../features/fog-of-war.md)에서 주인공 시야와 합산된다.
- 소속 세력은 [Faction 엔티티](Faction.md) 참고.
- 이름·세력은 [Camp Menu](../features/camp-menu.md)에 표시된다.
