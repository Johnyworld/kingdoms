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

# NPC가 자기 캠프를 방어하는 반경(헥스). 이 안에 적 부대가 들어오면 그 침입자를 요격 우선한다.
const NPC_DEFEND_RADIUS := 5

# NPC가 후퇴를 판단할 때 주변 적 부대를 살피는 반경(헥스). 이 안에 자기보다 강한 적이 있으면 후퇴.
const NPC_RETREAT_SCAN := 6

# 표적 우선순위(무방비 캠프·약한 적)를 이 반경 안에서만 우대한다. 밖이면 기존 최근접 접근으로 폴백.
const NPC_PRIORITY_SCAN := 8

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
@onready var party = $Party   # 현재 활성(선택된) 플레이어 부대. 다른 부대 클릭 시 재할당된다. 모든 부대는 _units.
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
# 상호작용 모드. MOVE=파랑 이동 범위+공격가능 적(빨강)+중앙 메뉴, SHOOT=사격 가능 적(빨강)만, BOMBARD=투석 표적(빨강)만.
const MODE_MOVE := "move"
const MODE_SHOOT := "shoot"
const MODE_BOMBARD := "bombard"   # [투석] 선택 모드 — 사거리 내 성벽 적 거점·적 부대를 빨강 강조·클릭 발사 → siege-engines.md
var _mode := MODE_MOVE
var _move_cells: Array[Vector2i] = []     # 이동 범위(파랑) 표시용
# 공격 가능한 적: enemy 칸 → {enemy, cell, melee, shoot}. 빨강 오버레이·팝업·사격 판단에 쓴다.
var _attack_targets: Dictionary = {}
var _attack_cells: Array[Vector2i] = []   # 공격 가능 적 칸(MOVE에서 빨강)
var _shoot_cells: Array[Vector2i] = []    # 사격 가능 적 칸([사격] 활성 판정·타겟)
var _shoot_area_cells: Array[Vector2i] = []   # 사격 사거리 전체 칸(SHOOT 모드 빨강 오버레이)
# 투석 표적: 사거리 안 성벽 적 거점·적 부대. cell → {kind:"wall"/"party", ref}. [투석] 활성·BOMBARD 오버레이·클릭에 쓴다. → siege-engines.md
var _bombard_cells: Dictionary = {}
var _bombard_area_cells: Array[Vector2i] = []
# 인접 가능한 적 거점: 수비대 유무로 나뉜다. camp 칸 → {camp, stand}. 빨강 오버레이·클릭 팝업에 쓴다.
var _capture_targets: Dictionary = {}     # 무방비 거점(중심 타일에 부대 없음 — 점령 대상)
var _capture_cells: Array[Vector2i] = []
var _capture_target = null                # 거점 점령 팝업의 대상 항목({camp, stand})(없으면 아님)
var _merge_targets: Dictionary = {}       # 인접 아군 부대: cell → party(병합 대상)
var _merge_target = null                  # 병합 팝업의 대상 부대(없으면 아님)
var _popup_target = null                  # 적 클릭 팝업의 대상 항목(없으면 중앙 메뉴)
var _ladders: Array = []                  # 성벽 공성 사다리 레코드 {building, target_cell, from_cell, faction, countdown} → wall.md
var _siege_overlay: Node2D                # 사다리 시각화(코드 생성, _ready에서 추가)
var _undo_party = null                     # 되돌릴 수 있는 마지막 이동의 부대(없으면 null)
var _undo_cell: Vector2i                   # 그 부대의 이동 전 칸
var party_action_menu: PartyActionMenu    # 부대 행동 메뉴(코드 생성, _ready에서 추가)
var loot_menu: LootMenu                    # 약탈 패널(코드 생성, _ready에서 추가). 플레이어 승자 화물 노획.
var equip_menu: EquipMenu                   # 장비 관리 모달(코드 생성, _ready에서 추가). 노획 장비 장착·탈착.

# 턴 진행. 턴 종료 시 유닛 이동 리셋 + 영지 자원 수입.
var _turn := TurnManager.new()
var _units: Array = []          # 턴당 1회 이동하는 부대(주인공 부대 등).
var _npc_parties: Array = []    # NPC 부대. 안개 표시·턴 리셋·턴 종료 시 이동(NpcAi) 대상. 일람은 제외.
var _territories: Array = []    # 자원 수입을 받는 영지(플레이어). NPC 영지는 미포함(경제 미사용).
var _outpost_count := 0         # 캠프 건설로 만든 전초기지 수(이름 단조 증가 카운터).
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
var confirm_dialog: ConfirmDialog   # 확인 다이얼로그(코드 생성, _ready에서 추가). 철거 등 확인용(동작은 open 콜백).
var split_panel: SplitPanel         # 부대 분할 패널(코드 생성, _ready에서 추가)
var _split_new = null               # 분할 중 새로 만든 부대(닫을 때 비어 있으면 취소·제거)
var toast: Toast                    # 점령/함락 알림(코드 생성, _ready에서 추가)

const BATTLE_SCENE := preload("res://scenes/combat/battle.gd")
const SIEGE_BOMBARD_SCENE := preload("res://scenes/combat/siege_bombard.gd")   # 성벽 투석 관전 씬 → siege-engines.md
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
	_siege_overlay = load("res://scenes/siege/siege_overlay.gd").new()   # 사다리 시각화
	_siege_overlay.terrain = terrain
	_siege_overlay.ladders = _ladders
	add_child(_siege_overlay)
	# 첫 거점은 마을회관 티어로 시작(캠프에서 한 번 업그레이드된 상태) — 인구 상한 10, 시작부터 생산 건물 해금.
	building.setup(terrain, Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2), "town_hall")
	_buildings = [building]
	_setup_factions()
	_setup_parties()
	_place_party()
	_units = [party]
	_seed_garrisons()   # 각 거점 중심 타일에 주둔 부대 1개(소집병 4명) 배치 → garrison.md
	fog.setup(terrain, MAP_WIDTH, MAP_HEIGHT)
	_update_fog()   # 시야 + 수비 배지 갱신
	party_roster.set_parties(_units)
	party_roster.party_selected.connect(_on_party_focused)
	turn_hud.set_turn(_turn.number)
	turn_hud.ended.connect(_on_turn_ended)
	camp_menu.build_selected.connect(_on_build_selected)
	camp_menu.garrison_changed.connect(_on_garrison_changed)
	camp_menu.upgrade_requested.connect(_on_upgrade_requested)
	camp_menu.wall_requested.connect(_on_wall_requested)
	camp_menu.siege_produced.connect(_on_siege_produced)
	camp_menu.found_camp_requested.connect(_on_found_camp_requested)
	camp_menu.demolish_requested.connect(_on_camp_demolish_requested)
	building_info.demolish_requested.connect(_on_demolish_requested)
	party_action_menu = PartyActionMenu.new()   # 코드 생성 UI(camp_menu와 달리 .tscn 노드 없음)
	add_child(party_action_menu)
	party_action_menu.action_selected.connect(_on_party_action)

	loot_menu = LootMenu.new()   # 약탈 패널(코드 생성 UI)
	add_child(loot_menu)

	equip_menu = EquipMenu.new()   # 장비 관리 모달(코드 생성 UI)
	add_child(equip_menu)
	result_overlay = ResultOverlay.new()   # 결과 화면(코드 생성)
	add_child(result_overlay)
	result_overlay.dismissed.connect(_on_result_dismissed)
	confirm_dialog = ConfirmDialog.new()   # 확인 다이얼로그(코드 생성). 동작은 open의 콜백으로 넘긴다.
	add_child(confirm_dialog)
	split_panel = SplitPanel.new()   # 부대 분할 패널(코드 생성)
	add_child(split_panel)
	split_panel.changed.connect(_on_split_changed)
	split_panel.closed.connect(_on_split_closed)
	toast = Toast.new()   # 점령/함락 알림(코드 생성)
	add_child(toast)

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
	var ranges := HexGrid.movement_ranges(terrain, start, move_range, MAP_WIDTH, MAP_HEIGHT, _blocked_for(party))
	var move_cells: Array[Vector2i] = ranges["move"]
	_reachable = {}
	for c in move_cells:
		_reachable[c] = true
	_move_cells = move_cells
	_compute_attack_targets(start)
	_compute_camp_targets(start)
	_compute_merge_targets(start)
	_compute_bombard_targets(start)
	_refresh_overlay()

## 활성 부대 칸에 인접한 다른 플레이어 부대(멤버 있는 것)를 병합 대상으로 분류한다. cell → party.
func _compute_merge_targets(start: Vector2i) -> void:
	_merge_targets = {}
	var neighbors := terrain.get_surrounding_cells(start)
	for p in _units:
		if p == party or p.members.is_empty():
			continue
		var pcell := terrain.local_to_map(p.position)
		if pcell in neighbors:
			_merge_targets[pcell] = p

## 투석 표적을 분류한다 — 투석기 실은 부대면 사거리 밴드(min~max, 지형 무시 헥스 거리) 안 성벽 적 거점·적 부대. → siege-engines.md
## cell → {kind, ref, dist}. 성벽 거점은 footprint 각 셀을 매핑(성벽이 부대 셀을 덮으면 성벽 우선 — 성벽 먼저 부숴야 함).
func _compute_bombard_targets(start: Vector2i) -> void:
	_bombard_cells = {}
	_bombard_area_cells = []
	if not party.has_siege():
		return
	var rng: int = party.siege_fire_range()
	var min_r: int = party.siege_min_range()   # 밴드 하한 — 이보다 가까운 표적은 못 침
	if rng <= 0:
		return
	var dists: Dictionary = HexGrid.bfs_distances(terrain, start, rng, MAP_WIDTH, MAP_HEIGHT)
	for p in _npc_parties:   # 적 부대(유닛 투석)
		if not p.visible or p.members.is_empty():
			continue
		var ec: Vector2i = terrain.local_to_map(p.position)
		if dists.has(ec) and int(dists[ec]) >= min_r:
			_bombard_cells[ec] = {"kind": "party", "ref": p, "dist": int(dists[ec])}
	for b in _buildings + _npc_buildings:   # 성벽 적 거점(성벽 투석) — 부대 셀을 덮어써 성벽 우선
		if not (BuildingTypes.is_center(b.building_type) and b.is_walled()):
			continue
		var bf: String = b.territory.faction.name if (b.territory != null and b.territory.faction != null) else ""
		if bf == party.faction_name:
			continue   # 아군 성벽 제외
		for c in b.cells:
			if dists.has(c) and int(dists[c]) >= min_r:
				_bombard_cells[c] = {"kind": "wall", "ref": b, "dist": int(dists[c])}
	_bombard_area_cells = _bombard_cells.keys()   # 빨강 오버레이용 표적 셀

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
	var walls := _wall_blocked_cells(party.faction_name)   # 적 세력 성벽 안 부대는 표적 제외(성벽이 보호) → wall.md
	for p in _npc_parties:
		if not p.visible:
			continue
		var ec: Vector2i = terrain.local_to_map(p.position)
		if walls.has(ec):
			continue   # 성벽 안 수비대는 공격·사격 대상 아님
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

## 발견된 각 NPC 거점 중 인접 가능한 것을 분류한다. 수비대 있으면 공격 대상, 없으면 점령 대상(캠프 칸 → {camp, stand}).
func _compute_camp_targets(start: Vector2i) -> void:
	_capture_targets = {}
	_capture_cells = []
	for camp in _npc_buildings:
		if not camp.visible:
			continue   # 미발견(안개) 거점은 대상 아님
		if camp.is_walled() and not _breached_by(camp, party.faction_name):
			continue   # 성벽 있는 적 거점은 진입 불가 → 점령 대상 아님. 단 준비된 사다리로 돌파했으면 열린다. → wall.md
		# 방어됨 = 중심 타일에 그 거점 세력의 주둔 부대가 있음(일반 전투로 먼저 격파해야 함).
		# 격파 후 플레이어 부대가 중심에 진입해 서 있으면(적 세력 아님) 방어로 치지 않아 점령할 수 있다.
		if _camp_defender(camp) != null:
			continue
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
	elif _mode == MODE_BOMBARD:
		overlay.show_ranges(none, _bombard_area_cells)
	else:
		var red: Array[Vector2i] = []
		red.append_array(_attack_cells)
		red.append_array(_capture_cells)
		overlay.show_ranges(_move_cells, red)

## 모든 시야원(플레이어 부대 전부 + 맵의 모든 완성 건물)을 합쳐 현재 시야 셀을 계산하고 안개를 갱신한다.
func _update_fog() -> void:
	var visible := {}
	for u in _units:
		if u.members.is_empty():
			continue   # 사라진(빈) 부대는 시야 없음
		for c in HexGrid.cells_within(terrain, terrain.local_to_map(u.position), u.vision(), MAP_WIDTH, MAP_HEIGHT):
			visible[c] = true
	# 완성 건물(캠프·농장 등)의 시야. 건설 중 건물은 buildings_vision이 제외한다.
	for c in BuildPlanner.buildings_vision(terrain, _buildings, MAP_WIDTH, MAP_HEIGHT):
		visible[c] = true
	fog.update_visible(visible)
	_update_npc_visibility()
	_update_npc_building_visibility()
	_refresh_garrison_badges()   # 거점 위 주둔 부대 인원으로 "수비 N" 배지 갱신(이동·전투·점령 후)

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
	# 활성 부대 칸(이동 시작점). party가 null(전멸로 부대 0)이면 이동 관련 분기는 _selected=false라 안 타므로 더미.
	var party_cell := terrain.local_to_map(party.position) if party != null else Vector2i(-1, -1)
	var reachable: bool = _reachable.has(cell)
	var clicked := _building_at(cell)   # 플레이어 건물. 거점(캠프·마을회관·성)은 CAMP_MENU, 그 외는 BUILDING_INFO로 분기.
	var clicked_party := _player_party_at(cell)   # 그 칸의 플레이어 부대(선택/전환 대상).
	var clicked_npc := _npc_at(cell)    # 보이는 NPC 부대가 있으면 정보 표시/공격 대상.
	var clicked_npc_building := _npc_building_at(cell)   # 발견된 NPC 거점이면 정보 표시(NPC_BASE_INFO).
	var on_camp := clicked != null and BuildingTypes.is_center(clicked.building_type)
	var on_building := clicked != null and not BuildingTypes.is_center(clicked.building_type)

	# SHOOT 모드: 사격 가능 적을 클릭하면 제자리 사격, 그 외 클릭은 MOVE 모드로 취소.
	# 주둔 부대도 사격 가능(_can_fire) — 발사해도 주둔 유지(garrison.md 주둔 중 사격).
	if _selected and _mode == MODE_SHOOT:
		if _attack_targets.has(cell) and _attack_targets[cell]["shoot"] and _can_fire():
			var e: Dictionary = _attack_targets[cell]
			_shoot_enemy(e["enemy"])
		else:
			_enter_move_mode()
		return

	# BOMBARD 모드: 투석 표적(성벽 적 거점/적 부대)을 클릭하면 투석, 그 외 클릭은 MOVE 모드로 취소. → siege-engines.md
	if _selected and _mode == MODE_BOMBARD:
		if _bombard_cells.has(cell) and party.can_attack():
			var t: Dictionary = _bombard_cells[cell]
			if t["kind"] == "wall":
				_bombard_wall(t["ref"])   # 성벽 → 경량 관전 씬(SiegeBombard)
			else:
				# 적 부대 → battle.gd 통합 전투(투석기 전투원 포함, 밴드 거리). → siege-engines.md
				_begin_battle(t["ref"], int(t["dist"]), Vector2i(-1, -1), true)
		else:
			_enter_move_mode()
		return

	# MOVE 모드: 공격 가능한 적(빨강)을 클릭하면 [이동][공격][사격] 팝업.
	if _selected and _mode == MODE_MOVE and _attack_targets.has(cell) and party.can_attack():
		_open_enemy_popup(_attack_targets[cell])
		return

	# MOVE 모드: 무방비 적 거점(빨강)을 클릭하면 [흡수][파괴] 팝업. (방어된 거점은 그 주둔 부대를 일반 전투로 친다.)
	if _selected and _mode == MODE_MOVE and _capture_targets.has(cell) and party.can_attack():
		_open_capture_popup(_capture_targets[cell])
		return

	# MOVE 모드: 인접 아군 부대를 클릭하면 [병합] 팝업(전환 대신 병합 — 전환하려면 먼저 선택 해제).
	if _selected and _mode == MODE_MOVE and _merge_targets.has(cell):
		_open_merge_popup(_merge_targets[cell])
		return

	match ClickRouter.resolve(clicked_party != null, clicked_npc != null, on_camp, on_building, clicked_npc_building != null, _selected, reachable, party_info.visible):
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
			# 인접한 플레이어 부대가 있으면 수비대 편성도 가능하게 넘긴다.
			camp_menu.open(clicked, _party_at_camp(clicked), _can_demolish_camp(clicked))
		ClickRouter.BUILDING_INFO:
			# 내 건물(거점 아님)은 철거 가능. 거점(캠프·마을회관·성)은 CAMP_MENU로 라우팅되므로 여기 안 온다.
			_open_building_info(clicked, not BuildingTypes.is_center(clicked.building_type))
		ClickRouter.NPC_BASE_INFO:
			_open_building_info(clicked_npc_building, false)   # 적 거점 — 정보만(철거·건축 없음)
		ClickRouter.FOCUS_PARTY:
			if clicked_party == party:
				# 같은 활성 부대: 정보 표시 + (미선택이고 행동 가능하면 선택 / 선택 중이면 메뉴 복귀).
				_show_party_info(party)
				if not _selected and (party.can_move() or party.can_rest()):
					_select()
				elif _selected:
					_enter_move_mode()   # 재클릭 = 팝업/사격 취소하고 중앙 메뉴로 복귀
			else:
				# 다른 플레이어 부대로 전환: 기존 선택 해제 → 활성 부대 교체 → 정보·선택.
				if _selected:
					_deselect()
				party = clicked_party
				_show_party_info(party)
				if party.can_move() or party.can_rest():
					_select()
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

## 캠프 메뉴 대상 부대(주둔 부대·병사 구매용). 중심 타일 위 주둔 부대를 우선, 없으면 인접 부대. 없으면 null.
func _party_at_camp(camp) -> Party:
	for p in _units:
		if not p.members.is_empty() and terrain.local_to_map(p.position) == camp.center_cell():
			return p   # 중심 주둔 부대 우선(병사 구매·수비 귀속 대상)
	for p in _units:
		var pcell := terrain.local_to_map(p.position)
		if pcell in camp.cells:
			return p
		for c in camp.cells:
			if pcell in terrain.get_surrounding_cells(c):
				return p
	return null

## 그 칸에 선 플레이어 부대(멤버 있는 것)를 찾는다(없으면 null). 클릭 선택 판정에 쓴다.
func _player_party_at(cell: Vector2i) -> Party:
	for p in _units:
		if p.members.is_empty():
			continue
		if terrain.local_to_map(p.position) == cell:
			return p
	return null

## 병사 구매로 주둔 부대 병력이 바뀌면 부대 일람·안개(부대 시야)·수비 배지(_update_fog)를 갱신한다.
func _on_garrison_changed() -> void:
	party_roster.set_parties(_units)
	_update_fog()

## 각 거점(플레이어·NPC) 중심 타일에 주둔 부대 1개(소집병 4명)를 배치한다. → garrison.md
func _seed_garrisons() -> void:
	for b in _buildings:
		if BuildingTypes.is_center(b.building_type):
			_units.append(_spawn_garrison_party(b))
	for b in _npc_buildings:
		if BuildingTypes.is_center(b.building_type):
			_npc_parties.append(_spawn_garrison_party(b))

## 거점 중심 타일에 서는 주둔 부대(소집병 4명, stationed)를 만든다. 세력 색·소속 영지(home_territory).
func _spawn_garrison_party(b) -> Party:
	var p: Party = PARTY_SCENE.instantiate()
	add_child(p)
	p.party_name = "수비대"
	p.stationed = true
	p.home_territory = b.territory
	var fac: Faction = b.territory.faction if b.territory != null else null
	if fac != null:
		p.faction_name = fac.name
		p.token_color = fac.color
	for m in UnitTypes.make_garrison(4):
		p.add_member(m)
	if not p.members.is_empty():
		p.commander = p.members[0]
	p.position = terrain.map_to_local(b.center_cell())
	return p

## 그 칸에 선 멤버 있는 부대(플레이어·NPC 통틀어)를 반환한다. 없으면 null. 수비 배지·방어 판정에 쓴다.
func _party_on_cell(cell: Vector2i) -> Party:
	for p in _units + _npc_parties:
		if not p.members.is_empty() and terrain.local_to_map(p.position) == cell:
			return p
	return null

## 거점 중심 타일을 지키는 그 거점 세력의 부대(진짜 수비대). 없으면 null(무방비 → 점령 가능).
## 다른 세력 부대(격파 후 진입한 공격자 포함)가 서 있어도 그 거점 세력이 아니면 방어로 치지 않는다. → garrison.md
func _camp_defender(camp) -> Party:
	if camp.territory == null or camp.territory.faction == null:
		return null
	var holder := _party_on_cell(camp.center_cell())
	if holder != null and holder.faction_name == camp.territory.faction.name:
		return holder
	return null

## 각 거점의 "수비 N" 배지값을 그 거점 세력 수비 부대 인원으로 갱신한다(표시 전용).
## _camp_defender를 써서, 격파 후 중심에 선 적 부대(다른 세력)는 그 거점의 수비로 세지 않는다.
func _refresh_garrison_badges() -> void:
	for b in _buildings + _npc_buildings:
		if not BuildingTypes.is_center(b.building_type):
			continue
		var gp := _camp_defender(b)
		b.defender_count = gp.members.size() if gp != null else 0
		b.queue_redraw()

## 플레이어 세력의 빈 새 부대를 만들어 셀에 둔다(금색·플레이어 소속). 빈 부대라 채우기 전엔 토큰 안 보임.
func _make_player_party(pname: String, cell: Vector2i) -> Party:
	var p: Party = PARTY_SCENE.instantiate()
	add_child(p)
	p.party_name = pname
	p.faction_name = _player_faction.name
	p.position = terrain.map_to_local(cell)
	return p

## footprint(부대·캠프 발자국)에 인접한(발자국 밖) 빈 칸을 하나 찾는다. 맵 안·미점유·산 아님. 없으면 (-1,-1).
func _empty_adjacent_to(footprint: Array) -> Vector2i:
	var occ := _occupied_cells(null)
	for cc in footprint:
		for n in terrain.get_surrounding_cells(cc):
			if n in footprint:
				continue
			if n.x < 0 or n.y < 0 or n.x >= MAP_WIDTH or n.y >= MAP_HEIGHT:
				continue
			if occ.has(n):
				continue
			if terrain.get_cell_source_id(n) == Terrain.MOUNTAIN:
				continue   # 산엔 배치 안 함(이동 불가 지형)
			return n
	return Vector2i(-1, -1)

## [분할]: 활성 부대 인접 빈 칸에 빈 새 부대를 만들고 분할 패널을 연다(멤버를 나눠 담는다).
func _split_party() -> void:
	var cell := _empty_adjacent_to([terrain.local_to_map(party.position)])
	if cell == Vector2i(-1, -1):
		return
	_split_new = _make_player_party("분할 부대", cell)
	_units.append(_split_new)
	party_action_menu.close()
	split_panel.open(party, _split_new)
	party_roster.set_parties(_units)
	_update_fog()

## 분할 패널에서 멤버가 이동하면 일람·안개를 갱신한다.
func _on_split_changed() -> void:
	party_roster.set_parties(_units)
	_update_fog()

## 분할 패널을 닫으면: 새 부대가 비면(아무도 안 옮김) 취소로 제거(소비 없음),
## 확정이면 원·새 부대 둘 다 이번 턴 행동 종료(재조직 비용). 이어서 선택 상태를 갱신한다.
func _on_split_closed() -> void:
	if _split_new != null:
		if _split_new.members.is_empty():
			# 취소 — 새 부대로 옮겨둔 화물·노획 장비를 원 부대로 회수(소실 방지) 후 제거.
			party.take_all_loot(_split_new)   # 화물 회수(초과 허용 — 원래 원 부대 것)
			party.loot_items.append_array(_split_new.loot_items)
			_units.erase(_split_new)
			_split_new.queue_free()
		else:
			party.mark_attacked()          # 분할 확정 → 양쪽 이번 턴 종료
			_split_new.mark_attacked()
	_split_new = null
	party_roster.set_parties(_units)
	_update_fog()
	if _selected and not party.members.is_empty():
		_select()   # 멤버 변동 반영(범위·메뉴 갱신)
	else:
		_deselect()

## [병합]: 인접 아군 부대 other를 활성 부대로 흡수하고 other를 맵에서 제거한다(턴 소비 없음).
func _merge_party(other) -> void:
	party.merge_from(other)
	_units.erase(other)
	other.queue_free()
	party.mark_attacked()   # 병합(재조직) → 이번 턴 행동 종료
	party_roster.set_parties(_units)
	_update_fog()
	if _selected:
		_select()   # 병력 증가 반영(범위·메뉴 갱신 — 행동 종료라 메뉴는 닫힘)

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
func _open_building_info(b, can_demolish := false) -> void:
	if _selected:
		_deselect()
	party_info.close()
	party_roster.hide()
	building_info.open(b, can_demolish)

## 건물 정보 패널의 철거 버튼 → 영지에서 제거·자재 환급 → 맵/추적 목록에서 제거 → 안개 갱신 → 패널 닫기.
## 노드 free는 지연 호출한다(버튼 pressed 처리 중이라 즉시 free하면 "locked" 에러).
## 캠프 메뉴의 업그레이드 버튼 → 거점을 다음 티어로 제자리 업그레이드.
## 비용 지불(build_pay) → 티어업(upgrade_to) → 안개 갱신(티어별 시야) → 캠프 메뉴 재오픈으로 표시 갱신.
func _on_upgrade_requested(b) -> void:
	var next_id := BuildingTypes.next_center(b.building_type)
	if next_id == "" or b.territory == null or not BuildPlanner.can_upgrade(b.territory, b):
		return
	b.territory.build_pay(next_id)   # 자재 차감(거점은 필요인원 0)
	b.upgrade_to(next_id)
	_update_fog()                    # 티어별 시야 변화 반영
	camp_menu.open(b, _party_at_camp(b), _can_demolish_camp(b))   # 갱신된 정보(상한·업그레이드 버튼)로 재오픈

## 성벽 건설 버튼 → 자재 지불 + wall_level 설정. 마을회관·성 + 자재 충분일 때만. → wall.md
func _on_wall_requested(b) -> void:
	if not BuildingTypes.can_build_wall(b.territory, b):
		return
	b.territory.spend(BuildingTypes.WALL_COST)   # 자재 차감
	b.wall_level = 1
	b.wall_hp = Siege.WALL_MAX_HP   # 성벽 내구도 만피 — 투석으로 깎이면 붕괴 → siege-engines.md
	b.queue_redraw()   # 성벽 링 그리기
	camp_menu.open(b, _party_at_camp(b), _can_demolish_camp(b))   # 갱신된 정보(성벽 버튼 숨김·자원)로 재오픈

## 투석기 생산 버튼 → 금·자재 지불 + 주둔 부대에 투석기 편입. 완성 작업장·주둔 부대·자원 충분일 때만. → siege-engines.md
func _on_siege_produced(b) -> void:
	var party = _party_at_camp(b)
	if party == null or b.territory == null or not b.territory.has_completed_building("siege_workshop"):
		return
	var cost := SiegeTypes.produce_full_cost(SiegeTypes.CATAPULT)
	if not b.territory.can_afford(cost):
		return
	b.territory.spend(cost)   # 금·자재 차감(인구 비소모)
	party.add_siege_unit(SiegeUnit.new(SiegeTypes.CATAPULT))
	party_roster.set_parties(_units)   # 일람·정보 갱신
	camp_menu.open(b, _party_at_camp(b), _can_demolish_camp(b))   # 갱신된 정보로 재오픈

## 철거 버튼 → 바로 철거하지 않고 확인 다이얼로그를 띄운다(환급 미리보기 포함). [철거] 확인 시 _do_demolish(b).
func _on_demolish_requested(b) -> void:
	var label: String = BuildingTypes.get_type(b.building_type).get("label", "건물")
	confirm_dialog.open("「%s」 철거 — %s" % [label, _refund_text(b)], "철거", _do_demolish.bind(b))

## 실제 환급(refund_on_demolish — 완성 salvage / 건설 중 build_cost 비례)을 "환급: 목재 2, 석재 1" 형태로. 없으면 "환급 없음".
func _refund_text(b) -> String:
	var refund: Dictionary = b.refund_on_demolish()
	if refund.is_empty():
		return "환급 없음"
	var parts: Array = []
	for res in refund:
		parts.append("%s %d" % [res, refund[res]])
	return "환급: " + ", ".join(parts)

## 실제 철거(확인 다이얼로그 [철거] 확정 콜백): 영지 제거·환급 → 추적 목록 제거 → 노드 free → 안개·패널 정리.
func _do_demolish(b) -> void:
	if not is_instance_valid(b):
		return   # 다이얼로그가 열린 사이 다른 경로로 건물이 제거됐으면 무시
	if b.territory != null:
		b.territory.demolish(b)   # 영지에서 떼고 refund_on_demolish 환급(완성 salvage / 건설 중 비례)
	_buildings.erase(b)
	building_info.close()
	b.queue_free.call_deferred()
	_update_fog()   # 철거된 건물 시야 제거

## 캠프 철거 가능 판정: 캠프(tier 0)·내 세력 영지·마지막 거점 아님(세력 소멸 방지)일 때만.
## 마을회관·성은 거짓(다운그레이드 미구현). 캠프 메뉴 [철거] 버튼 노출 여부.
func _can_demolish_camp(b) -> bool:
	if b == null or b.building_type != BuildingTypes.CAMP:
		return false
	if b.territory == null or b.territory.faction != _player_faction:
		return false
	return _faction_center_count(_player_faction) > 1   # 마지막 거점이면 불가

## 캠프 메뉴 [철거] → 확인 다이얼로그(영지 포기 경고) → [철거] 확인 시 _do_demolish_camp.
func _on_camp_demolish_requested(camp) -> void:
	var terr_name: String = camp.territory.name if camp.territory != null else "영지"
	confirm_dialog.open("「%s」 캠프를 철거하고 영지를 포기할까요?" % terr_name, "철거", _do_demolish_camp.bind(camp))

## 캠프 철거 확정: 그 영지의 모든 건물을 제거하고 영지를 세력·게임에서 분리한다(영지 통째 상실, 환급 없음).
func _do_demolish_camp(camp) -> void:
	if not is_instance_valid(camp):
		return
	var territory = camp.territory
	var terr_name: String = territory.name if territory != null else "영지"
	if territory != null:
		for b in territory.buildings.duplicate():   # 캠프 포함 모든 건물
			_buildings.erase(b)
			territory.remove_building(b)
			if is_instance_valid(b):
				b.queue_free.call_deferred()
		if territory.faction != null:
			territory.faction.remove_territory(territory)   # 세력에서 영지 분리
		_territories.erase(territory)   # 수입·플레이어 영지 목록에서 제외
	camp_menu.close_menu()
	_update_fog()
	toast.show_message("%s 철거 — 영지 포기" % terr_name)

## exclude를 뺀 모든 부대(플레이어 전부 + NPC)가 점유한 칸 집합({cell: true}). 이동 장애물로 넘긴다.
## 빈 부대(멤버 0)도 칸을 차지한다 — 새로 편성한 빈 부대가 자리를 지켜 겹침(두 부대가 한 칸)을 막는다.
func _occupied_cells(exclude) -> Dictionary:
	var occ := {}
	for p in _units + _npc_parties:
		if p == exclude:
			continue
		occ[terrain.local_to_map(p.position)] = true
	return occ

## faction_name 세력이 아닌 성벽 있는 거점들의 footprint 칸 집합({cell: true}). 그 세력에겐 완전 장애물·표적 제외.
## 단 그 세력의 준비된(countdown 0) 사다리가 연 통로(대상 ring 셀 + 중심)는 제외한다(방향 제한 돌파). → wall.md
func _wall_blocked_cells(faction_name: String) -> Dictionary:
	var blocked := {}
	for b in _buildings + _npc_buildings:
		if not (BuildingTypes.is_center(b.building_type) and b.is_walled()):
			continue
		var bf: String = b.territory.faction.name if (b.territory != null and b.territory.faction != null) else ""
		if bf == faction_name:
			continue   # 같은 세력 성벽은 통행·표적 자유
		var open_cells := _ladder_corridor(b, faction_name)   # 준비된 사다리가 연 통로 셀
		for c in b.cells:
			if open_cells.has(c):
				continue
			blocked[c] = true
	return blocked

## faction_name의 준비된 사다리가 거점 b에 대해 여는 통로 셀 집합(대상 ring 셀 + 중심). 없으면 빈 Dictionary. → wall.md
func _ladder_corridor(b, faction_name: String) -> Dictionary:
	var open_cells := {}
	for L in _ladders:
		if L["building"] == b and L["faction"] == faction_name and L["countdown"] <= 0:
			open_cells[L["target_cell"]] = true
			open_cells[b.center_cell()] = true
	return open_cells

## faction_name이 거점 b를 사다리로 돌파했는지(준비된 사다리 있음). 점령·공격 대상 판정에 쓴다.
func _breached_by(b, faction_name: String) -> bool:
	return not _ladder_corridor(b, faction_name).is_empty()

## party의 이동 장애물 = 다른 부대 점유 칸 + 적 세력 성벽 거점 footprint. 이동 범위·경로에 넘긴다. → wall.md
func _blocked_for(party) -> Dictionary:
	var occ := _occupied_cells(party)
	if party != null:
		for c in _wall_blocked_cells(party.faction_name):
			occ[c] = true
	return occ

## NPC 세력 fn이 향할 타깃 칸 목록. 적 부대·캠프로 진격하되, 자기 캠프가 위협받으면 침입자를 요격 우선.
## party_entries·camp_entries는 세력 무관하게 같으므로 _move_npcs가 턴당 한 번만 만들어 넘긴다.
## (enemy_cells가 세력으로 걸러 자기 부대·아군·자기 캠프는 자동 제외된다.)
func _npc_targets(p, party_entries: Array, camp_entries: Array) -> Array:
	var fn: String = p.faction_name
	# 약하면 후퇴: 근처 적이 자기보다 강하면 (적이 없는) 자기 캠프로 물러선다. 안전한 캠프가 없으면 후퇴 안 함.
	if _should_retreat(p):
		var safe := _safe_retreat_cells(fn)
		if not safe.is_empty():
			return safe
	# 표적 우선순위: 근처(NPC_PRIORITY_SCAN) 무방비 적 캠프 > 근처 약한 적 부대 > 나머지(전체 적 셀, 최근접 폴백).
	var my_power := NpcAi.party_power(p.members)
	var near := {}
	for c in HexGrid.cells_within(terrain, terrain.local_to_map(p.position), NPC_PRIORITY_SCAN, MAP_WIDTH, MAP_HEIGHT):
		near[c] = true
	var undefended: Array = []
	for b in _buildings + _npc_buildings:
		if not BuildingTypes.is_center(b.building_type) or _party_on_cell(b.center_cell()) != null:
			continue   # 중심 타일에 수비 부대가 있으면 방어됨 — 무방비 목록 제외
		if b.is_walled():
			continue   # 성벽 있으면 진입 불가 — 손쉬운 점령 대상 아님 → wall.md
		var bf := ""
		if b.territory != null and b.territory.faction != null:
			bf = b.territory.faction.name
		if bf != fn and near.has(b.center_cell()):
			undefended.append(b.center_cell())
	var weak: Array = []
	for other in _units + _npc_parties:
		if other == p or other.members.is_empty() or other.faction_name == fn:
			continue
		var ocell := terrain.local_to_map(other.position)
		if near.has(ocell) and NpcAi.party_power(other.members) <= my_power:
			weak.append(ocell)
	var rest: Array = NpcAi.enemy_cells(fn, party_entries) + NpcAi.enemy_cells(fn, camp_entries)
	var advance := NpcAi.prioritize([undefended, weak, rest])
	var defend := _threats_near_own_camp(fn, party_entries)
	return NpcAi.select_targets(advance, defend)

## NPC p가 후퇴해야 하는지 — NPC_RETREAT_SCAN 반경 안 적 부대 중 가장 강한 것과 비교해 교전이 불리하면 참.
func _should_retreat(p) -> bool:
	var scan := {}
	for c in HexGrid.cells_within(terrain, terrain.local_to_map(p.position), NPC_RETREAT_SCAN, MAP_WIDTH, MAP_HEIGHT):
		scan[c] = true
	var my_power := NpcAi.party_power(p.members)
	var worst := 0
	for other in _units + _npc_parties:
		if other == p or other.members.is_empty() or other.faction_name == p.faction_name:
			continue
		if scan.has(terrain.local_to_map(other.position)):
			worst = maxi(worst, NpcAi.party_power(other.members))
	return worst > 0 and not NpcAi.should_engage(my_power, worst)

## 세력 fn의 후퇴 목적지(캠프 중심). 적 부대가 가까이(2칸) 있는 캠프는 제외한다 — 위협받는 캠프로 도망치지 않게.
func _safe_retreat_cells(fn: String) -> Array:
	var out: Array = []
	for b in _buildings + _npc_buildings:
		if not BuildingTypes.is_center(b.building_type):
			continue
		if b.territory == null or b.territory.faction == null or b.territory.faction.name != fn:
			continue
		if _enemy_near(b.center_cell(), fn, 2):
			continue   # 적이 가까운 캠프로는 후퇴 안 함
		out.append(b.center_cell())
	return out

## cell 반경 radius 안에 세력 fn이 아닌(적) 부대가 있는지.
func _enemy_near(cell: Vector2i, fn: String, radius: int) -> bool:
	var near := {}
	for c in HexGrid.cells_within(terrain, cell, radius, MAP_WIDTH, MAP_HEIGHT):
		near[c] = true
	for other in _units + _npc_parties:
		if other.members.is_empty() or other.faction_name == fn:
			continue
		if near.has(terrain.local_to_map(other.position)):
			return true
	return false

## 살아 있는 모든 부대를 {cell, faction} 목록으로. NpcAi.enemy_cells의 입력(세력 필터가 자기 부대를 걸러낸다).
func _party_entries() -> Array:
	var out: Array = []
	for p in _units + _npc_parties:
		if p.members.is_empty():
			continue
		out.append({"cell": terrain.local_to_map(p.position), "faction": p.faction_name})
	return out

## 맵의 모든 캠프를 {cell(중심), faction} 목록으로. territory/faction이 없는 고아 캠프는 빈 문자열(방어적 기본값 — 현재는 발생 안 함).
func _camp_entries() -> Array:
	var out: Array = []
	for b in _buildings + _npc_buildings:
		if not BuildingTypes.is_center(b.building_type):
			continue
		var cf := ""
		if b.territory != null and b.territory.faction != null:
			cf = b.territory.faction.name
		out.append({"cell": b.center_cell(), "faction": cf})
	return out

## 세력 fn의 캠프 중심 NPC_DEFEND_RADIUS 이내로 침입한 적 부대 칸 목록(방어 타깃). 자기 캠프 없으면 빈 배열.
func _threats_near_own_camp(fn: String, party_entries: Array) -> Array:
	var near := {}
	for b in _buildings + _npc_buildings:
		if BuildingTypes.is_center(b.building_type) and b.territory != null and b.territory.faction != null and b.territory.faction.name == fn:
			for cell in HexGrid.cells_within(terrain, b.center_cell(), NPC_DEFEND_RADIUS, MAP_WIDTH, MAP_HEIGHT):
				near[cell] = true
	if near.is_empty():
		return []
	var out: Array = []
	for e in party_entries:
		if e["faction"] != fn and near.has(e["cell"]):
			out.append(e["cell"])
	return out

## [공격] 근접: 적 인접 칸으로 이동 후 근접 전투. 승리 시 수비 타일 점령.
func _melee_attack(entry: Dictionary) -> void:
	var start := terrain.local_to_map(party.position)
	var ecell: Vector2i = entry["cell"]
	var stand := _adjacent_stand(ecell, start)
	if stand == start:
		_begin_battle(entry["enemy"], 1, ecell)   # 이미 인접 — 제자리 근접 전투(거리 1)
		return
	party.mark_moved()
	_deselect()
	_hide_party_info()
	_move_player_to(start, stand, {"enemy": entry["enemy"], "occupy": ecell})

## [사격]: 현재 위치에서 원거리 전투(이동·점령 없음). 거리 = 부대↔적 헥스 거리.
func _shoot_enemy(enemy) -> void:
	_begin_battle(enemy, _engagement_distance(party, enemy), Vector2i(-1, -1))

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
		_transfer_camp(camp, _player_faction)
	else:
		_destroy_camp(camp)
	if _selected:
		_deselect()
	_hide_party_info()
	_update_fog()
	party_roster.set_parties(_units)

## 소유권 이전(점령 흡수, 플레이어·NPC 공용): 캠프의 영지를 new_faction으로 옮기고 건물 리스트를 재배치한다.
## 플레이어면 _buildings(시야·건축·수입 획득), NPC면 _npc_buildings(수입 제외). 라벨색·시야는 이후 _update_fog가 반영.
func _transfer_camp(camp, new_faction) -> void:
	_clear_ladders(camp)   # 소유권 바뀌면 그 거점 사다리 무효 → wall.md
	var territory = camp.territory
	var terr_name: String = territory.name if territory != null else ""
	var old_name: String = territory.faction.name if (territory != null and territory.faction != null) else ""
	if territory != null:
		if territory.faction != null:
			territory.faction.remove_territory(territory)
		new_faction.add_territory(territory)
	# 알림: 플레이어가 얻으면 점령, 플레이어가 잃으면 함락(NPC↔NPC는 조용히).
	if new_faction == _player_faction:
		toast.show_message("%s 점령!" % terr_name)
	elif old_name == _player_faction.name:
		toast.show_message("%s 함락!" % terr_name)
	_buildings.erase(camp)
	_npc_buildings.erase(camp)
	if new_faction == _player_faction:
		_buildings.append(camp)
		if territory != null and not (territory in _territories):
			_territories.append(territory)   # 플레이어 영지는 턴 수입 대상
	else:
		_npc_buildings.append(camp)
		if territory != null:
			_territories.erase(territory)    # 잃은 영지는 수입에서 제외
	camp.visible = true       # 이전 직후 표시(NPC 캠프는 _update_npc_building_visibility가 탐험 기준으로 재조정)
	camp.queue_redraw()       # 라벨색을 새 세력색으로 갱신
	_check_immediate_defeat()   # 플레이어가 캠프를 뺏겼으면 — 부대도 없으면 즉시 패배

## 파괴: 캠프를 영지·맵에서 제거한다(획득 없음). 영지·세력은 남지만 캠프 0개가 된다(소멸 판정은 다음 슬라이스).
func _destroy_camp(camp) -> void:
	_clear_ladders(camp)   # 파괴된 거점 사다리 제거 → wall.md
	var terr_name: String = camp.territory.name if camp.territory != null else ""
	if camp.territory != null:
		camp.territory.remove_building(camp)
	_npc_buildings.erase(camp)
	camp.queue_free()
	toast.show_message("%s 파괴!" % terr_name)   # 플레이어만 파괴 → 항상 플레이어 행동

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
## distance=교전 헥스 거리(근접=1), occupy_cell=근접 승리 시 이동할 수비 타일((-1,-1)이면 점령 없음). → battle.md
func _begin_battle(defender, distance: int, occupy_cell: Vector2i, include_siege := false) -> void:
	party.mark_attacked()
	_undo_party = null   # 공격/사격은 되돌릴 수 없다
	if _selected:
		_deselect()
	_hide_party_info()
	_run_battle(party, defender, distance, occupy_cell, include_siege)   # 비차단(await로 백그라운드 진행)

## 두 부대의 교전 헥스 거리. 인접(또는 같은 칸)이면 1(근접), 아니면 a 기준 헥스 거리(사거리 범위 내). → battle.md
func _engagement_distance(a, b) -> int:
	var acell := terrain.local_to_map(a.position)
	var bcell := terrain.local_to_map(b.position)
	if acell == bcell or bcell in terrain.get_surrounding_cells(acell):
		return 1   # 인접 = 근접 교전
	var reach: int = maxi(a.attack_range(), 1)
	var dists: Dictionary = HexGrid.bfs_distances(terrain, acell, reach, MAP_WIDTH, MAP_HEIGHT)
	return int(dists.get(bcell, reach))   # 사거리 범위 내에서만 개시하므로 보통 존재; 밖이면 reach로 클램프

## 오버레이 전투를 띄우고 관전한다(입력 잠금). 종료까지 await 후 사상자를 반영한다.
## occupy_cell != (-1,-1)이고 근접 승리(수비 전멸·공격 생존)면 공격 부대를 그 타일로 이동(점령).
func _run_battle(attacker, defender, distance := 1, occupy_cell := Vector2i(-1, -1), include_siege := false) -> void:
	_in_battle = true
	var overlay := BATTLE_SCENE.new()
	add_child(overlay)
	overlay.start(attacker, defender, distance, include_siege)
	var result: Array = await overlay.finished   # [a_survivors, b_survivors]
	overlay.queue_free()
	await _resolve_loot(attacker, defender, result[0], result[1])   # 전멸한 패자 화물 노획(플레이어 승자면 패널)
	_apply_survivors(attacker, result[0])
	_apply_survivors(defender, result[1])
	if include_siege:   # 투석 결투로 파괴된 투석기 제거(hp≤0). → siege-engines.md
		attacker.prune_destroyed_siege()
		defender.prune_destroyed_siege()
	_in_battle = false
	if occupy_cell != Vector2i(-1, -1) and defender.members.is_empty() and not attacker.members.is_empty():
		attacker.position = terrain.map_to_local(occupy_cell)   # 근접 승리 → 수비 타일 점령
	_update_fog()
	party_roster.set_parties(_units)
	# 부대 전멸로는 게임 오버되지 않는다(점령 승리만). 승패는 세력 소멸 판정(_update_endgame)에서만 난다.

## 세력 소멸 유예 판정(턴 종료마다). 각 세력의 캠프 수로 유예 카운트를 갱신하고, 소멸한 세력은 붕괴시킨다.
## 이어서 정복 승리/플레이어 세력 소멸 패배를 판정한다.
## 즉시 패배 확인: 플레이어가 거점도 부대도 모두 잃으면(수복 수단 전무) 유예 없이 즉시 게임 오버.
## 부대 전멸(_apply_survivors)·거점 상실(_transfer_camp)·턴 종료(_update_endgame)마다 호출한다.
func _check_immediate_defeat() -> void:
	if _game_over:
		return
	var has_center := _faction_center_count(_player_faction) > 0
	var has_party := _first_living_unit() != null
	if GameResult.immediate_defeat(has_center, has_party):
		_player_faction.eliminated = true
		_trigger_game_over("패배", "거점과 부대를 모두 잃었다")

func _update_endgame() -> void:
	if _game_over:
		return
	_check_immediate_defeat()   # 거점·부대 동시 상실 → 유예 없이 즉시 패배(유예 판정보다 먼저)
	if _game_over:
		return
	for f in _factions:
		if f.eliminated:
			continue
		var has_post := _faction_center_count(f) > 0
		f.grace_turns = GameResult.advance_grace(has_post, f.grace_turns)
		if GameResult.grace_eliminated(f.grace_turns):
			f.eliminated = true
			_eliminate_faction(f)
	_refresh_grace_hud()
	_check_endgame()

## 세력의 거점 수 = 소속 영지의 건물 중 거점(캠프·마을회관·성) 개수. 하나라도 있으면 세력 유지.
func _faction_center_count(faction) -> int:
	var n := 0
	for t in faction.territories:
		for b in t.buildings:
			if is_instance_valid(b) and BuildingTypes.is_center(b.building_type):
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
func _resolve_battle_headless(attacker, defender, distance := 1) -> void:
	var result := BattleSim.resolve_battle(attacker.members, defender.members, _rng, distance)
	_resolve_loot(attacker, defender, result["a"], result["b"])   # NPC 승자 → 전량 자동(패널 없음)
	_apply_survivors(attacker, result["a"])
	_apply_survivors(defender, result["b"])

## 전투 결과(생존자)로 한쪽만 전멸했으면 승자가 패자 화물을 노획한다([약탈](../../docs/spec/features/raid.md)).
## _apply_survivors(패자 queue_free)보다 먼저 호출해야 패자 화물을 읽을 수 있다.
## 승자가 NPC면 전량 자동, 플레이어 부대면 약탈 패널을 띄우고 닫힐 때까지 await한다.
func _resolve_loot(attacker, defender, a_survivors: Array, b_survivors: Array) -> void:
	var a_alive := not a_survivors.is_empty()
	var b_alive := not b_survivors.is_empty()
	if a_alive == b_alive:
		return   # 양쪽 생존(후퇴) 또는 양쪽 전멸(상호) → 약탈 없음
	var winner = attacker if a_alive else defender
	var loser = defender if a_alive else attacker
	var dropped: Array = loser.equipment_ids()   # 전사자 장비 스냅샷(_apply_survivors 전이라 멤버 살아있음)
	if loser.cargo_total() <= 0 and dropped.is_empty():
		return   # 노획할 화물·장비 없음
	# 승자 부대가 노획물을 보유한다(주둔 부대도 지속 부대라 동일 — 영지 귀속 없음). → raid.md
	# 플레이어 세력이면 선택 패널(화물+장비), NPC 세력이면 전량 자동.
	if winner.faction_name == _player_faction.name:
		loot_menu.open(winner, loser, dropped)
		await loot_menu.closed
	else:
		winner.take_all_loot(loser)
		winner.take_all_equipment(loser)

## 부대 멤버를 생존자로 교체한다. 지휘관 사망 시 재지정, 전멸(생존자 0)한 부대는 NPC·플레이어 모두 맵에서 제거.
## 전멸한 게 활성 party였으면 선택 해제 + 남은 살아있는 부대로 재할당(없으면 null — 부대 0이어도 패배 아님, 세력 소멸은 거점 0에서만).
func _apply_survivors(p, survivors: Array) -> void:
	p.members = survivors
	if not (p.commander in survivors):
		p.commander = survivors[0] if not survivors.is_empty() else null
	if not survivors.is_empty():
		return
	# 전멸 — 부대를 맵에서 제거한다(NPC·플레이어 모두 껍데기 안 남김).
	if p in _npc_parties:
		_npc_parties.erase(p)
		p.queue_free()
	elif p in _units:
		_units.erase(p)
		if party == p:   # 활성 부대가 전멸 → 선택 해제 + 남은 살아있는 부대로 재할당(없으면 null)
			if _selected:
				_deselect()
			_hide_party_info()
			party = _first_living_unit()   # 부대 0이면 null(패배 아님 — 세력 소멸은 거점 0에서만)
		p.queue_free()
		party_roster.set_parties(_units)
		_check_immediate_defeat()   # 부대 전멸 — 거점도 없으면 즉시 패배

## _units 중 멤버가 있는(살아있는) 첫 부대. 없으면 null. 활성 부대 재할당에 쓴다.
func _first_living_unit():
	for u in _units:
		if not u.members.is_empty():
			return u
	return null

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

## BOMBARD 모드: 투석 표적(성벽 적 거점·적 부대, 빨강)만, 메뉴 감춤. 표적 클릭 시 투석. → siege-engines.md
func _enter_bombard_mode() -> void:
	_mode = MODE_BOMBARD
	_refresh_overlay()
	party_action_menu.close()

## 중앙 부대 메뉴를 부대 토큰 근처에 연다. 주둔 중이면 [주둔 종료], 그 외 행동 가능할 때 [사격][휴식][경계](+분할·주둔).
func _open_action_menu() -> void:
	_clear_popup_targets()
	if party.stationed:
		# 주둔 부대 — 사거리 안 사격 가능 적 있고 미발사면 [사격](주둔 유지), 자기 거점 겨눈 사다리 있으면 [사다리 밀기] + [주둔 종료].
		var can_fire_now: bool = not _shoot_cells.is_empty() and _can_fire()
		party_action_menu.open(PartyActionMenu.party_actions(false, can_fire_now, false, false, false, true, false, _can_push_ladder(party)), _screen_pos(party.position))
		return
	if party.can_rest():
		var can_undo: bool = _undo_party == party
		var can_ladder: bool = not party.moved_this_turn and not _ladder_target_for(party).is_empty()   # 성벽 적 거점 인접 + 미이동
		var can_bombard: bool = party.has_siege() and party.can_attack() and not _bombard_cells.is_empty()   # 투석기 실음 + 사거리 안 표적(성벽/적 부대) → siege-engines.md
		party_action_menu.open(PartyActionMenu.party_actions(party.moved_this_turn, not _shoot_cells.is_empty(), can_undo, _can_split(), _on_own_center(), false, can_ladder, false, can_bombard), _screen_pos(party.position))
	else:
		party_action_menu.close()

## 활성 부대가 분할 가능한지 — 멤버 2명 이상이고 인접 빈 칸이 있어야 한다.
func _can_split() -> bool:
	return party.members.size() >= 2 and _empty_adjacent_to([terrain.local_to_map(party.position)]) != Vector2i(-1, -1)

## 이번 턴 사격 가능한지 — 일반 부대는 can_attack, 주둔 부대는 아직 발사 안 했으면 가능(주둔 유지한 채 사격). → garrison.md
func _can_fire() -> bool:
	return party.can_attack() or (party.stationed and not party.attacked_this_turn)

## 활성 부대가 자기 세력 거점 중심 타일 위에 있는지([주둔] 버튼 노출 조건). → garrison.md
func _on_own_center() -> bool:
	if party == null:
		return false
	var cell := terrain.local_to_map(party.position)
	for b in _buildings:
		if BuildingTypes.is_center(b.building_type) and b.center_cell() == cell:
			return true
	return false

## 부대가 인접한 성벽 적 거점의 사다리 설치 대상 {building, target_cell}. 없으면 빈 Dictionary. → wall.md
## 부대는 성벽 밖에 있으므로, 인접한 footprint 셀(ring)이 사다리가 걸릴 대상 면이다.
func _ladder_target_for(p) -> Dictionary:
	if p == null:
		return {}
	var pcell := terrain.local_to_map(p.position)
	var neighbors := terrain.get_surrounding_cells(pcell)
	for b in _buildings + _npc_buildings:
		if not (BuildingTypes.is_center(b.building_type) and b.is_walled()):
			continue
		var bf: String = b.territory.faction.name if (b.territory != null and b.territory.faction != null) else ""
		if bf == p.faction_name:
			continue   # 아군 성벽엔 사다리 안 놓는다
		for c in b.cells:
			if c in neighbors and not _has_ladder_at(b, c):
				return {"building": b, "target_cell": c}   # 붙은 ring 셀 중 사다리 없는 면
	return {}

## [투석]→성벽: 활성 부대가 대상 성벽 거점을 포격. 관전 씬 뒤 wall_hp 감소, 0이면 붕괴. 부대 행동 종료(1턴 1발). → siege-engines.md
func _bombard_wall(building) -> void:
	if building == null:
		return
	party.mark_attacked()   # 투석 = 부대 행동 종료 → 자연히 1턴 1발
	_undo_party = null
	var dmg := Siege.rolled_damage(party.siege_attack(), _rng.randf())
	var from_hp: int = building.wall_hp
	_deselect()
	_hide_party_info()
	await _run_wall_bombard(building, from_hp, dmg)
	building.wall_hp = Siege.wall_after_hit(building.wall_hp, dmg)
	if Siege.wall_broken(building.wall_hp):
		building.wall_level = 0
		building.wall_hp = 0
		_clear_ladders(building)   # 붕괴된 성벽 사다리 정리 → wall.md
		var tname: String = building.territory.name if building.territory != null else "성벽"
		toast.show_message("%s 성벽 붕괴!" % tname)
	else:
		toast.show_message("성벽 −%d (%d/%d)" % [dmg, building.wall_hp, Siege.WALL_MAX_HP])
	building.queue_redraw()   # 성벽 링 색(내구도) 갱신·붕괴 시 제거
	party_roster.set_parties(_units)


## 성벽 투석 관전 씬(SiegeBombard)을 띄우고 종료까지 await(입력 잠금). 실제 wall_hp 반영은 호출부가 씬 종료 후 처리(씬은 연출만). → siege-engines.md
func _run_wall_bombard(building, from_hp: int, damage: int) -> void:
	_in_battle = true
	var overlay := SIEGE_BOMBARD_SCENE.new()
	add_child(overlay)
	overlay.start_wall(party, building, from_hp, damage)
	await overlay.finished
	overlay.queue_free()
	_in_battle = false

## 거점 b의 셀 c에 이미 사다리가 걸려 있는지(면당 하나 — 같은 면 중복 적층 방지). → wall.md
func _has_ladder_at(b, c: Vector2i) -> bool:
	for L in _ladders:
		if L["building"] == b and L["target_cell"] == c:
			return true
	return false

## 주둔 방어 부대가 지키는 거점(중심 타일 위)에 겨눠진 사다리가 있는지([사다리 밀기] 노출 조건). → wall.md
func _can_push_ladder(p) -> bool:
	var b = _building_garrisoned_by(p)
	if b == null:
		return false
	for L in _ladders:
		if L["building"] == b:
			return true
	return false

## 부대가 중심 타일 위에 서서 지키는 거점(is_center, 그 부대 세력). 없으면 null.
func _building_garrisoned_by(p):
	if p == null:
		return null
	var cell := terrain.local_to_map(p.position)
	for b in _buildings + _npc_buildings:
		if BuildingTypes.is_center(b.building_type) and b.center_cell() == cell:
			return b
	return null

## 사다리 설치 — 대상 거점·ring 셀에 그 부대 세력 사다리를 세운다(countdown=LADDER_TURNS). 부대 행동 종료. → wall.md
func _place_ladder(p) -> void:
	var t := _ladder_target_for(p)
	if t.is_empty() or _has_ladder_at(t["building"], t["target_cell"]):
		return   # 대상 없음·그 면에 이미 사다리(면당 하나)
	var hooked: bool = "grapple_ladder" in p.loot_items   # 고리 사다리 소지 시 밀기 저항 사다리
	if hooked:
		p.loot_items.erase("grapple_ladder")   # 설치 시 1개 소모 → items.md
	_ladders.append({
		"building": t["building"], "target_cell": t["target_cell"],
		"from_cell": terrain.local_to_map(p.position), "faction": p.faction_name,
		"countdown": Siege.LADDER_TURNS, "hooked": hooked,
	})
	p.mark_attacked()   # 설치는 그 부대 행동 종료
	_undo_party = null
	_refresh_siege_overlay()

## 사다리 밀기 — 거점 b를 겨눈 각 사다리를 독립 판정, 성공분 제거. hooked(고리 사다리) 사다리는 밀기 확률 감소. → wall.md
func _push_ladders(b) -> void:
	var kept: Array = []
	for L in _ladders:
		var markup: float = Siege.HOOKED_PUSH_REDUCTION if L.get("hooked", false) else 0.0
		if L["building"] == b and Siege.push_succeeds(_rng.randf(), markup):
			continue   # 파괴됨
		kept.append(L)
	_ladders = kept
	_refresh_siege_overlay()

## 거점 b를 겨눈 사다리를 모두 제거한다(점령·파괴 시). → wall.md
func _clear_ladders(b) -> void:
	var kept: Array = []
	for L in _ladders:
		if L["building"] != b:
			kept.append(L)
	_ladders = kept
	_refresh_siege_overlay()

## 사다리 시각화 갱신(레코드 변경 시).
func _refresh_siege_overlay() -> void:
	_siege_overlay.ladders = _ladders
	_siege_overlay.queue_redraw()

## 턴 종료마다 모든 사다리 countdown −1(하한 0). 0이면 통로가 열린다(_wall_blocked_cells). → wall.md
func _advance_ladders() -> void:
	for L in _ladders:
		L["countdown"] = maxi(0, L["countdown"] - 1)
	_refresh_siege_overlay()

## 팝업 대상(적 부대/점령/병합)을 모두 비운다. 팝업을 새로 열기 전에 호출.
func _clear_popup_targets() -> void:
	_popup_target = null
	_capture_target = null
	_merge_target = null

## 인접 아군 부대 클릭 팝업 [병합]을 그 부대 근처에 연다. 대상 부대를 _merge_target에 둔다.
func _open_merge_popup(other) -> void:
	_clear_popup_targets()
	_merge_target = other
	party_action_menu.open(PartyActionMenu.merge_actions(), _screen_pos(other.position))

## 공격 가능한 적 클릭 팝업 [공격][사격]을 그 적 근처에 연다. 대상 항목을 _popup_target에 둔다.
func _open_enemy_popup(entry: Dictionary) -> void:
	_clear_popup_targets()
	_popup_target = entry
	party_action_menu.open(PartyActionMenu.enemy_actions(entry["melee"], entry["shoot"]), _screen_pos(terrain.map_to_local(entry["cell"])))

## 무방비 적 거점 클릭 팝업 [흡수][파괴]을 캠프 중심 근처에 연다. 대상 항목을 _capture_target에 둔다.
func _open_capture_popup(entry: Dictionary) -> void:
	_clear_popup_targets()
	_capture_target = entry
	party_action_menu.open(PartyActionMenu.capture_actions(), _screen_pos(terrain.map_to_local(entry["camp"].center_cell())))

## 월드 좌표 → 화면 좌표(카메라·줌 반영). 메뉴를 클릭 지점 근처에 띄우는 데 쓴다.
func _screen_pos(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

## 메뉴 버튼 처리. 팝업(적 대상)이면 공격/사격, 중앙 메뉴면 사격 모드/휴식/경계.
func _on_party_action(id: String) -> void:
	if not _selected:
		return
	if _merge_target != null:
		var other = _merge_target
		_merge_target = null
		if id == "merge":
			_merge_party(other)
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
		"split":
			_split_party()   # 분할 — 편성(턴 소비 없음)
		"station":
			party.stationed = true   # 주둔 — 거점에서 대기(이동·공격 불가, 다음 턴에도 유지)
			_undo_party = null
			_deselect()
			_hide_party_info()
		"unstation":
			party.stationed = false   # 주둔 종료 — 이번 턴부터 다시 이동·공격 가능
			_update_ranges()
			_open_action_menu()
		"ladder":
			_place_ladder(party)   # 성벽 적 거점에 사다리 설치 — 행동 종료
			_deselect()
			_hide_party_info()
		"catapult":
			_enter_bombard_mode()   # 투석 — 표적 선택 모드(성벽/적 부대 클릭 발사) → siege-engines.md
		"push_ladder":
			_push_ladders(_building_garrisoned_by(party))   # 성벽 사다리 밀기(15% 파괴)
			party.mark_attacked()   # 밀기는 방어 부대 행동 종료(주둔 유지)
			_deselect()
			_hide_party_info()
		"equip":
			party_action_menu.close()
			equip_menu.open(party)   # 장비 관리 — 노획 장비 장착·탈착(턴 소비 없음)
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
	_advance_ladders()   # 사다리 카운트다운 −1(0이면 통로 열림) → wall.md
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

	# 타깃 입력은 세력 무관하게 같으므로 루프 밖에서 한 번만 만든다(부대·캠프 목록).
	var party_entries := _party_entries()
	var camp_entries := _camp_entries()

	# 세력별로 그룹핑(등장 순서 유지). 각 항목은 {party, path}.
	var factions: Array = []
	var groups: Dictionary = {}
	for p in _npc_parties:
		if p.stationed:
			continue   # 주둔 NPC 부대는 이동하지 않고 거점에서 대기 → garrison.md
		var start := terrain.local_to_map(p.position)
		var occ := _blocked_for(p)   # 자기 외 부대 점유 + 적 세력 성벽 거점 footprint = 이동 장애물.
		var dest := NpcAi.choose_destination(terrain, start, p.movement(), MAP_WIDTH, MAP_HEIGHT, _rng, occ, _npc_targets(p, party_entries, camp_entries))
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
		if attacker.stationed:
			# 주둔 NPC 부대는 이동·근접 개시는 안 함. 성벽 사다리가 있으면 밀기 우선, 없으면 사거리 안 적 제자리 사격(주둔 유지). → garrison.md · wall.md
			if not attacker.attacked_this_turn and _can_push_ladder(attacker):
				attacker.mark_attacked()
				_push_ladders(_building_garrisoned_by(attacker))   # NPC 자동 사다리 밀기(15%씩)
			elif attacker.attack_range() >= 2 and not attacker.attacked_this_turn:
				var st = _adjacent_enemy(attacker)   # 사거리(=attack_range) 안 적
				if st != null:
					attacker.mark_attacked()
					var sd := _engagement_distance(attacker, st)   # 교전 거리(주둔 사격은 보통 원거리)
					if st in _units:
						await _run_battle(attacker, st, sd)   # 플레이어가 방어 → 오버레이 관전
					else:
						_resolve_battle_headless(attacker, st, sd)   # NPC끼리 → 즉시 결산
			continue   # 사격·밀기 후에도 이동·근접 개시 없이 대기
		if not attacker.can_attack():
			continue
		var target = _adjacent_enemy(attacker)
		if target != null:
			if not NpcAi.should_engage(NpcAi.party_power(attacker.members), NpcAi.party_power(target.members)):
				continue   # 신중한 교전: 불리하면 공격하지 않고 대기
			attacker.mark_attacked()
			var dist := _engagement_distance(attacker, target)
			if target in _units:
				await _run_battle(attacker, target, dist)   # 플레이어 부대가 방어 → 오버레이 관전
			else:
				_resolve_battle_headless(attacker, target, dist)   # NPC끼리 → 즉시 결산
			continue
		# 공격할 적 부대가 없으면 인접한 무방비 적 캠프(중심 타일에 부대 없음)를 흡수한다.
		# 방어된 캠프의 주둔 부대는 위 부대 전투 분기(_adjacent_enemy)에서 이미 처리된다.
		var camp = _adjacent_enemy_camp(attacker)
		if camp != null and _party_on_cell(camp.center_cell()) == null:
			attacker.mark_attacked()
			_transfer_camp(camp, _faction_named(attacker.faction_name))
			_update_fog()
			continue
		# 칠 적·흡수할 거점이 없으면, 인접 성벽 적 거점에 빈 면이 있으면 사다리 설치(공성). → wall.md
		if not _ladder_target_for(attacker).is_empty():
			_place_ladder(attacker)   # 그 NPC 세력 사다리 설치 — 행동 종료(mark_attacked)
			continue
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
	var walls := _wall_blocked_cells(attacker.faction_name)   # 적 성벽 안 수비대는 접근 불가 → 표적 제외 → wall.md
	for other in _units + _npc_parties:
		if other == attacker or other.members.is_empty():
			continue
		if other.faction_name == attacker.faction_name:
			continue   # 같은 세력(아군)은 공격 대상 아님(주둔 부대 도입 후 같은 세력 인접이 생겨 필요)
		var oc: Vector2i = terrain.local_to_map(other.position)
		if walls.has(oc):
			continue   # 성벽 안 수비대는 표적 아님
		if in_range.has(oc):
			return other
	return null

## attacker에 인접한(또는 그 위) 적 캠프를 찾는다(소유 세력이 다른 것). 수비대 유무는 호출부가 판단. 없으면 null.
func _adjacent_enemy_camp(attacker):
	var acell := terrain.local_to_map(attacker.position)
	var fn: String = attacker.faction_name
	var neighbors := terrain.get_surrounding_cells(acell)
	for b in _buildings + _npc_buildings:
		if not BuildingTypes.is_center(b.building_type):
			continue
		if b.is_walled() and not _breached_by(b, fn):
			continue   # 성벽 거점은 진입 불가 → 흡수 대상 아님. 단 이 세력이 사다리로 돌파했으면 열린다. → wall.md
		var bf := ""
		if b.territory != null and b.territory.faction != null:
			bf = b.territory.faction.name
		if bf == fn:
			continue   # 아군 거점
		for c in b.cells:
			if c == acell or c in neighbors:
				return b
	return null

## 세력 이름으로 Faction 객체를 찾는다(_factions에서). 없으면 null.
func _faction_named(fname: String):
	for f in _factions:
		if f.name == fname:
			return f
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
	var path := HexGrid.reconstruct_path(terrain, start_cell, dest_cell, party.movement(), MAP_WIDTH, MAP_HEIGHT, _blocked_for(party))
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
			_begin_battle(then_action["enemy"], 1, then_action["occupy"])   # 이동 후 근접 전투(거리 1)
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
	_clear_popup_targets()
	_reachable = {}
	_attack_targets = {}
	_capture_targets = {}
	_merge_targets = {}
	_move_cells = []
	_attack_cells = []
	_capture_cells = []
	_shoot_cells = []
	_shoot_area_cells = []
	_bombard_cells = {}
	_bombard_area_cells = []
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
	_enter_build_mode(type_id, territory)

## 캠프 메뉴의 "캠프 건설" → 새 영지 캠프 건설 모드. 배치 영역은 활성 부대 시야(_build_vision).
## 활성 부대가 비어(멤버 0) 있으면 시야가 없어 배치 불가 → 진입하지 않고 안내 토스트만 띄운다.
func _on_found_camp_requested(territory: Territory) -> void:
	camp_menu.close_menu()
	if party == null or party.members.is_empty():
		toast.show_message("캠프를 세우려면 부대가 필요하다")
		return
	_enter_build_mode(BuildingTypes.CAMP, territory)

## 건설 모드 진입 공통. 배치 영역(윤곽선)을 종류에 맞는 시야로 그린다 — 캠프는 부대 시야, 그 외는 영지 시야.
func _enter_build_mode(type_id: String, territory: Territory) -> void:
	_build_mode = true
	_build_type = type_id
	_build_territory = territory
	build_preview.clear()
	build_area.show_area(_build_vision())

## 현재 건설 종류의 배치 가능 시야 {cell: true}. 캠프(새 영지)는 활성 부대 시야 반경, 그 외는 영지 시야.
func _build_vision() -> Dictionary:
	if _build_type == BuildingTypes.CAMP:
		var vis := {}
		for c in HexGrid.cells_within(terrain, terrain.local_to_map(party.position), party.vision(), MAP_WIDTH, MAP_HEIGHT):
			vis[c] = true
		return vis
	return BuildPlanner.territory_vision(terrain, _build_territory, MAP_WIDTH, MAP_HEIGHT)

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
	var vision := _build_vision()   # 캠프=부대 시야, 그 외=영지 시야
	var occupied := BuildPlanner.occupied_cells(_buildings + _npc_buildings)
	return BuildPlanner.can_place(terrain, cell, MAP_WIDTH, MAP_HEIGHT, vision, occupied, _build_footprint())

## 현재 건설 종류의 발자국 헥스 수(카탈로그 footprint, 기본 7).
func _build_footprint() -> int:
	return BuildingTypes.get_type(_build_type).get("footprint", 7)

## 커서 아래의 맵 셀.
func _mouse_cell() -> Vector2i:
	return terrain.local_to_map(terrain.to_local(get_global_mouse_position()))

## 건설 모드 입력: 이동=미리보기, 좌클릭=배치, 우클릭/ESC=취소.
func _handle_build_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _mouse_cell()
		build_preview.show_preview(BuildPlanner.footprint(terrain, cell, _build_footprint()), _can_build_at(cell))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place(_mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_exit_build_mode()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_build_mode()

## 그 셀에 건물을 배치한다: 자원 차감 → 건설 중 건물 생성 → 영지 편입 → 건설 모드 종료.
## 배치 불가·자원 부족·선행 미충족이면 아무 일도 하지 않고 모드를 유지한다.
func _try_place(cell: Vector2i) -> void:
	if not _can_build_at(cell):
		return
	# 건축 조건(선행·자재·필요인원) 재확인(방어적). 리스트에서 비활성 항목은 애초에 못 고르지만, 배치 시점에도 지킨다.
	if not BuildPlanner.can_build(_build_territory, _build_type):
		return
	_build_territory.build_pay(_build_type)   # 자재 차감 + 필요인원 고용
	if _build_type == BuildingTypes.CAMP:
		_found_camp(cell)   # 캠프는 새 영지 생성
	else:
		var b := Building.new()
		add_child(b)
		b.setup(terrain, cell, _build_type, true)   # 건설 중으로 생성
		_build_territory.add_building(b)
		_buildings.append(b)
	_exit_build_mode()

## 새 영지를 개척한다: 자원 0인 새 영지를 플레이어 세력에 편입하고, 건설 중 캠프를 그 자리에 세운다.
## 비용은 여는 영지가 이미 지불(build_pay). 새 영지는 인구·자원 0(전초기지), 수비대 없음(부대 편성으로 방어).
func _found_camp(cell: Vector2i) -> void:
	var territory := Territory.new(_next_outpost_name(), {})
	_player_faction.add_territory(territory)
	var b := Building.new()
	add_child(b)
	b.setup(terrain, cell, BuildingTypes.CAMP, true)   # 건설 중 캠프
	territory.add_building(b)
	_buildings.append(b)
	_territories.append(territory)
	_update_fog()

## 새 전초기지 영지 이름("전초기지 N"). 단조 증가 카운터라 영지를 잃어도 이름이 겹치지 않는다.
func _next_outpost_name() -> String:
	_outpost_count += 1
	return "전초기지 %d" % _outpost_count

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
