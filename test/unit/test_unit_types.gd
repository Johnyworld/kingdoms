extends GutTest
## 유닛·부대 카탈로그(UnitTypes) 테스트 — 순수 class+count 모델.
## 세력별 영웅 4명(이름) + 병종 아키타입(경보병·경궁병). 개별 Human·스탯은 없다.

var types = load("res://scenes/party/unit_types.gd")

# --- id 상수 ---

func test_id_constants() -> void:
	assert_eq(types.PLAYER_ID, "azel", "플레이어 세력 id")
	assert_eq(types.NPC_IDS, ["qasim", "balthazar", "batur"], "NPC 세력 3종")
	assert_eq(types.FACTION_IDS, ["azel", "qasim", "balthazar", "batur"], "전 세력 4종")
	assert_eq(types.TROOP_SIZE, 10, "일반부대 병사 10명")
	assert_eq(types.HEROES_PER_FACTION, 4, "세력당 영웅 4명")

# --- 세력 카탈로그 ---

func test_all_factions_have_keys() -> void:
	for id in types.FACTION_IDS:
		var spec: Dictionary = types.get_faction(id)
		for key in ["faction", "color", "territory", "start_corner", "heroes"]:
			assert_true(spec.has(key), "%s 스펙에 %s 키 존재" % [id, key])
		assert_eq((spec["heroes"] as Array).size(), 4, "%s 영웅 4명" % id)

func test_faction_start_corner() -> void:
	assert_eq(types.get_faction("azel")["start_corner"], "SW", "플레이어 = 남서")
	assert_eq(types.get_faction("qasim")["start_corner"], "SE", "사막 술탄국 = 남동")
	assert_eq(types.get_faction("balthazar")["start_corner"], "NE", "암흑 제국 = 북동")
	assert_eq(types.get_faction("batur")["start_corner"], "NW", "초원 칸국 = 북서")

func test_faction_color_loaded_from_hex() -> void:
	# CSV hex(#334DCC) → Color 복원. 정확값이 아니라 로드 성공(기본색이 아님)만 확인.
	assert_eq(types.get_faction("azel")["color"], Color.html("#334DCC"), "azel 색 = hex 복원값")

func test_hero_faction_referential_integrity() -> void:
	# heroes.csv 의 모든 영웅이 유효 세력에 FK-join 되어 세력당 4명 채워졌는지.
	for id in types.FACTION_IDS:
		assert_eq((types.get_faction(id)["heroes"] as Array).size(), types.HEROES_PER_FACTION,
			"%s FK join → 영웅 %d명" % [id, types.HEROES_PER_FACTION])

func test_player_faction_spec() -> void:
	var spec: Dictionary = types.get_faction("azel")
	assert_eq(spec["faction"], "푸른 왕국", "세력 = 푸른 왕국")
	assert_eq(spec["territory"], "창천성", "수도 = 창천성")

func test_npc_territory_names() -> void:
	assert_eq(types.get_faction("qasim")["territory"], "알사바흐", "사막 술탄국 수도")
	assert_eq(types.get_faction("balthazar")["territory"], "흑요요새", "암흑 제국 수도")
	assert_eq(types.get_faction("batur")["territory"], "텡그리 언덕", "초원 칸국 수도")

# --- 영웅 이름 ---

func test_hero_name_azel_first() -> void:
	assert_eq(types.hero_name("azel", 0), "아젤 하르윈", "azel 첫 영웅(지휘관)")

func test_hero_names_azel_four_no_elwin() -> void:
	var names: Array = types.get_faction("azel")["heroes"]
	assert_eq(names, ["아젤 하르윈", "로엔 카스터", "미라 벨포드", "가레스 던"], "엘윈 사수 제거, 4명")

func test_hero_party_name() -> void:
	assert_eq(types.hero_party_name("azel", 0), "아젤 하르윈 부대", "영웅부대명")

func test_hero_bounds() -> void:
	assert_eq(types.hero_name("azel", 9), "", "범위 밖 index → 빈 문자열")
	assert_eq(types.hero_party_name("azel", 9), "", "범위 밖 index → 빈 문자열")

# --- 병종 이름 ---

func test_troop_name() -> void:
	assert_eq(types.troop_name("light_infantry"), "경보병", "경보병 이름")
	assert_eq(types.troop_name("light_archer"), "경궁병", "경궁병 이름")

# --- 경계 ---

func test_unknown_faction_empty() -> void:
	assert_eq(types.get_faction("없음").size(), 0, "없는 세력 → 빈 Dictionary")
	assert_eq(types.hero_name("없음", 0), "", "없는 세력 → 빈 문자열")

func test_unknown_troop_empty() -> void:
	assert_eq(types.troop_name("없음"), "", "없는 병종 → 빈 문자열")
