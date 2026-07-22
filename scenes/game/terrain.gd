class_name Terrain
extends RefCounted
## 지형(타일) 카탈로그. 각 지형의 타입 id·라벨·이동 규칙을 데이터로 정의한다.
##
## 지형 타입은 **보이지 않는 데이터 레이어**(TerrainLayer)의 source id로 보관한다
## (terrain_tileset.tres, 모두 atlas (0,0)). 실제 맵 그림은 TerrainRenderer가 이 데이터를 읽어
## LaPetiteTile 오토타일 비주얼 레이어 스택에 그린다. → scenes/game/terrain_renderer.gd
##
## 이동 규칙(칸마다 진입비용 누적):
## - 지나는 칸마다 그 칸의 진입비용(enter_cost)을 이동력에서 소모한다(가중 BFS). → scenes/game/hex_grid.gd
## - 산·물은 진입 불가(비용 BLOCKED). BFS 통과도 막는다.
## - 도시 건물·거점 칸은 지형 대신 건물 통행비용이 우선한다(건물 발자국). → scenes/building/build_planner.gd

const PLAINS := 0    # 초원 — 기본 이동 (농장·식량)
const FOREST := 1    # 숲 — 이동력 1/2(올림) (벌목소·목재)
const SWAMP := 2     # 습지 — 이동력 1/2(내림)
const MOUNTAIN := 3  # 산 — 이동 불가
const DESERT := 4    # 사막 — 기본 이동
const WATER := 7     # 물 — 이동 불가
# 생산 지형. 통행 가능·기본 이동. 자원 4종 축소로 철맥·금맥만 유지.
# id는 재번호하지 않는다(데이터 레이어 타일셋 참조 안정) — 그래서 5·6·10 공백. → docs/spec/data/terrain.md
const IRON_VEIN := 8    # 철맥 — 철광
const GOLD_VEIN := 9    # 금맥 — 금광

# 데이터 레이어 타일은 모두 단일 타일이라 atlas 좌표가 같다(set_cell용).
const ATLAS := Vector2i(0, 0)

const CATALOG := {
	PLAINS: {"label": "초원"},
	FOREST: {"label": "숲"},
	SWAMP: {"label": "습지"},
	MOUNTAIN: {"label": "산"},
	DESERT: {"label": "사막"},
	WATER: {"label": "물"},
	IRON_VEIN: {"label": "철맥"},
	GOLD_VEIN: {"label": "금맥"},
}

## 이동 BFS가 통과할 수 없는 지형의 타입 id 목록(산·물). movement_ranges가 넘긴다.
const IMPASSABLE := [MOUNTAIN, WATER]

## 지형 라벨. 알 수 없는 id(미도색 -1 포함)는 "초원"으로 취급한다.
static func label(source_id: int) -> String:
	return CATALOG.get(source_id, CATALOG[PLAINS])["label"]

## 진입 가능 여부. IMPASSABLE(산·물) 목록을 단일 기준으로 판정한다.
static func is_passable(source_id: int) -> bool:
	return not IMPASSABLE.has(source_id)

## 진입 불가 칸의 비용 표식(enter_cost 반환값). 가중 BFS가 이 값이면 진입 자체를 막는다.
const BLOCKED := -1

## 이 지형 칸에 진입하는 데 드는 이동력 비용(칸마다 누적).
## - 초원·사막·철맥·금맥: 1, 숲: 2, 습지: 3. 산·물: BLOCKED(진입 불가).
## - 미도색 셀(source id -1)은 초원(1)으로 취급한다.
static func enter_cost(source_id: int) -> int:
	match source_id:
		FOREST:
			return 2
		SWAMP:
			return 3
		MOUNTAIN, WATER:
			return BLOCKED
		_:
			return 1
