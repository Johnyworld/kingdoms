class_name SiegeSystem
extends RefCounted
## 성벽 공성 도메인 계층 — 사다리 레코드(설치·밀기·카운트다운·통로)와 성벽 차단/붕괴·헤드리스 투석·충차 반격.
## game.gd에서 분리했다. 연출(사다리 오버레이 갱신·토스트·전투 오버레이)은 game.gd가 맡는다.
## 월드 상태는 world(덕 타이핑 — game.gd 또는 테스트 스텁)의 좁은 조회 인터페이스로만 읽는다:
##   all_buildings() · party_on_cell(cell)
## 규칙 상수·확률 판정은 Siege(static)를 그대로 쓴다. → docs/spec/features/wall.md · siege-engines.md

var terrain: TileMapLayer
var rng: RandomNumberGenerator
var world   # 월드 조회 인터페이스(game.gd / 테스트 스텁)

## 사다리 레코드 목록 {building, target_cell, from_cell, faction, countdown, hooked}.
## 시각화(siege_overlay)가 그대로 읽는다 — 변경 후 game.gd가 오버레이에 재주입한다. → wall.md
var ladders: Array = []

func _init(p_terrain: TileMapLayer, p_rng: RandomNumberGenerator, p_world) -> void:
	terrain = p_terrain
	rng = p_rng
	world = p_world

## 부대(Node2D)가 선 맵 셀.
func _cell_of(p) -> Vector2i:
	return terrain.local_to_map(p.position)

# --- 조회 ---

## faction_name 세력이 아닌 성벽 있는 거점들의 footprint 칸 집합({cell: true}). 그 세력에겐 완전 장애물·표적 제외.
## 단 그 세력의 준비된(countdown 0) 사다리가 연 통로(대상 ring 셀 + 중심)는 제외한다(방향 제한 돌파). → wall.md
func wall_blocked_cells(faction_name: String) -> Dictionary:
	var blocked := {}
	for b in world.all_buildings():
		if not (BuildingTypes.is_center(b.building_type) and b.is_walled()):
			continue
		if b.faction_name() == faction_name:
			continue   # 같은 세력 성벽은 통행·표적 자유
		var open_cells := ladder_corridor(b, faction_name)   # 준비된 사다리가 연 통로 셀
		if b.gate_broken():   # 부서진 성문은 모든 적 세력에 그 면 통로 개방 → wall.md 성문
			open_cells[b.gate_cell()] = true
			open_cells[b.center_cell()] = true
		for c in b.cells:
			if open_cells.has(c):
				continue
			blocked[c] = true
	return blocked

## faction_name의 준비된 사다리가 거점 b에 대해 여는 통로 셀 집합(대상 ring 셀 + 중심). 없으면 빈 Dictionary. → wall.md
func ladder_corridor(b, faction_name: String) -> Dictionary:
	var open_cells := {}
	for L in ladders:
		if L["building"] == b and L["faction"] == faction_name and L["countdown"] <= 0:
			open_cells[L["target_cell"]] = true
			open_cells[b.center_cell()] = true
	return open_cells

## faction_name이 거점 b를 돌파했는지 — 부서진 성문(모든 세력) 또는 그 세력의 준비된 사다리. 점령·공격 대상 판정. → wall.md
func breached_by(b, faction_name: String) -> bool:
	return b.gate_broken() or not ladder_corridor(b, faction_name).is_empty()

## 거점 b의 셀 c에 이미 사다리가 걸려 있는지(면당 하나 — 같은 면 중복 적층 방지). → wall.md
func has_ladder_at(b, c: Vector2i) -> bool:
	for L in ladders:
		if L["building"] == b and L["target_cell"] == c:
			return true
	return false

## 거점 b를 겨눈 사다리가 하나라도 있는지([사다리 밀기] 노출 조건). → wall.md
func has_ladder_on(b) -> bool:
	for L in ladders:
		if L["building"] == b:
			return true
	return false

## 부대가 인접한 성벽 적 거점의 사다리 설치 대상 {building, target_cell}. 없으면 빈 Dictionary. → wall.md
## 부대는 성벽 밖에 있으므로, 인접한 footprint 셀(ring)이 사다리가 걸릴 대상 면이다.
func ladder_target_for(p) -> Dictionary:
	if p == null:
		return {}
	var pcell := _cell_of(p)
	var neighbors := terrain.get_surrounding_cells(pcell)
	for b in world.all_buildings():
		if not (BuildingTypes.is_center(b.building_type) and b.is_walled()):
			continue
		if b.faction_name() == p.faction_name:
			continue   # 아군 성벽엔 사다리 안 놓는다
		for c in b.cells:
			if c in neighbors and not has_ladder_at(b, c):
				return {"building": b, "target_cell": c}   # 붙은 ring 셀 중 사다리 없는 면
	return {}

## 사다리 L이 유지 중인지 — from_cell(설치 위치)에 그 사다리 세력의 부대가 서 있으면 참. 부대·세력 무관 위치 기준이라 재사용 가능. → wall.md
func ladder_manned(L: Dictionary) -> bool:
	var holder = world.party_on_cell(L["from_cell"])
	return holder != null and holder.faction_name == L["faction"]

# --- 변경 ---

## 사다리 설치 — 대상 거점·ring 셀에 그 부대 세력 사다리를 세운다(countdown=LADDER_TURNS). 설치했으면 true.
## 고리 사다리(grapple_ladder) 소지 시 1개 소모하고 hooked(밀기 저항) 사다리가 된다. → wall.md · items.md
## 행동 종료(mark_attacked)·오버레이 갱신은 호출부(game.gd)가 한다.
func place_ladder(p) -> bool:
	var t := ladder_target_for(p)
	if t.is_empty() or has_ladder_at(t["building"], t["target_cell"]):
		return false   # 대상 없음·그 면에 이미 사다리(면당 하나)
	var hooked: bool = "grapple_ladder" in p.loot_items
	if hooked:
		p.loot_items.erase("grapple_ladder")   # 설치 시 1개 소모
	ladders.append({
		"building": t["building"], "target_cell": t["target_cell"],
		"from_cell": _cell_of(p), "faction": p.faction_name,
		"countdown": Siege.LADDER_TURNS, "hooked": hooked,
	})
	return true

## 사다리 밀기 — 거점 b를 겨눈 각 사다리를 독립 판정, 성공분 제거. hooked(고리 사다리) 사다리는 밀기 확률 감소. → wall.md
func push_ladders(b) -> void:
	var kept: Array = []
	for L in ladders:
		var markup: float = Siege.HOOKED_PUSH_REDUCTION if L.get("hooked", false) else 0.0
		if L["building"] == b and Siege.push_succeeds(rng.randf(), markup):
			continue   # 파괴됨
		kept.append(L)
	ladders = kept

## 거점 b를 겨눈 사다리를 모두 제거한다(점령·파괴·성벽 붕괴 시). → wall.md
func clear_ladders(b) -> void:
	var kept: Array = []
	for L in ladders:
		if L["building"] != b:
			kept.append(L)
	ladders = kept

## 턴 종료마다 사다리 준비 카운트 진행 — 그 자리를 지키는(manned) 사다리만 −1. 0이면 통로가 열린다(wall_blocked_cells). → wall.md
func advance_ladders() -> void:
	for L in ladders:
		L["countdown"] = Siege.advance_ladder_countdown(L["countdown"], ladder_manned(L))

## 성벽 붕괴 처리(내구도 0 이하) — wall_level·wall_hp 0, 사다리 정리. 붕괴됐으면 true. 오버레이·헤드리스(5g) 공용. → wall.md
func collapse_wall(building) -> bool:
	if not Siege.wall_broken(building.wall_hp):
		return false
	building.wall_level = 0
	building.wall_hp = 0
	clear_ladders(building)   # 붕괴된 성벽 사다리 정리
	return true

## NPC↔NPC 헤드리스 성벽 투석(5g) — attacker 공성 유닛마다 1발 flat 피해 합산해 wall_hp 차감·붕괴. 오버레이 없음(플레이어 불참). → siege-engines.md
func bombard_wall_headless(attacker, building) -> void:
	var attacks: Array = []
	var rolls: Array = []
	for s in attacker.siege_units:
		attacks.append(s.attack())
		rolls.append(rng.randf())
	building.wall_hp = Siege.wall_after_hit(building.wall_hp, Siege.total_bombard_damage(attacks, rolls))
	collapse_wall(building)   # 헤드리스라 토스트 없음(안개 밖이면 링만 갱신)
	building.queue_redraw()

## 충차 반격 — attacker의 근접(밴드 1) 공성 유닛(충차)에 수비 반격 피해를 주고, 파괴된 수를 반환한다(없으면 0).
## 투석기(밴드 4~5)는 안전. 방어 거점 여부 판정·토스트는 호출부(game.gd)가 한다. → siege-engines.md
func ram_counter(attacker) -> int:
	var countered := false
	for u in attacker.siege_units:
		if u.min_range() <= 1:   # 근접(밴드 1) 공성 유닛 = 충차만 반격 대상
			u.hit_points -= Siege.ram_counter_damage(rng.randf())
			countered = true
	if not countered:
		return 0
	return attacker.prune_destroyed_siege()
