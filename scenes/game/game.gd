extends Node2D
## 50x50 헥스 타일 맵(초원)을 그리고, 카메라를 중앙에 배치한다.
## 카메라는 WASD 또는 마우스를 화면 가장자리에 대면 상하좌우로 이동한다.

const MAP_WIDTH := 50
const MAP_HEIGHT := 50

const CAM_SPEED := 900.0    # 픽셀/초
const EDGE_MARGIN := 24     # 마우스 가장자리 스크롤 감지 여백(px)

# 줌 배율(값이 작을수록 확대). 0.5 = 확대, 1 = 기본, 3 = 축소.
# Camera2D.zoom 은 값이 클수록 확대되므로 실제로는 (1 / 배율)로 변환해 적용한다.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.1
const PAN_ZOOM_SPEED := 0.05   # 트랙패드 두 손가락 스크롤(PanGesture) delta.y → 줌 배율 계수

const PARTY_SCENE := preload("res://scenes/party/party.tscn")

# 부대 이동 애니메이션. 칸당 이동 시간(플레이어·NPC 공유) / 같은 세력 내 NPC 부대 시작 간격(스태거).
const MOVE_STEP_TIME := 0.12
const NPC_PARTY_STAGGER := 0.2

# NPC 부대 배치 오프셋(맵 중앙 기준 칸). 초기 시야 안에 들도록 임시 배치한다.
const NPC_OFFSETS := {
	"qasim": Vector2i(5, 0),
	"balthazar": Vector2i(0, -5),
	"batur": Vector2i(-7, 1),
}

# NPC 세력 거점(캠프) 배치 오프셋(맵 중앙 기준 칸). 각 부대와 같은 방향의 바깥쪽 —
# 초기 시야 밖이라 처음엔 안개에 가려지고, 플레이어가 다가가 발견하면 드러난다.
const NPC_BASE_OFFSETS := {
	"qasim": Vector2i(11, 0),      # 사막 술탄국 — 동
	"balthazar": Vector2i(0, -11), # 암흑 제국 — 북
	"batur": Vector2i(-12, 1),     # 초원 칸국 — 서
}

@onready var terrain: TileMapLayer = $TerrainLayer
@onready var camera: Camera2D = $Camera2D
@onready var party = $Party
@onready var overlay = $RangeOverlay
@onready var building = $Building
@onready var camp_menu = $CampMenu
@onready var fog = $Fog
@onready var turn_hud = $TurnHud
@onready var build_preview = $BuildPreview
@onready var build_area = $BuildArea
@onready var party_info = $PartyInfo
@onready var party_roster = $PartyRoster
@onready var building_info = $BuildingInfo

var _min_pos: Vector2
var _max_pos: Vector2
var _zoom_level := 1.0

# 현재 이동 가능한 목적지 셀 집합(지형 상한 반영) → true. 클릭 이동 판정에 사용.
var _reachable: Dictionary = {}
# 주인공이 선택되었는지. 선택 상태에서만 범위 표시 + 이동이 가능하다.
var _selected := false
# 상호작용 모드. MOVE=파랑 이동 범위+공격가능 적(빨강)+중앙 메뉴, SHOOT=사격 가능 적(빨강)만.
const MODE_MOVE := "move"
const MODE_SHOOT := "shoot"
var _mode := MODE_MOVE
var _move_cells: Array[Vector2i] = []     # 이동 범위(파랑) 표시용
# 공격 가능한 적: enemy 칸 → {enemy, cell, melee, shoot}. 빨강 오버레이·팝업·사격 판단에 쓴다.
var _attack_targets: Dictionary = {}
var _attack_cells: Array[Vector2i] = []   # 공격 가능 적 칸(MOVE에서 빨강)
var _shoot_cells: Array[Vector2i] = []    # 사격 가능 적 칸([사격] 활성 판정·타겟)
var _shoot_area_cells: Array[Vector2i] = []   # 사격 사거리 전체 칸(SHOOT 모드 빨강 오버레이)
# 점령 가능한 적 거점: camp 칸 → {camp, stand}. 빨강 오버레이·클릭 팝업에 쓴다.
var _capture_targets: Dictionary = {}
var _capture_cells: Array[Vector2i] = []  # 점령 가능 캠프 칸(MOVE에서 빨강)
var _capture_target = null                # 거점 점령 팝업의 대상 항목({camp, stand})(없으면 아님)
var _popup_target = null                  # 적 클릭 팝업의 대상 항목(없으면 중앙 메뉴)
var _undo_party = null                     # 되돌릴 수 있는 마지막 이동의 부대(없으면 null)
var _undo_cell: Vector2i                   # 그 부대의 이동 전 칸
var party_action_menu: PartyActionMenu    # 부대 행동 메뉴(코드 생성, _ready에서 추가)

# 턴 진행. 턴 종료 시 유닛 이동 리셋 + 영지 자원 수입.
var _turn := TurnManager.new()
var _units: Array = []          # 턴당 1회 이동하는 부대(주인공 부대 등).
var _npc_parties: Array = []    # NPC 부대. 안개 표시·턴 리셋·턴 종료 시 이동(NpcAi) 대상. 일람은 제외.
var _territories: Array = []    # 자원 수입을 받는 영지(플레이어). NPC 영지는 미포함(경제 미사용).
var _buildings: Array = []      # 플레이어 건물(캠프 + 건설된 농장). 겹침 검사·시야 합산·추적용.
var _npc_buildings: Array = []  # NPC 세력 거점(캠프). 안개(탐험됨) 표시 + 클릭 정보 대상. 시야 합산 제외.
var _player_faction: Faction    # 플레이어 세력(캠프 흡수 시 영지 편입 대상). _setup_factions에서 설정.
var _factions: Array = []       # 모든 세력(플레이어 + NPC). 세력 소멸/정복 승리 판정 대상.

# NPC 이동 AI가 목적지를 무작위로 고를 때 쓰는 난수기(_ready에서 randomize).
var _rng := RandomNumberGenerator.new()

# 진행 중인 NPC 이동 애니메이션. 재진입(애니메이션 중 다시 턴 종료) 시 목적지로 스냅하는 데 쓴다.
var _npc_tweens: Array = []          # 살아 있는 Tween 목록(재진입 시 kill).
var _npc_move_targets: Dictionary = {}   # party → 최종 목적지 칸(스냅용).
var _npc_move_epoch := 0             # NPC 이동 세대. 새 라운드가 시작되면 이전 코루틴을 중단시킨다.

# 진행 중인 플레이어 부대 이동 애니메이션. 이동 중에는 좌클릭을 잠근다.
var _player_moving := false
var _player_tween: Tween = null
var _player_move_target: Vector2i

# 전투 오버레이가 떠 있는 동안 월드맵 좌클릭·턴 종료를 잠근다.
var _in_battle := false

# 게임 오버(승패 확정) 상태. true면 월드맵 좌클릭·턴 종료를 잠그고 결과 오버레이를 띄운다.
var _game_over := false
var result_overlay: ResultOverlay   # 결과 화면(코드 생성, _ready에서 추가)

const BATTLE_SCENE := preload("res://scenes/combat/battle.gd")
const TITLE_SCENE := "res://scenes/title/title.tscn"

# 건설 모드. 캠프 메뉴에서 건물을 고르면 진입 — 맵을 클릭해 배치한다.
var _build_mode := false
var _build_type := ""
var _build_territory: Territory = null

func _ready() -> void:
	_rng.randomize()
	_generate_map()
	_center_camera()
	overlay.setup(terrain)
	build_preview.setup(terrain)
	build_area.setup(terrain)
	building.setup(terrain, Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2), BuildingTypes.CAMP)
	_buildings = [building]
	_setup_factions()
	_setup_parties()
	_place_party()
	fog.setup(terrain, MAP_WIDTH, MAP_HEIGHT)
	_update_fog()
	_units = [party]
	party_roster.set_parties(_units)
	party_roster.party_selected.connect(_on_party_focused)
	turn_hud.set_turn(_turn.number)
	turn_hud.ended.connect(_on_turn_ended)
	camp_menu.build_selected.connect(_on_build_selected)
	party_action_menu = PartyActionMenu.new()   # 코드 생성 UI(camp_menu와 달리 .tscn 노드 없음)
	add_child(party_action_menu)
	party_action_menu.action_selected.connect(_on_party_action)
	result_overlay = ResultOverlay.new()   # 결과 화면(코드 생성)
	add_child(result_overlay)
	result_overlay.dismissed.connect(_on_result_dismissed)

## 맵 전체를 초원 타일로 채운 뒤, 시작 지점 근처에 숲을 조금 배치한다.
func _generate_map() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			terrain.set_cell(Vector2i(x, y), Terrain.GRASS, Terrain.ATLAS)

	_place_starting_terrain()

	# 카메라 이동 범위(월드 좌표) 계산 — 맵 밖으로 벗어나지 않도록 클램프용.
	var corner_a := terrain.map_to_local(Vector2i(0, 0))
	var corner_b := terrain.map_to_local(Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1))
	_min_pos = Vector2(min(corner_a.x, corner_b.x), min(corner_a.y, corner_b.y))
	_max_pos = Vector2(max(corner_a.x, corner_b.x), max(corner_a.y, corner_b.y))

## 시작 지점(중앙 캠프) 근처에 방ㄴ향별 지형 덩어리를 배치한다.
## 서쪽=숲 · 동쪽=습지 · 북쪽=사막 · 남쪽=산. 캠프(중앙 반경1)·주인공 배치 칸과 겹치지 않게 떨어뜨린다.
## (y가 커질수록 남쪽, x가 커질수록 동쪽.)
func _place_starting_terrain() -> void:
	var center := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	_paint_patches([center + Vector2i(-6, -1), center + Vector2i(-8, 2)], Terrain.FOREST)   # 서쪽 숲
	_paint_patches([center + Vector2i(6, -1), center + Vector2i(8, 2)], Terrain.SWAMP)      # 동쪽 습지
	_paint_patches([center + Vector2i(0, -6), center + Vector2i(2, -7)], Terrain.DESERT)    # 북쪽 사막
	_paint_patches([center + Vector2i(0, 7), center + Vector2i(-2, 8)], Terrain.MOUNTAIN)   # 남쪽 산

## 씨앗 칸들 각각을 중심으로 (씨앗 + 이웃 6칸)을 해당 지형으로 칠한다.
func _paint_patches(seeds: Array, source_id: int) -> void:
	for center in seeds:
		terrain.set_cell(center, source_id, Terrain.ATLAS)
		for n in terrain.get_surrounding_cells(center):
			terrain.set_cell(n, source_id, Terrain.ATLAS)

## 카메라를 맵 중앙 타일로 이동시킨다.
func _center_camera() -> void:
	var center_cell := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	camera.position = terrain.map_to_local(center_cell)
	camera.make_current()

## 플레이어 + NPC 세력·영지·거점을 유닛 카탈로그에서 만든다.
## 플레이어: 세력 "푸른 왕국" → 영지 "창천성"에 중앙 캠프를 넣는다(자원 수입 대상 _territories).
## NPC 3세력: 각 부대 방향 바깥쪽에 수도 영지 + 완성 캠프를 배치한다(_npc_buildings, 경제 미사용).
func _setup_factions() -> void:
	var spec := UnitTypes.get_party(UnitTypes.PLAYER_ID)
	var territory := Territory.new(spec["territory"], _camp_resources())
	_player_faction = Faction.new(spec["faction"], spec["color"])
	_player_faction.add_territory(territory)
	territory.add_building(building)
	_territories = [territory]
	_factions = [_player_faction]

	var center := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	for id in UnitTypes.NPC_IDS:
		_npc_buildings.append(_setup_npc_base(id, center + NPC_BASE_OFFSETS[id]))

## NPC 세력 하나의 거점을 만든다: 세력 → 수도 영지 → 완성 캠프(중심 base_cell). 캠프 노드를 반환한다.
## 세력·영지는 캠프의 territory 참조로 살아 있게 유지된다(_npc_buildings가 캠프 노드를 보유).
func _setup_npc_base(id: String, base_cell: Vector2i) -> Building:
	var spec := UnitTypes.get_party(id)
	var territory := Territory.new(spec["territory"], _camp_resources())
	var faction := Faction.new(spec["faction"], spec["color"])
	faction.add_territory(territory)
	_factions.append(faction)
	var camp := Building.new()
	add_child(camp)
	camp.setup(terrain, base_cell, BuildingTypes.CAMP)   # 완성 상태(건설 중 아님)
	territory.add_building(camp)
	return camp

## 캠프 카탈로그의 초기 자원 사본(영지 생성 시 시작 자원). 플레이어·NPC 공용.
func _camp_resources() -> Dictionary:
	var camp_spec := BuildingTypes.get_type(BuildingTypes.CAMP)
	return (camp_spec.get("resources", {}) as Dictionary).duplicate(true)

## 부대를 유닛 카탈로그에서 생성한다.
## 플레이어 부대(아젤 하르윈)는 기존 $Party 노드에 채우고 금색 유지.
## NPC 부대 3개는 새로 인스턴스화해 세력 색으로 그리고 시작 지점 주변에 배치(표시만).
func _setup_parties() -> void:
	_populate_party(party, UnitTypes.PLAYER_ID)
	var center := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
	for id in UnitTypes.NPC_IDS:
		var p := PARTY_SCENE.instantiate()
		add_child(p)
		_populate_party(p, id)
		p.token_color = UnitTypes.get_party(id)["color"]
		p.position = terrain.map_to_local(center + NPC_OFFSETS[id])
		_npc_parties.append(p)

## 부대에 카탈로그 멤버를 채우고 이름·지휘관을 설정한다.
func _populate_party(p, id: String) -> void:
	var spec := UnitTypes.get_party(id)
	p.party_name = spec["party_name"]
	p.faction_name = spec["faction"]
	var members := UnitTypes.make_members(id)
	for m in members:
		p.add_member(m)
	if not members.is_empty():
		p.commander = members[0]

## 주인공 부대를 캠프 바로 아래(캠프 영역 밖) 타일에 배치한다.
func _place_party() -> void:
	var party_cell := Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2 + 3)
	party.position = terrain.map_to_local(party_cell)

## 주인공 위치에서 이동력만큼 BFS로 도달 셀(파랑)을 구하고, 공격 가능한 적(빨강)을 분류한다.
func _update_ranges() -> void:
	var start := terrain.local_to_map(party.position)
	var move_range: int = party.movement() if party.can_move() else 0
	var ranges := HexGrid.movement_ranges(terrain, start, move_range, MAP_WIDTH, MAP_HEIGHT, _occupied_cells(party))
	var move_cells: Array[Vector2i] = ranges["move"]
	_reachable = {}
	for c in move_cells:
		_reachable[c] = true
	_move_cells = move_cells
	_compute_attack_targets(start)
	_compute_capture_targets(start)
	_refresh_overlay()

## 보이는 각 NPC를 공격 가능 여부로 분류한다. 근접=(현재∪이동칸 중 인접칸 존재), 사격=(원거리 무기·현재 위치 사거리 내).
func _compute_attack_targets(start: Vector2i) -> void:
	_attack_targets = {}
	_attack_cells = []
	_shoot_cells = []
	_shoot_area_cells = []
	var rng: int = party.attack_range()
	var shoot_area := {}
	if rng >= 2:
		for c in HexGrid.cells_within(terrain, start, rng, MAP_WIDTH, MAP_HEIGHT):
			if c == start:
				continue
			shoot_area[c] = true
			_shoot_area_cells.append(c)   # SHOOT 모드에서 사거리 전체를 빨강으로 표시
	for p in _npc_parties:
		if not p.visible:
			continue
		var ec: Vector2i = terrain.local_to_map(p.position)
		var melee := _cell_melee_reachable(ec, start)
		var shoot: bool = rng >= 2 and shoot_area.has(ec)
		if melee or shoot:
			_attack_targets[ec] = {"enemy": p, "cell": ec, "melee": melee, "shoot": shoot}
			_attack_cells.append(ec)
			if shoot:
				_shoot_cells.append(ec)

## 그 적에 인접한 칸이 (현재 칸 ∪ 이동칸)에 있으면 근접 가능(이동해서 붙을 수 있음).
func _cell_melee_reachable(enemy_cell: Vector2i, start: Vector2i) -> bool:
	for n in terrain.get_surrounding_cells(enemy_cell):
		if n == start or _reachable.has(n):
			return true
	return false

## 발견된 각 NPC 거점 중 인접 가능한 것을 점령 대상으로 분류한다(캠프 칸 → {camp, stand}).
func _compute_capture_targets(start: Vector2i) -> void:
	_capture_targets = {}
	_capture_cells = []
	for camp in _npc_buildings:
		if not camp.visible:
			continue   # 미발견(안개) 거점은 점령 대상 아님
		var stand := _camp_stand(camp, start)
		if stand == Vector2i(-1, -1):
			continue   # 인접 못 함
		for c in camp.cells:
			_capture_targets[c] = {"camp": camp, "stand": stand}
			_capture_cells.append(c)

## 캠프에 붙어 점령할 설 자리. 이미 인접이면 현재 칸, 아니면 캠프 인접한 도달 칸 하나, 없으면 (-1,-1).
func _camp_stand(camp, start: Vector2i) -> Vector2i:
	for cc in camp.cells:
		if start in terrain.get_surrounding_cells(cc):
			return start
	for cc in camp.cells:
		for n in terrain.get_surrounding_cells(cc):
			if _reachable.has(n):
				return n
	return Vector2i(-1, -1)

## 현재 모드에 맞는 오버레이. MOVE=파랑 이동+빨강(공격 가능 적 + 점령 가능 거점), SHOOT=빨강 사격 사거리 전체.
func _refresh_overlay() -> void:
	var none: Array[Vector2i] = []
	if _mode == MODE_SHOOT:
		overlay.show_ranges(none, _shoot_area_cells)
	else:
		var red: Array[Vector2i] = []
		red.append_array(_attack_cells)
		red.append_array(_capture_cells)
		overlay.show_ranges(_move_cells, red)

## 모든 시야원(주인공 부대 + 맵의 모든 완성 건물)을 합쳐 현재 시야 셀을 계산하고 안개를 갱신한다.
func _update_fog() -> void:
	var visible := {}
	var party_cell := terrain.local_to_map(party.position)
	for c in HexGrid.cells_within(terrain, party_cell, party.vision(), MAP_WIDTH, MAP_HEIGHT):
		visible[c] = true
	# 완성 건물(캠프·농장 등)의 시야. 건설 중 건물은 buildings_vision이 제외한다.
	for c in BuildPlanner.buildings_vision(terrain, _buildings, MAP_WIDTH, MAP_HEIGHT):
		visible[c] = true
	fog.update_visible(visible)
	_update_npc_visibility()
	_update_npc_building_visibility()

## NPC 부대 토큰은 플레이어 현재 시야 안에 있을 때만 보이고, 시야 밖이면 안개에 가려 숨긴다.
## (NPC는 시야를 밝히지 않으므로 _update_fog 시야 합산에는 넣지 않는다.)
func _update_npc_visibility() -> void:
	for p in _npc_parties:
		p.visible = fog.is_cell_visible(terrain.local_to_map(p.position))

## NPC 거점(캠프)은 한 번 발견(탐험)하면 계속 보인다(정적 구조물). 미발견이면 안개에 가려 숨긴다.
## 부대와 달리 현재 시야가 아니라 탐험됨(fog.is_cell_explored)으로 판정 — 7칸 중 하나라도 본 적 있으면 발견.
## (NPC 거점도 플레이어 시야를 밝히지 않으므로 _update_fog 시야 합산에는 넣지 않는다.)
func _update_npc_building_visibility() -> void:
	for b in _npc_buildings:
		b.visible = _base_discovered(b)

## 거점의 7칸(중심 + 이웃) 중 하나라도 탐험된 적 있으면 발견으로 본다.
func _base_discovered(b) -> bool:
	for c in b.cells:
		if fog.is_cell_explored(c):
			return true
	return false

## 좌클릭 처리. 우선순위 판정은 순수 함수 ClickRouter.resolve에 위임하고 여기서는 실행만 한다.
## - 부대 우선(캠프 위 재클릭 시 메뉴) → 선택 중 이동(건물 위 통행) → 캠프 메뉴 → 건물 정보 → 선택 해제.
func _handle_click(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(terrain.to_local(world_pos))
	var party_cell := terrain.local_to_map(party.position)
	var reachable: bool = _reachable.has(cell)
	var clicked := _building_at(cell)   # 플레이어 건물. 캠프는 CAMP_MENU, 그 외는 BUILDING_INFO로 분기.
	var clicked_npc := _npc_at(cell)    # 보이는 NPC 부대가 있으면 정보 표시/공격 대상.
	var clicked_npc_building := _npc_building_at(cell)   # 발견된 NPC 거점이면 정보 표시(NPC_BASE_INFO).
	var on_camp := clicked != null and clicked.building_type == BuildingTypes.CAMP
	var on_building := clicked != null and clicked.building_type != BuildingTypes.CAMP

	# SHOOT 모드: 사격 가능 적을 클릭하면 제자리 사격, 그 외 클릭은 MOVE 모드로 취소.
	if _selected and _mode == MODE_SHOOT:
		if _attack_targets.has(cell) and _attack_targets[cell]["shoot"] and party.can_attack():
			var e: Dictionary = _attack_targets[cell]
			_shoot_enemy(e["enemy"])
		else:
			_enter_move_mode()
		return

	# MOVE 모드: 공격 가능한 적(빨강)을 클릭하면 [이동][공격][사격] 팝업.
	if _selected and _mode == MODE_MOVE and _attack_targets.has(cell) and party.can_attack():
		_open_enemy_popup(_attack_targets[cell])
		return

	# MOVE 모드: 점령 가능한 적 거점(빨강)을 클릭하면 [흡수][파괴] 팝업.
	if _selected and _mode == MODE_MOVE and _capture_targets.has(cell) and party.can_attack():
		_open_capture_popup(_capture_targets[cell])
		return

	match ClickRouter.resolve(cell == party_cell, clicked_npc != null, on_camp, on_building, clicked_npc_building != null, _selected, reachable, party_info.visible):
		ClickRouter.MOVE:
			# 이동은 클릭 즉시 확정하고(재이동 불가·선택 해제), 토큰만 경로 따라 애니메이션한다.
			_undo_party = party   # 되돌리기용: 이동 전 칸 기록(다른 부대 이동/행동 시 갱신·소멸)
			_undo_cell = party_cell
			party.mark_moved()   # 부대는 한 턴에 1회만 이동.
			_deselect()
			_hide_party_info()
			_move_player_to(party_cell, cell)
		ClickRouter.CAMP_MENU:
			if _selected:
				_deselect()
			_hide_party_info()
			camp_menu.open(building)
		ClickRouter.BUILDING_INFO:
			_open_building_info(clicked)
		ClickRouter.NPC_BASE_INFO:
			_open_building_info(clicked_npc_building)   # 발견된 NPC 거점 — 정보만(건축 없음)
		ClickRouter.FOCUS_PARTY:
			# 정보 패널은 항상 연다. 아직 선택 전이고 행동 가능하면 함께 선택(파랑 범위 + 행동 메뉴).
			_show_party_info(party)
			if not _selected and (party.can_move() or party.can_rest()):
				_select()
			elif _selected:
				_enter_move_mode()   # 재클릭 = 팝업/사격 취소하고 중앙 메뉴로 복귀
		ClickRouter.FOCUS_NPC:
			# NPC는 정보만 표시한다(선택·이동 없음). 진행 중이던 선택은 해제한다.
			if _selected:
				_deselect()
			_show_party_info(clicked_npc)
		ClickRouter.DESELECT:
			_deselect()
			_hide_party_info()

## 셀을 점유한 건물을 찾는다(없으면 null). 캠프·건설된 농장 모두 _buildings에 있다.
func _building_at(cell: Vector2i) -> Building:
	for b in _buildings:
		if b.contains_cell(cell):
			return b
	return null

## 그 셀에 선 NPC 부대를 찾는다(없으면 null). 안개에 가려 보이지 않는(visible == false) NPC는 제외한다.
func _npc_at(cell: Vector2i) -> Party:
	for p in _npc_parties:
		if p.visible and terrain.local_to_map(p.position) == cell:
			return p
	return null

## 그 셀을 포함하는 NPC 거점(캠프)을 찾는다(없으면 null). 아직 발견 안 돼 가려진(visible == false) 거점은 제외한다.
func _npc_building_at(cell: Vector2i) -> Building:
	for b in _npc_buildings:
		if b.visible and b.contains_cell(cell):
			return b
	return null

## 우측 상단에 건물 정보 패널을 띄운다. 부대 정보·일람은 감춘다(캠프 메뉴와 같은 규칙). 선택 중이면 해제.
## 플레이어 건물(BUILDING_INFO)·NPC 거점(NPC_BASE_INFO)이 공유한다.
func _open_building_info(b) -> void:
	if _selected:
		_deselect()
	party_info.close()
	party_roster.hide()
	building_info.open(b)

## exclude를 뺀 모든 부대(플레이어 + NPC)가 점유한 칸 집합({cell: true}). 이동 장애물로 넘긴다.
func _occupied_cells(exclude) -> Dictionary:
	var occ := {}
	for p in [party] + _npc_parties:
		if p == exclude:
			continue
		occ[terrain.local_to_map(p.position)] = true
	return occ

## [공격] 근접: 적 인접 칸으로 이동 후 근접 전투. 승리 시 수비 타일 점령.
func _melee_attack(entry: Dictionary) -> void:
	var start := terrain.local_to_map(party.position)
	var ecell: Vector2i = entry["cell"]
	var stand := _adjacent_stand(ecell, start)
	if stand == start:
		_begin_battle(entry["enemy"], false, ecell)   # 이미 인접 — 제자리 근접 전투
		return
	party.mark_moved()
	_deselect()
	_hide_party_info()
	_move_player_to(start, stand, {"enemy": entry["enemy"], "occupy": ecell})

## [사격]: 현재 위치에서 원거리 전투(이동·점령 없음).
func _shoot_enemy(enemy) -> void:
	_begin_battle(enemy, true, Vector2i(-1, -1))

## [흡수]/[파괴]: 캠프 인접 칸으로(필요 시) 이동 후 점령한다. absorb=흡수, false=파괴.
func _capture_camp(entry: Dictionary, absorb: bool) -> void:
	var start := terrain.local_to_map(party.position)
	var stand: Vector2i = entry["stand"]
	if stand == start:
		_do_capture(entry["camp"], absorb)   # 이미 인접 — 제자리 점령
		return
	party.mark_moved()
	_deselect()
	_hide_party_info()
	_move_player_to(start, stand, {"capture": entry["camp"], "absorb": absorb})

## 점령 실행: 행동을 끝내고(mark_attacked) 흡수/파괴한 뒤 선택·안개·일람을 갱신한다.
func _do_capture(camp, absorb: bool) -> void:
	party.mark_attacked()
	_undo_party = null   # 점령은 되돌릴 수 없다
	if absorb:
		_absorb_camp(camp)
	else:
		_destroy_camp(camp)
	if _selected:
		_deselect()
	_hide_party_info()
	_update_fog()
	party_roster.set_parties(_units)

## 흡수: 캠프의 영지를 플레이어 세력으로 이전하고, 캠프를 플레이어 건물로 편입한다(시야·건축·수입 획득).
func _absorb_camp(camp) -> void:
	var territory = camp.territory
	if territory != null:
		if territory.faction != null:
			territory.faction.remove_territory(territory)
		_player_faction.add_territory(territory)
		if not (territory in _territories):
			_territories.append(territory)
	_npc_buildings.erase(camp)
	if not (camp in _buildings):
		_buildings.append(camp)
	camp.visible = true       # 플레이어 건물은 항상 보인다
	camp.queue_redraw()       # 라벨색을 플레이어 세력색으로 갱신

## 파괴: 캠프를 영지·맵에서 제거한다(획득 없음). 영지·세력은 남지만 캠프 0개가 된다(소멸 판정은 다음 슬라이스).
func _destroy_camp(camp) -> void:
	if camp.territory != null:
		camp.territory.remove_building(camp)
	_npc_buildings.erase(camp)
	camp.queue_free()

## 적 인접 칸: 이미 인접이면 현재 칸, 아니면 인접한 도달 칸 하나, 없으면 현재 칸.
func _adjacent_stand(enemy_cell: Vector2i, start: Vector2i) -> Vector2i:
	var neighbors := terrain.get_surrounding_cells(enemy_cell)
	if start in neighbors:
		return start
	for n in neighbors:
		if _reachable.has(n):
			return n
	return start

## 플레이어가 적에게 개시하는 전투. 공격은 부대 행동을 끝낸다(mark_attacked).
## ranged=원거리 모드, occupy_cell=근접 승리 시 이동할 수비 타일((-1,-1)이면 점령 없음).
func _begin_battle(defender, ranged: bool, occupy_cell: Vector2i) -> void:
	party.mark_attacked()
	_undo_party = null   # 공격/사격은 되돌릴 수 없다
	if _selected:
		_deselect()
	_hide_party_info()
	_run_battle(party, defender, ranged, occupy_cell)   # 비차단(await로 백그라운드 진행)

## 개시 시 두 부대가 인접이 아니면(떨어져 있으면) 원거리 전투로 본다.
func _is_ranged_engagement(a, b) -> bool:
	var acell := terrain.local_to_map(a.position)
	var bcell := terrain.local_to_map(b.position)
	return acell != bcell and not (bcell in terrain.get_surrounding_cells(acell))

## 오버레이 전투를 띄우고 관전한다(입력 잠금). 종료까지 await 후 사상자를 반영한다.
## occupy_cell != (-1,-1)이고 근접 승리(수비 전멸·공격 생존)면 공격 부대를 그 타일로 이동(점령).
func _run_battle(attacker, defender, ranged := false, occupy_cell := Vector2i(-1, -1)) -> void:
	_in_battle = true
	var overlay := BATTLE_SCENE.new()
	add_child(overlay)
	overlay.start(attacker, defender, ranged)
	var result: Array = await overlay.finished   # [a_survivors, b_survivors]
	_apply_survivors(attacker, result[0])
	_apply_survivors(defender, result[1])
	overlay.queue_free()
	_in_battle = false
	if occupy_cell != Vector2i(-1, -1) and defender.members.is_empty() and not attacker.members.is_empty():
		attacker.position = terrain.map_to_local(occupy_cell)   # 근접 승리 → 수비 타일 점령
	_update_fog()
	party_roster.set_parties(_units)
	# 부대 전멸로는 게임 오버되지 않는다(점령 승리만). 승패는 세력 소멸 판정(_update_endgame)에서만 난다.

## 세력 소멸 유예 판정(턴 종료마다). 각 세력의 캠프 수로 유예 카운트를 갱신하고, 소멸한 세력은 붕괴시킨다.
## 이어서 정복 승리/플레이어 세력 소멸 패배를 판정한다.
func _update_endgame() -> void:
	if _game_over:
		return
	for f in _factions:
		if f.eliminated:
			continue
		var has_post := _faction_camp_count(f) > 0
		f.grace_turns = GameResult.advance_grace(has_post, f.grace_turns)
		if GameResult.grace_eliminated(f.grace_turns):
			f.eliminated = true
			_eliminate_faction(f)
	_refresh_grace_hud()
	_check_endgame()

## 세력의 지휘소(캠프) 수 = 소속 영지의 건물 중 CAMP 개수.
func _faction_camp_count(faction) -> int:
	var n := 0
	for t in faction.territories:
		for b in t.buildings:
			if is_instance_valid(b) and b.building_type == BuildingTypes.CAMP:
				n += 1
	return n

## 세력 소멸(붕괴): 그 세력 소속 NPC 부대를 맵에서 제거한다. 플레이어 세력이면 부대는 그대로 둔다(패배 처리).
func _eliminate_faction(faction) -> void:
	for p in _npc_parties.duplicate():
		if p.faction_name == faction.name:
			_npc_parties.erase(p)
			p.queue_free()
	_update_fog()   # 제거된 NPC 부대 반영(일람은 우리 세력만이라 갱신 불필요)

## 정복 승리/플레이어 세력 소멸 판정 → 결과 오버레이.
func _check_endgame() -> void:
	if _game_over:
		return
	var all_npc_eliminated := true
	for f in _factions:
		if f == _player_faction:
			continue
		if not f.eliminated:
			all_npc_eliminated = false
	match GameResult.endgame(_player_faction.eliminated, all_npc_eliminated):
		GameResult.VICTORY:
			_trigger_game_over("정복 승리", "모든 적 세력을 물리쳤다")
		GameResult.DEFEAT:
			_trigger_game_over("패배", "세력이 소멸했다")

## 소멸 위기(캠프 0, grace_turns>=0) 세력을 턴 HUD에 목록으로 표시한다.
func _refresh_grace_hud() -> void:
	var entries: Array = []
	for f in _factions:
		if f.eliminated:
			continue
		if f.grace_turns >= 0:
			entries.append({"text": "%s 소멸까지 %d턴" % [f.name, f.grace_turns], "color": f.color})
	turn_hud.set_grace(entries)

## 게임 오버: 상태를 잠그고 진행 중 선택·메뉴를 정리한 뒤 결과 오버레이를 띄운다. 중복 호출은 무시.
func _trigger_game_over(title: String, subtitle: String) -> void:
	if _game_over:
		return
	_game_over = true
	if _selected:
		_deselect()
	_hide_party_info()
	result_overlay.show_result(title, subtitle)

## 결과 오버레이 클릭 → 타이틀로 복귀(페이드 전환).
func _on_result_dismissed() -> void:
	SceneManager.change_scene(TITLE_SCENE)

## NPC끼리 전투를 화면 없이 즉시 결산한다(BattleSim). 사상자만 반영.
func _resolve_battle_headless(attacker, defender, ranged := false) -> void:
	var result := BattleSim.resolve_battle(attacker.members, defender.members, _rng, ranged)
	_apply_survivors(attacker, result["a"])
	_apply_survivors(defender, result["b"])

## 부대 멤버를 생존자로 교체한다. 지휘관 사망 시 재지정, NPC 부대 전멸 시 맵에서 제거.
## 플레이어 부대는 전멸해도 노드를 유지한다(전멸 후 처리는 미구현).
func _apply_survivors(p, survivors: Array) -> void:
	p.members = survivors
	if not (p.commander in survivors):
		p.commander = survivors[0] if not survivors.is_empty() else null
	if survivors.is_empty() and p in _npc_parties:
		_npc_parties.erase(p)
		p.queue_free()

## 주인공 부대를 선택하고 이동 범위·공격 가능 적·중앙 메뉴를 표시한다.
func _select() -> void:
	_selected = true
	party.set_selected(true)
	_mode = MODE_MOVE
	_update_ranges()
	_open_action_menu()

## MOVE 모드로 (재)진입: 파랑 범위 + 빨강 적 + 중앙 메뉴. 팝업/사격 취소 시에도 쓴다.
func _enter_move_mode() -> void:
	_mode = MODE_MOVE
	_refresh_overlay()
	_open_action_menu()

## SHOOT 모드: 사격 가능 적(빨강)만, 메뉴 감춤. 그 적을 클릭하면 제자리 사격.
func _enter_shoot_mode() -> void:
	_mode = MODE_SHOOT
	_refresh_overlay()
	party_action_menu.close()

## 중앙 부대 메뉴 [사격][휴식][경계]를 부대 토큰 근처에 연다. 행동 가능할 때만.
func _open_action_menu() -> void:
	_popup_target = null
	_capture_target = null
	if party.can_rest():
		var can_undo: bool = _undo_party == party
		party_action_menu.open(PartyActionMenu.party_actions(party.moved_this_turn, not _shoot_cells.is_empty(), can_undo), _screen_pos(party.position))
	else:
		party_action_menu.close()

## 공격 가능한 적 클릭 팝업 [공격][사격]을 그 적 근처에 연다. 대상 항목을 _popup_target에 둔다.
func _open_enemy_popup(entry: Dictionary) -> void:
	_capture_target = null
	_popup_target = entry
	party_action_menu.open(PartyActionMenu.enemy_actions(entry["melee"], entry["shoot"]), _screen_pos(terrain.map_to_local(entry["cell"])))

## 점령 가능한 적 거점 클릭 팝업 [흡수][파괴]을 캠프 중심 근처에 연다. 대상 항목을 _capture_target에 둔다.
func _open_capture_popup(entry: Dictionary) -> void:
	_popup_target = null
	_capture_target = entry
	party_action_menu.open(PartyActionMenu.capture_actions(), _screen_pos(terrain.map_to_local(entry["camp"].center_cell())))

## 월드 좌표 → 화면 좌표(카메라·줌 반영). 메뉴를 클릭 지점 근처에 띄우는 데 쓴다.
func _screen_pos(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

## 메뉴 버튼 처리. 팝업(적 대상)이면 공격/사격, 중앙 메뉴면 사격 모드/휴식/경계.
func _on_party_action(id: String) -> void:
	if not _selected:
		return
	if _capture_target != null:
		var entry: Dictionary = _capture_target
		_capture_target = null
		match id:
			"absorb":
				_capture_camp(entry, true)
			"destroy":
				_capture_camp(entry, false)
		return
	if _popup_target != null:
		var entry: Dictionary = _popup_target
		_popup_target = null
		match id:
			"attack":
				_melee_attack(entry)
			"shoot":
				_shoot_enemy(entry["enemy"])
		return
	match id:
		"shoot":
			_enter_shoot_mode()
		"rest":
			for m in party.members:
				m.apply_rest()   # hp·스태미나 25% 회복
			party.mark_rested()
			_undo_party = null   # 턴 종료 행동 → 되돌리기 소멸
			_deselect()
			_hide_party_info()
		"alert":
			for m in party.members:
				m.apply_alert()   # 스태미나 10% + 전투 버프(적 턴 후 해제)
			party.mark_attacked()   # 경계도 이번 턴 행동을 끝낸다
			_undo_party = null
			_deselect()
			_hide_party_info()
		"wait":
			party.mark_attacked()   # 대기 — 효과 없이 턴만 종료
			_undo_party = null
			_deselect()
			_hide_party_info()
		"undo":
			_undo_last_move()

## [취소]: 마지막 이동을 되돌린다 — 이동 전 칸으로 복귀 + moved 해제 + 시야·범위·메뉴 재표시.
func _undo_last_move() -> void:
	if _undo_party != party:
		return
	party.position = terrain.map_to_local(_undo_cell)
	party.undo_move()
	_undo_party = null
	_update_fog()
	_select()   # 이제 이동 전 상태 → 메뉴 [사격][휴식][경계]

## 턴 종료: 번호 +1, 모든 유닛 이동 리셋, 모든 영지 자원 수입, NPC 이동. 진행 중 선택은 해제한다.
func _on_turn_ended() -> void:
	if _in_battle or _game_over:
		return   # 전투 관전 중·게임 오버에는 턴을 넘기지 않는다.
	_finish_player_move()   # 이동 애니메이션 중이면 목적지로 스냅한 뒤 턴을 넘긴다.
	_undo_party = null   # 턴이 바뀌면 되돌리기 초기화
	if _selected:
		_deselect()
	_hide_party_info()
	# 플레이어 부대 + NPC 부대 모두 이동 상태를 리셋한다(일람은 우리 세력만이라 _units만 등록).
	_turn.end_turn(_units + _npc_parties, _territories)
	turn_hud.set_turn(_turn.number)
	_update_fog()   # 건설 완료 농장 시야 + NPC 현재 위치 표시를 안개에 반영.
	_update_endgame()   # 세력 소멸 유예 판정 → 소멸 시 부대 붕괴 + 정복 승리/패배
	if _game_over:
		return   # 승패 확정 → NPC 이동 생략
	_move_npcs()    # 비차단: NPC를 경로 따라 애니메이션으로 이동(플레이어 조작 안 막음).

## 각 NPC 부대를 목적지(NpcAi)까지 경로 따라 애니메이션으로 이동시킨다.
## 세력 간 순차, 같은 세력 내 부대는 NPC_PARTY_STAGGER 간격으로 동시 이동. 비차단(await로 백그라운드 진행).
func _move_npcs() -> void:
	_finish_pending_npc_moves()   # 재진입: 진행 중이던 이동을 목적지로 스냅.
	_npc_move_epoch += 1
	var epoch := _npc_move_epoch   # 이 라운드의 세대. 도중 새 라운드가 시작되면 아래 루프를 빠져나온다.

	# 세력별로 그룹핑(등장 순서 유지). 각 항목은 {party, path}.
	var factions: Array = []
	var groups: Dictionary = {}
	for p in _npc_parties:
		var start := terrain.local_to_map(p.position)
		var occ := _occupied_cells(p)   # 자기 외 모든 부대의 현재 위치 = 이동 장애물이자 접근 타깃.
		var dest := NpcAi.choose_destination(terrain, start, p.movement(), MAP_WIDTH, MAP_HEIGHT, _rng, occ, occ.keys())
		var path := HexGrid.reconstruct_path(terrain, start, dest, p.movement(), MAP_WIDTH, MAP_HEIGHT, occ)
		var f: String = p.faction_name
		if not groups.has(f):
			groups[f] = []
			factions.append(f)
		groups[f].append({"party": p, "path": path})

	# 세력을 하나씩 순차로 애니메이션한다(한 세력이 끝나야 다음).
	for f in factions:
		if epoch != _npc_move_epoch:
			return   # 새 이동 라운드가 시작됨 → 이 코루틴은 중단(이중 이동 방지).
		await _animate_faction(groups[f])

	# 이동이 끝나면 공격 페이즈: 인접한 적이 있는 NPC가 차례로 전투를 건다.
	if epoch == _npc_move_epoch:
		await _npc_attack_phase(epoch)

## 각 NPC가 이동 후 인접한 적에게 전투를 건다. 플레이어가 낀 전투는 오버레이(await), NPC끼리는 헤드리스.
func _npc_attack_phase(epoch: int) -> void:
	for attacker in _npc_parties.duplicate():
		if epoch != _npc_move_epoch:
			_clear_player_alert()   # 중단돼도 경계 버프는 반드시 해제(다음 내 턴에 남지 않게)
			return
		if _game_over:
			return   # 이 전투로 게임 오버(플레이어 전멸) 확정 → 남은 NPC 공격 결산 중단
		if not is_instance_valid(attacker) or not (attacker in _npc_parties):
			continue   # 이전 전투로 제거됨.
		if not attacker.can_attack():
			continue
		var target = _adjacent_enemy(attacker)
		if target == null:
			continue
		attacker.mark_attacked()
		var ranged := _is_ranged_engagement(attacker, target)
		if target == party:
			await _run_battle(attacker, target, ranged)   # 플레이어가 방어 → 오버레이 관전
		else:
			_resolve_battle_headless(attacker, target, ranged)   # NPC끼리 → 즉시 결산
	_clear_player_alert()   # 적 턴 종료 → 경계 버프 해제(= 내 다음 턴)
	_update_fog()   # 헤드리스 전투로 바뀐 위치·제거를 안개·표시에 반영

## 플레이어 부대 멤버의 경계(alert) 버프를 모두 해제한다. NPC 공격 페이즈가 끝나거나 중단될 때 호출.
func _clear_player_alert() -> void:
	for u in _units:
		for m in u.members:
			m.alert = false

## attacker의 공격거리 이내에 있는 자기 외 부대를 찾는다(멤버 있는 것만). 없으면 null.
## (NPC가 사거리를 유지하며 포지셔닝하는 AI는 미구현 — 접근해 붙은 뒤 사거리 판정만 반영.)
func _adjacent_enemy(attacker):
	# 근접(사거리 0)은 인접(1)까지, 원거리는 사거리까지 공격 대상으로 본다.
	var reach: int = maxi(attacker.attack_range(), 1)
	var in_range := {}
	for c in HexGrid.cells_within(terrain, terrain.local_to_map(attacker.position), reach, MAP_WIDTH, MAP_HEIGHT):
		in_range[c] = true
	for other in [party] + _npc_parties:
		if other == attacker or other.members.is_empty():
			continue
		if in_range.has(terrain.local_to_map(other.position)):
			return other
	return null

## 한 세력의 부대들을 동시에(부대마다 NPC_PARTY_STAGGER 지연) 애니메이션하고, 전부 끝날 때까지 대기한다.
func _animate_faction(plans: Array) -> void:
	var max_dur := 0.0
	for i in plans.size():
		var path: Array = plans[i]["path"]
		var delay: float = i * NPC_PARTY_STAGGER
		_start_party_animation(plans[i]["party"], path, delay)
		var steps: int = maxi(0, path.size() - 1)
		max_dur = maxf(max_dur, delay + steps * MOVE_STEP_TIME)
	if max_dur > 0.0:
		await get_tree().create_timer(max_dur).timeout

## 부대를 경로(path)의 칸을 차례로 지나도록 Tween으로 이동시킨다(칸당 MOVE_STEP_TIME). delay 후 시작.
## 각 칸에 도착할 때마다 on_arrive.call(cell)을 실행한다(도착 시점이라 party.position == 그 칸).
## 플레이어·NPC 이동이 공유한다. 이동할 칸이 없으면(path < 2) null을 돌려준다.
func _animate_path(party, path: Array, delay: float, on_arrive: Callable) -> Tween:
	if path.size() < 2:
		return null
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	for i in range(1, path.size()):
		var cell: Vector2i = path[i]
		tw.tween_property(party, "position", terrain.map_to_local(cell), MOVE_STEP_TIME)
		tw.tween_callback(on_arrive.bind(cell))
	return tw

## NPC 한 부대의 이동 애니메이션. 각 칸 도착 시 그 칸의 시야 여부로 토큰 표시를 토글한다(안개).
func _start_party_animation(party, path: Array, delay: float) -> void:
	var tw := _animate_path(party, path, delay, func(cell: Vector2i) -> void:
		party.visible = fog.is_cell_visible(cell))
	if tw == null:
		return   # 제자리/도달 불가 — 이동 없음.
	_npc_move_targets[party] = path[path.size() - 1]
	tw.tween_callback(func() -> void: _npc_move_targets.erase(party))
	_npc_tweens.append(tw)
	tw.finished.connect(func() -> void: _npc_tweens.erase(tw))

## 진행 중인 NPC 이동을 즉시 끝낸다: 트윈을 죽이고 각 부대를 최종 목적지 칸으로 스냅.
func _finish_pending_npc_moves() -> void:
	for t in _npc_tweens.duplicate():
		if is_instance_valid(t) and t.is_valid():
			t.kill()
	_npc_tweens.clear()
	for party in _npc_move_targets:
		party.position = terrain.map_to_local(_npc_move_targets[party])
	_npc_move_targets.clear()

## 플레이어 부대를 start_cell에서 dest_cell까지 경로 따라 애니메이션 이동한다.
## 이동 중에는 좌클릭을 잠그고(_player_moving), 각 칸 도착마다 _update_fog로 시야를 연다.
## then_attack가 주어지면 이동 완료 후 그 적과 전투를 시작하고,
## 아니면 이동 후 공격 범위에 적이 있는지 재평가한다(빨강 재표시).
func _move_player_to(start_cell: Vector2i, dest_cell: Vector2i, then_attack = null) -> void:
	var path := HexGrid.reconstruct_path(terrain, start_cell, dest_cell, party.movement(), MAP_WIDTH, MAP_HEIGHT, _occupied_cells(party))
	_player_move_target = dest_cell
	var tw := _animate_path(party, path, 0.0, func(_cell: Vector2i) -> void: _update_fog())
	if tw == null:
		# 경로가 없으면(예외) 즉시 목적지로 마무리한다.
		party.position = terrain.map_to_local(dest_cell)
		_update_fog()
		_after_move(then_attack)
		return
	_player_moving = true
	_player_tween = tw
	tw.finished.connect(func() -> void:
		_player_moving = false
		_player_tween = null
		_after_move(then_attack))

## 이동 완료 후 처리. then_action이 근접 전투({enemy, occupy})나 점령({capture, absorb})이면 그걸 잇고,
## 없으면 재선택(메뉴·빨강 갱신).
func _after_move(then_action) -> void:
	if then_action != null:
		if then_action.has("capture"):
			_do_capture(then_action["capture"], then_action["absorb"])   # 이동 후 점령
		else:
			_begin_battle(then_action["enemy"], false, then_action["occupy"])   # 이동 후 근접 전투
		return
	if not party.can_rest():
		return
	# 이동 후에도 선택을 유지해 행동 메뉴([사격]·[대기])와 빨강 적 타일을 갱신한다.
	_select()

## 진행 중인 플레이어 이동을 즉시 끝낸다(턴 종료 시): 트윈을 죽이고 목적지로 스냅 + 시야 갱신.
func _finish_player_move() -> void:
	if not _player_moving:
		return
	if is_instance_valid(_player_tween) and _player_tween.is_valid():
		_player_tween.kill()
	party.position = terrain.map_to_local(_player_move_target)
	_player_moving = false
	_player_tween = null
	_update_fog()

## 선택을 해제하고 범위 표시를 지운다.
func _deselect() -> void:
	_selected = false
	party.set_selected(false)
	_mode = MODE_MOVE
	_popup_target = null
	_capture_target = null
	_reachable = {}
	_attack_targets = {}
	_capture_targets = {}
	_move_cells = []
	_attack_cells = []
	_capture_cells = []
	_shoot_cells = []
	_shoot_area_cells = []
	party_action_menu.close()
	var empty: Array[Vector2i] = []
	overlay.show_ranges(empty, empty)

## 부대 정보 패널을 연다. 우측 상단을 공유하는 부대 일람·건물 정보는 감춘다.
func _show_party_info(party_to_show) -> void:
	building_info.close()
	party_info.open(party_to_show)
	party_roster.hide()

## 부대 정보·건물 정보 패널을 닫고, 부대 일람을 다시 표시한다.
func _hide_party_info() -> void:
	building_info.close()
	party_info.close()
	party_roster.show()

## 부대 일람에서 항목을 클릭하면 그 부대 위치로 카메라를 즉시 이동한다(맵 범위 클램프).
func _on_party_focused(focused_party) -> void:
	camera.position = focused_party.position
	camera.position.x = clampf(camera.position.x, _min_pos.x, _max_pos.x)
	camera.position.y = clampf(camera.position.y, _min_pos.y, _max_pos.y)

## 캠프 메뉴에서 건물을 선택하면 건설 모드로 들어간다.
## 건물을 지을 수 있는 영역(영지 시야) 윤곽선을 파랑으로 표시한다 — 시야는 배치 중 변하지 않으므로 한 번만 계산한다.
func _on_build_selected(type_id: String, territory: Territory) -> void:
	_build_mode = true
	_build_type = type_id
	_build_territory = territory
	build_preview.clear()
	build_area.show_area(BuildPlanner.territory_vision(terrain, territory, MAP_WIDTH, MAP_HEIGHT))

## 건설 모드를 끝내고 미리보기·영역 윤곽선을 지운다.
func _exit_build_mode() -> void:
	_build_mode = false
	_build_type = ""
	_build_territory = null
	build_preview.clear()
	build_area.clear()

## 현재 시야·점유를 기준으로 그 셀에 건물을 놓을 수 있는지.
## 점유는 플레이어 건물 + NPC 거점 모두 — 적 캠프 발자국 위에 겹쳐 짓지 못하게 한다.
func _can_build_at(cell: Vector2i) -> bool:
	var vision := BuildPlanner.territory_vision(terrain, _build_territory, MAP_WIDTH, MAP_HEIGHT)
	var occupied := BuildPlanner.occupied_cells(_buildings + _npc_buildings)
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

## 줌 조절: 마우스 휠 / 트랙패드 두 손가락 스크롤 / 트랙패드 핀치.
## 값이 작을수록 확대이므로, 확대 = _zoom_level 감소.
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
			# 이동 애니메이션·전투·게임 오버 중에는 새 클릭(이동·선택·메뉴)을 무시한다. 줌은 위에서 이미 처리됨.
			if not _player_moving and not _in_battle and not _game_over:
				_handle_click(get_global_mouse_position())
	elif event is InputEventPanGesture:
		# 두 손가락 스크롤: 위로(delta.y<0) = 확대, 아래로 = 축소.
		_set_zoom(_zoom_level + event.delta.y * PAN_ZOOM_SPEED)
	elif event is InputEventMagnifyGesture and event.factor > 0.0:
		# 핀치: 벌리면(factor>1) 확대, 오므리면(factor<1) 축소.
		# factor<=0(비정상 입력)은 무시 — 0 나눗셈/NaN으로 zoom이 깨지지 않도록.
		_set_zoom(_zoom_level / event.factor)

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
