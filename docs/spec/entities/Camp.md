# Entity: Camp (캠프)

> 스크립트: `scenes/camp/camp.gd` (`extends Node2D`)

맵 중앙에 위치한 캠프. **중심 1헥스 + 주변 6헥스 = 총 7헥스**를 차지한다.
헥스 중 하나라도 클릭되면 게임 쪽에서 [캠프 메뉴](../features/camp-menu.md)를 연다.
`_draw()`로 흙색 부지 + 중심 텐트 표시를 직접 그린다.

## Properties

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

## 관련

- 보유 자원 목록은 [data/resources.md](../data/resources.md) 참고.
- 시야는 [Fog of War](../features/fog-of-war.md)에서 주인공 시야와 합산된다.
