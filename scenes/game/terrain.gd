class_name Terrain
extends RefCounted
## 지형(타일) 카탈로그. 각 지형의 타일셋 source id·라벨·이동 규칙을 데이터로 정의한다.
## 타일 텍스처는 terrain_tileset.tres의 sources/<id>에 대응한다(모두 atlas (0,0)).
##
## 이동 규칙(목적지 지형이 이동력을 반감):
## - 도착 칸의 지형에 따라, 그 칸까지 갈 수 있는 최대 헥스 거리(이동력)가 정해진다.
## - 산은 진입·통과 불가(도달 거리 -1). BFS 통과도 막는다.

const GRASS := 0     # 초원 — 기본 (농장·식량)
const FOREST := 1    # 숲 — 이동력 1/2(올림) (벌목소·목재)
const SWAMP := 2     # 습지 — 이동력 1/2(내림)
const MOUNTAIN := 3  # 산 — 이동 불가
const DESERT := 4    # 사막 — 기본
# 생산 지형. 통행 가능·기본 이동. 자원 4종 축소로 철맥·금맥만 유지(돌·동물·물가·은맥 제거).
# id는 재번호하지 않는다(타일셋 참조 안정) — 그래서 5~7·10 공백. → docs/spec/data/terrain.md
const IRON_VEIN := 8    # 철맥 — 철광
const GOLD_VEIN := 9    # 금맥 — 금광

# 타일셋 소스는 모두 단일 타일이라 atlas 좌표가 같다.
const ATLAS := Vector2i(0, 0)

const CATALOG := {
	GRASS: {"label": "초원"},
	FOREST: {"label": "숲"},
	SWAMP: {"label": "습지"},
	MOUNTAIN: {"label": "산"},
	DESERT: {"label": "사막"},
	IRON_VEIN: {"label": "철맥"},
	GOLD_VEIN: {"label": "금맥"},
}

## 이동 BFS가 통과할 수 없는 지형의 source id 목록(산). movement_ranges가 넘긴다.
const IMPASSABLE := [MOUNTAIN]

## 지형 라벨. 알 수 없는 id(미도색 -1 포함)는 "초원"으로 취급한다.
static func label(source_id: int) -> String:
	return CATALOG.get(source_id, CATALOG[GRASS])["label"]

## 진입 가능 여부. IMPASSABLE(산) 목록을 단일 기준으로 판정한다.
static func is_passable(source_id: int) -> bool:
	return not IMPASSABLE.has(source_id)

## full 이동력 기준, 이 지형 칸에서 이동을 끝낼 수 있는 최대 헥스 거리.
## - 숲: ceil(이동력/2), 습지: floor(이동력/2), 산: -1(도달 불가), 그 외: 이동력 그대로.
## - 미도색 셀(source id -1)은 초원으로 취급한다.
static func move_cap(source_id: int, movement: int) -> int:
	match source_id:
		FOREST:
			return int(ceil(movement / 2.0))
		SWAMP:
			return movement / 2   # 정수 나눗셈 = 내림
		MOUNTAIN:
			return -1
		_:
			return movement
