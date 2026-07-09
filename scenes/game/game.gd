extends Node2D
## 300x300 헥스 타일 맵(초원)을 그리고, 카메라를 중앙에 배치한다.
## 카메라는 WASD 또는 마우스를 화면 가장자리에 대면 상하좌우로 이동한다.

const MAP_WIDTH := 300
const MAP_HEIGHT := 300

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
# 현재 공격 범위(빨강) 셀 집합 → true. 빨강 클릭으로 공격 대상 판정에 사용.
var _attackable: Dictionary = {}
# 주인공이 선택되었는지. 선택 상태에서만 범위 표시 + 이동이 가능하다.
var _selected := false

# 턴 진행. 턴 종료 시 유닛 이동 리셋 + 영지 자원 수입.
var _turn := TurnManager.new()
var _units: Array = []          # 턴당 1회 이동하는 부대(주인공 부대 등).
var _npc_parties: Array = []    # NPC 부대. 안개 표시·턴 리셋·턴 종료 시 이동(NpcAi) 대상. 일람은 제외.
var _territories: Array = []    # 자원 수입을 받는 영지.
var _buildings: Array = []      # 맵의 모든 건물(캠프 + 건설된 농장). 겹침 검사·추적용.

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

const BATTLE_SCENE := preload("res://scenes/combat/battle.gd")

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
	_setup_faction()
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

## 시작 지점(중앙 캠프) 근처에 방향별 지형 덩어리를 배치한다.
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

## 플레이어 시작 영지·세력을 유닛 카탈로그(플레이어 부대 스펙)에서 만든다.
## 세력 "푸른 왕국" → 영지 "창천성"에 캠프를 넣는다. 초기 자원은 캠프 카탈로그 resources 복사.
func _setup_faction() -> void:
	var camp_spec := BuildingTypes.get_type(BuildingTypes.CAMP)
	var start_res: Dictionary = (camp_spec.get("resources", {}) as Dictionary).duplicate(true)
	var spec := UnitTypes.get_party(UnitTypes.PLAYER_ID)
	var territory := Territory.new(spec["territory"], start_res)
	var faction := Faction.new(spec["faction"], spec["color"])
	faction.add_territory(territory)
	territory.add_building(building)
	_territories = [territory]

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

## 주인공 위치에서 이동력만큼 BFS로 도달 셀을 구하고, 범위를 갱신한다.
## 이동 범위(파랑)는 지형 이동 상한(숲 ceil·습지 floor·산 불가)을 반영하고,
## 공격 범위(빨강)는 그 이동 영역 바로 바깥 한 칸이다(자세히는 HexGrid.movement_ranges).
func _update_ranges() -> void:
	var start := terrain.local_to_map(party.position)
	# 이동 가능하면 이동력만큼, 이동을 마쳤으면(공격만 가능) 0 → 이동칸 없이 인접(공격 범위)만.
	var move_range: int = party.movement() if party.can_move() else 0
	var ranges := HexGrid.movement_ranges(terrain, start, move_range, MAP_WIDTH, MAP_HEIGHT, _occupied_cells(party))
	var move_cells: Array[Vector2i] = ranges["move"]
	# 이동 판정은 지형 상한이 반영된 이동 목적지 집합으로 한다.
	_reachable = {}
	for c in move_cells:
		_reachable[c] = true
	# 공격 범위 = 이동 프런티어(이동칸+시작칸)에서 부대 공격거리 이내 칸(이동칸·시작칸 제외).
	var seeds := move_cells.duplicate()
	seeds.append(start)
	var attack_cells: Array[Vector2i] = []
	_attackable = {}
	for c in HexGrid.cells_within_any(terrain, seeds, party.attack_range(), MAP_WIDTH, MAP_HEIGHT):
		if c == start or _reachable.has(c):
			continue
		_attackable[c] = true
		attack_cells.append(c)
	overlay.show_ranges(move_cells, attack_cells)

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

## NPC 부대 토큰은 플레이어 현재 시야 안에 있을 때만 보이고, 시야 밖이면 안개에 가려 숨긴다.
## (NPC는 시야를 밝히지 않으므로 _update_fog 시야 합산에는 넣지 않는다.)
func _update_npc_visibility() -> void:
	for p in _npc_parties:
		p.visible = fog.is_cell_visible(terrain.local_to_map(p.position))

## 좌클릭 처리. 우선순위 판정은 순수 함수 ClickRouter.resolve에 위임하고 여기서는 실행만 한다.
## - 부대 우선(캠프 위 재클릭 시 메뉴) → 선택 중 이동(건물 위 통행) → 캠프 메뉴 → 건물 정보 → 선택 해제.
func _handle_click(world_pos: Vector2) -> void:
	var cell := terrain.local_to_map(terrain.to_local(world_pos))
	var party_cell := terrain.local_to_map(party.position)
	var reachable: bool = _reachable.has(cell)
	var clicked := _building_at(cell)   # 캠프는 CAMP_MENU, 그 외 건물은 BUILDING_INFO로 분기.
	var clicked_npc := _npc_at(cell)    # 보이는 NPC 부대가 있으면 정보 표시/공격 대상.
	var on_camp := clicked != null and clicked.building_type == BuildingTypes.CAMP
	var on_building := clicked != null and clicked.building_type != BuildingTypes.CAMP
	# 공격 판정: 클릭한 적이 현재 공격 범위(빨강) 안이고 부대가 공격 가능한가.
	var enemy_attackable: bool = clicked_npc != null and _attackable.has(cell) and party.can_attack()

	match ClickRouter.resolve(cell == party_cell, clicked_npc != null, on_camp, on_building, _selected, reachable, party_info.visible, enemy_attackable):
		ClickRouter.MOVE:
			# 이동은 클릭 즉시 확정하고(재이동 불가·선택 해제), 토큰만 경로 따라 애니메이션한다.
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
			if _selected:
				_deselect()
			# 부대 정보·일람을 감추고 우측 상단에 건물 정보를 띄운다.
			party_info.close()
			party_roster.hide()
			building_info.open(clicked)
		ClickRouter.FOCUS_PARTY:
			# 정보 패널은 항상 연다. 아직 선택 전이고 이동/공격 중 하나라도 가능하면 함께 선택(범위 표시).
			_show_party_info(party)
			if not _selected and (party.can_move() or party.can_attack()):
				_select()
		ClickRouter.FOCUS_NPC:
			# NPC는 정보만 표시한다(선택·이동 없음). 진행 중이던 선택은 해제한다.
			if _selected:
				_deselect()
			_show_party_info(clicked_npc)
		ClickRouter.ATTACK:
			_attack_enemy(clicked_npc, cell)
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

## exclude를 뺀 모든 부대(플레이어 + NPC)가 점유한 칸 집합({cell: true}). 이동 장애물로 넘긴다.
func _occupied_cells(exclude) -> Dictionary:
	var occ := {}
	for p in [party] + _npc_parties:
		if p == exclude:
			continue
		occ[terrain.local_to_map(p.position)] = true
	return occ

## 공격 범위(빨강)의 적을 공격한다. 적이 공격거리 이내면 그 자리에서(원거리 발사),
## 아니면 적에 공격거리 이내인 도달 가능 칸으로 자동 이동한 뒤 전투한다.
func _attack_enemy(enemy, enemy_cell: Vector2i) -> void:
	var party_cell := terrain.local_to_map(party.position)
	# 적에 공격거리 이내인 칸 집합(사거리는 지형 무관).
	var in_range := {}
	for c in HexGrid.cells_within(terrain, enemy_cell, party.attack_range(), MAP_WIDTH, MAP_HEIGHT):
		in_range[c] = true
	if in_range.has(party_cell):
		_begin_battle(enemy)   # 이미 사거리 안 — 이동 없이 전투
		return
	var stand := _stand_cell_in_range(in_range)
	if stand == party_cell:
		_begin_battle(enemy)   # 사거리 안 이동칸을 못 찾으면(예외) 제자리 전투
		return
	# 적을 사거리 안에 두는 이동칸으로 이동 후 전투.
	party.mark_moved()
	_deselect()
	_hide_party_info()
	_move_player_to(party_cell, stand, enemy)

## in_range(적에 사거리 이내 칸) 중 도달 가능한 이동칸 하나. 없으면 부대 현재 칸.
func _stand_cell_in_range(in_range: Dictionary) -> Vector2i:
	for c in in_range:
		if _reachable.has(c):
			return c
	return terrain.local_to_map(party.position)

## 플레이어가 적에게 개시하는 전투. 공격은 플레이어 부대의 행동을 끝낸다(mark_attacked).
## 인접이 아니면(사거리 두고 침) 원거리 모드로 개시한다.
func _begin_battle(defender) -> void:
	party.mark_attacked()
	if _selected:
		_deselect()
	_hide_party_info()
	_run_battle(party, defender, _is_ranged_engagement(party, defender))   # 비차단(await로 백그라운드 진행)

## 개시 시 두 부대가 인접이 아니면(떨어져 있으면) 원거리 전투로 본다.
func _is_ranged_engagement(a, b) -> bool:
	var acell := terrain.local_to_map(a.position)
	var bcell := terrain.local_to_map(b.position)
	return acell != bcell and not (bcell in terrain.get_surrounding_cells(acell))

## 오버레이 전투를 띄우고 관전한다(입력 잠금). 종료까지 await 후 사상자를 반영한다.
## 플레이어가 참여하는 전투에 쓴다(공격 페이즈에서도 순차 await).
func _run_battle(attacker, defender, ranged := false) -> void:
	_in_battle = true
	var overlay := BATTLE_SCENE.new()
	add_child(overlay)
	overlay.start(attacker, defender, ranged)
	var result: Array = await overlay.finished   # [a_survivors, b_survivors]
	_apply_survivors(attacker, result[0])
	_apply_survivors(defender, result[1])
	overlay.queue_free()
	_in_battle = false
	_update_fog()
	party_roster.set_parties(_units)

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

## 주인공 부대를 선택하고 이동/공격 범위를 표시한다.
func _select() -> void:
	_selected = true
	party.set_selected(true)
	_update_ranges()

## 턴 종료: 번호 +1, 모든 유닛 이동 리셋, 모든 영지 자원 수입, NPC 이동. 진행 중 선택은 해제한다.
func _on_turn_ended() -> void:
	if _in_battle:
		return   # 전투 관전 중에는 턴을 넘기지 않는다.
	_finish_player_move()   # 이동 애니메이션 중이면 목적지로 스냅한 뒤 턴을 넘긴다.
	if _selected:
		_deselect()
	_hide_party_info()
	# 플레이어 부대 + NPC 부대 모두 이동 상태를 리셋한다(일람은 우리 세력만이라 _units만 등록).
	_turn.end_turn(_units + _npc_parties, _territories)
	turn_hud.set_turn(_turn.number)
	_update_fog()   # 건설 완료 농장 시야 + NPC 현재 위치 표시를 안개에 반영.
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
			return   # 새 턴이 시작됨 → 중단.
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
	_update_fog()   # 헤드리스 전투로 바뀐 위치·제거를 안개·표시에 반영

## attacker의 공격거리 이내에 있는 자기 외 부대를 찾는다(멤버 있는 것만). 없으면 null.
## (NPC가 사거리를 유지하며 포지셔닝하는 AI는 미구현 — 접근해 붙은 뒤 사거리 판정만 반영.)
func _adjacent_enemy(attacker):
	var in_range := {}
	for c in HexGrid.cells_within(terrain, terrain.local_to_map(attacker.position), attacker.attack_range(), MAP_WIDTH, MAP_HEIGHT):
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

## 이동 완료 후 처리. then_attack가 있으면 전투 개시, 없으면 공격 범위에 적이 있으면 빨강만 재표시.
func _after_move(then_attack) -> void:
	if then_attack != null:
		_begin_battle(then_attack)
		return
	if not party.can_attack():
		return
	_select()   # 이동을 마쳤으므로 _update_ranges가 공격 범위(빨강)만 표시한다.
	if not _has_attackable_enemy():
		_deselect()   # 공격할 적이 없으면 빈 범위를 남기지 않는다.

## 현재 공격 범위(_attackable) 안에 보이는 적 NPC가 있는지.
func _has_attackable_enemy() -> bool:
	for p in _npc_parties:
		if p.visible and _attackable.has(terrain.local_to_map(p.position)):
			return true
	return false

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
	_reachable = {}
	_attackable = {}
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
			# 이동 애니메이션·전투 중에는 새 클릭(이동·선택·메뉴)을 무시한다. 줌은 위에서 이미 처리됨.
			if not _player_moving and not _in_battle:
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
