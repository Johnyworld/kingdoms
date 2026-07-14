# Data: Terrain (지형)

> 카탈로그: `scenes/game/terrain.gd` (`class_name Terrain`, `extends RefCounted`)
> 타일셋: `tiles/terrain_tileset.tres` · 텍스처: `assets/tiles/<지형>_hex.svg`

맵 타일의 종류와 **이동 규칙**을 데이터로 정의한다. 각 지형은 타일셋의 `sources/<id>`에 대응하며, 모두 단일 타일이라 atlas 좌표는 `(0,0)`(`Terrain.ATLAS`)로 같다.

## 지형 목록

| id | 상수 | 라벨 | 텍스처 | 이동 |
| --- | --- | --- | --- | --- |
| 0 | `GRASS` | 초원 | `grass_hex.svg` | 기본 (이동력 그대로) |
| 1 | `FOREST` | 숲 | `forest_hex.svg` | 이동력 **1/2 올림**(`ceil`) |
| 2 | `SWAMP` | 습지 | `swamp_hex.svg` | 이동력 **1/2 내림**(`floor`) |
| 3 | `MOUNTAIN` | 산 | `mountain_hex.svg` | **진입·통과 불가** |
| 4 | `DESERT` | 사막 | `desert_hex.svg` | 기본 (이동력 그대로) |
| 5 | `STONE` | 돌 | `stone_hex.svg` | 기본 (채석장 지형) |
| 6 | `ANIMAL` | 동물 | `animal_hex.svg` | 기본 (사냥터 지형) |
| 7 | `WATER` | 물가 | `water_hex.svg` | 기본 (낚시터 지형 — 항해 규칙은 후속, 현재 통행 가능) |
| 8 | `IRON_VEIN` | 철맥 | `iron_vein_hex.svg` | 기본 (철광 지형) |
| 9 | `GOLD_VEIN` | 금맥 | `gold_vein_hex.svg` | 기본 (금광 지형) |
| 10 | `SILVER_VEIN` | 은맥 | `silver_vein_hex.svg` | 기본 (은광 지형) |

> id 5~10은 [1차 생산 건물](../features/production.md)의 `buildable_terrains` 대상(슬라이스 2). 텍스처는 임시 플레이스홀더 SVG. 전부 통행 가능·기본 이동(산만 예외).

## 이동 규칙 (`move_cap`)

**목적지 지형이 이동력을 반감**하는 모델. `move_cap(source_id, movement)`는 그 지형 칸에서 이동을 끝낼 수 있는 최대 헥스 거리를 준다.

- 초원·사막: `movement` 그대로.
- 숲: `ceil(movement/2)` — 예) 이동력 3 → 2, 2 → 1, 1 → 1.
- 습지: `floor(movement/2)` — 예) 이동력 3 → 1, 2 → 1, **1 → 0**(진입 불가).
- 산: `-1`(도달 불가). 추가로 `is_passable(MOUNTAIN) = false`이며 `IMPASSABLE = [MOUNTAIN]`로 BFS **통과**도 막는다.
- **미도색 셀**(`get_cell_source_id` = -1)은 초원으로 취급한다.

> 경로 비용은 균일(칸당 거리 1)하고, **도착 칸의 지형만** 이동 상한에 영향을 준다. 산만 예외적으로 통과 자체를 막는다.
> 시야(`HexGrid.cells_within`)는 지형에 막히지 않는다 — 이동 BFS에만 `IMPASSABLE`을 넘긴다.

## API

| 함수 | 설명 |
| --- | --- |
| `move_cap(source_id, movement) -> int` | 그 지형 칸까지 갈 수 있는 최대 헥스 거리(-1 = 도달 불가) |
| `is_passable(source_id) -> bool` | 진입 가능 여부(산만 `false`) |
| `label(source_id) -> String` | 지형 라벨(알 수 없는 id는 "초원") |
| `IMPASSABLE` | 이동 BFS 통과 불가 지형 id 목록(`[MOUNTAIN]`) |
| `ATLAS` | 모든 지형 타일의 atlas 좌표 `(0,0)` |

## 테스트

- `test/unit/test_terrain.gd` — `move_cap`(초원/사막/숲 ceil/습지 floor/산/미도색)·`is_passable`·`label`.
- `test/unit/test_hex_grid.gd` — 산 통과 불가·숲/습지 이동 상한이 `movement_ranges`에 반영되는지, 시야는 산에 안 막히는지.

## 미구현 / TODO

- **맵 생성기**: 현재는 시작 지점 근처에 방향별 소규모 덩어리(서=숲·동=습지·북=사막·남=산 + 1차 생산 지형 6종 흩뿌림)만 고정 배치([map-and-camera.md](../features/map-and-camera.md)). 맵 전역 절차적 생성·바이옴 규칙은 미구현.
- **시야 차단**: 산이 시야를 가리는 규칙은 없음(이동만 막는다).
- **자원/생산 연계**: 지형별 자원 산출·건설 가능 지형 제한 등은 미구현.
