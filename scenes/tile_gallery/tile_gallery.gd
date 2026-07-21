extends Node2D
## 타일 보기 — LaPetiteTile 팩의 타일/스프라이트를 빠짐없이 훑어보는 읽기 전용 화면.
## 런타임 열거: 모든 터레인 타일셋의 전 terrain(오토타일 스와치) + 스탠드얼론 폴더의 전 png(스프라이트 썸네일).
## 게임에서 실제로 쓰는 지형·건물은 별도 섹션에서 실제 렌더(TerrainRenderer.PAINT·BuildingRenderer)로 보여준다.
## 카메라: WASD/드래그/두 손가락 스크롤 이동, 휠/핀치 줌. ESC·뒤로 버튼으로 타이틀.

const TS_DIR := "res://assets/tiles/lapetite/Tilesets/"
const SPRITE_ROOT := "res://assets/tiles/lapetite/Textures/"

# 열거할 터레인 타일셋(파일명). 아래→위 순서(게임 지형 섹션의 레이어 겹침에 영향).
const ALL_TILESETS := [
	"Tileset_Ocean", "Tileset_OceanOverlay", "Tileset_WavesAnimation", "Tileset_SandShore",
	"Tileset_Ground", "Tileset_GroundOverlay", "Tileset_Grass", "Tileset_Cliff",
	"Tileset_Roads", "Tileset_Rock", "Tileset_Pattern",
	"Tileset_Elements", "Tileset_Elements_RampartsBack", "Tileset_Elements_RampartsFront",
]
# 게임 지형 PAINT의 layer_key → 타일셋명.
const PAINT_KEY_TS := {
	"ocean": "Tileset_Ocean", "waves": "Tileset_WavesAnimation",
	"ground": "Tileset_Ground", "overlay": "Tileset_GroundOverlay", "grass": "Tileset_Grass",
	"cliff": "Tileset_Cliff", "decoration": "Tileset_Elements",
}
# 스프라이트 폴더(Textures 하위). 재귀로 png 전부 나열.
const SPRITE_FOLDERS := [
	"Standalone_Buildings", "Standalone_Vegetation", "Standalone_Rocks",
	"Standalone_Creatures", "Ship", "Icons", "Parchment&WindRoses",
]

const GAME_TERRAINS := [
	Terrain.PLAINS, Terrain.FOREST, Terrain.SWAMP, Terrain.DESERT,
	Terrain.MOUNTAIN, Terrain.WATER, Terrain.IRON_VEIN, Terrain.GOLD_VEIN,
]
const GAME_BUILDINGS := ["camp", "town_hall", "castle"]

const SWATCH := 3        # 오토타일 스와치 블록 크기(셀)
const COLS := 8
const COL_PITCH := 5
const ROW_PITCH := 5
const SPRITE_PX := 42.0   # 스프라이트 썸네일 최대 변(월드 px)

const CAM_SPEED := 900.0
const ZOOM_MIN := 0.1
const ZOOM_MAX := 2.0
const PAN_GESTURE_SPEED := 1.5

var _layers := {}     # 타일셋명 -> TileMapLayer
var _geom: TileMapLayer   # 좌표 기준 레이어(Ground)
var _zoom := 0.6
var _row := 0
var _col := 0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	for tsname in ALL_TILESETS:
		var ts_res: TileSet = load(TS_DIR + tsname + ".tres")
		if ts_res == null:
			push_warning("타일 보기: 타일셋 로드 실패 — %s (건너뜀)" % tsname)
			continue
		var layer := TileMapLayer.new()
		layer.tile_set = ts_res
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(layer)
		_layers[tsname] = layer
	$UI/BackButton.pressed.connect(_go_back)
	camera.zoom = Vector2.ONE / _zoom
	_geom = _layers.get("Tileset_Ground")
	if _geom == null:
		push_error("타일 보기: Tileset_Ground 로드 실패 — 갤러리 중단")
		return
	_build()

func _build() -> void:
	# 1) 게임에서 실제 쓰는 지형·건물(실제 렌더).
	_section("게임 지형 (실제 렌더)")
	for t in GAME_TERRAINS:
		_slot_game_terrain(t)
		_label(Terrain.label(t), false)
		_advance()
	_slot_river()   # 강 = 물 밑 + 땅 틈 기법(단일 타일 아님)
	_label("강 (물+땅틈)", false)
	_advance()
	_end_row()
	_section("게임 건물 (플레이어색)")
	for b in GAME_BUILDINGS:
		_slot_building(b)
		_label(b, false)
		_advance()
	_end_row()

	# 2) 모든 터레인 타일셋의 전 terrain.
	for tsname in ALL_TILESETS:
		if not _layers.has(tsname):
			continue   # 로드 실패로 건너뛴 타일셋
		var ts: TileSet = _layers[tsname].tile_set
		_section("%s (terrain %d세트)" % [tsname.replace("Tileset_", ""), ts.get_terrain_sets_count()])
		for s in ts.get_terrain_sets_count():
			for t in ts.get_terrains_count(s):
				_slot_raw(tsname, s, t)
				_label(ts.get_terrain_name(s, t), false)
				_advance()
		_end_row()

	# 3) 스탠드얼론 스프라이트 폴더 전부.
	for folder in SPRITE_FOLDERS:
		var pngs: Array[String] = []
		_list_pngs(SPRITE_ROOT + folder, pngs)
		pngs.sort()
		if pngs.is_empty():
			continue
		_section("%s — 스프라이트 %d개" % [folder, pngs.size()])
		for path in pngs:
			_slot_sprite(path)
			_advance()
		_end_row()

	# 진입 시 첫 섹션(상단)부터 보이도록.
	var vp := get_viewport().get_visible_rect().size
	camera.position = Vector2(_cell_world(Vector2i(COLS * COL_PITCH / 2, 0)).x, _cell_world(Vector2i(0, 0)).y + vp.y * 0.5 * _zoom)

# --- 레이아웃 커서 ---

func _origin() -> Vector2i:
	return Vector2i(_col * COL_PITCH, _row * ROW_PITCH)

func _advance() -> void:
	_col += 1
	if _col >= COLS:
		_col = 0
		_row += 1

func _end_row() -> void:
	if _col > 0:
		_row += 1
		_col = 0

func _section(title: String) -> void:
	_end_row()
	_label_at(title, Vector2i(0, _row * ROW_PITCH), true)
	_row += 1

func _cell_world(cell: Vector2i) -> Vector2:
	return _geom.map_to_local(cell)

func _block(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in SWATCH:
		for dx in SWATCH:
			cells.append(origin + Vector2i(dx, dy))
	return cells

# --- 슬롯(각 항목) ---

## 해당 타일셋 레이어에 오토타일 페인트(레이어 없으면 조용히 건너뜀 — 로드 실패 방어).
func _paint(tsname: String, cells: Array[Vector2i], terrain_set: int, terrain_id: int) -> void:
	if _layers.has(tsname):
		_layers[tsname].set_cells_terrain_connect(cells, terrain_set, terrain_id)

func _slot_game_terrain(t: int) -> void:
	var cells := _block(_origin())
	_paint("Tileset_Ground", cells, 0, 1)   # 초원 지면 밑칠
	for op in TerrainRenderer.PAINT[t]:
		_paint(PAINT_KEY_TS[op[0]], cells, op[1], op[2])

## 강 데모: 초원 블록에 물길(대각선) 틈을 내고 그 밑에 Ocean(물)을 깔아 강 기법을 보여준다.
## (강은 단일 타일이 아니라 "물 위에 땅을 칠하되 강 자리만 비우는" 다층 기법.)
func _slot_river() -> void:
	var origin := _origin()
	var water: Array[Vector2i] = [origin + Vector2i(2, 0), origin + Vector2i(1, 1), origin + Vector2i(0, 2)]
	var land: Array[Vector2i] = []
	for c in _block(origin):
		if not (c in water):
			land.append(c)
	_paint("Tileset_Ocean", _block(origin), 0, 0)   # 밑에 물 전체
	_paint("Tileset_Ground", land, 0, 1)            # 강 자리만 빼고 땅

func _slot_building(building_type: String) -> void:
	var cells := _block(_origin())
	_paint("Tileset_Ground", cells, 0, 1)
	_paint("Tileset_Elements", cells, BuildingRenderer.TERRAIN_SET, BuildingRenderer.terrain_index(building_type, "푸른 왕국"))

func _slot_raw(tsname: String, terrain_set: int, terrain_id: int) -> void:
	var cells := _block(_origin())
	# 건물/나무/오버레이 등은 초원 위에 얹어야 보인다. Ground/Ocean 계열은 자체가 배경.
	if not tsname.begins_with("Tileset_Ground") and tsname != "Tileset_Ocean":
		_paint("Tileset_Ground", cells, 0, 1)
	_paint(tsname, cells, terrain_set, terrain_id)

func _slot_sprite(path: String) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return   # 깨진/로드 실패 이미지는 건너뜀
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sz := tex.get_size()
	var s: float = SPRITE_PX / maxf(sz.x, sz.y) if maxf(sz.x, sz.y) > 0.0 else 1.0
	spr.scale = Vector2(s, s)
	# 슬롯 중앙(블록 중심)에 배치.
	spr.position = _cell_world(_origin() + Vector2i(1, 1))
	add_child(spr)

# --- 라벨 ---

func _label(text: String, is_header: bool) -> void:
	_label_at(text, _origin() + Vector2i(0, SWATCH), is_header)

func _label_at(text: String, cell: Vector2i, is_header: bool) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 7 if is_header else 4)
	if is_header:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	label.position = _cell_world(cell) + Vector2(-10, 1)
	add_child(label)

# --- 파일 열거 ---

func _list_pngs(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_list_pngs(dir_path + "/" + f, out)
		elif f.ends_with(".png"):
			out.append(dir_path + "/" + f)
		f = d.get_next()

# --- 카메라 ---

func _process(delta: float) -> void:
	var dir := Vector2(
		(1.0 if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) else 0.0),
		(1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
	)
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAM_SPEED * delta * _zoom

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_go_back()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom - 0.05)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom + 0.05)
	elif event is InputEventMagnifyGesture and event.factor > 0.0:
		_set_zoom(_zoom / event.factor)
	elif event is InputEventPanGesture:
		camera.position += event.delta * PAN_GESTURE_SPEED * _zoom
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		camera.position -= event.relative * _zoom

func _set_zoom(level: float) -> void:
	_zoom = clampf(level, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2.ONE / _zoom

func _go_back() -> void:
	SceneManager.change_scene("res://scenes/title/title.tscn")
