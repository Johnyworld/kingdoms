extends GutTest
## NpcAi.choose_destination — 도달 가능한 가장 먼 칸 중 무작위 선택.
## 결정적 검증을 위해 시드 고정 RandomNumberGenerator를 넘긴다.
## 헥스 인접·지형은 엔진 의존이라 실제 헥스 타일셋 TileMapLayer로 검증한다.
## (무도색 셀 source_id = -1 은 초원 취급 → 이동 상한 = 이동력 그대로.)

const MAP := 41  # 중앙 기준 반경 몇 칸은 경계에 안 닿을 만큼 넉넉한 정사각 맵.

var terrain: TileMapLayer

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

func _rng(seed_val := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r

# --- 목적지 유효성 ---

func test_destination_in_move_set() -> void:
	var start := _center()
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng())
	var move_cells: Array = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["move"]
	assert_true(dest in move_cells, "목적지는 이동 가능 집합에 속한다")

func test_wander_varies_distance() -> void:
	# 배회는 거리 무관 무작위 — 여러 시드 중 최대 거리(3)보다 짧은 칸을 고르는 경우가 있어야 한다.
	var start := _center()
	var dist: Dictionary = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["dist"]
	var saw_shorter := false
	for s in range(1, 30):
		var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(s))
		if dist[dest] < 3:
			saw_shorter = true
			break
	assert_true(saw_shorter, "배회는 최대 거리보다 짧은 칸도 고른다(항상 최대 이동력 아님)")

func test_zero_movement_stays() -> void:
	var start := _center()
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 0, MAP, MAP, _rng())
	assert_eq(dest, start, "이동력 0이면 제자리")

# --- 결정성 ---

func test_deterministic_same_seed() -> void:
	var start := _center()
	var a: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(42))
	var b: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(42))
	assert_eq(a, b, "같은 시드 → 같은 목적지")

# --- 지형(산 배제) ---

func test_avoids_mountains() -> void:
	# 이웃 6칸 중 5칸을 산으로 막으면, 이동력 1 목적지는 남은 초원 이웃 1칸뿐이어야 한다.
	var start := _center()
	var neighbors := terrain.get_surrounding_cells(start)
	var open_cell: Vector2i = neighbors[0]
	for i in range(1, neighbors.size()):
		terrain.set_cell(neighbors[i], Terrain.MOUNTAIN, Terrain.ATLAS)
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 1, MAP, MAP, _rng())
	assert_eq(dest, open_cell, "산으로 막히면 유일한 초원 이웃으로 이동(산 칸은 목적지 아님)")
	assert_false(terrain.get_cell_source_id(dest) == Terrain.MOUNTAIN, "목적지는 산이 아니다")

# --- 유닛 점유(blocked_cells) 회피 ---

func test_does_not_choose_occupied_cell() -> void:
	# 이웃 6칸 중 5칸을 점유로 막으면 이동력 1 목적지는 남은 한 칸뿐.
	var start := _center()
	var neighbors := terrain.get_surrounding_cells(start)
	var open_cell: Vector2i = neighbors[0]
	var occ := {}
	for i in range(1, neighbors.size()):
		occ[neighbors[i]] = true
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 1, MAP, MAP, _rng(), occ)
	assert_eq(dest, open_cell, "점유되지 않은 유일한 이웃으로 이동")
	assert_false(occ.has(dest), "점유 칸은 목적지가 아니다")

func test_all_neighbors_occupied_stays() -> void:
	var start := _center()
	var occ := {}
	for n in terrain.get_surrounding_cells(start):
		occ[n] = true
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 1, MAP, MAP, _rng(), occ)
	assert_eq(dest, start, "이동력 1 + 이웃 전부 점유 → 제자리")

# --- 목표지향(targets) ---

func _world_dist(a: Vector2i, b: Vector2i) -> float:
	return terrain.map_to_local(a).distance_to(terrain.map_to_local(b))

func test_moves_closer_to_target() -> void:
	var start := _center()
	var target := start + Vector2i(6, 0)   # 동쪽 멀리
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [target])
	assert_true(_world_dist(dest, target) < _world_dist(start, target), "타깃에 더 가까워지는 칸으로 이동")

func test_destination_minimizes_distance_to_target() -> void:
	var start := _center()
	var target := start + Vector2i(6, 0)
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [target])
	# 이동 칸 전체에서 타깃과의 최소 거리를 직접 구해 비교.
	var move_cells: Array = HexGrid.movement_ranges(terrain, start, 3, MAP, MAP)["move"]
	var best := INF
	for c in move_cells:
		best = minf(best, _world_dist(c, target))
	assert_almost_eq(_world_dist(dest, target), best, 0.01, "목적지는 타깃과의 거리가 최소인 칸")

func test_nearest_of_multiple_targets() -> void:
	var start := _center()
	var far := start + Vector2i(6, 0)
	var near := start + Vector2i(-2, 0)   # 서쪽 가까이
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [far, near])
	# 가장 가까운 타깃(near) 쪽으로 접근 → near에 더 가까워진다.
	assert_true(_world_dist(dest, near) < _world_dist(start, near), "가장 가까운 타깃에 접근")

func test_stays_when_cannot_get_closer() -> void:
	var start := _center()
	# 타깃이 시작 칸이면 어떤 이동칸도 더 가까워질 수 없다 → 제자리.
	var dest: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(), {}, [start])
	assert_eq(dest, start, "더 가까워지는 칸 없으면 제자리")

func test_target_seeking_deterministic() -> void:
	var start := _center()
	var target := start + Vector2i(6, 0)
	var a: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(9), {}, [target])
	var b: Vector2i = NpcAi.choose_destination(terrain, start, 3, MAP, MAP, _rng(9), {}, [target])
	assert_eq(a, b, "같은 시드 → 같은 목적지")

# --- 타깃 선정: 세력 필터·방어 우선 (순수, 노드 비의존) ---

func test_enemy_cells_filters_by_faction() -> void:
	var entries := [
		{"cell": Vector2i(1, 0), "faction": "푸른 왕국"},
		{"cell": Vector2i(2, 0), "faction": "사막 술탄국"},
		{"cell": Vector2i(3, 0), "faction": "암흑 제국"},
	]
	var out: Array = NpcAi.enemy_cells("사막 술탄국", entries)
	assert_eq(out, [Vector2i(1, 0), Vector2i(3, 0)], "같은 세력 제외, 적의 cell만")

func test_enemy_cells_all_allies_empty() -> void:
	var entries := [
		{"cell": Vector2i(1, 0), "faction": "사막 술탄국"},
		{"cell": Vector2i(2, 0), "faction": "사막 술탄국"},
	]
	assert_eq(NpcAi.enemy_cells("사막 술탄국", entries), [], "전부 같은 세력이면 빈 배열")

func test_select_targets_prefers_defend() -> void:
	var advance := [Vector2i(5, 5), Vector2i(6, 6)]
	var defend := [Vector2i(1, 1)]
	assert_eq(NpcAi.select_targets(advance, defend), defend, "방어 대상 있으면 방어 우선")

func test_select_targets_falls_back_to_advance() -> void:
	var advance := [Vector2i(5, 5)]
	assert_eq(NpcAi.select_targets(advance, []), advance, "방어 대상 없으면 진격 타깃")

# --- 영웅그룹 묶기: hero_groups (순수) — NPC 이동을 영웅+하위 그룹 단위로 순차 진행 ---

func _hero_party() -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.kind = p.KIND_HERO
	return p

func _troop_party(lord = null) -> Node2D:
	var p: Node2D = load("res://scenes/party/party.gd").new()
	add_child_autofree(p)
	p.kind = p.KIND_TROOP
	p.lord = lord
	return p

func test_hero_groups_hero_with_subs() -> void:
	var h1 := _hero_party()
	var h2 := _hero_party()
	var t1 := _troop_party(h1)
	var t2 := _troop_party(h1)
	var t3 := _troop_party(h2)
	var groups := NpcAi.hero_groups([h1, t1, t2, h2, t3])
	assert_eq(groups.size(), 2, "영웅 2명 → 그룹 2개")
	assert_eq(groups[0][0], h1, "그룹0 첫 원소 = H1")
	assert_eq(groups[0].size(), 3, "H1 그룹 = 영웅 + 하위 2")
	assert_eq(groups[1][0], h2, "그룹1 첫 원소 = H2")
	assert_eq(groups[1].size(), 2, "H2 그룹 = 영웅 + 하위 1")

func test_hero_groups_hero_no_subs() -> void:
	var h := _hero_party()
	var groups := NpcAi.hero_groups([h])
	assert_eq(groups.size(), 1, "하위 없는 영웅 → 단독 그룹")
	assert_eq(groups[0], [h], "그룹 = [영웅]")

func test_hero_groups_troops_only_singletons() -> void:
	var t1 := _troop_party()
	var t2 := _troop_party()
	var groups := NpcAi.hero_groups([t1, t2])
	assert_eq(groups.size(), 2, "영웅 없으면 각 부대가 단독 그룹")

func test_hero_groups_empty() -> void:
	assert_eq(NpcAi.hero_groups([]), [], "빈 입력 → 빈 결과")

# --- 지휘 범위 내 적: enemies_within (순수, 실제 헥스 맵) ---

func test_enemies_within_filters_by_radius() -> void:
	var c := _center()
	var e1: Vector2i = c + Vector2i(1, 0)   # 거리 1
	var e2: Vector2i = c + Vector2i(2, 0)   # 거리 2
	var e3: Vector2i = c + Vector2i(3, 0)   # 거리 3
	var got := NpcAi.enemies_within(terrain, c, 2, [e1, e2, e3], MAP, MAP)
	assert_true(e1 in got and e2 in got, "거리 ≤2 적 포함")
	assert_false(e3 in got, "거리 3 적 제외(반경 2)")

func test_enemies_within_none_in_range() -> void:
	var c := _center()
	assert_eq(NpcAi.enemies_within(terrain, c, 2, [c + Vector2i(5, 0)], MAP, MAP), [], "범위 밖만 있으면 빈 배열")
	assert_eq(NpcAi.enemies_within(terrain, c, 2, [], MAP, MAP), [], "적 목록 비면 빈 배열")

func test_enemies_within_radius_zero() -> void:
	var c := _center()
	var got := NpcAi.enemies_within(terrain, c, 0, [c, c + Vector2i(1, 0)], MAP, MAP)
	assert_eq(got, [c], "반경 0이면 center 칸 적만")

# --- 전력 인식: party_power / should_engage (순수) ---

func _soldier(hp: int) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new("병사")
	h.hit_points = hp
	return h

func test_party_power_sums_hp() -> void:
	assert_eq(NpcAi.party_power([_soldier(40), _soldier(30)]), 70, "멤버 hit_points 합")

func test_party_power_empty_zero() -> void:
	assert_eq(NpcAi.party_power([]), 0, "빈 부대 전력 0")

func test_should_engage_equal() -> void:
	assert_true(NpcAi.should_engage(100, 100), "대등하면 교전")

func test_should_engage_boundary() -> void:
	assert_true(NpcAi.should_engage(70, 100), "70%면 교전(경계)")

func test_should_engage_outmatched() -> void:
	assert_false(NpcAi.should_engage(60, 100), "60%면 불리 → 회피")

func test_should_engage_enemy_zero() -> void:
	assert_true(NpcAi.should_engage(10, 0), "적 전력 0이면 교전")

# --- 근·원거리 선호 (순수) → docs/spec/features/npc-movement.md ---

func test_prefers_ranged_when_ranged_stronger() -> void:
	assert_true(NpcAi.prefers_ranged(10, 20), "원거리 파워 우위 → 원거리 선호")

func test_prefers_ranged_when_melee_stronger() -> void:
	assert_false(NpcAi.prefers_ranged(20, 10), "근접 파워 우위 → 근접 선호")

func test_prefers_ranged_tie_and_zero() -> void:
	assert_false(NpcAi.prefers_ranged(15, 15), "동률은 근접(strictly greater만 원거리)")
	assert_false(NpcAi.prefers_ranged(0, 0), "무장 없으면 근접")

# --- 표적 우선순위: prioritize (순수) ---

func test_prioritize_first_nonempty() -> void:
	assert_eq(NpcAi.prioritize([[], [Vector2i(1,0)], [Vector2i(2,0)]]), [Vector2i(1,0)], "첫 비지 않은 티어")

func test_prioritize_top_tier() -> void:
	assert_eq(NpcAi.prioritize([[Vector2i(1,0)], [Vector2i(2,0)]]), [Vector2i(1,0)], "상위 티어 우선")

func test_prioritize_all_empty() -> void:
	assert_eq(NpcAi.prioritize([[], []]), [], "전부 비면 빈 배열")

# --- NPC 투석기 주기 생산 판정: should_produce_siege (순수) → docs/spec/features/siege-engines.md ---

func test_npc_siege_production_constants() -> void:
	assert_eq(NpcAi.NPC_SIEGE_INTERVAL, 5, "생산 주기 5턴")
	assert_eq(NpcAi.NPC_SIEGE_CAP, 2, "투석기 상한 2")

func test_should_produce_siege_on_interval_below_cap() -> void:
	assert_true(NpcAi.should_produce_siege(5, 0), "5턴·0대 → 생산")
	assert_true(NpcAi.should_produce_siege(10, 1), "10턴·1대 → 생산")

func test_should_produce_siege_off_interval() -> void:
	assert_false(NpcAi.should_produce_siege(4, 0), "주기 아님 → 생산 안 함")
	assert_false(NpcAi.should_produce_siege(7, 0), "주기 아님 → 생산 안 함")

func test_should_produce_siege_at_cap() -> void:
	assert_false(NpcAi.should_produce_siege(5, 2), "상한(2) 도달 → 생산 안 함")
	assert_false(NpcAi.should_produce_siege(10, 3), "상한 초과 → 생산 안 함")

func test_should_produce_siege_turn_zero() -> void:
	assert_false(NpcAi.should_produce_siege(0, 0), "0턴 → 생산 안 함")
