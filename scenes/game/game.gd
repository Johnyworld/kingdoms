extends Node2D
## 300x300 헥스 타일 맵(초원)을 그리고, 카메라를 중앙에 배치한다.
## 카메라는 WASD 또는 마우스를 화면 가장자리에 대면 상하좌우로 이동한다.

const MAP_WIDTH := 300
const MAP_HEIGHT := 300
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS := Vector2i(0, 0)

const CAM_SPEED := 900.0    # 픽셀/초
const EDGE_MARGIN := 24     # 마우스 가장자리 스크롤 감지 여백(px)

# 줌 배율(값이 작을수록 확대). 0.5 = 확대, 1 = 기본, 3 = 축소.
# Camera2D.zoom 은 값이 클수록 확대되므로 실제로는 (1 / 배율)로 변환해 적용한다.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.1

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var camera: Camera2D = $Camera2D
@onready var party = $Party
@onready var overlay = $RangeOverlay
@onready var building = $Building
@onready var camp_menu = $CampMenu
@onready var fog = $Fog
@onready var turn_hud = $TurnHud
@onready var build_preview = $BuildPreview
@onready var party_info = $PartyInfo

var _min_pos: Vector2
var _max_pos: Vector2
var _zoom_level := 1.0

# 현재 도달 가능한 셀 → 시작점으로부터의 거리. 클릭 이동 판정에 사용.
var _reachable: Dictionary = {}
# 주인공이 선택되었는지. 선택 상태에서만 범위 표시 + 이동이 가능하다.
var _selected := false

# 턴 진행. 턴 종료 시 유닛 이동 리셋 + 영지 자원 수입.
var _turn := TurnManager.new()
var _units: Array = []          # 턴당 1회 이동하는 부대(주인공 부대 등).
var _territories: Array = []    # 자원 수입을 받는 영지.
var _buildings: Array = []      # 맵의 모든 건물(캠프 + 건설된 농장). 겹침 검사·추적용.

# 건설 모드. 캠프 메뉴에서 건물을 고르면 진입 — 맵을 클릭해 배치한다.
var _build_mode := false
var _build_type := ""
var _build_territory: Territory = null

func _ready() -> void:
	_generate_map()
	_center_camera()
	overlay.setup(terrain)
	build_preview.setup(terrain)
	building.setup(terrain, Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2), BuildingTypes.CAMP)
	_buildings = [building]
	_setup_faction()
	_setup_party()
	_place_party()
	fog.setup(terrain, MAP_WIDTH, MAP_HEIGHT)
	_update_fog()
	_units = [party]
	turn_hud.set_turn(_turn.number)
	turn_hud.ended.connect(_on_turn_ended)
	camp_menu.build_selected.connect(_on_build_selected)

## 맵 전체를 초원 타일로 채운다.
func _generate_map() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			terrain.set_cell(Vector2i(x, y), GRASS_SOURCE_ID, GRASS_ATLAS)

	# 카메라 이동 범위(월드 좌표) 계산 — 맵 밖으로 벗어나지 않도록 클램프용.
	var corner_a := terrain.map_to_local(Vector2i(0, 0))
	var corner_b := terrain.map_to_local(Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1))
	_min_pos = Vector2(min(corner_a.x, corner_b.x), min(corner_a.y, corner_b.y))
	_max_pos = Vector2(max(corner_a.x, corner_b.x), max(corner_a.y, corner_b.y))

## 카메라를 맵 중앙 타일로 이동시킨다.
func _center_camera() -> void:
	var center_cell := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	camera.position = terrain.map_to_local(center_cell)
	camera.make_current()

## 시작 영지("파리")를 만들어 세력("프랑스")에 편입하고, 캠프 건물을 그 영지에 넣는다.
## 영지 초기 자원은 캠프 종류 카탈로그의 resources를 복사한다(인구 포함 7종).
func _setup_faction() -> void:
	var camp_spec := BuildingTypes.get_type(BuildingTypes.CAMP)
	var start_res: Dictionary = (camp_spec.get("resources", {}) as Dictionary).duplicate(true)
	var paris := Territory.new("파리", start_res)
	var france := Faction.new("프랑스", Color(0.2, 0.3, 0.8))
	france.add_territory(paris)
	paris.add_building(building)
	_territories = [paris]

## 주인공 부대의 멤버를 구성한다. 테스트맨(이동력 3) + 짐꾼(이동력 2).
## 부대 이동력은 멤버 중 최소값이라 이 구성에서는 2가 된다.
func _setup_party() -> void:
	var testman := Human.new("테스트맨")
	var porter := Human.new("짐꾼")
	porter.movement = 2
	party.add_member(testman)
	party.add_member(porter)

## 주인공 부대를 캠프 바로 아래(캠프 영역 밖) 타일에 배치한다.
func _place_party() -> void:
	var party_cell := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2 + 3)
	party.position = terrain.map_to_local(party_cell)

## 주인공 위치에서 이동력만큼 BFS로 도달 셀을 구하고, 범위를 갱신한다.
## 거리 1~이동력 = 이동 범위(파랑), 이동력+1 = 공격 범위(빨강).
func _update_ranges() -> void:
	var start := terrain.local_to_map(party.position)
	var ranges := HexGrid.movement_ranges(terrain, start, party.movement(), MAP_WIDTH, MAP_HEIGHT)
	var move_cells: Array[Vector2i] = ranges["move"]
	var attack_cells: Array[Vector2i] = ranges["attack"]
	_reachable = ranges["dist"]
	overlay.show_ranges(move_cells, attack_cells)

## 모든 시야원(주인공 + 캠프)을 합쳐 현재 시야 셀을 계산하고 안개를 갱신한다.
func _update_fog() -> void:
	var visible := {}
	var party_cell := terrain.local_to_map(party.position)
	for c in HexGrid.cells_within(terrain, party_cell, party.vision(), MAP_WIDTH, MAP_HEIGHT):
		visible[c] = true
	for c in HexGrid.cells_within(terrain, building.center_cell(), building.vision, MAP_WIDTH, MAP_HEIGHT):
		visible[c] = true
	fog.update_visible(visible)

## 좌클릭 처리.
## - 선택 안 됨: 주인공 칸을 클릭하면 선택한다.
## - 선택됨: 이동 범위 칸이면 이동, 그 외 칸이면 선택 해제한다.
func _handle_click(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(terrain.to_local(world_pos))
	var party_cell := terrain.local_to_map(party.position)

	# 건물(캠프) 클릭이 최우선: 선택·정보 패널을 닫고 캠프 메뉴를 연다.
	if building.contains_cell(cell):
		if _selected:
			_deselect()
		party_info.close()
		camp_menu.open(building)
		return

	# 부대 칸 클릭: 정보 패널은 항상 연다(이동 완료 부대 포함).
	# 아직 선택 전이고 이동 가능하면 함께 선택해 이동 범위도 표시한다.
	if cell == party_cell:
		party_info.open(party)
		if not _selected and party.can_move():
			_select()
		return

	# 그 외 칸 클릭: 선택 상태면 이동 범위 칸으로 이동. 이후 선택·정보 패널을 닫는다.
	if _selected and _reachable.has(cell) and _reachable[cell] >= 1 and _reachable[cell] <= party.movement():
		party.position = terrain.map_to_local(cell)
		party.mark_moved()   # 부대는 한 턴에 1회만 이동.
		_update_fog()
	_deselect()
	party_info.close()

## 주인공 부대를 선택하고 이동/공격 범위를 표시한다.
func _select() -> void:
	_selected = true
	party.set_selected(true)
	_update_ranges()

## 턴 종료: 번호 +1, 모든 유닛 이동 리셋, 모든 영지 자원 수입. 진행 중 선택은 해제한다.
func _on_turn_ended() -> void:
	if _selected:
		_deselect()
	party_info.close()
	_turn.end_turn(_units, _territories)
	turn_hud.set_turn(_turn.number)

## 선택을 해제하고 범위 표시를 지운다.
func _deselect() -> void:
	_selected = false
	party.set_selected(false)
	_reachable = {}
	var empty: Array[Vector2i] = []
	overlay.show_ranges(empty, empty)

## 캠프 메뉴에서 건물을 선택하면 건설 모드로 들어간다.
func _on_build_selected(type_id: String, territory: Territory) -> void:
	_build_mode = true
	_build_type = type_id
	_build_territory = territory
	build_preview.clear()

## 건설 모드를 끝내고 미리보기를 지운다.
func _exit_build_mode() -> void:
	_build_mode = false
	_build_type = ""
	_build_territory = null
	build_preview.clear()

## 현재 시야·점유를 기준으로 그 셀에 건물을 놓을 수 있는지.
func _can_build_at(cell: Vector2i) -> bool:
	var vision := BuildPlanner.territory_vision(terrain, _build_territory, MAP_WIDTH, MAP_HEIGHT)
	var occupied := BuildPlanner.occupied_cells(_buildings)
	return BuildPlanner.can_place(terrain, cell, MAP_WIDTH, MAP_HEIGHT, vision, occupied)

## 커서 아래의 맵 셀.
func _mouse_cell() -> Vector2i:
	return terrain.local_to_map(terrain.to_local(get_global_mouse_position()))

## 건설 모드 입력: 이동=미리보기, 좌클릭=배치, 우클릭/ESC=취소.
func _handle_build_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _mouse_cell()
		build_preview.show_preview(BuildPlanner.footprint(terrain, cell), _can_build_at(cell))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place(_mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_exit_build_mode()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_build_mode()

## 그 셀에 건물을 배치한다: 자원 차감 → 건설 중 건물 생성 → 영지 편입 → 건설 모드 종료.
## 배치 불가하거나 자원 부족이면 아무 일도 하지 않고 모드를 유지한다.
func _try_place(cell: Vector2i) -> void:
	if not _can_build_at(cell):
		return
	var cost: Dictionary = BuildingTypes.get_type(_build_type).get("build_cost", {})
	if not _build_territory.can_afford(cost):
		return
	_build_territory.spend(cost)
	var b := Building.new()
	add_child(b)
	b.setup(terrain, cell, _build_type, true)   # 건설 중으로 생성
	_build_territory.add_building(b)
	_buildings.append(b)
	_exit_build_mode()

## 마우스 휠로 줌 배율을 조절한다. 휠 위 = 확대, 휠 아래 = 축소.
func _unhandled_input(event: InputEvent) -> void:
	# 건설 모드에서는 배치 입력만 처리한다(일반 클릭·선택 차단).
	if _build_mode:
		_handle_build_input(event)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level - ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(get_global_mouse_position())

## 줌 배율을 [ZOOM_MIN, ZOOM_MAX] 범위로 클램프해 카메라에 적용한다.
func _set_zoom(level: float) -> void:
	_zoom_level = clampf(level, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2.ONE / _zoom_level

func _process(delta: float) -> void:
	var dir := Vector2.ZERO

	# 키보드 (WASD)
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0

	# 마우스 화면 가장자리
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var view_size := vp.get_visible_rect().size
	if mouse.x <= EDGE_MARGIN:
		dir.x -= 1.0
	elif mouse.x >= view_size.x - EDGE_MARGIN:
		dir.x += 1.0
	if mouse.y <= EDGE_MARGIN:
		dir.y -= 1.0
	elif mouse.y >= view_size.y - EDGE_MARGIN:
		dir.y += 1.0

	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAM_SPEED * delta
		camera.position.x = clampf(camera.position.x, _min_pos.x, _max_pos.x)
		camera.position.y = clampf(camera.position.y, _min_pos.y, _max_pos.y)
