extends GutTest
## SiegeSystem — 사다리 레코드(설치·통로·카운트다운·정리)·성벽 차단/붕괴·헤드리스 투석·충차 반격 테스트.
## game.gd 대신 월드 조회 스텁(WorldStub)을 주입해 공성 도메인만 검증한다(확률 판정 자체는 test_siege.gd 몫).

const MAP := 41
const PartyScript = preload("res://scenes/party/party.gd")
const HumanScript = preload("res://scenes/human/human.gd")
const BuildingScript = preload("res://scenes/building/building.gd")
const SystemScript = preload("res://scenes/siege/siege_system.gd")

## SiegeSystem 월드 조회 인터페이스 스텁 — game.gd의 all_buildings/party_on_cell과 같은 이름·형태.
class WorldStub:
	var terrain: TileMapLayer
	var parties: Array = []
	var buildings: Array = []

	func _init(t: TileMapLayer) -> void:
		terrain = t

	func all_buildings() -> Array:
		return buildings

	func party_on_cell(cell: Vector2i):
		for p in parties:
			if not p.members.is_empty() and terrain.local_to_map(p.position) == cell:
				return p
		return null

## 공성 유닛 스텁 — SiegeUnit의 attack()/min_range()/hit_points만 흉내(충차=min_range 1, 투석기=4).
class SiegeUnitStub:
	var hit_points := 40
	var _attack := 50
	var _min_range := 4

	func _init(p_min_range := 4, p_attack := 50, p_hp := 40) -> void:
		_min_range = p_min_range
		_attack = p_attack
		hit_points = p_hp

	func attack() -> int:
		return _attack

	func min_range() -> int:
		return _min_range

var terrain: TileMapLayer
var world: WorldStub
var siege

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	world = WorldStub.new(terrain)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	siege = SystemScript.new(terrain, rng, world)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

## 세력 fn 소속 성벽 거점(마을회관)을 cell에 만들어 스텁 월드에 등록한다.
func _walled(fn: String, cell: Vector2i) -> Node2D:
	var b: Node2D = BuildingScript.new()
	add_child_autofree(b)
	b.setup(terrain, cell, "town_hall")
	b.wall_level = 1
	b.wall_hp = Siege.WALL_MAX_HP
	b.gate_hp = Siege.GATE_MAX_HP
	var f = load("res://scenes/faction/faction.gd").new(fn, Color.RED)
	var t = load("res://scenes/territory/territory.gd").new(fn + " 영지", {})
	f.add_territory(t)
	t.add_building(b)
	world.buildings.append(b)
	return b

## 세력 fn 1인 부대를 cell에 만들어 스텁 월드에 등록한다.
func _party(fn: String, cell: Vector2i) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.faction_name = fn
	p.position = terrain.map_to_local(cell)
	p.add_member(HumanScript.new(fn))
	world.parties.append(p)
	return p

## 성벽 거점 b의 ring 셀에 인접한 밖 칸을 찾아 부대를 세우고 사다리를 설치한다. 설치 성공을 단언.
func _place(b: Node2D, fn := "A") -> Node2D:
	var ring: Vector2i = b.cells[1] if b.cells[1] != b.center_cell() else b.cells[2]
	var stand := Vector2i(-1, -1)
	for n in terrain.get_surrounding_cells(ring):
		if not b.contains_cell(n):
			stand = n
			break
	var p := _party(fn, stand)
	assert_true(siege.place_ladder(p), "성벽 인접 부대는 사다리 설치 성공")
	return p

# --- 설치 / 대상 ---

func test_place_ladder_records_and_one_per_face() -> void:
	var b := _walled("B", _center())
	var p := _place(b)
	assert_eq(siege.ladders.size(), 1, "사다리 레코드 1개")
	var L: Dictionary = siege.ladders[0]
	assert_eq(L["faction"], "A", "설치 세력 기록")
	assert_eq(L["countdown"], Siege.LADDER_TURNS, "카운트다운 = LADDER_TURNS")
	assert_true(siege.has_ladder_at(b, L["target_cell"]), "그 면에 사다리 있음")
	assert_true(siege.has_ladder_on(b), "거점에 사다리 있음(밀기 노출 조건)")
	# 같은 자리에서 재설치 → 그 면은 이미 차서 옆 면에 설치되거나(빈 면), 전부 차면 실패. 최소한 중복 적층은 없다.
	siege.place_ladder(p)
	for i in siege.ladders.size():
		for j in siege.ladders.size():
			if i != j:
				assert_ne(siege.ladders[i]["target_cell"], siege.ladders[j]["target_cell"], "면당 사다리 하나(중복 적층 없음)")

func test_ladder_target_skips_own_faction() -> void:
	var b := _walled("A", _center())   # 아군 성벽
	var ring: Vector2i = b.cells[1]
	var stand := Vector2i(-1, -1)
	for n in terrain.get_surrounding_cells(ring):
		if not b.contains_cell(n):
			stand = n
			break
	var p := _party("A", stand)   # 성벽 ring에 인접해 있어도
	assert_eq(siege.ladder_target_for(p), {}, "아군 성벽엔 사다리 대상 없음")
	p.faction_name = "C"   # 같은 자리라도 적 세력이면 대상이 생긴다 — 스킵이 인접이 아니라 세력 때문임을 확인
	assert_false(siege.ladder_target_for(p).is_empty(), "적 세력이면 같은 자리에서 대상 있음")

func test_place_consumes_grapple_and_marks_hooked() -> void:
	var b := _walled("B", _center())
	var ring: Vector2i = b.cells[1]
	var stand := Vector2i(-1, -1)
	for n in terrain.get_surrounding_cells(ring):
		if not b.contains_cell(n):
			stand = n
			break
	var p := _party("A", stand)
	p.loot_items = ["grapple_ladder"]
	assert_true(siege.place_ladder(p), "설치 성공")
	assert_eq(p.loot_items, [], "고리 사다리 1개 소모")
	assert_true(siege.ladders[0]["hooked"], "hooked(밀기 저항) 사다리")

# --- 통로 / 차단 / 돌파 ---

func test_corridor_opens_after_manned_countdown() -> void:
	var b := _walled("B", _center())
	_place(b)   # 설치 부대가 from_cell을 지키고 있음(manned)
	assert_true(siege.ladder_corridor(b, "A").is_empty(), "설치 직후엔 통로 없음(countdown 3)")
	assert_false(siege.breached_by(b, "A"), "준비 전엔 미돌파")
	for i in Siege.LADDER_TURNS:
		siege.advance_ladders()
	var corridor: Dictionary = siege.ladder_corridor(b, "A")
	assert_false(corridor.is_empty(), "카운트다운 소진 → 통로 개방")
	assert_true(corridor.has(b.center_cell()), "통로에 중심 포함")
	assert_true(siege.breached_by(b, "A"), "준비된 사다리 = 돌파")
	assert_false(siege.breached_by(b, "C"), "다른 세력에겐 통로 아님")

func test_countdown_frozen_when_unmanned() -> void:
	var b := _walled("B", _center())
	var p := _place(b)
	p.position = terrain.map_to_local(_center() + Vector2i(15, 15))   # 설치 위치 이탈
	siege.advance_ladders()
	assert_eq(siege.ladders[0]["countdown"], Siege.LADDER_TURNS, "지키는 부대 없으면 카운트다운 정지")

func test_wall_blocked_cells_by_faction_and_corridor() -> void:
	var b := _walled("B", _center())
	assert_eq(siege.wall_blocked_cells("B").size(), 0, "자기 세력 성벽은 자유 통행")
	assert_eq(siege.wall_blocked_cells("A").size(), b.cells.size(), "적 세력엔 footprint 전체 차단")
	_place(b)
	for i in Siege.LADDER_TURNS:
		siege.advance_ladders()
	var blocked: Dictionary = siege.wall_blocked_cells("A")
	assert_eq(blocked.size(), b.cells.size() - 2, "준비된 사다리 통로(대상 면+중심) 2칸 개방")
	assert_false(blocked.has(b.center_cell()), "중심은 열림")

func test_broken_gate_opens_for_all() -> void:
	var b := _walled("B", _center())
	b.gate_hp = 0
	assert_true(siege.breached_by(b, "C"), "부서진 성문은 모든 세력에 돌파")
	var blocked: Dictionary = siege.wall_blocked_cells("C")
	assert_false(blocked.has(b.gate_cell()), "성문 면 열림")
	assert_false(blocked.has(b.center_cell()), "중심 열림")

# --- 정리 / 붕괴 ---

func test_clear_ladders_only_target_building() -> void:
	var b1 := _walled("B", _center())
	var b2 := _walled("B", _center() + Vector2i(10, 0))
	_place(b1)
	_place(b2, "C")
	siege.clear_ladders(b1)
	assert_eq(siege.ladders.size(), 1, "대상 거점 사다리만 제거")
	assert_eq(siege.ladders[0]["building"], b2, "다른 거점 사다리는 유지")

func test_collapse_wall_clears_level_and_ladders() -> void:
	var b := _walled("B", _center())
	_place(b)
	b.wall_hp = 0
	assert_true(siege.collapse_wall(b), "내구도 0 → 붕괴")
	assert_eq(b.wall_level, 0, "성벽 제거")
	assert_false(siege.has_ladder_on(b), "붕괴 시 사다리 정리")
	b.wall_level = 1
	b.wall_hp = 50
	assert_false(siege.collapse_wall(b), "내구도 남으면 붕괴 아님")
	assert_eq(b.wall_level, 1, "상태 불변")

func test_push_ladders_touches_only_target_building() -> void:
	var b1 := _walled("B", _center())
	var b2 := _walled("B", _center() + Vector2i(10, 0))
	_place(b1)
	_place(b2, "C")
	siege.push_ladders(b1)   # 확률 판정과 무관하게 b2 사다리는 건드리지 않는다
	assert_true(siege.has_ladder_on(b2), "다른 거점 사다리는 밀기 대상 아님")

# --- 헤드리스 투석 / 충차 반격 ---

class AttackerStub:
	var siege_units: Array = []
	func prune_destroyed_siege() -> int:
		var removed := 0
		var kept: Array = []
		for u in siege_units:
			if u.hit_points > 0:
				kept.append(u)
			else:
				removed += 1
		siege_units = kept
		return removed

func test_bombard_wall_headless_damages_and_collapses() -> void:
	var b := _walled("B", _center())
	var atk := AttackerStub.new()
	atk.siege_units = [SiegeUnitStub.new(4, 50)]
	siege.bombard_wall_headless(atk, b)
	assert_lt(b.wall_hp, Siege.WALL_MAX_HP, "투석 1발로 내구도 감소(30~70)")
	atk.siege_units = [SiegeUnitStub.new(4, 999)]   # 확실히 붕괴시키는 큰 공격력
	siege.bombard_wall_headless(atk, b)
	assert_eq(b.wall_level, 0, "내구도 소진 → 붕괴까지 처리")

func test_ram_counter_hits_only_melee_units() -> void:
	var atk := AttackerStub.new()
	var ram := SiegeUnitStub.new(1, 90, 100)        # 충차(min_range 1) — 반격 대상, HP 커서 생존
	var catapult := SiegeUnitStub.new(4, 50, 40)    # 투석기 — 안전
	atk.siege_units = [ram, catapult]
	assert_eq(siege.ram_counter(atk), 0, "충차 생존 → 파괴 0")
	assert_lt(ram.hit_points, 100, "충차는 반격 피해")
	assert_eq(catapult.hit_points, 40, "투석기는 무피해")

func test_ram_counter_destroys_low_hp_ram() -> void:
	var atk := AttackerStub.new()
	atk.siege_units = [SiegeUnitStub.new(1, 90, 1)]   # HP 1 충차 — 반격 1회로 파괴
	assert_eq(siege.ram_counter(atk), 1, "파괴된 충차 수 반환")
	assert_eq(atk.siege_units, [], "파괴 충차 제거(prune)")

func test_ram_counter_no_melee_units_noop() -> void:
	var atk := AttackerStub.new()
	atk.siege_units = [SiegeUnitStub.new(4, 50, 40)]   # 투석기만
	assert_eq(siege.ram_counter(atk), 0, "충차 없으면 반격 없음")
	assert_eq(atk.siege_units[0].hit_points, 40, "무피해")
