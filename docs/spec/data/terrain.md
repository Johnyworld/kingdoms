# Data: Terrain (지형)

> 카탈로그(게임 규칙): `scenes/game/terrain.gd` (`class_name Terrain`, `extends RefCounted`)
> 렌더: `scenes/game/terrain_renderer.gd` (`class_name TerrainRenderer`)

맵 타일의 종류와 **이동 규칙**을 데이터로 정의한다.

## 데이터/렌더 분리

지형은 **데이터**와 **렌더**를 분리한다.

- **데이터 레이어** — `game.tscn`의 `TerrainLayer`(보이지 않는 `TileMapLayer`, `visible = false`). 각 칸의 **지형 타입을 source id로** 보관한다(`tiles/terrain_tileset.tres`, 모두 atlas `(0,0)` = `Terrain.ATLAS`). BFS·이동·시야·건설 판정과 좌표 지오메트리(`map_to_local`/`get_surrounding_cells`)의 **단일 기준**. 헥스 지오메트리는 비주얼과 맞추기 위해 `tile_size = (16, 16)`.
- **비주얼 레이어 스택** — `game.tscn`의 `TerrainVisual`(nearest 필터, `texture_filter = 1`) 아래 [LaPetiteTile Maps](https://studio-garrigue.itch.io/la-petite-tile-maps) 오토타일(코너 매칭) 레이어들. `TerrainRenderer`가 데이터 레이어를 읽어 타입별로 `set_cells_terrain_connect`로 그린다. 지형 경계가 매끄럽게 이어진다. 픽셀아트는 정수배 줌 + nearest로 선명하게 렌더.
- 에셋 원본: `assets/tiles/lapetite/` (텍스처 + 타일셋 `.tres`, 16×16 헥스). 라이선스: 상업적 사용 허용·재배포 금지.

## 지형 목록

| id | 상수 | 라벨 | 이동 | 비주얼 렌더(레이어·terrain) |
| --- | --- | --- | --- | --- |
| 0 | `PLAINS` | 초원 | 기본 (이동력 그대로) | Ground=GroundGrass + Grass=Light + 성긴 덤불 산재(Decoration Tree_Bush) |
| 1 | `FOREST` | 숲 | 이동력 **1/2 올림**(`ceil`) | Ground=GroundGrass + Grass=Dark + Decoration=Tree_Pines |
| 2 | `SWAMP` | 습지 | 이동력 **1/2 내림**(`floor`) | Ground=GroundGrass + GroundOverlay=Swamp |
| 3 | `MOUNTAIN` | 산 | **진입·통과 불가** | Ground=GroundRock + Cliff=CliffRock + Decoration=Mountain_Basic |
| 4 | `DESERT` | 사막 | 기본 (이동력 그대로) | Ground=GroundGrass + GroundOverlay=SandTile |
| 7 | `WATER` | 물 | **진입·통과 불가** | Ocean=Shallow + Waves |
| 8 | `IRON_VEIN` | 철맥 | 기본 (철광 지형) | Ground=Grass + Decoration=Mountain_Basic (회색 바위 노두) |
| 9 | `GOLD_VEIN` | 금맥 | 기본 (금광 지형) | Ground=Grass + Decoration=Mountain_SandDune (노란 사구) |

> **생산 지형**은 **초원(농장·식량)·숲(벌목소·목재)·철맥(철광)·금맥(금광)** 넷([production.md](../features/production.md)의 `buildable_terrains` 대상). 철맥·금맥은 초원 위에 **바위 노두(철맥=회색, 금맥=노란 사구)** 표식을 얹어 광산 자리를 한눈에 보이게 한다(통행은 가능 — 표식은 Decoration 장식일 뿐 이동/판정에 영향 없음).
> **남은 id는 재번호하지 않는다**(철맥 8·금맥 9 유지 — 타일셋 참조 안정). id 5·6·10은 공백(제거된 돌·동물·은맥). 데이터 타일셋의 옛 SVG 소스는 보이지 않는 레이어라 렌더에 안 쓰이며 **미사용**으로 남는다(에셋 정리는 후속).

## 이동 규칙 (`move_cap`)

**목적지 지형이 이동력을 반감**하는 모델. `move_cap(source_id, movement)`는 그 지형 칸에서 이동을 끝낼 수 있는 최대 헥스 거리를 준다.

- 초원·사막: `movement` 그대로.
- 숲: `ceil(movement/2)` — 예) 이동력 3 → 2, 2 → 1, 1 → 1.
- 습지: `floor(movement/2)` — 예) 이동력 3 → 1, 2 → 1, **1 → 0**(진입 불가).
- 산·물: `-1`(도달 불가). `is_passable = false`이며 `IMPASSABLE = [MOUNTAIN, WATER]`로 BFS **통과**도 막는다.
- **미도색 셀**(`get_cell_source_id` = -1)은 초원으로 취급한다.

> 경로 비용은 균일(칸당 거리 1)하고, **도착 칸의 지형만** 이동 상한에 영향을 준다. 산·물만 통과 자체를 막는다.
> 시야(`HexGrid.cells_within`)는 지형에 막히지 않는다 — 이동 BFS에만 `IMPASSABLE`을 넘긴다.

## API

| 함수 / 상수 | 설명 |
| --- | --- |
| `move_cap(source_id, movement) -> int` | 그 지형 칸까지 갈 수 있는 최대 헥스 거리(-1 = 도달 불가) |
| `is_passable(source_id) -> bool` | 진입 가능 여부(산·물만 `false`) |
| `label(source_id) -> String` | 지형 라벨(알 수 없는 id는 "초원") |
| `IMPASSABLE` | 이동 BFS 통과 불가 지형 id 목록(`[MOUNTAIN, WATER]`) |
| `ATLAS` | 데이터 레이어 타일의 atlas 좌표 `(0,0)` |
| `TerrainRenderer.new(layers).repaint(data, w, h)` | 데이터 레이어를 읽어 비주얼 레이어 스택 전체를 다시 그림 |

## 테스트

- `test/unit/test_terrain.gd` — `move_cap`(초원/사막/숲 ceil/습지 floor/산·물)·`is_passable`·`label`·`IMPASSABLE`.
- `test/unit/test_terrain_renderer.gd` — 데이터 타입이 올바른 비주얼 레이어로 그려지는지(물→Ocean, 산→Ground+Cliff, 초원→Ground+Grass), repaint가 이전 그림을 지우는지.
- `test/unit/test_hex_grid.gd` — 산 통과 불가·숲/습지 이동 상한이 `movement_ranges`에 반영되는지, 시야는 산에 안 막히는지(데이터 레이어 16×16 헥스 위상 동일 → 반경 셀 수 7/19/37 불변).

## 미구현 / TODO (후속 슬라이스)

- **장식**: 숲=나무(Decoration set0 Tree_Pines)·산=산봉우리(set1 Mountain_Basic)·초원=성긴 덤불 산재(set0 Tree_Bush, 결정적 해시 ~1/11)·철맥·금맥=바위 표식 완료. 도로·성벽은 미구현(도로/성벽 지형 개념 자체가 게임에 없음).
- **철맥·금맥 deposit 데이터 분리**: 현재는 초원 위에 Decoration 바위/사구 **표식**을 얹어 렌더(구현됨). base 지형과 자원 deposit을 별개 데이터로 완전 분리하는 것은 후속.
- **해안 전환(SandShore)**: 물↔육지 경계 SandShore 레이어는 씬에 두었으나 아직 미도색.
- **옛 SVG 타일 제거**: 데이터 레이어가 참조하는 `assets/tiles/*_hex.svg`는 렌더에 안 쓰이나 아직 남아 있다.
- **맵 생성기**: 시작 지점 근처 방향별 소규모 덩어리(서=숲·동=습지·북=사막·남=산·남동=호수 + 철맥·금맥) 고정 배치만. 절차적 생성·바이옴은 미구현.
- **시야 차단**: 산·물이 시야를 가리는 규칙 없음(이동만 막는다).
