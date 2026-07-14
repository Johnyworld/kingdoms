extends GutTest
## 유닛·부대 카탈로그(UnitTypes) 테스트.
## 랑그릿사식 이분화 — 세력별 영웅 4명(영웅부대) + 병종 아키타입(경보병·경궁병, 일반부대 10인).

var types = load("res://scenes/party/unit_types.gd")

# --- id 상수 ---

func test_id_constants() -> void:
	assert_eq(types.PLAYER_ID, "azel", "플레이어 세력 id")
	assert_eq(types.NPC_IDS, ["qasim", "balthazar", "batur"], "NPC 세력 3종")
	assert_eq(types.FACTION_IDS, ["azel", "qasim", "balthazar", "batur"], "전 세력 4종")
	assert_eq(types.TROOP_SIZE, 10, "일반부대 병사 10명")
	assert_eq(types.HEROES_PER_FACTION, 4, "세력당 영웅 4명")

# --- 세력 카탈로그 키 ---

func test_all_factions_have_keys() -> void:
	for id in types.FACTION_IDS:
		var spec: Dictionary = types.get_faction(id)
		for key in ["faction", "color", "territory", "heroes"]:
			assert_true(spec.has(key), "%s 스펙에 %s 키 존재" % [id, key])

func test_player_faction_spec() -> void:
	var spec: Dictionary = types.get_faction("azel")
	assert_eq(spec["faction"], "푸른 왕국", "세력 = 푸른 왕국")
	assert_eq(spec["territory"], "창천성", "수도 = 창천성")

func test_npc_territory_names() -> void:
	assert_eq(types.get_faction("qasim")["territory"], "알사바흐", "사막 술탄국 수도")
	assert_eq(types.get_faction("balthazar")["territory"], "흑요요새", "암흑 제국 수도")
	assert_eq(types.get_faction("batur")["territory"], "텡그리 언덕", "초원 칸국 수도")

# --- 영웅 ---

func test_make_heroes_azel_four_no_elwin() -> void:
	var heroes: Array = types.make_heroes("azel")
	assert_eq(heroes.size(), 4, "azel 영웅 4명")
	var names: Array = []
	for h in heroes:
		names.append(h.human_name)
	assert_eq(names, ["아젤 하르윈", "로엔 카스터", "미라 벨포드", "가레스 던"], "엘윈 사수 제거, 4명")

func test_make_heroes_each_faction_four() -> void:
	for id in types.FACTION_IDS:
		var heroes: Array = types.make_heroes(id)
		assert_eq(heroes.size(), 4, "%s 영웅 4명" % id)
		assert_eq(heroes[0].human_name, types.get_faction(id)["heroes"][0]["name"], "%s 첫 영웅=지휘관" % id)

func test_hero_stats_mapping() -> void:
	var azel = types.make_hero("azel", 0)
	assert_eq(azel.strength, 78, "힘 78 (유닛.md 매핑)")
	assert_eq(azel.leadership, 88, "지휘력 88")
	assert_eq(azel.morale, 90, "사기 90")

func test_hero_faction_equipment() -> void:
	var azel = types.make_hero("azel", 0)
	assert_eq(azel.weapons, ["longsword", "bow"], "아젤 장검+보조 활(override)")
	assert_eq(azel.shield, "round_shield", "푸른 왕국 라운드 실드")
	var mage = types.make_hero("balthazar", 0)
	assert_eq(mage.weapons, ["wand"], "암흑 제국 완드")
	assert_false(mage.armor.is_empty(), "방어구 세트 적용")

func test_hero_thrower() -> void:
	var jamila = types.make_hero("qasim", 1)
	assert_eq(jamila.weapons, ["scimitar", "javelin"], "자밀라 곡도+투창")

func test_hero_party_name() -> void:
	assert_eq(types.hero_party_name("azel", 0), "아젤 하르윈 부대", "영웅부대명")

func test_all_units_movement_vision_full_hp() -> void:
	for id in types.FACTION_IDS:
		for h in types.make_heroes(id):
			assert_eq(h.movement, 4, "%s 이동력 4" % h.human_name)
			assert_eq(h.vision, 7, "%s 시야 7" % h.human_name)
			assert_eq(h.hit_points, h.max_hp(), "%s 시작 풀피" % h.human_name)
			assert_eq(h.max_stamina, h.stamina, "%s 풀 스태미나" % h.human_name)

func test_hero_bounds() -> void:
	assert_null(types.make_hero("azel", 9), "범위 밖 index → null")
	assert_eq(types.hero_party_name("azel", 9), "", "범위 밖 index → 빈 문자열")

# --- 병종(일반부대) ---

func test_make_troop_light_infantry() -> void:
	var t: Array = types.make_troop("light_infantry")
	assert_eq(t.size(), 10, "경보병 10명")
	for h in t:
		assert_true(h is Human, "병사는 Human")
		assert_eq(h.strength, 62, "경보병 힘 62 (동일)")
		assert_eq(h.weapons, ["spear"], "장창")
		assert_eq(h.shield, "round_shield", "라운드 실드")
		assert_eq(h.hit_points, h.max_hp(), "풀피")

func test_make_troop_light_archer() -> void:
	var t: Array = types.make_troop("light_archer")
	assert_eq(t.size(), 10, "경궁병 10명")
	for h in t:
		assert_eq(h.weapons, ["bow"], "활")
		assert_eq(h.shield, "", "방패 없음")
		assert_eq(h.vision, 7, "시야 7")

func test_troop_members_independent_arrays() -> void:
	# 각 병사 장비 배열은 독립(.duplicate) — 한 명을 바꿔도 다른 멤버 불변.
	var t: Array = types.make_troop("light_archer")
	t[0].weapons.append("sword")
	assert_eq(t[1].weapons, ["bow"], "다른 병사 무기 불변")

func test_troop_name() -> void:
	assert_eq(types.troop_name("light_infantry"), "경보병", "경보병 이름")
	assert_eq(types.troop_name("light_archer"), "경궁병", "경궁병 이름")

# --- 경계 ---

func test_unknown_faction_empty() -> void:
	assert_eq(types.get_faction("없음").size(), 0, "없는 세력 → 빈 Dictionary")
	assert_eq(types.make_heroes("없음").size(), 0, "없는 세력 → 빈 배열")

func test_unknown_troop_empty() -> void:
	assert_eq(types.make_troop("없음").size(), 0, "없는 병종 → 빈 배열")
	assert_eq(types.troop_name("없음"), "", "없는 병종 → 빈 문자열")
