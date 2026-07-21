extends GutTest
## NpcPlanner — NPC 의사결정(표적 선정·후퇴·포지셔닝·그룹 계획) 테스트.
## game.gd 대신 월드 조회 스텁(WorldStub)을 주입해 Node 트리 없이 판단만 검증한다.
## 헥스 인접·지형은 엔진 의존이라 실제 헥스 타일셋 TileMapLayer로 검증한다(test_npc_ai 패턴).

const MAP := 41
const PartyScript = preload("res://scenes/party/party.gd")
const BuildingScript = preload("res://scenes/building/building.gd")
const PlannerScript = preload("res://scenes/game/npc_planner.gd")

## NpcPlanner 월드 조회 인터페이스 스텁 — game.gd의 all_parties/all_buildings/party_on_cell/
## blocked_for와 같은 이름·형태.
class WorldStub:
	var terrain: TileMapLayer
	var parties: Array = []
	var buildings: Array = []

	func _init(t: TileMapLayer) -> void:
		terrain = t

	func all_parties() -> Array:
		return parties

	func all_buildings() -> Array:
		return buildings

	func party_on_cell(cell: Vector2i):
		for p in parties:
			if p.soldiers > 0 and terrain.local_to_map(p.position) == cell:
				return p
		return null

	func blocked_for(_p) -> Dictionary:
		return {}

var terrain: TileMapLayer
var world: WorldStub
var planner

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	world = WorldStub.new(terrain)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	planner = PlannerScript.new(terrain, MAP, MAP, rng, world)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

## 전력(power) = 병력수인 부대를 cell에 만들어 스텁 월드에 등록한다(전력 = Party.power() = soldiers).
## 병종은 경보병(근접·클래스 이동력)으로 둔다 — 그룹 이동 계획이 movement()>0을 필요로 한다.
func _party(fn: String, cell: Vector2i, power := 40) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.faction_name = fn
	p.position = terrain.map_to_local(cell)
	p.kind = PartyScript.KIND_TROOP
	p.troop_type = "light_infantry"
	p.soldiers = power
	world.parties.append(p)
	return p

## 세력 fn 소속 캠프를 cell에 만들어 스텁 월드에 등록한다. fn이 ""면 무소속.
func _camp(fn: String, cell: Vector2i) -> Node2D:
	var b: Node2D = BuildingScript.new()
	add_child_autofree(b)
	b.setup(terrain, cell, "camp")
	if fn != "":
		var f = load("res://scenes/faction/faction.gd").new(fn, Color.RED)
		var t = load("res://scenes/territory/territory.gd").new(fn + " 영지", {})
		f.add_territory(t)
		t.add_building(b)
	world.buildings.append(b)
	return b

# --- party_entries / camp_entries ---

func test_party_entries_skips_empty() -> void:
	_party("A", _center(), 10)
	var empty: Node2D = PartyScript.new()   # 멤버 0 부대 — 목록 제외
	add_child_autofree(empty)
	empty.faction_name = "A"
	world.parties.append(empty)
	var entries: Array = planner.party_entries()
	assert_eq(entries.size(), 1, "멤버 있는 부대만 수록")
	assert_eq(entries[0]["cell"], _center(), "부대 칸")
	assert_eq(entries[0]["faction"], "A", "세력 이름")

func test_camp_entries_centers_only() -> void:
	_camp("A", _center())
	var farm: Node2D = BuildingScript.new()   # 비거점 — 제외
	add_child_autofree(farm)
	farm.setup(terrain, _center() + Vector2i(10, 0), "farm")
	world.buildings.append(farm)
	var entries: Array = planner.camp_entries()
	assert_eq(entries.size(), 1, "거점(캠프)만 수록(농장 제외)")
	assert_eq(entries[0]["faction"], "A", "영지 경유 세력 이름")

# --- 밴드 셀(_band_cells) ---

func test_band_cells_ring() -> void:
	var band: Array = planner._band_cells([_center()], 2, 3)
	var within3: Array = HexGrid.cells_within(terrain, _center(), 3, MAP, MAP)
	var within1: Array = HexGrid.cells_within(terrain, _center(), 1, MAP, MAP)
	assert_eq(band.size(), within3.size() - within1.size(), "밴드 = 헥스 거리 2~3 링")
	assert_false(_center() in band, "중심(거리 0)은 밴드 밖")

# --- 후퇴 판단(_should_retreat) ---

func test_should_retreat_vs_stronger_nearby() -> void:
	var me := _party("A", _center(), 10)
	_party("B", _center() + Vector2i(2, 0), 100)   # RETREAT_SCAN(6) 안 압도적 적
	assert_true(planner._should_retreat(me), "근처 강한 적 → 후퇴")

func test_no_retreat_vs_weaker_or_far() -> void:
	var me := _party("A", _center(), 100)
	_party("B", _center() + Vector2i(2, 0), 10)   # 약한 적
	assert_false(planner._should_retreat(me), "약한 적 → 후퇴 안 함")
	var lone := _party("A", _center() + Vector2i(15, 15), 10)   # 강한 적도 스캔(6) 밖
	assert_false(planner._should_retreat(lone), "스캔 밖 적은 무시")

# --- 후퇴 목적지(_safe_retreat_cells) ---

func test_safe_retreat_cells_excludes_threatened_and_enemy() -> void:
	var safe_camp := _camp("A", _center() + Vector2i(-10, 0))
	var risky_camp := _camp("A", _center() + Vector2i(10, 0))
	_camp("B", _center() + Vector2i(0, 12))   # 적 캠프 — 후퇴 대상 아님
	_party("B", risky_camp.center_cell() + Vector2i(2, 0), 50)   # 적이 2칸 안 → 그 캠프 제외
	assert_eq(planner._safe_retreat_cells("A"), [safe_camp.center_cell()],
		"위협받는 캠프·적 캠프 제외, 안전한 자기 캠프만")

# --- 사거리 내 적 탐지(adjacent_enemy) ---

func test_adjacent_enemy_skips_ally() -> void:
	var me := _party("A", _center(), 40)
	_party("A", _center() + Vector2i(1, 0), 40)   # 아군 — 대상 아님
	var enemy := _party("B", _center() + Vector2i(-1, 0), 40)
	assert_eq(planner.adjacent_enemy(me), enemy, "인접 적을 찾는다(아군 제외)")

# --- 표적 우선순위(targets_for) ---

func test_targets_for_prefers_nearby_undefended_camp() -> void:
	var me := _party("A", _center(), 100)
	var camp := _camp("B", _center() + Vector2i(5, 0))   # PRIORITY_SCAN(8) 안 무방비 적 캠프
	_party("B", _center() + Vector2i(18, 0), 10)          # 먼 적 부대(rest 티어)
	var pe: Array = planner.party_entries()
	var ce: Array = planner.camp_entries()
	assert_eq(planner.targets_for(me, pe, ce), [camp.center_cell()], "근처 무방비 적 캠프 최우선")

func test_targets_for_retreats_to_safe_camp() -> void:
	var me := _party("A", _center(), 10)
	_party("B", _center() + Vector2i(1, 0), 200)   # 압도적 적 인접 → 후퇴 판단
	var home := _camp("A", _center() + Vector2i(-12, 0))
	var pe: Array = planner.party_entries()
	var ce: Array = planner.camp_entries()
	assert_eq(planner.targets_for(me, pe, ce), [home.center_cell()], "후퇴 → 안전한 자기 캠프 중심")

# --- 그룹 이동 계획(plan_group_move) ---

func test_plan_group_move_hero_moves_toward_target() -> void:
	var hero := _party("A", _center(), 100)
	hero.kind = PartyScript.KIND_HERO
	var enemy := _party("B", _center() + Vector2i(6, 0), 10)
	var pe: Array = planner.party_entries()
	var ce: Array = planner.camp_entries()
	var plans: Dictionary = planner.plan_group_move([hero], pe, ce)
	assert_true(plans.has(hero), "영웅 계획 수록")
	var path: Array = plans[hero]
	assert_eq(path[0], _center(), "경로 시작 = 영웅 현재 칸")
	assert_true(path.size() >= 2, "적을 향해 이동(제자리 아님)")
	var start_d := terrain.map_to_local(_center()).distance_to(enemy.position)
	var end_d := terrain.map_to_local(path[path.size() - 1]).distance_to(enemy.position)
	assert_lt(end_d, start_d, "경로 끝이 적에게 더 가깝다")
