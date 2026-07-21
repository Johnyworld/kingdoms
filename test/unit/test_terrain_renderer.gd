extends GutTest
## TerrainRenderer: 보이지 않는 데이터 레이어(지형타입=source id)를 읽어
## LaPetiteTile 오토타일 비주얼 레이어 스택에 올바른 레이어로 그리는지 검증한다.
## 오토타일 결과 atlas 좌표는 엔진 소관이라, "어느 레이어에 칠해졌는가"만 확인한다.

const TILESETS := {
	"ocean": "res://assets/tiles/lapetite/Tilesets/Tileset_Ocean.tres",
	"waves": "res://assets/tiles/lapetite/Tilesets/Tileset_WavesAnimation.tres",
	"sandshore": "res://assets/tiles/lapetite/Tilesets/Tileset_SandShore.tres",
	"ground": "res://assets/tiles/lapetite/Tilesets/Tileset_Ground.tres",
	"overlay": "res://assets/tiles/lapetite/Tilesets/Tileset_GroundOverlay.tres",
	"grass": "res://assets/tiles/lapetite/Tilesets/Tileset_Grass.tres",
	"cliff": "res://assets/tiles/lapetite/Tilesets/Tileset_Cliff.tres",
}
const W := 8
const H := 8

var _data: TileMapLayer
var _layers: Dictionary
var _renderer: TerrainRenderer

func before_each() -> void:
	_data = TileMapLayer.new()
	_data.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(_data)
	_layers = {}
	for key in TILESETS:
		var l := TileMapLayer.new()
		l.tile_set = load(TILESETS[key])
		add_child_autofree(l)
		_layers[key] = l
	_renderer = TerrainRenderer.new(_layers)

## 전 칸 초원 + 물 덩어리(좌상)·산 덩어리(우상)를 두고 렌더한 뒤 레이어 배정을 본다.
func _paint_sample() -> Dictionary:
	for y in H:
		for x in W:
			_data.set_cell(Vector2i(x, y), Terrain.PLAINS, Terrain.ATLAS)
	var water := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
	var mountain := [Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 2)]
	for c in water:
		_data.set_cell(c, Terrain.WATER, Terrain.ATLAS)
	for c in mountain:
		_data.set_cell(c, Terrain.MOUNTAIN, Terrain.ATLAS)
	_renderer.repaint(_data, W, H)
	return {"water": water, "mountain": mountain}

func test_water_goes_to_ocean_not_ground() -> void:
	var s := _paint_sample()
	var ocean: Array = _layers["ocean"].get_used_cells()
	var ground: Array = _layers["ground"].get_used_cells()
	for c in s["water"]:
		assert_true(c in ocean, "물 칸은 Ocean 레이어에: %s" % c)
		assert_false(c in ground, "물 칸은 Ground 레이어에 없음: %s" % c)

func test_mountain_paints_ground_and_cliff() -> void:
	var s := _paint_sample()
	var ground: Array = _layers["ground"].get_used_cells()
	var cliff: Array = _layers["cliff"].get_used_cells()
	for c in s["mountain"]:
		assert_true(c in ground, "산 칸은 Ground(바위)에: %s" % c)
		assert_true(c in cliff, "산 칸은 Cliff 레이어에: %s" % c)

func test_plains_paints_ground_and_grass() -> void:
	_paint_sample()
	var ground: Array = _layers["ground"].get_used_cells()
	var grass: Array = _layers["grass"].get_used_cells()
	var plains := Vector2i(4, 5)   # 표본에서 초원인 칸
	assert_true(plains in ground, "초원 칸은 Ground에")
	assert_true(plains in grass, "초원 칸은 Grass(잔디)에")

func test_vein_and_unknown_render_as_plains() -> void:
	# 철맥·금맥은 초원(Ground+Grass)으로 렌더, 미지정 id(-1)도 default=초원.
	for y in H:
		for x in W:
			_data.set_cell(Vector2i(x, y), Terrain.PLAINS, Terrain.ATLAS)
	_data.set_cell(Vector2i(1, 1), Terrain.IRON_VEIN, Terrain.ATLAS)
	_data.set_cell(Vector2i(2, 1), Terrain.GOLD_VEIN, Terrain.ATLAS)
	_data.erase_cell(Vector2i(3, 1))   # 미도색(-1)
	_renderer.repaint(_data, W, H)
	var ground: Array = _layers["ground"].get_used_cells()
	var grass: Array = _layers["grass"].get_used_cells()
	for c in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		assert_true(c in ground, "철맥·금맥·미도색은 초원처럼 Ground에: %s" % c)
		assert_true(c in grass, "철맥·금맥·미도색은 초원처럼 Grass에: %s" % c)
	assert_eq(_layers["ocean"].get_used_cells().size(), 0, "물 없음 → Ocean 비움")

func test_repaint_clears_previous() -> void:
	_paint_sample()
	# 전부 초원으로 덮어쓰고 다시 그리면 Ocean/Cliff는 비어야 한다.
	for y in H:
		for x in W:
			_data.set_cell(Vector2i(x, y), Terrain.PLAINS, Terrain.ATLAS)
	_renderer.repaint(_data, W, H)
	assert_eq(_layers["ocean"].get_used_cells().size(), 0, "물 없으면 Ocean 비움")
	assert_eq(_layers["cliff"].get_used_cells().size(), 0, "산 없으면 Cliff 비움")
