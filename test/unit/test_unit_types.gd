extends GutTest
## 유닛·부대 카탈로그(UnitTypes) 테스트.
## 세력별 부대 정의(이름·색·지휘관·멤버)와 멤버 Human 생성(능력치 매핑)을 검증한다.

var types = load("res://scenes/party/unit_types.gd")

func _all_ids() -> Array:
	return [types.PLAYER_ID] + types.NPC_IDS

# --- id 상수 ---

func test_player_and_npc_ids() -> void:
	assert_eq(types.PLAYER_ID, "azel", "플레이어 부대 id")
	assert_eq(types.NPC_IDS, ["qasim", "balthazar", "batur"], "NPC 부대 3종")

# --- 카탈로그 키 ---

func test_all_parties_have_keys() -> void:
	for id in _all_ids():
		var spec: Dictionary = types.get_party(id)
		for key in ["party_name", "faction", "color", "commander", "members"]:
			assert_true(spec.has(key), "%s 스펙에 %s 키 존재" % [id, key])

func test_player_party_spec() -> void:
	var spec: Dictionary = types.get_party("azel")
	assert_eq(spec["faction"], "푸른 왕국", "세력 = 푸른 왕국")
	assert_eq(spec["party_name"], "아젤 하르윈 부대", "부대명")
	assert_eq(spec["commander"], "아젤 하르윈", "지휘관")

# --- 멤버 생성 ---

func test_make_members_count_and_first() -> void:
	var members: Array = types.make_members("azel")
	assert_eq(members.size(), 4, "아젤 부대 4명")
	assert_eq(members[0].human_name, "아젤 하르윈", "첫 멤버 = 지휘관")

func test_make_members_stats_mapping() -> void:
	var leader = types.make_members("azel")[0]
	assert_eq(leader.strength, 78, "힘 78 (유닛.md 매핑)")
	assert_eq(leader.leadership, 88, "지휘력 88")
	assert_eq(leader.morale, 90, "사기 90")

func test_all_members_movement_vision_human_base() -> void:
	for id in _all_ids():
		for h in types.make_members(id):
			assert_eq(h.movement, 4, "%s 이동력 4 (인간 기본)" % h.human_name)
			assert_eq(h.vision, 7, "%s 시야 7 (인간 기본)" % h.human_name)

func test_members_get_faction_equipment() -> void:
	var mage = types.make_members("balthazar")[0]
	assert_eq(mage.weapon, "wand", "암흑 제국 멤버는 완드 장착")
	assert_false(mage.armor.is_empty(), "방어구 세트가 적용됨")

func test_members_get_faction_shield() -> void:
	assert_eq(types.make_members("azel")[0].shield, "round_shield", "푸른 왕국 멤버는 라운드 실드")

func test_commander_name() -> void:
	assert_eq(types.commander_name("qasim"), "카심 이븐 라시드", "지휘관 이름")

func test_all_parties_have_four_members() -> void:
	for id in _all_ids():
		assert_eq(types.make_members(id).size(), 4, "%s 멤버 4명" % id)

# --- 경계 ---

func test_unknown_id_empty() -> void:
	assert_eq(types.get_party("없음").size(), 0, "없는 id → 빈 Dictionary")
	assert_eq(types.make_members("없음").size(), 0, "없는 id → 빈 배열")
