extends Node2D
## 50x50 헥스 타일 맵(초원)을 그리고, 카메라를 플레이어 거점(남서 모서리)에 배치한다.
## 카메라는 WASD 로, 또는 마우스를 화면 가장자리에 대고 좌클릭하면 상하좌우로 이동한다.

const MAP_WIDTH := 50
const MAP_HEIGHT := 50

const CAM_SPEED := 450.0    # 픽셀/초
const EDGE_MARGIN := 24     # 마우스 가장자리 스크롤 감지 여백(px)

# 줌 배율(값이 작을수록 확대). 0.5 = 확대, 1 = 기본, 3 = 축소.
# Camera2D.zoom 은 값이 클수록 확대되므로 실제로는 (1 / 배율)로 변환해 적용한다.
# 16px 픽셀아트 헥스 기준. 값이 작을수록 확대(camera.zoom = 1/_zoom_level).
# 0.125 = 8×(타일 128px, 최대 확대) ~ 1.0 = 1×(전체 맵 조망).
const ZOOM_MIN := 0.125
const ZOOM_MAX := 1.0
const ZOOM_STEP := 0.05
const PAN_ZOOM_SPEED := 0.05   # 트랙패드 두 손가락 스크롤(PanGesture) delta.y → 줌 배율 계수

# 부대 이동 애니메이션. 칸당 이동 시간(플레이어·NPC 공유) / 같은 세력 내 NPC 부대 시작 간격(스태거).
const MOVE_STEP_TIME := 0.12
const NPC_PARTY_STAGGER := 0.2
const NPC_FOCUS_PAUSE := 0.3   # 시야 내 NPC 영웅그룹으로 카메라 포커스 후 잠깐 정지(초). → turn.md · npc-movement.md
const NPC_ENGAGE_FOCUS := 1.0  # NPC 공격 연출: 공격자·대상 하이라이트를 보여주는 시간(초). → npc-movement.md
const HL_ATTACKER := Color(1.0, 0.3, 0.3)   # 공격자 하이라이트(빨강)
const HL_TARGET := Color(1.0, 1.0, 1.0)     # 대상 하이라이트(흰색 — 선택·버프 금색과 구분)
const HL_NONE := Color(0, 0, 0, 0)          # 하이라이트 해제
const FOLLOW_STAGGER := 0.1   # 즉시 추종(비차단 트레일) 시 하위부대 출발 간격(초) → squad-stance.md

# 4왕국 거점 배치 — 각 왕국을 맵 모서리 근처(안쪽 MARGIN칸)에 둔다. y↑=남, x↑=동.
# 시작 모서리(SW/NW/NE/SE)는 factions.csv 의 start_corner 컬럼이 정한다(플레이어=SW).
# 좌표는 _start_cell(id) / corner_cell(...) 이 맵 크기·MARGIN 으로 계산한다.
const MARGIN := 10   # 모서리에서 거점 중심까지 안쪽 거리(칸)

@onready var terrain: TileMapLayer = $TerrainLayer   # 보이지 않는 데이터 레이어(지형타입=source id). 지오메트리·BFS 기준.
@onready var terrain_visual: Node2D = $TerrainVisual   # LaPetiteTile 오토타일 비주얼 레이어 스택
@onready var buildings_layer: TileMapLayer = $BuildingsLayer   # 거점 건물 오토타일(세력색) 공유 레이어
@onready var roads_layer: TileMapLayer = $TerrainVisual/Roads   # 장식용 흙길(거점↔자원지 연결, 이동 무관)
@onready var camera: Camera2D = $Camera2D
@onready var party = $Party   # 현재 활성(선택된) 플레이어 부대. 다른 부대 클릭 시 재할당된다. 모든 부대는 _pmgr.units.
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
var _zoom_level := 0.33   # 기본 ~3× 확대 → 16px 타일이 화면상 48px
var _terrain_renderer: TerrainRenderer   # 데이터 레이어 → 비주얼 레이어 렌더

# 현재 이동 가능한 목적지 셀 집합(지형 상한 반영) → true. 클릭 이동 판정에 사용.
var _reachable: Dictionary = {}
# 주인공이 선택되었는지. 선택 상태에서만 범위 표시 + 이동이 가능하다.
var _selected := false
var _move_cells: Array[Vector2i] = []     # 이동 범위(파랑) 표시용
# 공격 가능한 적: enemy 칸 → {enemy, cell, melee, shoot, stand}. 빨강 오버레이·적 클릭 공격에 쓴다.
# (중앙 메뉴·SHOOT 모드 삭제 — 공격은 적 직접 클릭. → party-action-menu.md)
var _attack_targets: Dictionary = {}
var _attack_cells: Array[Vector2i] = []   # 공격 가능 적 칸(빨강)
# 인접 가능한 적 거점: 수비대 유무로 나뉜다. camp 칸 → {camp, stand}. 빨강 오버레이·클릭 팝업에 쓴다.
var _capture_targets: Dictionary = {}     # 무방비 거점(중심 타일에 부대 없음 — 점령 대상)
var _capture_cells: Array[Vector2i] = []
var _capture_target = null                # 거점 점령 팝업의 대상 항목({camp, stand})(없으면 아님)
var _merge_targets: Dictionary = {}       # 인접 아군 부대: cell → party(병합 대상)
var _merge_target = null                  # 병합 팝업의 대상 부대(없으면 아님)
var party_action_menu: PartyActionMenu    # 부대 행동 팝업(거점 점령·병합, 코드 생성, _ready에서 추가)
var lord_menu: LordMenu                      # 소속 모달(코드 생성, _ready에서 추가). 일반부대 소속 영웅 설정/해제 → party-lord.md
var command_menu: CommandMenu                # 지휘 모달(코드 생성). 영웅부대 따라옴/전투 스탠스 설정 → squad-stance.md

# 턴 진행. 턴 종료 시 유닛 이동 리셋 + 영지 자원 수입.
var _turn := TurnManager.new()
# 부대 생명주기(목록 단일 출처·생성·전멸/소멸 제거·칸 조회). _ready에서 생성 → parties.md
var _pmgr: PartyManager
# 건물·영지 도메인(목록 단일 출처·소유권 이전·철거·1차 생산·개척). _ready에서 생성 → production.md · building.md
var _bmgr: BuildingManager
var _player_faction: Faction    # 플레이어 세력(캠프 흡수 시 영지 편입 대상). _setup_factions에서 설정.
var _factions: Array = []       # 모든 세력(플레이어 + NPC). 세력 소멸/정복 승리 판정 대상.

# NPC 이동 AI가 목적지를 무작위로 고를 때 쓰는 난수기(_ready에서 randomize).
var _rng := RandomNumberGenerator.new()

# NPC 의사결정 계층(표적·후퇴·포지셔닝·그룹 이동 계획). _ready에서 생성 — 월드 조회는 self로 위임. → npc-movement.md
var _npc_planner: NpcPlanner

# 진행 중인 NPC 이동 애니메이션. 재진입(애니메이션 중 다시 턴 종료) 시 목적지로 스냅하는 데 쓴다.
var _npc_tweens: Array = []          # 살아 있는 Tween 목록(재진입 시 kill).
var _npc_move_targets: Dictionary = {}   # party → 최종 목적지 칸(스냅용).
var _npc_move_epoch := 0             # NPC 이동 세대. 새 라운드가 시작되면 이전 코루틴을 중단시킨다.

# 진행 중인 플레이어 부대 이동 애니메이션. 이동 중에는 좌클릭을 잠근다.
var _player_moving := false
var _player_tween: Tween = null
var _player_move_target: Vector2i
# 다중 클릭 이동: 진행 중 경로와 이동력 차감 정보(ESC 정지 시 부분 차감·재경로). → selection-and-movement.md
var _move_path: Array = []               # 진행 중 플레이어 이동 경로(start 포함). ESC 정지 시 도달 칸 스냅용.
var _move_arrived := 0                    # 마지막으로 도달한 경로 인덱스(칸 도착 콜백이 증가).
var _move_dist: Dictionary = {}           # 이동 시작 시점의 누적비용 맵(칸→비용). 완주·부분 차감 계산.

# 호버 경로 미리보기(선택 중 마우스 올린 칸까지의 파랑/빨강 선). → selection-and-movement.md
var path_preview: PathPreview
var _hover_cell := Vector2i(-9999, -9999)   # 마지막 호버 셀 — 바뀔 때만 미리보기 갱신.

# 진행 중인 하위부대 추종(비차단 트레일) 이동. 턴 종료 시 목적지로 스냅한다. → squad-stance.md
var _follow_tweens: Array = []           # 살아 있는 추종 Tween 목록.
var _follow_targets: Dictionary = {}     # 하위부대 → 최종 목적지 칸(스냅용).
var _follow_dist: Dictionary = {}        # 하위부대 → 트레일 시작 시점 누적비용 맵. 정지·완주 시 실제 도달 칸 기준으로 이동력 차감.

# 전투우선 지휘 시퀀스(하위부대 순차 접근·전투)가 도는 동안 참. 맵 클릭·턴 종료를 잠근다. → squad-stance.md
var _command_busy := false
# 마지막 플레이어 이동의 출발 칸 — 즉시 추종 시 진행 방향(전방) 판정에 쓴다. → squad-stance.md
var _move_from_cell := Vector2i(-1, -1)

# 전투 오버레이가 떠 있는 동안 월드맵 좌클릭·턴 종료를 잠근다.
var _in_battle := false

# 게임 오버(승패 확정) 상태. true면 월드맵 좌클릭·턴 종료를 잠그고 결과 오버레이를 띄운다.
var _game_over := false
var result_overlay: ResultOverlay   # 결과 화면(코드 생성, _ready에서 추가)
var confirm_dialog: ConfirmDialog   # 확인 다이얼로그(코드 생성, _ready에서 추가). 철거 등 확인용(동작은 open 콜백).
var toast: Toast                    # 점령/함락 알림(코드 생성, _ready에서 추가)
var turn_banner: TurnBanner         # 현재 행동 세력 배너(코드 생성, _ready에서 추가). → turn.md
var _npc_turn_active := false       # NPC 턴 진행 중 — 플레이어 좌클릭·턴 종료 잠금. → turn.md

const LANG_BATTLE_SCENE := preload("res://scenes/lang_battle/lang_battle.tscn")   # 플레이어 근접 전투 오버레이(lang) → lang-battle.md
const TITLE_SCENE := "res://scenes/title/title.tscn"

# 건설 모드. 캠프 메뉴에서 건물을 고르면 진입 — 맵을 클릭해 배치한다.
var _build_mode := false
var _build_type := ""
var _build_territory: Territory = null

func _ready() -> void:
	_rng.randomize()
	_npc_planner = NpcPlanner.new(terrain, MAP_WIDTH, MAP_HEIGHT, _rng, self)
	_bmgr = BuildingManager.new(terrain, MAP_WIDTH, MAP_HEIGHT, self, buildings_layer)
	_pmgr = PartyManager.new(terrain, self)
	_terrain_renderer = TerrainRenderer.new({
		"ocean": $TerrainVisual/Ocean,
		"waves": $TerrainVisual/Waves,
		"sandshore": $TerrainVisual/SandShore,
		"ground": $TerrainVisual/Ground,
		"overlay": $TerrainVisual/GroundOverlay,
		"grass": $TerrainVisual/Grass,
		"cliff": $TerrainVisual/Cliff,
		"decoration": $TerrainVisual/Decoration,
	})
	_generate_map()   # 절차 생성 / 데이터 손맵 / 비주얼 손맵을 알아서 처리(내부에서 repaint 결정)
	_center_camera()
	overlay.setup(terrain)
	path_preview = PathPreview.new()   # 호버 경로 미리보기(코드 생성 Node2D, overlay 위)
	add_child(path_preview)
	path_preview.setup(terrain)
	build_preview.setup(terrain)
	build_area.setup(terrain)
	# 첫 거점은 마을회관 티어로 시작(캠프에서 한 번 업그레이드된 상태) — 인구 상한 10, 시작부터 생산 건물 해금.
	building.setup(terrain, _placement_cell("PlayerBase", _start_cell(FactionCatalog.PLAYER_ID)), "town_hall", false, buildings_layer)
	_bmgr.buildings = [building]
	_setup_factions()
	_setup_parties()   # 세력별 군대(영웅4+부하12=16) 생성·배치. _pmgr.units·_pmgr.npc_parties·party 설정 → parties.md
	fog.setup(terrain, MAP_WIDTH, MAP_HEIGHT)
	_update_fog()   # 시야 + 수비 배지 갱신
	party_roster.set_parties(_pmgr.units)
	party_roster.party_selected.connect(_on_party_focused)
	turn_hud.set_turn(_turn.number)
	turn_hud.ended.connect(_on_turn_ended)
	turn_hud.next_unit.connect(_on_next_unit_requested)
	camp_menu.build_selected.connect(_on_build_selected)
	camp_menu.upgrade_requested.connect(_on_upgrade_requested)
	camp_menu.found_camp_requested.connect(_on_found_camp_requested)
	camp_menu.demolish_requested.connect(_on_camp_demolish_requested)
	building_info.demolish_requested.connect(_on_demolish_requested)
	building_info.center_change_requested.connect(_on_center_change)
	party_action_menu = PartyActionMenu.new()   # 코드 생성 UI(거점 점령·병합 팝업 전용)
	add_child(party_action_menu)
	party_action_menu.action_selected.connect(_on_party_action)
	party_info.action_selected.connect(_on_party_info_action)   # 부대 정보 박스 [소속] 버튼 → party-lord.md

	lord_menu = LordMenu.new()   # 소속 모달(코드 생성 UI) → party-lord.md
	add_child(lord_menu)
	lord_menu.changed.connect(_on_lord_changed)
	command_menu = CommandMenu.new()   # 지휘 모달(따라옴/전투 스탠스) → squad-stance.md
	add_child(command_menu)
	command_menu.changed.connect(_on_command_changed)
	result_overlay = ResultOverlay.new()   # 결과 화면(코드 생성)
	add_child(result_overlay)
	result_overlay.dismissed.connect(_on_result_dismissed)
	confirm_dialog = ConfirmDialog.new()   # 확인 다이얼로그(코드 생성). 동작은 open의 콜백으로 넘긴다.
	add_child(confirm_dialog)
	toast = Toast.new()   # 점령/함락 알림(코드 생성)
	add_child(toast)
	turn_banner = TurnBanner.new()   # 현재 행동 세력 배너(코드 생성). → turn.md
	add_child(turn_banner)
	_begin_player_turn()   # 시작은 플레이어 턴 — 배너는 감춰 둔다(NPC 차례에만 표시). → turn.md

## 맵 지형을 준비한다. 세 경우: → docs/spec/features/map-and-camera.md
##  1) **비주얼 손맵**: TerrainVisual 레이어를 에디터에서 직접 칠했으면 그 그림을 그대로 두고(repaint 안 함),
##     게임 로직용 데이터(TerrainLayer 지형타입)를 비주얼에서 역산한다. → _derive_data_from_visuals
##  2) **데이터 손맵**: TerrainLayer에 미리 칠해진 게 있으면 그걸 쓰고 TerrainRenderer로 비주얼을 그린다.
##  3) **절차 생성**: 둘 다 비었으면 초원 + 시작 지형 + 강 + 길을 생성하고 비주얼을 그린다.
## 데이터 레이어는 런타임에 항상 숨긴다(에디터에서 데이터 손맵 그릴 때만 visible로 토글).
func _generate_map() -> void:
	terrain.visible = false
	if _visual_authored():
		_derive_data_from_visuals()   # 손으로 칠한 비주얼 유지, 데이터만 역산(repaint 없음)
	else:
		if terrain.get_used_cells().is_empty():
			for y in MAP_HEIGHT:
				for x in MAP_WIDTH:
					terrain.set_cell(Vector2i(x, y), Terrain.PLAINS, Terrain.ATLAS)
			_place_starting_terrain()
			_place_river()
			_place_roads()
		_terrain_renderer.repaint(terrain, MAP_WIDTH, MAP_HEIGHT)   # 데이터 → 비주얼 오토타일

	# 카메라 이동 범위(월드 좌표) 계산 — 맵 밖으로 벗어나지 않도록 클램프용.
	var corner_a := terrain.map_to_local(Vector2i(0, 0))
	var corner_b := terrain.map_to_local(Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1))
	_min_pos = Vector2(min(corner_a.x, corner_b.x), min(corner_a.y, corner_b.y))
	_max_pos = Vector2(max(corner_a.x, corner_b.x), max(corner_a.y, corner_b.y))

## 플레이어 거점(남서 모서리) 근처에 방향별 지형 덩어리를 배치한다.
## 서쪽=숲 · 동쪽=습지 · 북쪽=사막 · 남쪽=산 · 남동쪽=호수(물). 캠프(중심 반경1)·주인공 배치 칸과 겹치지 않게 떨어뜨린다.
## (y가 커질수록 남쪽, x가 커질수록 동쪽.)
func _place_starting_terrain() -> void:
	var center := _start_cell(FactionCatalog.PLAYER_ID)
	_paint_patches([center + Vector2i(-6, -1), center + Vector2i(-8, 2)], Terrain.FOREST)   # 서쪽 숲
	_paint_patches([center + Vector2i(6, -1), center + Vector2i(8, 2)], Terrain.SWAMP)      # 동쪽 습지
	_paint_patches([center + Vector2i(0, -6), center + Vector2i(2, -7)], Terrain.DESERT)    # 북쪽 사막
	_paint_patches([center + Vector2i(0, 7), center + Vector2i(-2, 8)], Terrain.MOUNTAIN)   # 남쪽 산
	_paint_patches([center + Vector2i(4, 5), center + Vector2i(5, 6)], Terrain.WATER)       # 남동쪽 호수(물)
	# 생산 지형(철맥·금맥). 거점 주변에 흩어 배치 → 철광·금광 자리. → production.md
	_paint_patches([center + Vector2i(5, -5)], Terrain.IRON_VEIN)    # 철맥 → 철광
	_paint_patches([center + Vector2i(8, -3)], Terrain.GOLD_VEIN)    # 금맥 → 금광

## 씨앗 칸들 각각을 중심으로 (씨앗 + 이웃 6칸)을 해당 지형으로 칠한다.
func _paint_patches(seeds: Array, source_id: int) -> void:
	for center in seeds:
		terrain.set_cell(center, source_id, Terrain.ATLAS)
		for n in terrain.get_surrounding_cells(center):
			terrain.set_cell(n, source_id, Terrain.ATLAS)

## 맵 중앙에 굽이치는 강(WATER)을 배치한다. WATER는 통행 불가라 부대는 돌아가야 한다(다리는 후속).
## 거점 4곳과 떨어진 중앙, 가장자리엔 안 닿게 해 맵을 완전히 갈라 고립시키지 않는다(양끝으로 우회 가능).
## Ocean 오토타일이 강가 둑을 자동으로 그린다. → docs/spec/features/map-and-camera.md
func _place_river() -> void:
	for y in range(6, 31):
		var cx := 25 + int(round(3.0 * sin(y * 0.42)))   # 사인 곡선으로 굽이침
		terrain.set_cell(Vector2i(cx, y), Terrain.WATER, Terrain.ATLAS)
		if y % 2 == 0:   # 군데군데 2칸 폭
			terrain.set_cell(Vector2i(cx + 1, y), Terrain.WATER, Terrain.ATLAS)

## 장식용 흙길: 플레이어 거점에서 철맥·금맥 자리로 이어지는 길을 Roads 레이어에 그린다.
## 순수 시각(이동/BFS와 무관). 경로는 HexGrid로 산·물을 우회해 잇는다. → docs/spec/features/map-and-camera.md
func _place_roads() -> void:
	var base := _start_cell(FactionCatalog.PLAYER_ID)
	for dest in [base + Vector2i(5, -5), base + Vector2i(8, -3)]:   # 철맥·금맥 씨앗(_place_starting_terrain과 동일)
		var path := HexGrid.reconstruct_path(terrain, base, dest, MAP_WIDTH + MAP_HEIGHT, MAP_WIDTH, MAP_HEIGHT)
		if path.size() > 1:
			roads_layer.set_cells_terrain_connect(path, 0, 0)

## 비주얼 레이어(TerrainVisual)를 에디터에서 손으로 칠했는지 — 지형 레이어에 타일이 있으면 참.
## Roads·Waves는 절차 생성이 부가로 칠하는 파생 레이어라 판별에서 제외(오탐 방지).
const _AUTHORED_IGNORE := ["Roads", "Waves"]
func _visual_authored() -> bool:
	for child in $TerrainVisual.get_children():
		if child.name in _AUTHORED_IGNORE:
			continue
		if child is TileMapLayer and not (child as TileMapLayer).get_used_cells().is_empty():
			return true
	return false

## 손으로 칠한 비주얼 레이어에서 각 칸의 게임 지형타입을 역산해 데이터 레이어(TerrainLayer)에 채운다.
## 이동/시야/건설 판정이 이 데이터를 읽으므로, 손맵도 물·산=통행불가, 숲/습지=이동비용이 반영된다.
func _derive_data_from_visuals() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			var c := Vector2i(x, y)
			terrain.set_cell(c, _derive_type(c), Terrain.ATLAS)

## 한 칸의 비주얼 타일에서 게임 지형타입을 추정한다(TerrainRenderer.PAINT의 역). 우선순위:
## 물(Ocean만·Ground 없음) > 산(Cliff 또는 Ground 바위) > 숲(Decoration 나무) > 습지/사막(GroundOverlay) > 초원.
## 철맥·금맥은 겉보기로 구분 불가라 초원으로 취급된다(전용 표식은 후속 과제).
## 물 판정 규칙: Ocean은 전체 바닥 underlay로 깔리므로, "Ocean 있음"만으론 물이 아니다.
## Ground가 안 덮여 물이 드러난 칸(Ocean 있고 Ground 없음)만 물(통행 불가). 땅이 덮이면 육지.
## → LaPetiteTile 정석 기법(Ground 틈으로 Ocean이 비쳐 바다·강이 됨). docs/spec/features/map-and-camera.md
func _derive_type(cell: Vector2i) -> int:
	var has_ground: bool = $TerrainVisual/Ground.get_cell_source_id(cell) != -1
	if $TerrainVisual/Ocean.get_cell_source_id(cell) != -1 and not has_ground:
		return Terrain.WATER
	if $TerrainVisual/Cliff.get_cell_source_id(cell) != -1:
		return Terrain.MOUNTAIN
	var g: TileData = $TerrainVisual/Ground.get_cell_tile_data(cell)
	if g != null and g.terrain_set == 2:   # Ground 바위(set2) = 산
		return Terrain.MOUNTAIN
	var d: TileData = $TerrainVisual/Decoration.get_cell_tile_data(cell)
	if d != null:
		if d.terrain_set == 1:   # Elements 산(set1) = 산봉우리만 칠한 경우도 통행 불가
			return Terrain.MOUNTAIN
		if d.terrain_set == 0:   # Elements 나무(set0) = 숲
			return Terrain.FOREST
	var o: TileData = $TerrainVisual/GroundOverlay.get_cell_tile_data(cell)
	if o != null:
		return Terrain.SWAMP if o.terrain == 4 else Terrain.DESERT   # t4=SwampOverlay, 그 외=모래류
	return Terrain.PLAINS

## 거점 배치 마커(Placements/<이름>)가 있으면 그 칸을, 없으면 기본 좌표를 쓴다.
## 손맵에서 에디터로 마커를 원하는 칸에 드래그하면 거점이 거기 생긴다(부대는 소속 거점 근처에 배치).
func _placement_cell(marker_name: String, fallback: Vector2i) -> Vector2i:
	var m: Node2D = get_node_or_null("Placements/%s" % marker_name)
	if m != null:
		var cell := terrain.local_to_map(terrain.to_local(m.global_position))   # 노드 오프셋 무관하게 월드→셀
		if cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT:
			return cell   # 맵 밖 마커는 무시하고 기본 좌표 사용(거점이 맵 밖에 생기지 않게)
	return fallback

## 시작 모서리(SW/NW/NE/SE) → 거점 중심 칸. 맵 크기·MARGIN 기준. 알 수 없으면 SW(플레이어).
static func corner_cell(corner: String, map_w: int, map_h: int, margin: int) -> Vector2i:
	match corner:
		"NW": return Vector2i(margin, margin)
		"NE": return Vector2i(map_w - 1 - margin, margin)
		"SE": return Vector2i(map_w - 1 - margin, map_h - 1 - margin)
		_: return Vector2i(margin, map_h - 1 - margin)   # SW

## 세력의 시작 거점 중심 칸 — factions.csv 의 start_corner 로 계산.
func _start_cell(faction_id: String) -> Vector2i:
	return corner_cell(FactionCatalog.get_faction(faction_id).get("start_corner", "SW"), MAP_WIDTH, MAP_HEIGHT, MARGIN)

## 카메라를 플레이어 거점 타일로 이동시킨다.
func _center_camera() -> void:
	camera.position = terrain.map_to_local(_placement_cell("PlayerBase", _start_cell(FactionCatalog.PLAYER_ID)))
	camera.make_current()
	_set_zoom(_zoom_level)   # 시작 줌 배율을 카메라에 적용(16px 픽셀아트 기본 ~3× 확대)

## 플레이어 + NPC 세력·영지·거점을 유닛 카탈로그에서 만든다.
## 플레이어: 세력 "푸른 왕국" → 영지 "창천성"에 남서 모서리 캠프를 넣는다(자원 수입 대상 _bmgr.territories).
## NPC 3세력: 나머지 세 모서리에 수도 영지 + 완성 캠프를 배치한다(_bmgr.npc_buildings, 경제 미사용).
func _setup_factions() -> void:
	var spec := FactionCatalog.get_faction(FactionCatalog.PLAYER_ID)
	var territory := Territory.new(spec["territory"], _camp_resources())
	_player_faction = Faction.new(spec["faction"], spec["color"])
	_bmgr.player_faction = _player_faction   # 소유권·수입·생산 배정 판정 기준
	_player_faction.add_territory(territory)
	territory.add_building(building)
	_bmgr.territories = [territory]
	_factions = [_player_faction]

	for id in FactionCatalog.NPC_IDS:
		_bmgr.npc_buildings.append(_setup_npc_base(id, _placement_cell(id, _start_cell(id))))

## NPC 세력 하나의 거점을 만든다: 세력 → 수도 영지 → 완성 캠프(중심 base_cell). 캠프 노드를 반환한다.
## 세력·영지는 캠프의 territory 참조로 살아 있게 유지된다(_bmgr.npc_buildings가 캠프 노드를 보유).
func _setup_npc_base(id: String, base_cell: Vector2i) -> Building:
	var spec := FactionCatalog.get_faction(id)
	var territory := Territory.new(spec["territory"], _camp_resources())
	var faction := Faction.new(spec["faction"], spec["color"])
	faction.add_territory(territory)
	_factions.append(faction)
	var camp := Building.new()
	add_child(camp)
	camp.setup(terrain, base_cell, BuildingTypes.CAMP, false, buildings_layer)   # 완성 상태(건설 중 아님)
	territory.add_building(camp)
	return camp

## 캠프 카탈로그의 초기 자원 사본(영지 생성 시 시작 자원). 플레이어·NPC 공용.
func _camp_resources() -> Dictionary:
	var camp_spec := BuildingTypes.get_type(BuildingTypes.CAMP)
	return (camp_spec.get("resources", {}) as Dictionary).duplicate(true)

## 부대를 유닛 카탈로그에서 생성한다.
## 초기 유닛을 unit_spawns.csv 데이터대로 생성해 맵에 배치한다(개별 유닛 절대좌표 + leader 소속). → parties.md · unit-spawns.md
## 플레이어 부대는 _pmgr.units, NPC 세력은 _pmgr.npc_parties. 활성 부대(party)는 플레이어 첫 영웅(=$Party 재사용).
## 지정 좌표가 통과불가·중복이면 인접 빈 칸으로 보정(산·물·겹침 안전망). 생산 유닛은 이후 런타임 변수로만 존재.
func _setup_parties() -> void:
	var occupied := {}          # 점유 셀(세력 간 겹침 방지 + 보정 기준)
	var id_to_party := {}       # 스폰 id → Party (leader 연결용)
	var hero_index := {}        # faction → 다음 영웅 순번(등장 순서 = FactionCatalog hero index)
	var by_faction := {}        # faction → Array[Party] (생성 순서 유지)
	var active_hero: Party = null   # 재사용한 플레이어 첫 영웅(=활성 부대). CSV 행 순서와 무관하게 확정.
	# 1) entry 순서대로 Party 생성·배치. 플레이어 첫 영웅만 기존 $Party 노드를 재사용한다.
	for e in UnitSpawns.entries():
		var fid: String = e["faction"]
		var type: String = e["type"]
		var is_hero := type == "hero"
		var fspec := FactionCatalog.get_faction(fid)
		var is_player := fid == FactionCatalog.PLAYER_ID
		var hero_col: Color = Color(0.92, 0.78, 0.35) if is_player else fspec["color"]   # 플레이어 금색 = Party 기본
		var reuse_active := is_player and is_hero and not hero_index.has(fid)   # 플레이어 첫 영웅
		var p: Party = party if reuse_active else _new_party()
		if reuse_active:
			active_hero = p
		p.faction_name = fspec["faction"]
		if is_hero:
			var hi: int = hero_index.get(fid, 0)
			hero_index[fid] = hi + 1
			p.kind = Party.KIND_HERO
			p.token_color = hero_col
			p.commander_name = FactionCatalog.hero_name(fid, hi)
			p.party_name = FactionCatalog.hero_party_name(fid, hi)
			p.soldiers = UnitTypes.max_hp("hero")   # 영웅 병력 = 지휘관 클래스 HP 풀(lang 전투와 동일 값)
		else:
			p.kind = Party.KIND_TROOP
			p.troop_type = type   # 병종 → 병합 가능 판정(같은 병종끼리만). → party-composition.md
			p.token_color = hero_col.darkened(0.35)   # 일반부대는 약간 어두운 색
			p.soldiers = FactionCatalog.TROOP_SIZE   # 일반부대 병력 = 10
			# 이름·lord 는 2단계에서 확정(leader 참조 행이 뒤에 올 수 있어서).
		# 배치: 지정 셀이 통과가능·미점유면 그대로, 아니면 인접 빈 칸으로 보정.
		var cell: Vector2i = e["cell"]
		if occupied.has(cell) or not Terrain.is_passable(terrain.get_cell_source_id(cell)):
			var free := _nearby_free_cells(cell, 1, occupied)
			if not free.is_empty():
				cell = free[0]
			else:
				push_error("unit_spawns: '%s' 좌표 %s 배치 불가(통과 가능한 빈 칸 없음)" % [e["id"], str(cell)])
		p.position = terrain.map_to_local(cell)
		occupied[cell] = true
		id_to_party[e["id"]] = p
		if not by_faction.has(fid):
			by_faction[fid] = []
		by_faction[fid].append(p)
	# 2) leader → lord 소속 연결 + 부하부대 이름 확정("{소속 영웅} {병종}"). → Party.md 소속(Lord)
	for e in UnitSpawns.entries():
		if e["leader"] == "":
			continue
		var tp: Party = id_to_party[e["id"]]
		var lord = id_to_party.get(e["leader"], null)
		tp.lord = lord
		if lord != null:
			tp.commander_name = FactionCatalog.troop_name(e["type"])
			tp.party_name = "%s %s" % [lord.commander_name, FactionCatalog.troop_name(e["type"])]
	# 3) 플레이어/NPC 분류 + 활성 부대(재사용한 플레이어 첫 영웅).
	_pmgr.units = by_faction.get(FactionCatalog.PLAYER_ID, [])
	party = active_hero if active_hero != null else (_pmgr.units[0] if not _pmgr.units.is_empty() else party)
	for fid in FactionCatalog.NPC_IDS:
		_pmgr.npc_parties.append_array(by_faction.get(fid, []))
	# 4) 병종 확정 후 이동력을 채운다(reset_turn = move_points ← movement()). 턴 1부터 이동 가능하도록. → turn.md
	for p in all_parties():
		p.reset_turn()

## 빈 새 부대 노드(PartyManager 위임). 카탈로그 정보는 호출부가 채운다.
func _new_party() -> Party:
	return _pmgr.new_party()

## anchor 주변에서 통과 가능(산 제외)·미점유 셀을 거리순으로 count개 모은다. 반경을 넓혀 가며 확보.
func _nearby_free_cells(anchor: Vector2i, count: int, occupied: Dictionary) -> Array:
	var radius := 2
	while true:
		var dist := HexGrid.bfs_distances(terrain, anchor, radius, MAP_WIDTH, MAP_HEIGHT, Terrain.IMPASSABLE)
		var cells: Array = dist.keys()
		cells.sort_custom(func(a, b): return dist[a] < dist[b])
		var free: Array = []
		for c in cells:
			if occupied.has(c) or not Terrain.is_passable(terrain.get_cell_source_id(c)):
				continue
			free.append(c)
			if free.size() >= count:
				return free
		if radius >= 14:
			return free   # 안전 상한(코너는 충분히 열려 있어 도달하지 않음)
		radius += 1
	return []   # 도달 불가(while true) — 정적 분석 만족용

## 주인공 위치에서 이동력만큼 BFS로 도달 셀(파랑)을 구하고, 공격 가능한 적(빨강)을 분류한다.
func _update_ranges() -> void:
	var start := _cell_of(party)
	var move_range: int = party.move_points if party.can_move() else 0
	var ranges := HexGrid.movement_ranges(terrain, start, move_range, MAP_WIDTH, MAP_HEIGHT, _enemy_occupied_cells(party), _building_costs(), barrier_edges(), _ally_occupied_cells(party))
	var move_cells: Array[Vector2i] = ranges["move"]
	_reachable = {}
	for c in move_cells:
		_reachable[c] = true
	_move_cells = move_cells
	_compute_attack_targets(start)
	_compute_camp_targets(start)
	_compute_merge_targets(start)
	_refresh_overlay()

## 활성 부대 칸에 인접하고 병합 가능한(같은 병종·일반부대) 다른 플레이어 부대를 병합 대상으로 분류한다. cell → party.
func _compute_merge_targets(start: Vector2i) -> void:
	_merge_targets = {}
	var neighbors := terrain.get_surrounding_cells(start)
	for p in _pmgr.units:
		if p == party or p.soldiers <= 0 or not party.can_merge_with(p):
			continue
		var pcell := _cell_of(p)
		if pcell in neighbors:
			_merge_targets[pcell] = p

## 보이는 각 NPC를 공격 가능 여부로 분류하고 공격 위치(stand)를 정한다.
## 근접(rng 0)=(현재∪이동칸 중 인접칸 존재), stand=인접 도달 칸. 사격(rng≥2)=사거리에 드는 도달 칸 존재, stand=가장 먼 칸(카이팅).
func _compute_attack_targets(start: Vector2i) -> void:
	_attack_targets = {}
	_attack_cells = []
	if not party.can_attack():
		return   # 이미 공격을 마쳤으면 어차피 못 치므로 빨강 타일을 아예 계산·표시하지 않는다. → selection-and-movement.md
	var rng: int = party.attack_range()
	var ranged: bool = rng >= 2
	# 원거리 사격 위치 후보 = 시작칸 ∪ 도달 가능 칸.
	var fire_cands: Array = [start]
	fire_cands.append_array(_move_cells)
	for p in _pmgr.npc_parties:
		if not p.visible:
			continue
		var ec: Vector2i = _cell_of(p)
		var melee := false
		var shoot := false
		var stand := Vector2i(-1, -1)
		if ranged:
			var fire := HexGrid.best_fire_cell(terrain, fire_cands, ec, rng, MAP_WIDTH, MAP_HEIGHT)
			if fire != Vector2i(-1, -1):
				shoot = true
				stand = fire
		elif _cell_melee_reachable(ec, start):
			melee = true
			stand = _adjacent_stand(ec, start)   # 인접이면 start, 아니면 인접 도달 칸
		if melee or shoot:
			_attack_targets[ec] = {"enemy": p, "cell": ec, "melee": melee, "shoot": shoot, "stand": stand}
			_attack_cells.append(ec)

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
	for camp in _bmgr.npc_buildings:
		if not camp.visible:
			continue   # 미발견(안개) 거점은 대상 아님
		# 방어됨 = 중심 타일에 그 거점 세력 부대가 있음(일반 전투로 먼저 격파해야 함).
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

## 오버레이: 파랑 이동 범위 + 빨강(공격 가능 적 + 점령 가능 거점). (SHOOT 모드 삭제 — 공격은 적 직접 클릭.)
func _refresh_overlay() -> void:
	var red: Array[Vector2i] = []
	red.append_array(_attack_cells)
	red.append_array(_capture_cells)
	overlay.show_ranges(_move_cells, red)

## 모든 시야원(플레이어 부대 전부 + 맵의 모든 완성 건물)을 합쳐 현재 시야 셀을 계산하고 안개를 갱신한다.
func _update_fog() -> void:
	var visible := {}
	for u in _pmgr.units:
		if u.soldiers <= 0:
			continue   # 사라진(빈) 부대는 시야 없음
		for c in HexGrid.cells_within(terrain, _cell_of(u), u.vision(), MAP_WIDTH, MAP_HEIGHT):
			visible[c] = true
	# 완성 건물(캠프·농장 등)의 시야. 건설 중 건물은 buildings_vision이 제외한다.
	for c in BuildPlanner.buildings_vision(terrain, _bmgr.buildings, MAP_WIDTH, MAP_HEIGHT):
		visible[c] = true
	fog.update_visible(visible)
	_update_npc_visibility()
	_update_npc_building_visibility()
	_refresh_garrison_badges()   # 거점 중심 점거 방어 부대 인원으로 "수비 N" 배지 갱신(이동·전투·점령 후)
	_refresh_command_buffs()     # 지휘 범위 안 부대 배지 갱신(이동/전투/턴마다 — _update_fog가 정착점). → command-range.md
	_refresh_exhausted()         # "E"(이번 턴 더 할 것 없음) 배지 갱신. → selection-and-movement.md

## NPC 부대 토큰은 플레이어 현재 시야 안에 있을 때만 보이고, 시야 밖이면 안개에 가려 숨긴다.
## (NPC는 시야를 밝히지 않으므로 _update_fog 시야 합산에는 넣지 않는다.)
func _update_npc_visibility() -> void:
	for p in _pmgr.npc_parties:
		p.visible = fog.is_cell_visible(_cell_of(p))

## NPC 거점(캠프)은 한 번 발견(탐험)하면 계속 보인다(정적 구조물). 미발견이면 안개에 가려 숨긴다.
## 부대와 달리 현재 시야가 아니라 탐험됨(fog.is_cell_explored)으로 판정 — 7칸 중 하나라도 본 적 있으면 발견.
## (NPC 거점도 플레이어 시야를 밝히지 않으므로 _update_fog 시야 합산에는 넣지 않는다.)
func _update_npc_building_visibility() -> void:
	for b in _bmgr.npc_buildings:
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
	var party_cell := _cell_of(party) if party != null else Vector2i(-1, -1)
	var reachable: bool = _reachable.has(cell)
	var clicked := _building_at(cell)   # 플레이어 건물. 거점(캠프·마을회관·성)은 CAMP_MENU, 그 외는 BUILDING_INFO로 분기.
	var clicked_party := _player_party_at(cell)   # 그 칸의 플레이어 부대(선택/전환 대상).
	var clicked_npc := _npc_at(cell)    # 보이는 NPC 부대가 있으면 정보 표시/공격 대상.
	var clicked_npc_building := _npc_building_at(cell)   # 발견된 NPC 거점이면 정보 표시(NPC_BASE_INFO).
	var on_camp := clicked != null and BuildingTypes.is_center(clicked.building_type)
	var on_building := clicked != null and not BuildingTypes.is_center(clicked.building_type)

	# 공격 가능한 적(빨강)을 클릭하면 팝업 없이 바로 공격(병종으로 근접/사격 자동). → party-action-menu.md
	if _selected and _attack_targets.has(cell) and party.can_attack():
		_attack_enemy(_attack_targets[cell])
		return

	# 무방비 적 거점(빨강)을 클릭하면 [흡수][파괴] 팝업. (방어된 거점은 중심 점거 부대를 일반 전투로 친다.)
	if _selected and _capture_targets.has(cell) and party.can_attack():
		_open_capture_popup(_capture_targets[cell])
		return

	# 인접 아군 부대를 클릭하면 [병합] 팝업(전환 대신 병합 — 전환하려면 먼저 선택 해제).
	if _selected and _merge_targets.has(cell):
		_open_merge_popup(_merge_targets[cell])
		return

	var action := ClickRouter.resolve(clicked_party != null, clicked_npc != null, on_camp, on_building, clicked_npc_building != null, _selected, reachable, party_info.visible)
	# 범위 밖 빈 칸 클릭(DESELECT) + 선택·이동 가능 → 그 방향으로 최대 전진(경로 따라 이동력 닿는 데까지). 목적지를 목표로 기억. → selection-and-movement.md
	if action == ClickRouter.DESELECT and _selected and party.can_move():
		party.move_goal = cell            # 이동 목표 기억(도달 못 하면 다음 턴 [계속 이동])
		if _try_max_advance(party_cell, cell):
			return
		party.move_goal = Vector2i(-1, -1)   # 경로 없어 못 감 → 목표 취소
	match action:
		ClickRouter.MOVE:
			# 다중 클릭 이동: 선택을 유지한 채 경로를 걸어가고, 완료 시 이동력을 차감하고 범위를 다시 그린다. 목적지를 목표로 기억(도달 시 해제). → selection-and-movement.md
			party.move_goal = cell
			_start_player_move(party_cell, cell)
		ClickRouter.CAMP_MENU:
			if _selected:
				_deselect()
			_hide_party_info()
			camp_menu.open(clicked)
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
					# 재클릭 = 열린 팝업(점령·병합) 취소하고 범위 오버레이 복원.
					_clear_popup_targets()
					party_action_menu.close()
					_refresh_overlay()
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

## 셀을 점유한 플레이어 건물(BuildingManager 위임). 클릭 라우팅에 쓴다.
func _building_at(cell: Vector2i) -> Building:
	return _bmgr.building_at(cell)

## 그 칸에 선 플레이어 부대(PartyManager 위임). 클릭 선택 판정에 쓴다.
func _player_party_at(cell: Vector2i) -> Party:
	return _pmgr.player_party_at(cell)

## 모든 부대(플레이어 + NPC) 목록. NpcPlanner 월드 조회 겸용(PartyManager 위임).
func all_parties() -> Array:
	return _pmgr.all()

## 맵의 모든 건물(플레이어 + NPC 거점) 목록. NpcPlanner 월드 조회 겸용(BuildingManager 위임).
func all_buildings() -> Array:
	return _bmgr.all()

## 부대(Node2D)가 선 맵 셀. 위치→셀 변환 반복의 단일 출처.
func _cell_of(p) -> Vector2i:
	return terrain.local_to_map(p.position)

## 그 칸에 선 병력 있는 부대(PartyManager 위임 — NpcPlanner 월드 조회 겸용).
func party_on_cell(cell: Vector2i) -> Party:
	return _pmgr.party_on_cell(cell)

## 거점 중심 타일을 지키는 그 거점 세력의 부대(진짜 수비대). 없으면 null(무방비 → 점령 가능).
## 다른 세력 부대(격파 후 진입한 공격자 포함)가 서 있어도 그 거점 세력이 아니면 방어로 치지 않는다. → camp-capture.md
func _camp_defender(camp) -> Party:
	var cf: String = camp.faction_name()
	if cf == "":
		return null
	var holder := party_on_cell(camp.center_cell())
	if holder != null and holder.faction_name == cf:
		return holder
	return null

## 각 거점의 "수비 N" 배지값을 그 거점 세력 수비 부대 인원으로 갱신한다(표시 전용).
## _camp_defender를 써서, 격파 후 중심에 선 적 부대(다른 세력)는 그 거점의 수비로 세지 않는다.
func _refresh_garrison_badges() -> void:
	for b in all_buildings():
		if not BuildingTypes.is_center(b.building_type):
			continue
		var gp := _camp_defender(b)
		b.defender_count = gp.soldiers if gp != null else 0
		b.queue_redraw()

## [병합]: 인접 아군 부대 other를 활성 부대로 흡수하고 other를 맵에서 제거한다(턴 소비 없음).
func _merge_party(other) -> void:
	party.merge_from(other)
	_pmgr.remove_party(other)
	party.mark_attacked()   # 병합(재조직) → 이번 턴 행동 종료
	party_roster.set_parties(_pmgr.units)
	_update_fog()
	if _selected:
		_select()   # 병력 증가 반영(범위·메뉴 갱신 — 행동 종료라 메뉴는 닫힘)

## 그 셀에 선 보이는 NPC 부대(PartyManager 위임). 클릭 정보 표시에 쓴다.
func _npc_at(cell: Vector2i) -> Party:
	return _pmgr.npc_at(cell)

## 그 셀을 포함하는 발견된 NPC 거점(BuildingManager 위임). 클릭 라우팅에 쓴다.
func _npc_building_at(cell: Vector2i) -> Building:
	return _bmgr.npc_building_at(cell)

## 우측 상단에 건물 정보 패널을 띄운다. 부대 정보·일람은 감춘다(캠프 메뉴와 같은 규칙). 선택 중이면 해제.
## 플레이어 건물(BUILDING_INFO)·NPC 거점(NPC_BASE_INFO)이 공유한다.
func _open_building_info(b, can_demolish := false) -> void:
	if _selected:
		_deselect()
	party_info.close()
	party_roster.hide()
	var dist: int = _bmgr.center_distance(b) if b.is_primary_production() else 0
	building_info.open(b, can_demolish, dist)

## 건물 정보 패널의 철거 버튼 → 영지에서 제거·자재 환급 → 맵/추적 목록에서 제거 → 안개 갱신 → 패널 닫기.
## 노드 free는 지연 호출한다(버튼 pressed 처리 중이라 즉시 free하면 "locked" 에러).
## 캠프 메뉴의 업그레이드 버튼 → 거점을 다음 티어로 제자리 업그레이드.
## 비용 지불(build_pay) → 티어업(upgrade_to) → 안개 갱신(티어별 시야). 메뉴 표시는 영지 changed 시그널이 자동 갱신.
func _on_upgrade_requested(b) -> void:
	var next_id := BuildingTypes.next_center(b.building_type)
	if next_id == "" or b.territory == null or not BuildPlanner.can_upgrade(b.territory, b):
		return
	b.territory.build_pay(next_id)   # 자재 차감(거점은 필요인원 0) — changed → 캠프 메뉴 deferred 갱신
	b.upgrade_to(next_id)
	_update_fog()                    # 티어별 시야 변화 반영

## 철거 버튼 → 바로 철거하지 않고 확인 다이얼로그를 띄운다(환급 미리보기 포함). [철거] 확인 시 _do_demolish(b).
func _on_demolish_requested(b) -> void:
	var label: String = BuildingTypes.get_type(b.building_type).get("label", "건물")
	confirm_dialog.open("「%s」 철거 — %s" % [label, _refund_text(b)], "철거", _do_demolish.bind(b))

## 실제 환급(refund_on_demolish — 완성 salvage / 건설 중 build_cost 비례)을 "환급: 목재 2, 철 1" 형태로. 없으면 "환급 없음".
func _refund_text(b) -> String:
	var refund: Dictionary = b.refund_on_demolish()
	if refund.is_empty():
		return "환급 없음"
	var parts: Array = []
	for res in refund:
		parts.append("%s %d" % [res, refund[res]])
	return "환급: " + ", ".join(parts)

## 실제 철거(확인 다이얼로그 [철거] 확정 콜백): 도메인은 BuildingManager, 여기선 패널·안개 정리만.
func _do_demolish(b) -> void:
	if not is_instance_valid(b):
		return   # 다이얼로그가 열린 사이 다른 경로로 건물이 제거됐으면 무시
	_bmgr.demolish_building(b)   # 영지 제거·환급 → 목록 제거 → 노드 지연 free
	building_info.close()
	_update_fog()   # 철거된 건물 시야 제거

## 캠프 메뉴 [철거] → 확인 다이얼로그(영지 포기 경고) → [철거] 확인 시 _do_demolish_camp.
## (철거 버튼 노출 판정은 camp_menu._can_demolish — 캠프·마지막 거점 아님(Faction.center_count)이 단일 출처.)
func _on_camp_demolish_requested(camp) -> void:
	var terr_name: String = camp.territory.name if camp.territory != null else "영지"
	confirm_dialog.open("「%s」 캠프를 철거하고 영지를 포기할까요?" % terr_name, "철거", _do_demolish_camp.bind(camp))

## 캠프 철거 확정(영지 통째 상실, 환급 없음): 도메인은 BuildingManager, 여기선 메뉴·안개·알림만.
func _do_demolish_camp(camp) -> void:
	if not is_instance_valid(camp):
		return
	var terr_name := _bmgr.demolish_camp_territory(camp)
	camp_menu.close_menu()
	_update_fog()
	toast.show_message("%s 철거 — 영지 포기" % terr_name)

## exclude를 뺀 모든 부대(플레이어 전부 + NPC)가 점유한 칸 집합({cell: true}). 이동 장애물로 넘긴다.
## 빈 부대(병력 0)도 칸을 차지한다 — 새로 편성한 빈 부대가 자리를 지켜 겹침(두 부대가 한 칸)을 막는다.
func _occupied_cells(exclude) -> Dictionary:
	var occ := {}
	for p in all_parties():
		if p == exclude:
			continue
		occ[_cell_of(p)] = true
	return occ

## party의 이동 장애물 = 자기 외 모든 부대 점유 칸(완전 차단). NPC 경로계획·유예된 작전 코드가 쓴다(아군/적 미구분).
func blocked_for(party) -> Dictionary:
	return _occupied_cells(party)

## party 기준 **적(다른 세력) 부대** 점유 칸 — 완전 차단(통과·정지 불가). 플레이어 이동 blocked_cells. → selection-and-movement.md
func _enemy_occupied_cells(party) -> Dictionary:
	var occ := {}
	for p in all_parties():
		if p == party or p.faction_name == party.faction_name:
			continue
		occ[_cell_of(p)] = true
	return occ

## party 기준 **아군(같은 세력) 부대** 점유 칸 — 통과 O·정지 X. 플레이어 이동 no_stop_cells(아군은 벽이 아니다). → selection-and-movement.md
func _ally_occupied_cells(party) -> Dictionary:
	var occ := {}
	for p in all_parties():
		if p == party or p.faction_name != party.faction_name:
			continue
		occ[_cell_of(p)] = true
	return occ

## 건물 발자국의 이동 진입비용 override { cell: cost }(도시=2, 불가 건물=BLOCKED). 이동 계산 cell_costs로 넘긴다.
## 소속 무관 — 플레이어·NPC 거점 모두 포함(all_buildings). NPC 경로계획(NpcPlanner)과 같은 집합.
func _building_costs() -> Dictionary:
	return BuildPlanner.movement_costs(all_buildings())

## 이동 차단 경계 집합 { edge_key: kind }. authored 장벽(강·벽)에서 합성한다(Barriers 노드).
## 다리 해제·건설벽 추가는 후속 — 그때 이 합성에 출처를 더한다. NpcPlanner도 world.barrier_edges()로 공유.
func barrier_edges() -> Dictionary:
	var b: Node = get_node_or_null("Barriers")
	return b.blocked_edge_set() if b != null else {}

## 적 클릭 공격 — 병종으로 근접/사격 자동 분기(팝업 없음). → party-action-menu.md
func _attack_enemy(entry: Dictionary) -> void:
	if entry["shoot"]:
		_shoot_target(entry)
	else:
		_melee_attack(entry)

## 근접: stand(적 인접 도달 칸)으로 이동(이동력 소모) 후 근접 전투. 승리 시 수비 타일 점령.
func _melee_attack(entry: Dictionary) -> void:
	var start := _cell_of(party)
	var ecell: Vector2i = entry["cell"]
	var stand: Vector2i = entry["stand"]
	if stand == start:
		_begin_battle(entry["enemy"], 1, ecell)   # 이미 인접 — 제자리 근접 전투(거리 1)
		return
	_deselect()
	_hide_party_info()
	_move_player_to(start, stand, {"enemy": entry["enemy"], "occupy": ecell})

## 원거리: stand(사거리에 드는 가장 먼 도달 칸)으로 (필요 시) 이동 후 제자리 사격(점령 없음).
func _shoot_target(entry: Dictionary) -> void:
	var start := _cell_of(party)
	var stand: Vector2i = entry["stand"]
	if stand == start:
		_shoot_enemy(entry["enemy"])   # 이미 사거리 안 — 제자리 사격
		return
	_deselect()
	_hide_party_info()
	_move_player_to(start, stand, {"shoot": entry["enemy"]})

## 제자리 사격: 현재 위치에서 원거리 전투(이동·점령 없음). 거리 = 부대↔적 헥스 거리.
func _shoot_enemy(enemy) -> void:
	_begin_battle(enemy, _engagement_distance(party, enemy), Vector2i(-1, -1))

## [흡수]/[파괴]: 캠프 인접 칸으로(필요 시) 이동 후 점령한다. absorb=흡수, false=파괴.
func _capture_camp(entry: Dictionary, absorb: bool) -> void:
	var start := _cell_of(party)
	var stand: Vector2i = entry["stand"]
	if stand == start:
		_do_capture(entry["camp"], absorb)   # 이미 인접 — 제자리 점령
		return
	_deselect()
	_hide_party_info()
	_move_player_to(start, stand, {"capture": entry["camp"], "absorb": absorb})

## 점령 실행: 행동을 끝내고(mark_attacked) 흡수/파괴한 뒤 선택·안개·일람을 갱신한다.
func _do_capture(camp, absorb: bool) -> void:
	party.mark_attacked()
	if absorb:
		_transfer_camp(camp, _player_faction)
	else:
		_destroy_camp(camp)
	if _selected:
		_deselect()
	_hide_party_info()
	_update_fog()
	party_roster.set_parties(_pmgr.units)

## 소유권 이전(점령 흡수, 플레이어·NPC 공용): 도메인(영지 세력 이동·목록 재배치)은 BuildingManager,
## 여기선 알림·표시·패배 확인만. 라벨색·시야는 이후 _update_fog가 반영.
func _transfer_camp(camp, new_faction) -> void:
	var r := _bmgr.transfer_camp(camp, new_faction)
	# 알림: 플레이어가 얻으면 점령, 플레이어가 잃으면 함락(NPC↔NPC는 조용히).
	if new_faction == _player_faction:
		toast.show_message("%s 점령!" % r["territory_name"])
	elif r["old_faction_name"] == _player_faction.name:
		toast.show_message("%s 함락!" % r["territory_name"])
	camp.visible = true       # 이전 직후 표시(NPC 캠프는 _update_npc_building_visibility가 탐험 기준으로 재조정)
	camp.refresh_body()       # 라벨색 + 오토타일 건물색을 새 세력색으로 갱신
	_check_immediate_defeat()   # 플레이어가 캠프를 뺏겼으면 — 부대도 없으면 즉시 패배

## 파괴: 캠프를 영지·맵에서 제거(BuildingManager 위임 — 획득 없음). 여기선 알림만.
func _destroy_camp(camp) -> void:
	toast.show_message("%s 파괴!" % _bmgr.destroy_camp(camp))   # 플레이어만 파괴 → 항상 플레이어 행동

## 적 인접 칸: 이미 인접이면 현재 칸, 아니면 인접한 도달 칸 하나, 없으면 현재 칸.
func _adjacent_stand(enemy_cell: Vector2i, start: Vector2i) -> Vector2i:
	var neighbors := terrain.get_surrounding_cells(enemy_cell)
	if start in neighbors:
		return start
	for n in neighbors:
		if _reachable.has(n):
			return n
	return start

## 플레이어가 적에게 개시하는 전투. 공격은 공격 행동을 끝낸다(mark_attacked)지만 이동력은 별개다(이동·공격 독립).
## distance=교전 헥스 거리(근접=1), occupy_cell=근접 승리 시 이동할 수비 타일((-1,-1)이면 점령 없음). → battle.md
func _begin_battle(defender, distance: int, occupy_cell: Vector2i) -> void:
	party.mark_attacked()
	if _selected:
		_deselect()
	_hide_party_info()
	var attacker = party
	await _run_battle(attacker, defender, distance, occupy_cell)
	# 이동·공격 독립: 공격 후에도 이동력이 남고 살아 있으면 다시 선택해 계속 이동할 수 있게 한다. → selection-and-movement.md
	# 단 전투 중 승패가 확정됐으면(_game_over) 결과 오버레이 위에 범위·패널을 다시 띄우지 않는다.
	if not _game_over and is_instance_valid(attacker) and attacker == party and attacker.soldiers > 0 and party.can_move():
		_show_party_info(party)
		_select()

## 두 부대의 교전 헥스 거리. 인접(또는 같은 칸)이면 1(근접), 아니면 a 기준 헥스 거리(사거리 범위 내). → battle.md
func _engagement_distance(a, b) -> int:
	var acell := _cell_of(a)
	var bcell := _cell_of(b)
	if acell == bcell or bcell in terrain.get_surrounding_cells(acell):
		return 1   # 인접 = 근접 교전
	var reach: int = maxi(a.attack_range(), 1)
	var dists: Dictionary = HexGrid.bfs_distances(terrain, acell, reach, MAP_WIDTH, MAP_HEIGHT)
	return int(dists.get(bcell, reach))   # 사거리 범위 내에서만 개시하므로 보통 존재; 밖이면 reach로 클램프

## 오버레이 전투를 띄우고 관전한다(입력 잠금). 종료까지 await 후 사상자를 반영한다.
## occupy_cell != (-1,-1)이고 근접 승리(수비 전멸·공격 생존)면 공격 부대를 그 타일로 이동(점령).
func _run_battle(attacker, defender, distance := 1, occupy_cell := Vector2i(-1, -1)) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return   # 연속/중첩 전투(교전·돌격·NPC 페이즈)에서 await 사이에 한쪽이 전멸·해제됐으면 건너뛴다
	_in_battle = true
	_refresh_command_buffs()                  # 최신 위치로 지휘 범위 갱신(맵 배지). 구 전투 ×1.2는 폐기, lang 미연동. → command-range.md
	# 모든 전투 = lang 오버레이(완전 교체 전투). → lang-battle.md
	var result: Array = await _run_lang_overlay(attacker, defender, distance)
	_apply_survivors(attacker, result[0])
	_apply_survivors(defender, result[1])
	_in_battle = false
	if occupy_cell != Vector2i(-1, -1) and is_instance_valid(defender) and defender.soldiers <= 0 and is_instance_valid(attacker) and attacker.soldiers > 0:
		attacker.position = terrain.map_to_local(occupy_cell)   # 근접 승리 → 수비 타일 점령
	_update_fog()
	party_roster.set_parties(_pmgr.units)
	# 부대 전멸로는 게임 오버되지 않는다(점령 승리만). 승패는 세력 소멸 판정(_update_endgame)에서만 난다.

## lang 근접 전투 오버레이를 띄우고(카메라 무관 CanvasLayer로 감쌈) 종료까지 await, [a최종병력, d최종병력] 반환.
## presenter는 부대 cfg로 재생하고 최종 병력수(finished)를 돌려준다 → game.gd가 party.soldiers에 반영. → lang-battle.md
func _run_lang_overlay(attacker, defender, distance: int) -> Array:
	var layer := CanvasLayer.new()   # Battlefield(Node2D)를 스크린 좌표로(게임 카메라 무관) 얹는다
	layer.layer = 60
	add_child(layer)
	var battle: Node2D = LANG_BATTLE_SCENE.instantiate()
	battle.overlay_mode = true   # add_child 전 설정 → _ready 자동 로드 안 함
	layer.add_child(battle)
	battle.get_node("HudLayer").layer = 61   # 전투 HUD를 전장 위·게임 UI 위로
	battle.start_overlay(LangBridge.battle_config(attacker, defender, distance))
	var counts: Array = await battle.finished   # [a_soldiers, d_soldiers]
	layer.queue_free()
	return [counts[0], counts[1]]

## 세력 소멸 유예 판정(턴 종료마다). 각 세력의 캠프 수로 유예 카운트를 갱신하고, 소멸한 세력은 붕괴시킨다.
## 이어서 정복 승리/플레이어 세력 소멸 패배를 판정한다.
## 즉시 패배 확인: 플레이어가 거점도 부대도 모두 잃으면(수복 수단 전무) 유예 없이 즉시 게임 오버.
## 부대 전멸(_apply_survivors)·거점 상실(_transfer_camp)·턴 종료(_update_endgame)마다 호출한다.
func _check_immediate_defeat() -> void:
	if _game_over:
		return
	var has_center := _player_faction.center_count() > 0
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
		var has_post: bool = f.center_count() > 0
		f.grace_turns = GameResult.advance_grace(has_post, f.grace_turns)
		if GameResult.grace_eliminated(f.grace_turns):
			f.eliminated = true
			_eliminate_faction(f)
	_refresh_grace_hud()
	_check_endgame()

## 세력 소멸(붕괴): 그 세력 소속 NPC 부대 제거(PartyManager 위임) 후 안개 갱신. 플레이어 세력이면 부대는 그대로(패배 처리).
func _eliminate_faction(faction) -> void:
	_pmgr.eliminate_faction_parties(faction.name)
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
	turn_banner.clear()   # 세력 배너 정리(결과 오버레이 위에 남지 않게). → turn.md
	_hide_party_info()
	result_overlay.show_result(title, subtitle)

## 결과 오버레이 클릭 → 타이틀로 복귀(페이드 전환).
func _on_result_dismissed() -> void:
	SceneManager.change_scene(TITLE_SCENE)

## NPC끼리 전투를 화면 없이 즉시 결산한다. lang(근접 resolve_engagement·원거리 resolve_ranged). → lang-battle.md
func _resolve_battle_headless(attacker, defender, distance := 1) -> void:
	_refresh_command_buffs()                  # 지휘 범위 갱신(맵 배지). → command-range.md
	# NPC↔NPC = lang(완전 교체). 근접(≤1)=1교전 공방, 원거리(≥2)=사격(궁병 side만 1볼리, 소모전). → lang-battle.md
	var rng := LangRng.new(_rng.randi())
	var a_unit := LangBridge.unit_from_party(attacker, 0)
	var d_unit := LangBridge.unit_from_party(defender, 1)
	var res: Dictionary
	if distance >= 2:
		var a_rounds := 1 if UnitTypes.is_ranged(attacker.archetype()) else 0
		var d_rounds := 1 if UnitTypes.is_ranged(defender.archetype()) else 0
		res = LangResolver.resolve_ranged(rng, a_unit, d_unit, a_rounds, d_rounds)
	else:
		res = LangResolver.resolve_engagement(rng, a_unit, d_unit)
	_apply_survivors(attacker, res["final_a_soldiers"])
	_apply_survivors(defender, res["final_d_soldiers"])

## 전투 최종 병력수를 부대에 반영한다 — 데이터·제거는 PartyManager, 여기선 플레이어 전멸 후처리만.
## 전멸한 게 활성 party였으면 선택 해제 + 남은 살아있는 부대로 재할당(없으면 null — 부대 0이어도 패배 아님, 세력 소멸은 거점 0에서만).
func _apply_survivors(p, final_soldiers: int) -> void:
	if _pmgr.apply_survivors(p, final_soldiers) != PartyManager.WIPED_PLAYER:
		return   # 생존/NPC 전멸/이미 해제 — 추가 후처리 없음
	if party == p:   # 활성 부대가 전멸 → 선택 해제 + 남은 살아있는 부대로 재할당(없으면 null)
		if _selected:
			_deselect()
		_hide_party_info()
		party = _first_living_unit()   # 부대 0이면 null(패배 아님 — 세력 소멸은 거점 0에서만)
	party_roster.set_parties(_pmgr.units)
	_check_immediate_defeat()   # 부대 전멸 — 거점도 없으면 즉시 패배

## 살아있는 첫 플레이어 부대(PartyManager 위임). 활성 부대 재할당에 쓴다.
func _first_living_unit():
	return _pmgr.first_living_unit()

## 주인공 부대를 선택하고 이동 범위·공격 가능 적을 표시한다. 정보 패널([소속]/[지휘]/[계속 이동] 버튼)·노란 목표선도 갱신한다.
func _select() -> void:
	_selected = true
	party.set_selected(true)
	_clear_popup_targets()
	_update_ranges()
	_show_party_info(party)
	_refresh_goal_line()

## 선택 부대에 이동 목표(move_goal)가 남았으면 현재→목표 전체 경로를 노란 선으로 그린다(없으면 지운다). → selection-and-movement.md
func _refresh_goal_line() -> void:
	if party != null and party.move_goal != Vector2i(-1, -1) and party.move_goal != _cell_of(party):
		var full := _full_path_to(_cell_of(party), party.move_goal)
		if full.size() >= 2:
			var pts := PackedVector2Array()
			for c in full:
				pts.append(terrain.map_to_local(c))
			path_preview.show_goal(pts)
			return
	path_preview.clear_goal()

## [소속] 버튼 노출 조건: 일반부대 + (인접 아군 영웅부대 있음 또는 이미 소속 보유). → party-lord.md
func _can_manage_lord(p) -> bool:
	if p == null or p.kind != Party.KIND_TROOP:
		return false
	return p.has_lord() or not _adjacent_player_heroes(p).is_empty()

## troop 칸에 헥스 인접한 플레이어 영웅부대(병력 있는 KIND_HERO) 목록. 소속 모달 후보. → party-lord.md
func _adjacent_player_heroes(troop) -> Array:
	var cell := _cell_of(troop)
	var neighbors := terrain.get_surrounding_cells(cell)
	var out: Array = []
	for p in _pmgr.units:
		if p.kind == Party.KIND_HERO and p.soldiers > 0 and _cell_of(p) in neighbors:
			out.append(p)
	return out

## 소속 변경 후 — 부대 일람·지휘 버프·정보 패널([소속] 버튼 상태)을 갱신한다. 턴 소비 없음. → party-lord.md
func _on_lord_changed() -> void:
	party_roster.set_parties(_pmgr.units)
	_refresh_command_buffs()   # 소속이 바뀌면 지휘 범위 버프 배지도 즉시 갱신. → command-range.md
	if _selected and party != null:
		_show_party_info(party)   # [독립]/소속 변경 후 [소속] 버튼 노출 조건 재평가

## 팝업 대상(점령/병합)을 모두 비운다. 팝업을 새로 열기 전에 호출.
func _clear_popup_targets() -> void:
	_capture_target = null
	_merge_target = null

## 인접 아군 부대 클릭 팝업 [병합]을 그 부대 근처에 연다. 대상 부대를 _merge_target에 둔다.
func _open_merge_popup(other) -> void:
	_clear_popup_targets()
	_merge_target = other
	party_action_menu.open(PartyActionMenu.merge_actions(), _screen_pos(other.position))

## 무방비 적 거점 클릭 팝업 [흡수][파괴]을 캠프 중심 근처에 연다. 대상 항목을 _capture_target에 둔다.
func _open_capture_popup(entry: Dictionary) -> void:
	_clear_popup_targets()
	_capture_target = entry
	party_action_menu.open(PartyActionMenu.capture_actions(), _screen_pos(terrain.map_to_local(entry["camp"].center_cell())))

## 월드 좌표 → 화면 좌표(카메라·줌 반영). 메뉴를 클릭 지점 근처에 띄우는 데 쓴다.
func _screen_pos(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

## 팝업 버튼 처리(거점 점령·병합). 중앙 메뉴·적 공격 팝업·작전 메뉴는 삭제됨(공격은 적 직접 클릭, 지휘는 [지휘] 모달).
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

## 부대 정보 박스 행동 버튼([소속]·[지휘]·[계속 이동]) 처리. → party-lord.md · squad-stance.md · selection-and-movement.md
func _on_party_info_action(id: String) -> void:
	if not _selected:
		return
	if id == "lord":
		lord_menu.open(party, _adjacent_player_heroes(party))   # 소속 영웅 설정/해제(턴 소비 없음)
	elif id == "command":
		command_menu.open(party)   # 영웅 따라옴/전투 스탠스 지속 설정(턴 소비 없음)
	elif id == "continue":
		# 기억된 이동 목표로 최대 전진(도달 시 _settle_after_move가 목표 해제). 경로 없으면 목표 취소.
		if party.move_goal != Vector2i(-1, -1) and not _try_max_advance(_cell_of(party), party.move_goal):
			party.move_goal = Vector2i(-1, -1)
			_refresh_goal_line()
			_show_party_info(party)
	elif id == "wait":
		# [대기]: 남은 이동력·공격을 포기하고 강제 E. 더 할 게 없으니 선택 해제·패널 닫고 배지·카운터 갱신. → turn.md
		party.wait()
		_deselect()
		_hide_party_info()
		_update_fog()

## 지휘 설정 변경 후 — 정보 패널([지휘] 버튼 상태)을 갱신한다. 턴 소비 없음. → squad-stance.md
func _on_command_changed() -> void:
	if _selected and party != null:
		_show_party_info(party)

## 턴 종료: 번호 +1, 모든 유닛 이동 리셋, 모든 영지 자원 수입, NPC 이동. 진행 중 선택은 해제한다.
func _on_turn_ended() -> void:
	if _in_battle or _game_over or _command_busy or _npc_turn_active:
		return   # 전투·게임 오버·전투우선 지휘 시퀀스·NPC 턴 진행 중에는 턴을 넘기지 않는다. → squad-stance.md · turn.md
	_finish_player_move()   # 이동 애니메이션 중이면 목적지로 스냅한 뒤 턴을 넘긴다.
	_finish_pending_follow_moves()   # 비차단 추종 트레일 중이면 하위부대도 목적지로 스냅. → squad-stance.md
	if _selected:
		_deselect()
	_hide_party_info()
	# NPC 턴 진입: 입력·"명령 남음" 카운터를 잠근다. end_turn이 플레이어 이동력을 리셋하므로
	# 이 플래그를 리셋·_update_fog보다 먼저 세워야 리셋된 카운트가 NPC 턴에 새지 않는다. → turn.md
	_npc_turn_active = true
	# 플레이어 부대 + NPC 부대 모두 이동 상태를 리셋한다(일람은 우리 세력만이라 _pmgr.units만 등록).
	_turn.end_turn(all_parties(), _bmgr.territories)
	_bmgr.tick_production()   # 1차 생산 건물 생산포인트 산출(1÷거리, 거리 기반) → production.md
	turn_hud.set_turn(_turn.number)
	_update_fog()   # 건설 완료 농장 시야 + NPC 현재 위치 표시를 안개에 반영.
	_update_endgame()   # 세력 소멸 유예 판정 → 소멸 시 부대 붕괴 + 정복 승리/패배
	if _game_over:
		return   # 승패 확정 → NPC 이동 생략(입력 잠금은 게임 오버가 대신 막음)
	# NPC 턴: 입력을 잠근 채(_npc_turn_active는 위에서 세움) NPC 페이즈를 끝까지 기다린 뒤 플레이어 턴으로. → turn.md
	await _move_npcs()
	_npc_turn_active = false
	if not _game_over:
		_begin_player_turn(true)   # NPC 턴을 거쳐 복귀 → "플레이어 턴입니다" 알림 표시

## 플레이어 턴 시작 — "명령 남음" 카운터를 새 턴 상태로 다시 계산해 표시한다. → turn.md
## announce=true(NPC 턴 후 복귀)면 상단 중앙에 "플레이어 턴입니다" 양피지 배너를 ~3초 띄우고,
## false(게임 시작 첫 턴)면 첫 조작을 방해하지 않게 배너를 감추기만 한다.
func _begin_player_turn(announce := false) -> void:
	if announce:
		turn_banner.announce("플레이어 턴입니다")
	else:
		turn_banner.clear()
	_refresh_exhausted()   # NPC 턴 동안 0으로 숨겨둔 카운터를 플레이어 부대 기준으로 복원

## NPC 턴: 세력 순차 → 영웅그룹 순차. 각 그룹은 이동을 마친 뒤 곧바로 공격한다(영웅 먼저·하위 순서). → turn.md · npc-movement.md
## 세력 차례 시작 시 배너, 그룹·교전이 시야 안이면 카메라 포커스+하이라이트, 시야 밖이면 즉시 처리.
func _move_npcs() -> void:
	_finish_pending_npc_moves()   # 재진입: 진행 중이던 이동을 목적지로 스냅.
	_npc_move_epoch += 1
	var epoch := _npc_move_epoch   # 이 라운드의 세대. 도중 새 라운드가 시작되면 아래 루프를 빠져나온다.

	var party_entries: Array = _npc_planner.party_entries()
	var camp_entries: Array = _npc_planner.camp_entries()

	# 세력 등장 순서 + 세력별 전체 NPC 부대. 그룹 묶기는 hero_groups가 한다.
	var factions: Array = []
	var by_faction: Dictionary = {}
	for p in _pmgr.npc_parties:
		var f: String = p.faction_name
		if not by_faction.has(f):
			by_faction[f] = []
			factions.append(f)
		by_faction[f].append(p)

	for f in factions:
		if epoch != _npc_move_epoch:
			return   # 새 라운드 시작 → 중단.
		var fac = _faction_named(f)
		if fac != null:
			turn_banner.set_faction(fac.name, fac.color)
		# 앞 세력 차례의 크로스-세력 헤드리스 전투로 이 세력 부대가 해제됐을 수 있어, 살아있는 것만 그룹 묶기에 넘긴다.
		var living: Array = []
		for p in by_faction[f]:
			if is_instance_valid(p):
				living.append(p)
		for group in NpcAi.hero_groups(living):
			if epoch != _npc_move_epoch:
				return
			if _game_over:
				return
			# 1) 그룹 이동 계획(즉석 수립, 점유만 실시간). 하위부대는 영웅을 추종하되 지휘 범위 내 적은 문다. → npc-movement.md 편제
			var plans: Dictionary = _npc_planner.plan_group_move(group, party_entries, camp_entries)
			await _move_group(group, plans)
			# 2) 그룹 공격: 영웅 먼저, 그다음 하위부대 순서로 1유닛씩(전투 완료 후 다음).
			for attacker in group:
				if epoch != _npc_move_epoch:
					return
				if _game_over:
					return
				if not is_instance_valid(attacker) or not (attacker in _pmgr.npc_parties):
					continue   # 앞 전투로 제거됨.
				await _npc_unit_act(attacker)
	_update_fog()

## NPC 영웅그룹 하나를 이동시킨다. 그룹이 플레이어 시야 안이면 카메라 포커스+정지 후 걸어가는 애니메이션,
## 시야 밖이면 목적지로 즉시 스냅(연출·대기 없음). 그룹원은 NPC_PARTY_STAGGER 간격 동시 이동. → npc-movement.md
func _move_group(group: Array, plans: Dictionary) -> void:
	# 시야 판정 + 이동 여부 + 포커스 대상(살아있는 첫 부대). group 스냅샷에 해제 부대가 섞일 수 있어 is_instance_valid로 거른다.
	var any_move := false
	var in_view := false
	var focus_p = null
	for p in group:
		if not is_instance_valid(p):
			continue
		if focus_p == null:
			focus_p = p
		var path: Array = plans.get(p, [])
		if path.size() < 2:
			continue
		any_move = true
		var dst: Vector2i = path[path.size() - 1]
		if fog.is_cell_visible(_cell_of(p)) or fog.is_cell_visible(dst):
			in_view = true
	if not any_move:
		return   # 그룹 전원 제자리/해제 → 아무것도 안 함(포커스도 생략)
	if in_view:
		if focus_p != null:
			_focus_camera(focus_p.position)   # 살아있는 그룹 대표로 포커스
		await get_tree().create_timer(NPC_FOCUS_PAUSE).timeout
		var max_dur := 0.0
		var idx := 0
		for p in group:
			if not is_instance_valid(p):
				continue
			var path: Array = plans.get(p, [])
			var delay: float = idx * NPC_PARTY_STAGGER
			idx += 1
			_start_party_animation(p, path, delay)
			var steps: int = maxi(0, path.size() - 1)
			max_dur = maxf(max_dur, delay + steps * MOVE_STEP_TIME)
		if max_dur > 0.0:
			await get_tree().create_timer(max_dur).timeout
	else:
		for p in group:   # 시야 밖 — 즉시 스냅.
			if not is_instance_valid(p):
				continue
			var path: Array = plans.get(p, [])
			if not path.is_empty():
				p.position = terrain.map_to_local(path[path.size() - 1])
		_update_fog()

## 카메라를 world_pos로 옮긴다(맵 범위 클램프). NPC 포커스·부대 일람 클릭이 공유. → turn.md
func _focus_camera(world_pos: Vector2) -> void:
	camera.position = Vector2(clampf(world_pos.x, _min_pos.x, _max_pos.x), clampf(world_pos.y, _min_pos.y, _max_pos.y))

## NPC 한 유닛의 공격 행동(그룹 이동 직후, 영웅→하위 순으로 호출). 판정은 기존과 동일, 전투는 _npc_engage로 연출. → npc-movement.md
func _npc_unit_act(attacker) -> void:
	if not attacker.can_attack():
		return
	var target = _npc_planner.adjacent_enemy(attacker)
	if target != null:
		if not NpcAi.should_engage(attacker.power(), target.power()):
			return   # 신중한 교전: 불리하면 공격하지 않고 대기
		attacker.mark_attacked()
		await _npc_engage(attacker, target, _engagement_distance(attacker, target))
		return
	# 공격할 적 부대가 없으면 인접한 무방비 적 캠프(중심 타일에 부대 없음)를 흡수한다.
	var camp = _npc_planner.adjacent_enemy_camp(attacker)
	if camp != null and party_on_cell(camp.center_cell()) == null:
		attacker.mark_attacked()
		_transfer_camp(camp, _faction_named(attacker.faction_name))
		_update_fog()

## NPC 교전 연출: 공격자·대상이 시야 안이면 카메라 포커스 + 토큰 하이라이트(1초)로 "누가 누굴"을 보이고 결산. → npc-movement.md
## 플레이어 대상 → 오버레이 관전(_run_battle). NPC 대상 → 씬 없이 헤드리스 즉시 결산.
func _npc_engage(attacker, target, dist: int) -> void:
	var in_view := _party_visible(attacker) or _party_visible(target)
	if in_view:
		_focus_camera(attacker.position)
		attacker.set_highlight(HL_ATTACKER)
		target.set_highlight(HL_TARGET)
		await get_tree().create_timer(NPC_ENGAGE_FOCUS).timeout
	if target in _pmgr.units:
		await _run_battle(attacker, target, dist)   # 플레이어 방어 → 오버레이 관전
	else:
		_resolve_battle_headless(attacker, target, dist)   # NPC끼리 → 씬 없이 즉시 결산
	if in_view:
		if is_instance_valid(attacker):
			attacker.set_highlight(HL_NONE)
		if is_instance_valid(target):
			target.set_highlight(HL_NONE)

## 부대가 플레이어 시야(안개) 안에 있는지 — NPC 이동/공격 연출을 보여줄지 판정.
func _party_visible(p) -> bool:
	return is_instance_valid(p) and fog.is_cell_visible(_cell_of(p))

## 세력 이름으로 Faction 객체를 찾는다(_factions에서). 없으면 null.
func _faction_named(fname: String):
	for f in _factions:
		if f.name == fname:
			return f
	return null

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

## 다중 클릭 이동 시작(순수 이동): 선택을 유지한 채 경로를 걸어가고, 완료 시 이동력을 차감하고 범위를 다시 그린다.
## 아군(같은 세력)은 통과 가능(no_stop), 적은 완전 차단. ESC로 중간 정지하면 간 만큼만 소모한다. → selection-and-movement.md
func _start_player_move(start_cell: Vector2i, dest_cell: Vector2i) -> void:
	var enemy := _enemy_occupied_cells(party)
	var ally := _ally_occupied_cells(party)
	var costs := _building_costs()
	var edges := barrier_edges()
	var path := HexGrid.reconstruct_path(terrain, start_cell, dest_cell, party.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges, ally)
	if path.size() < 2:
		return   # 제자리·도달 불가 — 아무것도 안 함(선택 유지)
	_move_path = path
	_move_arrived = 0
	_move_from_cell = start_cell   # 즉시 추종의 진행 방향 판정용(영웅 이번 이동 출발 칸). → squad-stance.md
	_move_dist = HexGrid.cost_distances(terrain, start_cell, party.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges)
	_player_move_target = dest_cell
	party_action_menu.close()          # 걷는 동안 팝업·범위·미리보기를 잠깐 감춘다(완료 시 다시 그림).
	var empty: Array[Vector2i] = []
	overlay.show_ranges(empty, empty)
	path_preview.clear()
	_hover_cell = Vector2i(-9999, -9999)
	var tw := _animate_path(party, path, 0.0, func(_cell: Vector2i) -> void:
		_move_arrived += 1
		_update_fog())
	_player_moving = true
	_player_tween = tw
	# 즉시 추종: 영웅이 따라옴이면 영웅 출발과 **동시에**(시차) 하위부대 트레일도 목적지 주변으로 출발한다. → squad-stance.md
	if party.is_hero() and party.command_follow and _can_command_subordinates(party):
		_launch_follow(party, dest_cell, start_cell)
	tw.finished.connect(func() -> void:
		_player_moving = false
		_player_tween = null
		_settle_after_move(dest_cell))   # 목적지까지 이동력 차감 + (전투우선)교전 + 선택 정리(다중 클릭 계속)

## 이동 마무리: stop_cell까지의 누적비용만큼 이동력을 깎고, 진행 상태를 비운다.
## 전투우선 영웅이면 하위부대 트레일 완료 후 사거리 적 교전. 그 뒤 아직 행동 가능하면 선택 유지(다중 클릭 계속), 아니면 해제.
func _settle_after_move(stop_cell: Vector2i) -> void:
	var mover = party
	party.spend_movement(int(_move_dist.get(stop_cell, 0)))
	_move_path = []
	_move_arrived = 0
	_refresh_exhausted()   # 이동력 차감 직후 "E" 갱신(애니 중 마지막 fog는 차감 전이라 stale). → selection-and-movement.md
	if mover.move_goal == _cell_of(mover):
		mover.move_goal = Vector2i(-1, -1)   # 목표 도달 → 이동 목표 해제. → selection-and-movement.md
	# 전투우선: 함께 출발한 트레일이 도착한 뒤 사거리 적 순차 교전. → squad-stance.md
	if mover.is_hero() and mover.command_follow and mover.command_engage and not _subordinates_of(mover).is_empty():
		await _engage_followers(mover)
	if _game_over:
		return   # 교전 중 승패 확정 → 결과 오버레이 위에 범위·패널을 다시 띄우지 않는다.
	if _selected and (party.can_move() or party.can_attack()):
		_select()
	else:
		_deselect()
		_hide_party_info()

## 이동 중 ESC 정지: 트윈을 멈추고 마지막 도달 칸에 스냅한 뒤 간 만큼만 이동력을 깎는다. 하위부대 트레일도 현재 위치에 멈춘다. → selection-and-movement.md
func _stop_player_move() -> void:
	if is_instance_valid(_player_tween) and _player_tween.is_valid():
		_player_tween.kill()
	_stop_follow_trails()   # 함께 움직이던 하위부대도 그 자리에 정지
	party.move_goal = Vector2i(-1, -1)   # ESC 정지 → 예약 이동 포기(노란 목표선 삭제)
	path_preview.clear_goal()
	# 향하던(다음) 칸에서 멈춘다(뒤로 안 감). _move_arrived = 마지막 도달(중앙) 칸 인덱스이므로 +1이 향하던 칸.
	var idx: int = mini(_move_arrived + 1, _move_path.size() - 1)
	# 멈출 칸에 다른 부대가 있으면(경로가 아군 칸을 통과 중이었을 수 있음) 안 겹칠 때까지 한 칸씩 더 전진.
	var occupied := _occupied_cells(party)
	while idx < _move_path.size() - 1 and occupied.has(_move_path[idx]):
		idx += 1
	var stop_cell: Vector2i = _move_path[idx]
	_player_move_target = stop_cell   # 활강 중 턴 종료(_finish_player_move) 스냅이 원래 목적지가 아닌 정지 칸으로 가도록 갱신
	# 순간이동 대신 현재 위치→멈출 칸을 이어 붙여 부드럽게 마저 이동(중간 겹침-회피 칸도 지나감).
	var glide: Array = [_move_path[_move_arrived]]   # [0]은 시작 더미(_animate_path가 안 읽음)
	for i in range(_move_arrived + 1, idx + 1):
		glide.append(_move_path[i])
	_move_path = []   # 활강 중 재-정지(_cancel_or_stop) 진입 차단
	_move_arrived = 0
	var tw := _animate_path(party, glide, 0.0, func(_c: Vector2i) -> void: _update_fog())
	if tw == null:
		party.position = terrain.map_to_local(stop_cell)
		_player_moving = false
		_player_tween = null
		_update_fog()
		_settle_after_move(stop_cell)
		return
	_player_tween = tw
	tw.finished.connect(func() -> void:
		_player_moving = false
		_player_tween = null
		_settle_after_move(stop_cell))

## 부대 칸→dest의 전체 경로(이동력 무시, 적 차단·아군 통과·건물·경계 반영). 미리보기·최대 전진 공용. → selection-and-movement.md
func _full_path_to(start_cell: Vector2i, dest_cell: Vector2i) -> Array:
	return HexGrid.reconstruct_path(terrain, start_cell, dest_cell, MAP_WIDTH + MAP_HEIGHT, MAP_WIDTH, MAP_HEIGHT, _enemy_occupied_cells(party), _building_costs(), barrier_edges(), _ally_occupied_cells(party))

## 범위 밖 칸 클릭 → 그 칸까지 전체 경로에서 이번 턴 이동력이 닿는 마지막 정지 칸까지 전진. 이동했으면 true. → selection-and-movement.md
func _try_max_advance(start_cell: Vector2i, dest_cell: Vector2i) -> bool:
	var full := _full_path_to(start_cell, dest_cell)
	if full.size() < 2:
		return false
	var ally := _ally_occupied_cells(party)
	var idx := HexGrid.path_reachable_prefix(terrain, full, party.move_points, _building_costs())
	while idx >= 1 and ally.has(full[idx]):
		idx -= 1   # 정지 불가(아군) 칸이면 한 칸 당긴다
	if idx < 1:
		return false
	_start_player_move(start_cell, full[idx])
	return true

## 호버 미리보기 갱신: 선택·이동 가능·이동 중 아님일 때만. 셀이 바뀔 때만 경로를 다시 계산한다. → selection-and-movement.md
func _update_hover(world_pos: Vector2) -> void:
	if not _selected or _player_moving or not party.can_move():
		path_preview.clear()
		_hover_cell = Vector2i(-9999, -9999)
		return
	var cell := terrain.local_to_map(terrain.to_local(world_pos))
	if cell == _hover_cell:
		return
	_hover_cell = cell
	var start := _cell_of(party)
	# 공격 가능 적 위 → 공격 위치까지 경로 + 칼/화살 마커.
	if _attack_targets.has(cell) and party.can_attack():
		var entry: Dictionary = _attack_targets[cell]
		var marker: String = "ranged" if entry["shoot"] else "melee"
		var mpos := terrain.map_to_local(cell)
		if entry["stand"] == start:
			path_preview.show_path(PackedVector2Array(), PackedVector2Array(), marker, mpos)   # 제자리 공격 — 마커만
		else:
			_draw_hover_path(start, entry["stand"], marker, mpos)
		return
	# 그 외 → 그 칸까지 이동 경로(파랑/빨강 분할).
	_draw_hover_path(start, cell, "", Vector2.ZERO)

## start→dest 전체 경로를 구해 이동력 닿는 구간(파랑)/넘는 구간(빨강)으로 나눠 그린다. marker는 공격 표식(있으면 dest에).
func _draw_hover_path(start: Vector2i, dest: Vector2i, marker: String, marker_pos: Vector2) -> void:
	var full := _full_path_to(start, dest)
	if full.size() < 2:
		path_preview.clear()
		return
	var idx := HexGrid.path_reachable_prefix(terrain, full, party.move_points, _building_costs())
	var blue := PackedVector2Array()
	for i in range(0, idx + 1):
		blue.append(terrain.map_to_local(full[i]))
	var red := PackedVector2Array()
	if idx < full.size() - 1:
		for i in range(idx, full.size()):
			red.append(terrain.map_to_local(full[i]))   # idx에서 파랑과 이어지도록 겹쳐 시작
	path_preview.show_path(blue, red, marker, marker_pos)

## 플레이어 부대를 start_cell에서 dest_cell까지 경로 따라 애니메이션 이동한다(공격·점령 접근 전용 — then_attack 필수).
## 이동 중에는 좌클릭을 잠그고(_player_moving), 각 칸 도착마다 _update_fog로 시야를 연다.
## 이동 완료 후 그 적과 전투를 시작하거나(공격) 거점을 점령한다(_after_move). 순수 이동은 _start_player_move가 담당.
func _move_player_to(start_cell: Vector2i, dest_cell: Vector2i, then_attack = null) -> void:
	var enemy := _enemy_occupied_cells(party)
	var ally := _ally_occupied_cells(party)
	var costs := _building_costs()
	var edges := barrier_edges()
	var path := HexGrid.reconstruct_path(terrain, start_cell, dest_cell, party.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges, ally)
	_move_dist = HexGrid.cost_distances(terrain, start_cell, party.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges)
	_player_move_target = dest_cell
	var tw := _animate_path(party, path, 0.0, func(_cell: Vector2i) -> void: _update_fog())
	if tw == null:
		# 경로가 없으면(예외·제자리) 즉시 목적지로 마무리한다.
		party.position = terrain.map_to_local(dest_cell)
		party.spend_movement(int(_move_dist.get(dest_cell, 0)))
		_update_fog()
		_after_move(then_attack)
		return
	_player_moving = true
	_player_tween = tw
	tw.finished.connect(func() -> void:
		_player_moving = false
		_player_tween = null
		party.spend_movement(int(_move_dist.get(dest_cell, 0)))   # 접근 이동분 차감(이동·공격 독립)
		_after_move(then_attack))

## 접근 이동 완료 후 처리(공격·점령 전용). then_action: 근접 전투({enemy, occupy})·제자리 사격({shoot})·점령({capture, absorb}).
func _after_move(then_action) -> void:
	if then_action == null:
		return   # 순수 이동은 _start_player_move가 담당 — 여기 오지 않는다(방어적).
	if then_action.has("capture"):
		_do_capture(then_action["capture"], then_action["absorb"])   # 이동 후 점령
	elif then_action.has("shoot"):
		_shoot_enemy(then_action["shoot"])                           # 이동 후 제자리 사격
	else:
		_begin_battle(then_action["enemy"], 1, then_action["occupy"])   # 이동 후 근접 전투(거리 1)

## 진행 중인 플레이어 이동을 즉시 끝낸다(턴 종료 시): 트윈을 죽이고 목적지로 스냅 + 시야 갱신.
func _finish_player_move() -> void:
	if not _player_moving:
		return
	if is_instance_valid(_player_tween) and _player_tween.is_valid():
		_player_tween.kill()
	party.position = terrain.map_to_local(_player_move_target)
	_player_moving = false
	_player_tween = null
	_move_path = []
	_move_arrived = 0
	_update_fog()

## 일반부대 troop이 지금 자기 영웅(lord)의 지휘 범위 안인지(전투 버프 판정). → command-range.md
## lord가 있고 살아있어야 하며, troop 칸이 lord 칸의 command_range 헥스 이내(지형 무관 헥스 거리).
func _in_command(troop) -> bool:
	if troop.lord == null or troop.lord.soldiers <= 0:
		return false
	var cr: int = troop.lord.command_range()
	var lord_cell := _cell_of(troop.lord)
	var troop_cell := _cell_of(troop)
	return troop_cell in HexGrid.cells_within(terrain, lord_cell, cr, MAP_WIDTH, MAP_HEIGHT)

## 모든 부대의 command_buffed(지휘 범위 안 여부)를 갱신한다 — 맵 배지의 단일 출처. → command-range.md
## 위치가 정착하는 지점(턴 종료·이동 완료·작전 종료·NPC 이동·소속 변경·편성)마다 부른다.
## (구 전투 ×1.2 버프는 폐기 — lang 전투에 미연동. 여기선 배지만 갱신.)
func _refresh_command_buffs() -> void:
	for p in all_parties():
		var buffed := _in_command(p)
		if p.command_buffed != buffed:
			p.command_buffed = buffed
			p.queue_redraw()

## 플레이어 부대(영웅 포함)의 "E"(이번 턴 더 할 것 없음) 표시를 갱신하고, 그 반대(명령 남은 부대 수)를 HUD에 넘긴다. → selection-and-movement.md
func _refresh_exhausted() -> void:
	var commandable := 0
	# 건물 비용·경계 장벽은 부대 무관이라 루프 밖에서 1회만 계산한다(_update_fog 경유로 애니 매 스텝 도는 핫패스).
	var costs := _building_costs()
	var edges := barrier_edges()
	for p in _pmgr.units:
		var has := _has_commands(p, costs, edges)   # 살아있고 이동력·공격 중 하나라도 남음 = E의 반대
		p.set_exhausted(p.soldiers > 0 and not has)
		if has:
			commandable += 1
	# NPC 턴 중엔 플레이어 부대 이동력이 이미 리셋돼 있으므로 카운터를 숨긴다(플레이어 차례에만 노출). → turn.md
	turn_hud.set_commands_left(0 if _npc_turn_active else commandable)

## p가 이번 턴 아직 명령 가능한지 = 살아있고 (실제 갈 수 있는 이동 칸이 있거나 현재 칸 공격 대상 있음). "E"의 반대·"명령 남음" 집계용. → turn.md
## 이동력이 남아도 아군 정지·지형·적으로 막혀 정지할 칸이 하나도 없으면 명령 없음으로 본다. costs·edges는 부대 무관 값 — 호출부에서 1회 계산해 넘긴다.
func _has_commands(p, costs: Dictionary, edges: Dictionary) -> bool:
	return p.soldiers > 0 and (_has_move_cell(p, costs, edges) or _has_target_from_cell(p))

## p가 이번 턴 이동력으로 실제 **정지 가능한** 칸이 하나라도 있는지 — _update_ranges와 같은 점유·지형·경계 규칙(HexGrid.movement_ranges)으로 판정. → selection-and-movement.md
func _has_move_cell(p, costs: Dictionary, edges: Dictionary) -> bool:
	if p.move_points <= 0:
		return false
	var start := _cell_of(p)
	var ranges := HexGrid.movement_ranges(terrain, start, p.move_points, MAP_WIDTH, MAP_HEIGHT, _enemy_occupied_cells(p), costs, edges, _ally_occupied_cells(p))
	return not (ranges["move"] as Array).is_empty()

## p가 현재 칸에서 지금 칠 수 있는 보이는 적이 있는지 — 공격 가능(미공격) + (근접=인접 / 원거리=사거리 내). "E" 판정용.
func _has_target_from_cell(p) -> bool:
	if not p.can_attack():
		return false
	var pcell := _cell_of(p)
	var rng: int = p.attack_range()
	# 근접(rng<2)=인접 6칸, 원거리=사거리 내. 두 API 반환 타입이 달라(Array[Vector2i] vs Array) 명시적으로 Array로 받는다.
	var in_range: Array = terrain.get_surrounding_cells(pcell) if rng < 2 else HexGrid.cells_within(terrain, pcell, rng, MAP_WIDTH, MAP_HEIGHT)
	for e in _pmgr.npc_parties:
		if not e.visible or e.soldiers <= 0:
			continue
		if _cell_of(e) in in_range:
			return true
	return false

## hero에 소속된(lord == hero) 병력 있는 하위부대 목록. 즉시 추종 대상. → squad-stance.md
func _subordinates_of(hero) -> Array:
	var out: Array = []
	for p in all_parties():
		if p.lord == hero and p.soldiers > 0:
			out.append(p)
	return out

## hero에 이번 턴 명령 가능한(can_move) 하위부대가 하나라도 있는지 — [지휘] 버튼 노출·즉시 추종 발동 조건. → squad-stance.md
func _can_command_subordinates(hero) -> bool:
	for f in _subordinates_of(hero):
		if f.can_move():
			return true
	return false

## 한 부대를 경로 따라 이동시키고 애니메이션이 끝날 때까지 await한다(전투우선 지휘 접근용). 도착 칸마다 시야 개방.
func _move_party_await(p, path: Array) -> void:
	var tw := _animate_path(p, path, 0.0, func(_cell: Vector2i) -> void: _update_fog())
	if tw == null:
		return
	await tw.finished

## 즉시 추종 launch: 영웅과 **동시에(시차)** 따라옴 하위부대들을 영웅 목적지(hero_dest) 주변 링으로 출발시킨다(비차단 트레일). → squad-stance.md
## from_cell(영웅 출발 칸)로 진행 방향(전방 링)을 판정하고, 이동력 큰 순으로 처리해 빠른 부대가 앞을 차지하고, 배정 칸·영웅 도착 칸을 예약해 겹치지 않는다.
## 걸어간 만큼 이동력을 소모(다음 영웅 이동에 또 따라올 수 있게). 이전 트레일이 남아 있으면 스냅 후 재launch.
func _launch_follow(hero, hero_dest: Vector2i, from_cell: Vector2i) -> void:
	_finish_pending_follow_moves()   # 이전(비차단) 트레일 스냅 — 같은 부대에 트윈 두 개가 걸리지 않게
	var followers := _subordinates_of(hero)
	if followers.is_empty():
		return
	followers.sort_custom(func(a, b): return a.movement() > b.movement())   # 빠른 부대가 전방 링 먼저 선점
	var costs := _building_costs()
	var edges := barrier_edges()
	# 적은 완전 차단, **아군(하위부대끼리·영웅)은 통과 가능**(no_stop) — 서로를 벽으로 막지 않게. 목적지·예약 칸엔 못 멈춤.
	var enemy := _enemy_occupied_cells(hero)
	var no_stop := _ally_occupied_cells(hero)   # 다른 하위부대·영웅 현재 칸(통과 O·정지 X)
	no_stop[_cell_of(hero)] = true               # 영웅 현재 칸도 통과만
	no_stop[hero_dest] = true                    # 영웅이 도착할 칸 예약(정지 불가)
	var delay := FOLLOW_STAGGER                  # 영웅(딜레이 0)보다 살짝 늦게 — "영웅부터 시작"
	for f in followers:
		if not is_instance_valid(f) or not f.can_move():
			continue   # 이미 이동력 소진했거나 전멸 → 그 자리에 남음
		var f_cell := _cell_of(f)
		no_stop.erase(f_cell)   # 자기 현재 칸은 정지 후보에서 빼지 않음(제자리 허용)
		var dist := HexGrid.cost_distances(terrain, f_cell, f.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges)
		var dest: Vector2i = HexGrid.follow_destination(terrain, hero_dest, from_cell, f_cell, f.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges, no_stop)
		if dest != f_cell:
			var path := HexGrid.reconstruct_path(terrain, f_cell, dest, f.move_points, MAP_WIDTH, MAP_HEIGHT, enemy, costs, edges, no_stop)
			if path.size() >= 2:
				# 이동력은 트레일이 끝날 때 **실제 도달한 칸** 기준으로 깎는다(ESC 정지 시 간 만큼만). 차감용 누적비용 맵을 보관.
				_follow_dist[f] = dist
				_start_follow_animation(f, path, delay)
				delay += FOLLOW_STAGGER
		no_stop[dest] = true    # 예약 — 다음 하위부대가 이 최종 칸에 멈추지 않게(통과는 가능)

## 전투우선: 트레일이 다 끝나길 기다린 뒤, 각 하위부대가 사거리 내 적이 있고 전력이 신중 기준 이상이면 순차로 교전. → squad-stance.md
## 시퀀스 동안 _command_busy로 맵 클릭·턴 종료를 잠근다(전투 중은 _in_battle 병행). 중단은 _game_over.
func _engage_followers(hero) -> void:
	_command_busy = true
	await _await_follow_trails()   # 동시에 출발한 트레일이 모두 도착할 때까지
	for f in _subordinates_of(hero):
		if _game_over:
			break
		if not is_instance_valid(f):
			continue
		var target = _npc_planner.adjacent_enemy(f)
		if target != null and is_instance_valid(target) and NpcAi.should_engage(f.power(), target.power()):
			f.mark_attacked()
			var d := _engagement_distance(f, target)
			var occ := _cell_of(target) if d == 1 else Vector2i(-1, -1)   # 근접 승리 시만 점령
			await _run_battle(f, target, d, occ)
	_command_busy = false

## 진행 중인 추종 트레일이 모두 끝날 때까지 대기(프레임 폴링). 트윈은 완료 시 스스로 _follow_tweens에서 빠진다.
func _await_follow_trails() -> void:
	while not _follow_tweens.is_empty():
		await get_tree().process_frame

## 하위부대 한 부대의 추종 이동 애니메이션(플레이어 유닛 — 항상 보이며 걸으며 시야를 연다). 턴 종료·정지 스냅용으로 추적.
## 완주하면 목적지까지 실제 이동분을 차감한다(_settle_follower).
func _start_follow_animation(f, path: Array, delay: float) -> void:
	var tw := _animate_path(f, path, delay, func(_cell: Vector2i) -> void: _update_fog())
	if tw == null:
		return
	_follow_targets[f] = path[path.size() - 1]
	_follow_tweens.append(tw)
	tw.finished.connect(func() -> void:
		_follow_tweens.erase(tw)
		_settle_follower(f, _follow_targets.get(f, _cell_of(f))))   # 완주 → 목적지까지 차감

## 하위부대 트레일 종료 정산: 실제 도달한 cell까지의 누적비용만 이동력에서 깎고, 추적을 지운다. → squad-stance.md
func _settle_follower(f, cell: Vector2i) -> void:
	if is_instance_valid(f) and _follow_dist.has(f):
		f.spend_movement(int(_follow_dist[f].get(cell, 0)))
	_follow_dist.erase(f)
	_follow_targets.erase(f)
	_refresh_exhausted()   # 이동력 차감 직후 "E" 갱신 — 애니 중 마지막 fog는 차감 전이라 stale(_settle_after_move와 동일 관례). → selection-and-movement.md

## 진행 중인 추종 트레일을 즉시 끝낸다(턴 종료 시): 트윈을 죽이고 각 하위부대를 목적지 칸으로 스냅 + 전량 차감. → squad-stance.md
func _finish_pending_follow_moves() -> void:
	for t in _follow_tweens.duplicate():
		if is_instance_valid(t) and t.is_valid():
			t.kill()
	_follow_tweens.clear()
	for f in _follow_targets.keys():
		if is_instance_valid(f):
			f.position = terrain.map_to_local(_follow_targets[f])
		_settle_follower(f, _follow_targets.get(f, Vector2i(-1, -1)))

## 추종 트레일을 현재 위치(진행 중인 칸)에서 멈춘다(영웅 ESC 정지 시): 트윈을 죽이고 각 하위부대를 현재 칸으로 스냅 + 실제 이동분만 차감. → squad-stance.md
func _stop_follow_trails() -> void:
	for t in _follow_tweens.duplicate():
		if is_instance_valid(t) and t.is_valid():
			t.kill()
	_follow_tweens.clear()
	for f in _follow_targets.keys():
		var c := _cell_of(f) if is_instance_valid(f) else Vector2i(-1, -1)
		if is_instance_valid(f):
			f.position = terrain.map_to_local(c)   # 현재 칸에 스냅(목적지 아님)
		_settle_follower(f, c)   # 실제 걸어간 칸까지만 이동력 차감

## 선택을 해제하고 범위 표시를 지운다.
func _deselect() -> void:
	_selected = false
	party.set_selected(false)
	_clear_popup_targets()
	_reachable = {}
	_attack_targets = {}
	_capture_targets = {}
	_merge_targets = {}
	_move_cells = []
	_attack_cells = []
	_capture_cells = []
	party_action_menu.close()
	var empty: Array[Vector2i] = []
	overlay.show_ranges(empty, empty)
	path_preview.clear()
	path_preview.clear_goal()
	_hover_cell = Vector2i(-9999, -9999)

## 부대 정보 패널을 연다. 우측 상단을 공유하는 부대 일람·건물 정보는 감춘다.
## 선택 중인 플레이어 부대면 행동 버튼을 붙인다: 일반부대=[소속](관리 가능 시), 영웅부대=[지휘](명령 가능 하위부대 있을 시). → party-lord.md · squad-stance.md
func _show_party_info(party_to_show) -> void:
	building_info.close()
	var actions: Array = []
	if _selected and party_to_show == party:
		if _can_manage_lord(party_to_show):
			actions.append({"id": "lord", "label": "소속"})
		if party_to_show.is_hero() and _can_command_subordinates(party_to_show):
			actions.append({"id": "command", "label": "지휘"})
		# 이동 목표가 남았고 아직 이동력이 있으면 [계속 이동]. → selection-and-movement.md
		if party_to_show.move_goal != Vector2i(-1, -1) and party_to_show.move_goal != _cell_of(party_to_show) and party_to_show.can_move():
			actions.append({"id": "continue", "label": "계속 이동"})
		# 아직 할 게 남은 부대면 [대기] — 남은 이동력·공격을 포기하고 강제 E 진입. → turn.md
		if _has_commands(party_to_show, _building_costs(), barrier_edges()):
			actions.append({"id": "wait", "label": "대기"})
	party_info.open(party_to_show, actions)
	party_roster.hide()

## 부대 정보·건물 정보 패널을 닫고, 부대 일람을 다시 표시한다.
func _hide_party_info() -> void:
	building_info.close()
	party_info.close()
	party_roster.show()

## 부대 일람에서 항목을 클릭하면 그 부대 위치로 카메라를 즉시 이동한다(맵 범위 클램프).
func _on_party_focused(focused_party) -> void:
	_focus_camera(focused_party.position)

## "명령 남음 N" 클릭 → 명령 남은 플레이어 부대 중 현재 활성 부대 다음으로 순환 포커스·선택한다. → turn.md
## NPC 턴·전투·건설·이동 중엔 무시(플레이어 조작 잠금 상황과 동일 게이트).
func _on_next_unit_requested() -> void:
	if _npc_turn_active or _in_battle or _game_over or _command_busy or _player_moving or _build_mode:
		return
	var candidates: Array = []
	var costs := _building_costs()
	var edges := barrier_edges()
	for p in _pmgr.units:
		if _has_commands(p, costs, edges):
			candidates.append(p)
	if candidates.is_empty():
		return
	var here := candidates.find(party)   # 현재 활성 부대의 다음(없으면 처음)으로 순환
	var next_party = candidates[(here + 1) % candidates.size()] if here != -1 else candidates[0]
	if _selected:
		_deselect()
	party = next_party
	_focus_camera(party.position)
	_show_party_info(party)
	if party.can_move() or party.can_rest():
		_select()

## 캠프 메뉴에서 건물을 선택하면 건설 모드로 들어간다.
## 건물을 지을 수 있는 영역(영지 시야) 윤곽선을 파랑으로 표시한다 — 시야는 배치 중 변하지 않으므로 한 번만 계산한다.
func _on_build_selected(type_id: String, territory: Territory) -> void:
	_enter_build_mode(type_id, territory)

## 캠프 메뉴의 "캠프 건설" → 새 영지 캠프 건설 모드. 배치 영역은 활성 부대 시야(_build_vision).
## 활성 부대가 비어(병력 0) 있으면 시야가 없어 배치 불가 → 진입하지 않고 안내 토스트만 띄운다.
func _on_found_camp_requested(territory: Territory) -> void:
	camp_menu.close_menu()
	if party == null or party.soldiers <= 0:
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

## 현재 건설 종류의 배치 가능 시야 {cell: true}. → production.md 배치 규칙
## 캠프=활성 부대 시야 / 1차 생산=건물∪부대 시야 / 기타=마을회관 인접.
func _build_vision() -> Dictionary:
	if _build_type == BuildingTypes.CAMP:
		var vis := {}
		for c in HexGrid.cells_within(terrain, _cell_of(party), party.vision(), MAP_WIDTH, MAP_HEIGHT):
			vis[c] = true
		return vis
	if BuildingTypes.get_type(_build_type).get("primary_production", false):
		return _player_build_vision()   # 1차 생산 = 건물∪부대 시야
	return BuildPlanner.town_hall_adjacent_cells(terrain, _bmgr.buildings, MAP_WIDTH, MAP_HEIGHT)   # 기타 = 마을회관 인접

## 플레이어 건물 시야 ∪ 플레이어 부대 시야 합집합(1차 생산 건물 배치 범위). → production.md
func _player_build_vision() -> Dictionary:
	var vis := BuildPlanner.buildings_vision(terrain, _bmgr.buildings, MAP_WIDTH, MAP_HEIGHT)
	for p in _pmgr.units:
		if p.faction_name == _player_faction.name and p.soldiers > 0:
			for c in HexGrid.cells_within(terrain, _cell_of(p), p.vision(), MAP_WIDTH, MAP_HEIGHT):
				vis[c] = true
	return vis

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
	var vision := _build_vision()
	var occupied := BuildPlanner.occupied_cells(all_buildings())
	var terrains: Array = BuildingTypes.get_type(_build_type).get("buildable_terrains", [])
	return BuildPlanner.can_place(terrain, cell, MAP_WIDTH, MAP_HEIGHT, vision, occupied, _build_footprint(), terrains)

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
	# 건축 조건(선행·자재) 재확인(방어적). 리스트에서 비활성 항목은 애초에 못 고르지만, 배치 시점에도 지킨다.
	if not BuildPlanner.can_build(_build_territory, _build_type):
		return
	_build_territory.build_pay(_build_type)   # 자재 차감
	if _build_type == BuildingTypes.CAMP:
		_bmgr.found_camp(cell)   # 캠프는 새 영지("전초기지 N") 생성 → production.md
		_update_fog()
	else:
		_bmgr.place_building(cell, _build_type, _build_territory)   # 건설 중 생성 + 배정/편입 + 등록
	_exit_build_mode()

## [거점 변경] — 다음 플레이어 거점으로 배정을 옮긴다(BuildingManager 위임). 바뀌었으면 패널 갱신. → production.md
func _on_center_change(b) -> void:
	if _bmgr.cycle_production_center(b):
		_refresh_building_info(b)

## 건물 정보 패널을 현재 상태(거리 갱신)로 다시 그린다.
func _refresh_building_info(b) -> void:
	building_info.open(b, building_info._demolish_btn.visible, _bmgr.center_distance(b))

## ESC·우클릭: 이동 애니메이션 중이면 향하던 칸에서 정지(선택 유지), 아니면 선택 해제. → selection-and-movement.md
## 공격·점령 접근 이동(_move_path 빈)은 멈추지 않는다. 전투·지휘 시퀀스·NPC 턴 중엔 해제도 막는다(무시).
func _cancel_or_stop() -> void:
	if _player_moving and not _move_path.is_empty():
		_stop_player_move()
	elif _selected and not _player_moving and not _command_busy and not _in_battle and not _game_over and not _npc_turn_active:
		_deselect()
		_hide_party_info()

## 줌 조절: 마우스 휠 / 트랙패드 두 손가락 스크롤 / 트랙패드 핀치.
## 값이 작을수록 확대이므로, 확대 = _zoom_level 감소.
func _unhandled_input(event: InputEvent) -> void:
	if ModalStack.blocking():
		return   # 모달 열림 동안 게임 월드 입력(클릭·줌) 차단 → modal.md
	# 건설 모드에서는 배치 입력만 처리한다(일반 클릭·선택 차단).
	if _build_mode:
		_handle_build_input(event)
		return
	# ESC/우클릭: 이동 중이면 정지(향하던 칸), 아니면 선택 해제. → selection-and-movement.md
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_or_stop()
		return
	# 호버 경로 미리보기(선택 중, 이동/전투/지휘 시퀀스 아님). → selection-and-movement.md
	if event is InputEventMouseMotion:
		if _selected and not _command_busy and not _in_battle and not _game_over and not _npc_turn_active:
			_update_hover(get_global_mouse_position())
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level - ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_or_stop()   # 우클릭: 이동 중이면 정지, 아니면 선택 해제. → selection-and-movement.md
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# 화면 가장자리 클릭은 카메라 팬 전용(→ _process). 게임 클릭으로 넘기지 않는다.
			if _edge_pan_dir() != Vector2.ZERO:
				return
			# 이동 애니메이션·전투우선 지휘 시퀀스·전투·게임 오버·NPC 턴 중에는 새 클릭을 무시. 줌은 위에서 처리됨. → turn.md
			if not _player_moving and _follow_tweens.is_empty() and not _command_busy and not _in_battle and not _game_over and not _npc_turn_active:
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
	if ModalStack.blocking():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)   # 엣지 커서가 모달 위에 남지 않도록 복원
		return   # 모달 열림 동안 지도 카메라 팬(WASD·엣지 스크롤) 차단 → modal.md
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

	# 마우스 화면 가장자리: 일반 지도 탐색 중에만(건설 모드 제외) 커서를 방향 화살표로 바꾸고,
	# 좌클릭을 누르는 동안 그 방향으로 팬. 건설 모드에선 커서를 기본 화살표로 되돌린다(엣지 커서 stuck 방지).
	if _build_mode:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	else:
		var edge := _edge_pan_dir()
		Input.set_default_cursor_shape(_edge_cursor_shape(edge))
		if edge != Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			dir += edge

	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * CAM_SPEED * delta
		camera.position.x = clampf(camera.position.x, _min_pos.x, _max_pos.x)
		camera.position.y = clampf(camera.position.y, _min_pos.y, _max_pos.y)

## 마우스가 화면 가장자리(EDGE_MARGIN)에 있으면 팬 방향을, 아니면 ZERO를 돌려준다.
func _edge_pan_dir() -> Vector2:
	var vp := get_viewport()
	return _edge_dir_for(vp.get_mouse_position(), vp.get_visible_rect().size)

## 마우스 좌표·뷰 크기 → 가장자리 팬 방향(순수 함수, 테스트 대상).
func _edge_dir_for(mouse: Vector2, view_size: Vector2) -> Vector2:
	var dir := Vector2.ZERO
	if mouse.x <= EDGE_MARGIN:
		dir.x -= 1.0
	elif mouse.x >= view_size.x - EDGE_MARGIN:
		dir.x += 1.0
	if mouse.y <= EDGE_MARGIN:
		dir.y -= 1.0
	elif mouse.y >= view_size.y - EDGE_MARGIN:
		dir.y += 1.0
	return dir

## 팬 방향에 맞는 커서 모양(방향을 가리키는 화살표). ZERO면 기본 화살표.
func _edge_cursor_shape(dir: Vector2) -> Input.CursorShape:
	if dir == Vector2.ZERO:
		return Input.CURSOR_ARROW
	if dir.x == 0.0:
		return Input.CURSOR_VSIZE   # ↕ 위/아래
	if dir.y == 0.0:
		return Input.CURSOR_HSIZE   # ↔ 좌/우
	# 대각선: ↗↙ = FDIAG(우상·좌하), ↘↖ = BDIAG(우하·좌상)
	return Input.CURSOR_FDIAGSIZE if dir.x * dir.y < 0.0 else Input.CURSOR_BDIAGSIZE
