class_name NpcPlanner
extends RefCounted
## NPC 부대 의사결정 계층 — 표적 선정·후퇴 판단·포지셔닝·그룹 이동 계획. game.gd에서 분리했다.
## 실행·연출(이동 애니메이션·전투 오버레이·카메라·안개)은 game.gd가 맡고, 여기는 "어디로/누구를"만 정한다.
## 월드 상태는 world(덕 타이핑 — game.gd 또는 테스트 스텁)의 좁은 조회 인터페이스로만 읽는다:
##   all_parties() · all_buildings() · party_on_cell(cell) · blocked_for(party)
## 순수 티어 선택·목적지 계산은 NpcAi(static)를 그대로 쓴다. → docs/spec/features/npc-movement.md

# NPC가 자기 캠프를 방어하는 반경(헥스). 이 안에 적 부대가 들어오면 그 침입자를 요격 우선한다.
const DEFEND_RADIUS := 5

# NPC가 후퇴를 판단할 때 주변 적 부대를 살피는 반경(헥스). 이 안에 자기보다 강한 적이 있으면 후퇴.
const RETREAT_SCAN := 6

# 표적 우선순위(무방비 캠프·약한 적)를 이 반경 안에서만 우대한다. 밖이면 기존 최근접 접근으로 폴백.
const PRIORITY_SCAN := 8

var terrain: TileMapLayer
var map_w: int
var map_h: int
var rng: RandomNumberGenerator
var world   # 월드 조회 인터페이스(game.gd / 테스트 스텁)

func _init(p_terrain: TileMapLayer, p_map_w: int, p_map_h: int, p_rng: RandomNumberGenerator, p_world) -> void:
	terrain = p_terrain
	map_w = p_map_w
	map_h = p_map_h
	rng = p_rng
	world = p_world

## 부대(Node2D)가 선 맵 셀.
func _cell_of(p) -> Vector2i:
	return terrain.local_to_map(p.position)

## 살아 있는 모든 부대를 {cell, faction} 목록으로. NpcAi.enemy_cells의 입력(세력 필터가 자기 부대를 걸러낸다).
func party_entries() -> Array:
	var out: Array = []
	for p in world.all_parties():
		if p.soldiers <= 0:
			continue
		out.append({"cell": _cell_of(p), "faction": p.faction_name})
	return out

## 맵의 모든 캠프를 {cell(중심), faction} 목록으로. territory/faction이 없는 고아 캠프는 빈 문자열(방어적 기본값 — 현재는 발생 안 함).
func camp_entries() -> Array:
	var out: Array = []
	for b in world.all_buildings():
		if not BuildingTypes.is_center(b.building_type):
			continue
		out.append({"cell": b.center_cell(), "faction": b.faction_name()})
	return out

## NPC 세력 fn이 향할 타깃 칸 목록. 적 부대·캠프로 진격하되, 자기 캠프가 위협받으면 침입자를 요격 우선.
## party_entries·camp_entries는 세력 무관하게 같으므로 호출부(_move_npcs)가 턴당 한 번만 만들어 넘긴다.
## (enemy_cells가 세력으로 걸러 자기 부대·아군·자기 캠프는 자동 제외된다.)
func targets_for(p, p_party_entries: Array, p_camp_entries: Array) -> Array:
	var fn: String = p.faction_name
	# 약하면 후퇴: 근처 적이 자기보다 강하면 (적이 없는) 자기 캠프로 물러선다. 안전한 캠프가 없으면 후퇴 안 함.
	if _should_retreat(p):
		var safe := _safe_retreat_cells(fn)
		if not safe.is_empty():
			return safe
	# 표적 우선순위: 근처(PRIORITY_SCAN) 무방비 적 캠프 > 근처 약한 적 부대 > 나머지(전체 적 셀, 최근접 폴백).
	var my_power: int = p.power()
	var near := {}
	for c in HexGrid.cells_within(terrain, _cell_of(p), PRIORITY_SCAN, map_w, map_h):
		near[c] = true
	var undefended: Array = []
	for b in world.all_buildings():
		if not BuildingTypes.is_center(b.building_type) or world.party_on_cell(b.center_cell()) != null:
			continue   # 중심 타일에 수비 부대가 있으면 방어됨 — 무방비 목록 제외
		if b.faction_name() != fn and near.has(b.center_cell()):
			undefended.append(b.center_cell())
	var weak: Array = []
	for other in world.all_parties():
		if other == p or other.soldiers <= 0 or other.faction_name == fn:
			continue
		var ocell := _cell_of(other)
		if near.has(ocell) and other.power() <= my_power:
			weak.append(ocell)
	var rest: Array = NpcAi.enemy_cells(fn, p_party_entries) + NpcAi.enemy_cells(fn, p_camp_entries)
	# 교전 포지셔닝: 원거리 선호 부대는 약한 적 부대의 [2~attack_range] 밴드로(거리 유지), 근접 선호는 붙는다. → npc-movement.md
	var weak_target: Array = weak
	if _party_prefers_ranged(p):
		var band := _combat_band_cells(p, weak)
		weak_target = band if not band.is_empty() else weak   # 밴드 셀 없으면(막힌 지형 등) 접근으로 폴백
	var advance := NpcAi.prioritize([undefended, weak_target, rest])
	var defend := _threats_near_own_camp(fn, p_party_entries)
	return NpcAi.select_targets(advance, defend)

## NPC 영웅그룹의 이동 계획(party → path)을 세운다. 영웅은 목표지향, 하위부대는 영웅 추종(지휘 범위 내 적은 교전). → npc-movement.md 편제
func plan_group_move(group: Array, p_party_entries: Array, p_camp_entries: Array) -> Dictionary:
	var plans: Dictionary = {}
	var bcosts: Dictionary = BuildPlanner.movement_costs(world.all_buildings())   # 건물 발자국 이동비용(도시=2, 불가=BLOCKED)
	var hero = group[0] if not group.is_empty() and is_instance_valid(group[0]) and group[0].is_hero() else null
	var hero_from := Vector2i(-1, -1)
	var hero_dest := Vector2i(-1, -1)
	# 영웅: 기존 목표지향 AI.
	if hero != null:
		hero_from = _cell_of(hero)
		var hocc: Dictionary = world.blocked_for(hero)
		hero_dest = NpcAi.choose_destination(terrain, hero_from, hero.movement(), map_w, map_h, rng, hocc, targets_for(hero, p_party_entries, p_camp_entries), bcosts)
		plans[hero] = HexGrid.reconstruct_path(terrain, hero_from, hero_dest, hero.movement(), map_w, map_h, hocc, bcosts)
	# 하위부대: 영웅 추종(지휘 범위 내 적 있으면 교전). 배정 칸·영웅 칸을 예약해 겹침 방지.
	var reserved: Dictionary = {}
	if hero_dest != Vector2i(-1, -1):
		reserved[hero_dest] = true
	for p in group:
		if not is_instance_valid(p) or p == hero:
			continue
		var start := _cell_of(p)
		var occ: Dictionary = world.blocked_for(p)
		for c in reserved:
			occ[c] = true
		var dest: Vector2i
		if hero != null and hero_dest != Vector2i(-1, -1):
			var near := NpcAi.enemies_within(terrain, hero_dest, hero.command_range(), NpcAi.enemy_cells(p.faction_name, p_party_entries), map_w, map_h)
			if not near.is_empty():
				dest = NpcAi.choose_destination(terrain, start, p.movement(), map_w, map_h, rng, occ, near, bcosts)   # 지휘 범위 내 적 → 근접 교전
			else:
				dest = HexGrid.follow_destination(terrain, hero_dest, hero_from, start, p.movement(), map_w, map_h, occ, bcosts)   # 영웅 추종(대형)
		else:
			dest = NpcAi.choose_destination(terrain, start, p.movement(), map_w, map_h, rng, occ, targets_for(p, p_party_entries, p_camp_entries), bcosts)   # 독립 부대·영웅 없음
		plans[p] = HexGrid.reconstruct_path(terrain, start, dest, p.movement(), map_w, map_h, occ, bcosts)
		reserved[dest] = true
	return plans

## attacker의 공격거리 이내에 있는 자기 외 부대를 찾는다(멤버 있는 것만). 없으면 null.
## (원거리 선호 부대는 이동 페이즈에서 [2~attack_range] 밴드로 자리잡아(_combat_band_cells) 사거리 교전한다 — npc-movement.md.)
func adjacent_enemy(attacker):
	# 근접(사거리 0)은 인접(1)까지, 원거리는 사거리까지 공격 대상으로 본다.
	var reach: int = maxi(attacker.attack_range(), 1)
	var in_range := {}
	for c in HexGrid.cells_within(terrain, _cell_of(attacker), reach, map_w, map_h):
		in_range[c] = true
	for other in world.all_parties():
		if other == attacker or not is_instance_valid(other) or other.soldiers <= 0:
			continue
		if other.faction_name == attacker.faction_name:
			continue   # 같은 세력(아군)은 공격 대상 아님(거점 방어 부대로 같은 세력 인접이 생겨 필요)
		if in_range.has(_cell_of(other)):
			return other
	return null

## attacker에 인접한(또는 그 위) 적 캠프를 찾는다(소유 세력이 다른 것). 수비대 유무는 호출부가 판단. 없으면 null.
func adjacent_enemy_camp(attacker):
	var acell := _cell_of(attacker)
	var fn: String = attacker.faction_name
	var neighbors := terrain.get_surrounding_cells(acell)
	for b in world.all_buildings():
		if not BuildingTypes.is_center(b.building_type):
			continue
		if b.faction_name() == fn:
			continue   # 아군 거점
		for c in b.cells:
			if c == acell or c in neighbors:
				return b
	return null

## 원거리 무기 우위 부대인지 — 사거리 2+ 이고 원거리 파워 > 근접 파워. 교전 시 거리 유지 여부 판정. → npc-movement.md
func _party_prefers_ranged(p) -> bool:
	return p.attack_range() >= 2 and NpcAi.prefers_ranged(p.melee_power(), p.ranged_power())

## 원거리 선호 부대 p가 약한 적 부대(party_cells 중 최근접)를 [2~attack_range] 밴드에서 사격할 위치 셀. 없으면 빈 배열. → npc-movement.md
func _combat_band_cells(p, party_cells: Array) -> Array:
	if party_cells.is_empty():
		return []
	var pw: Vector2 = p.position
	var nearest: Vector2i = party_cells[0]
	var best_d := INF
	for c in party_cells:
		var d := pw.distance_to(terrain.map_to_local(c))
		if d < best_d:
			best_d = d
			nearest = c
	return _band_cells([nearest], 2, p.attack_range())   # 근접(리치 1) 밖·사거리 안

## source_cells에서 헥스 거리 [min_r ~ max_r] 밴드 안 셀 목록(다중 시작 BFS, 지형 무시). 교전 포지셔닝용. → npc-movement.md
func _band_cells(source_cells: Array, min_r: int, max_r: int) -> Array:
	var dist := {}
	var frontier: Array[Vector2i] = []
	for c in source_cells:
		dist[c] = 0
		frontier.append(c)
	var out: Array = []
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var d: int = dist[cur]
		if d >= min_r and d <= max_r:   # 거리 [min~max] 밴드(시즈 사거리·교전 거리 공용)
			out.append(cur)
		if d >= max_r:
			continue
		for n in terrain.get_surrounding_cells(cur):
			if n.x < 0 or n.x >= map_w or n.y < 0 or n.y >= map_h or dist.has(n):
				continue
			dist[n] = d + 1
			frontier.append(n)
	return out

## NPC p가 후퇴해야 하는지 — RETREAT_SCAN 반경 안 적 부대 중 가장 강한 것과 비교해 교전이 불리하면 참.
func _should_retreat(p) -> bool:
	var scan := {}
	for c in HexGrid.cells_within(terrain, _cell_of(p), RETREAT_SCAN, map_w, map_h):
		scan[c] = true
	var my_power: int = p.power()
	var worst := 0
	for other in world.all_parties():
		if other == p or other.soldiers <= 0 or other.faction_name == p.faction_name:
			continue
		if scan.has(_cell_of(other)):
			worst = maxi(worst, other.power())
	return worst > 0 and not NpcAi.should_engage(my_power, worst)

## 세력 fn의 후퇴 목적지(캠프 중심). 적 부대가 가까이(2칸) 있는 캠프는 제외한다 — 위협받는 캠프로 도망치지 않게.
func _safe_retreat_cells(fn: String) -> Array:
	var out: Array = []
	for b in world.all_buildings():
		if not BuildingTypes.is_center(b.building_type):
			continue
		if b.faction_name() != fn:
			continue
		if _enemy_near(b.center_cell(), fn, 2):
			continue   # 적이 가까운 캠프로는 후퇴 안 함
		out.append(b.center_cell())
	return out

## cell 반경 radius 안에 세력 fn이 아닌(적) 부대가 있는지.
func _enemy_near(cell: Vector2i, fn: String, radius: int) -> bool:
	var near := {}
	for c in HexGrid.cells_within(terrain, cell, radius, map_w, map_h):
		near[c] = true
	for other in world.all_parties():
		if other.soldiers <= 0 or other.faction_name == fn:
			continue
		if near.has(_cell_of(other)):
			return true
	return false

## 세력 fn의 캠프 중심 DEFEND_RADIUS 이내로 침입한 적 부대 칸 목록(방어 타깃). 자기 캠프 없으면 빈 배열.
func _threats_near_own_camp(fn: String, p_party_entries: Array) -> Array:
	var near := {}
	for b in world.all_buildings():
		if BuildingTypes.is_center(b.building_type) and b.faction_name() == fn:
			for cell in HexGrid.cells_within(terrain, b.center_cell(), DEFEND_RADIUS, map_w, map_h):
				near[cell] = true
	if near.is_empty():
		return []
	var out: Array = []
	for e in p_party_entries:
		if e["faction"] != fn and near.has(e["cell"]):
			out.append(e["cell"])
	return out
