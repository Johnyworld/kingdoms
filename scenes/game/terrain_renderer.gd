class_name TerrainRenderer
extends RefCounted
## 지형 데이터/렌더 분리의 렌더 절반.
## 보이지 않는 데이터 레이어(TerrainLayer)의 지형타입(source id)을 읽어,
## LaPetiteTile 오토타일 비주얼 레이어 스택에 그린다. → scenes/game/terrain.gd
##
## 각 지형타입은 한 개 이상의 (레이어, terrain_set, terrain_id) 페인트 지시로 매핑된다.
## 오토타일(코너 매칭, mode 1)이라 같은 (레이어, set, terrain)의 셀을 모아 한 번에
## set_cells_terrain_connect 하면 경계가 매끄럽게 이어진다.
##
## LaPetiteTile terrain_set/terrain 인덱스:
## - Ground:     set0 t1=GroundGrass1 · set2 t0=GroundRock1
## - Grass:      set0 t1=Grass_Light · t2=Grass_Dark
## - Overlay:    set0 t0=SandTile · t4=SwampOverlay
## - Cliff:      set0 t0=CliffRock
## - Ocean:      set0 t0=Shallow
## - Waves:      set0 t0=Waves
## - Decoration(Tileset_Elements): set0 t1=Tree_Pines(숲) · set1 t0=Mountain_Basic(산)

# 지형타입 → 페인트 지시 목록. 각 지시 = [layer_key, terrain_set, terrain_id].
const PAINT := {
	Terrain.PLAINS:    [["ground", 0, 1], ["grass", 0, 1]],
	Terrain.FOREST:    [["ground", 0, 1], ["grass", 0, 2], ["decoration", 0, 1]],   # 잔디 + 소나무 숲
	Terrain.SWAMP:     [["ground", 0, 1], ["overlay", 0, 4]],
	Terrain.DESERT:    [["ground", 0, 1], ["overlay", 0, 0]],
	Terrain.MOUNTAIN:  [["ground", 2, 0], ["cliff", 0, 0], ["decoration", 1, 0]],   # 바위 + 산봉우리
	Terrain.WATER:     [["ocean", 0, 0], ["waves", 0, 0]],
	Terrain.IRON_VEIN: [["ground", 0, 1], ["grass", 0, 1]],   # 아이콘/deposit 분리는 별도 슬라이스 (초원으로 렌더)
	Terrain.GOLD_VEIN: [["ground", 0, 1], ["grass", 0, 1]],
}

var _layers: Dictionary   # layer_key(String) -> TileMapLayer

func _init(layers: Dictionary) -> void:
	_layers = layers

## 데이터 레이어의 [0,map_w) x [0,map_h) 전 칸을 읽어 비주얼 레이어를 전부 다시 그린다.
func repaint(data: TileMapLayer, map_w: int, map_h: int) -> void:
	for layer in _layers.values():
		layer.clear()

	# (layer_key, set, terrain) → 셀 목록으로 묶는다(오토타일을 그룹당 1회 호출).
	var buckets := {}
	for y in map_h:
		for x in map_w:
			var cell := Vector2i(x, y)
			# 미도색(-1)·미지정 지형은 초원으로 렌더(단일 진실 원천 = PAINT[PLAINS]).
			var ops: Array = PAINT.get(data.get_cell_source_id(cell), PAINT[Terrain.PLAINS])
			for op in ops:
				var key: String = "%s|%d|%d" % op
				if not buckets.has(key):
					buckets[key] = {"layer": op[0], "set": op[1], "terrain": op[2], "cells": ([] as Array[Vector2i])}
				buckets[key]["cells"].append(cell)

	for b in buckets.values():
		var layer: TileMapLayer = _layers[b["layer"]]
		layer.set_cells_terrain_connect(b["cells"], b["set"], b["terrain"])
