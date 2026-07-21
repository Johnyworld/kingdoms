class_name BuildingRenderer
extends RefCounted
## 거점 건물(캠프·마을회관·성)을 LaPetiteTile 건물 오토타일(Tileset_Elements terrain_set 2)로
## 그릴 때, 세력·티어에 맞는 terrain 인덱스를 고른다. 실제 페인팅은 Building._refresh_body가 한다.
##
## 세력별 색 변형(마을/성 쌍): 4세력 = 4색.
## - 푸른 왕국  → White&Terracotta (마을 0 / 성 5)
## - 초원 칸국  → Wood            (마을 2 / 성 6)
## - 암흑 제국  → Gray&Slate      (마을 3 / 성 7)
## - 사막 술탄국 → White&Slate     (마을 4 / 성 8)
## 티어/형태: 성 → 성(castle), 그 외(캠프·마을회관·농장·집·벌목소·광산) → 마을(village).
## 거점(footprint 7)은 큰 마을/성, 소형 건물(footprint 1)은 같은 마을 테라인이 1칸이라 작은 집으로 그려진다.

const TERRAIN_SET := 2   # Tileset_Elements의 건물 terrain_set

const VARIANTS := {
	"푸른 왕국":   {"village": 0, "castle": 5},
	"초원 칸국":   {"village": 2, "castle": 6},
	"암흑 제국":   {"village": 3, "castle": 7},
	"사막 술탄국": {"village": 4, "castle": 8},
}
const _DEFAULT_VARIANT := {"village": 0, "castle": 5}   # 무소속/미지정 → 흰&테라코타

## 건물의 세력색 terrain 인덱스. 성만 castle, 나머지는 village(1칸이면 작은 집으로 렌더).
static func terrain_index(building_type: String, faction_name: String) -> int:
	var v: Dictionary = VARIANTS.get(faction_name, _DEFAULT_VARIANT)
	return v["castle"] if building_type == "castle" else v["village"]

## 티어별 렌더 칸 수(footprint 중 앞에서부터 n칸만 칠해 크기를 차등).
## 캠프=작은 마을(3칸), 마을회관·성=풀(footprint 전체). 소형 건물(footprint 1)은 그대로 1칸.
const RENDER_CELL_COUNT := {"camp": 3}

## 실제로 오토타일을 칠할 셀(footprint 앞에서부터 티어별 개수만). 순서는 [중심 + 이웃…].
static func render_cells(building_type: String, cells: Array) -> Array:
	var n: int = mini(RENDER_CELL_COUNT.get(building_type, cells.size()), cells.size())
	var out: Array[Vector2i] = []
	for i in n:
		out.append(cells[i])
	return out
