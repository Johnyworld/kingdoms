extends GutTest
## UnitSpawns — 초기 배치 카탈로그(res://data/unit_spawns.csv) 검증.
## 개별 유닛 절대좌표 + leader 소속 연결. 병종/세력 FK 무결성·편제 수·거점 중심 점거를 확인한다.

func _entries() -> Array:
	return UnitSpawns.entries()

func test_loads_64_rows() -> void:
	assert_eq(_entries().size(), 64, "세력 4 × (영웅4 + 부하12=16) = 64행")

func test_sixteen_per_faction() -> void:
	# 세력별 영웅 4 + 부하 12.
	for fid in FactionCatalog.FACTION_IDS:
		var rows := _entries().filter(func(e): return e["faction"] == fid)
		assert_eq(rows.size(), 16, "%s 편제 16" % fid)
		var heroes := rows.filter(func(e): return UnitTypes.kind(e["type"]) == "hero")
		assert_eq(heroes.size(), 4, "%s 영웅 4" % fid)
		var troops := rows.filter(func(e): return UnitTypes.kind(e["type"]) != "hero")
		assert_eq(troops.size(), 12, "%s 부하 12" % fid)

func test_ids_unique() -> void:
	var seen := {}
	for e in _entries():
		assert_false(seen.has(e["id"]), "id 유일: %s" % e["id"])
		seen[e["id"]] = true

func test_fk_integrity() -> void:
	# faction 은 factions.csv, type 은 unit_types.csv 에 있어야 한다.
	for e in _entries():
		assert_false(FactionCatalog.get_faction(e["faction"]).is_empty(), "faction FK: %s" % e["id"])
		assert_false(UnitTypes.spec(e["type"]).is_empty(), "type FK: %s" % e["id"])

func test_leader_points_to_hero_in_same_faction() -> void:
	# 영웅은 leader 빈 값, 부하는 같은 세력의 영웅 스폰 id 를 가리켜야 한다.
	var hero_faction := {}   # hero id → faction (영웅 판정은 kind 기준 — dark_hero 포함)
	for e in _entries():
		if UnitTypes.kind(e["type"]) == "hero":
			hero_faction[e["id"]] = e["faction"]
	for e in _entries():
		if UnitTypes.kind(e["type"]) == "hero":
			assert_eq(e["leader"], "", "영웅은 leader 없음: %s" % e["id"])
		else:
			assert_true(hero_faction.has(e["leader"]), "부하 leader 가 영웅 id: %s" % e["id"])
			assert_eq(hero_faction.get(e["leader"], ""), e["faction"], "leader 같은 세력: %s" % e["id"])

func test_coords_in_map_bounds() -> void:
	# 절대좌표는 50×50 맵 안이어야 한다(배치 폴백 이전에 유효 좌표).
	for e in _entries():
		var c: Vector2i = e["cell"]
		assert_true(c.x >= 0 and c.x < 50 and c.y >= 0 and c.y < 50, "맵 안 좌표: %s %s" % [e["id"], str(c)])

func test_no_intra_faction_coord_collision() -> void:
	# 같은 세력 스폰끼리 좌표가 겹치지 않아야 한다(겹치면 배치 폴백이 흩뜨려 편제가 깨진다).
	var by_faction := {}
	for e in _entries():
		var fid: String = e["faction"]
		if not by_faction.has(fid):
			by_faction[fid] = {}
		var seen: Dictionary = by_faction[fid]
		assert_false(seen.has(e["cell"]), "%s 좌표 중복: %s @ %s" % [fid, e["id"], str(e["cell"])])
		seen[e["cell"]] = true

func test_camp_defender_spawn_exists() -> void:
	# 세력마다 거점 방어자로 쓸 부하부대(t0)가 있다. 실제 거점 중심 점거는 런타임 배치가 건물 중심에 맞춘다. → camp-capture.md
	for fid in FactionCatalog.FACTION_IDS:
		var t0 := _entries().filter(func(e): return e["id"] == "%s_t0" % fid)
		assert_eq(t0.size(), 1, "%s 방어자 스폰(t0) 존재" % fid)
		assert_ne(UnitTypes.kind(t0[0]["type"]), "hero", "%s 방어자는 일반부대" % fid)

func test_dark_faction_uses_orc_units() -> void:
	# 암흑세력(balthazar)은 오크 병종, 인간 세력은 인간 병종을 쓴다(세력 외형 = 아키타입).
	var orc_types := ["dark_hero", "orc_infantry", "skel_archer"]
	var human_types := ["hero", "light_infantry", "light_archer"]
	for e in _entries():
		if e["faction"] == "balthazar":
			assert_true(e["type"] in orc_types, "balthazar 오크 병종: %s (%s)" % [e["id"], e["type"]])
		else:
			assert_true(e["type"] in human_types, "인간 세력 인간 병종: %s (%s)" % [e["id"], e["type"]])
