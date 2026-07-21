extends GutTest
## 건물 종류 카탈로그(BuildingTypes) 테스트. 자원 4종 축소 반영.

var types = load("res://scenes/building/building_types.gd")

# --- 기본 · 외형 ---

func test_camp_spec_has_keys() -> void:
	var spec: Dictionary = types.get_type("camp")
	for key in ["label", "vision", "resources", "fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "camp 스펙에 %s 키 존재" % key)

func test_camp_spec_values() -> void:
	var spec: Dictionary = types.get_type("camp")
	assert_eq(spec["label"], "캠프", "라벨은 캠프")
	assert_eq(spec["vision"], 5, "시야 5")
	assert_eq(spec["footprint"], 7, "캠프 footprint 7헥스")
	# 캠프 resources = 생성 영지 초기 자원(목재·식량·철·금 + 인구 = 5종).
	var expected := {"목재": 40, "식량": 50, "철": 10, "금": 0, "인구": 10}
	assert_eq(spec["resources"].size(), expected.size(), "자원 5종")
	for key in expected:
		assert_eq(spec["resources"].get(key), expected[key], "%s 초기값" % key)
	# 제거된 자원 키는 없다.
	for key in ["밀", "석재", "철괴", "나무", "빵", "고기"]:
		assert_false(spec["resources"].has(key), "제거된 자원 %s 없음" % key)

func test_farm_spec_values() -> void:
	var spec: Dictionary = types.get_type("farm")
	assert_eq(spec["label"], "농장", "라벨은 농장")
	assert_eq(spec["vision"], 4, "시야 4")
	assert_eq(spec["footprint"], 1, "농장 footprint 1헥스")
	for key in ["fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "farm 외형 색상 %s 키 존재" % key)

# --- 소형 건물 (footprint 1) ---

func test_house_spec() -> void:
	var spec: Dictionary = types.get_type("house")
	assert_eq(spec["label"], "집", "라벨은 집")
	assert_eq(spec["vision"], 2, "시야 2")
	assert_eq(spec["footprint"], 1, "집 footprint 1헥스")
	assert_eq(spec["build_turns"], 4, "집 필요 턴 4")
	assert_eq(spec["build_cost"], {"목재": 8, "식량": 4}, "집 필요 자원")
	assert_eq(spec["pop_cap"], 2, "집 인구 상한 기여 +2")
	assert_eq(spec.get("production", {}).size(), 0, "집은 생산 없음(상한으로 전환)")
	for key in ["fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "집 외형 색상 %s 키 존재" % key)

func test_pop_cap_tiers() -> void:
	assert_eq(types.get_type("camp")["pop_cap"], 0, "캠프 티어 인구 상한 0")
	assert_eq(types.get_type("town_hall")["pop_cap"], 10, "마을회관 티어 10")
	assert_eq(types.get_type("castle")["pop_cap"], 20, "성 티어 20")

func test_center_tier() -> void:
	assert_eq(types.center_tier("camp"), 0, "캠프 tier 0")
	assert_eq(types.center_tier("town_hall"), 1, "마을회관 tier 1")
	assert_eq(types.center_tier("castle"), 2, "성 tier 2")
	assert_eq(types.center_tier("farm"), -1, "비거점 -1")
	assert_eq(types.center_tier("없는id"), -1, "없는id -1")

func test_next_center() -> void:
	assert_eq(types.next_center("camp"), "town_hall", "캠프→마을회관")
	assert_eq(types.next_center("town_hall"), "castle", "마을회관→성")
	assert_eq(types.next_center("castle"), "", "성은 최종")
	assert_eq(types.next_center("farm"), "", "비거점은 다음 없음")

func test_lumberjack_spec() -> void:
	var spec: Dictionary = types.get_type("lumberjack")
	assert_eq(spec["label"], "벌목소", "라벨은 벌목소")
	assert_eq(spec["vision"], 3, "시야 3")
	assert_eq(spec["footprint"], 1, "벌목소 footprint 1헥스")
	assert_eq(spec["build_turns"], 3, "벌목소 필요 턴 3")
	assert_eq(spec["build_cost"], {"목재": 5}, "벌목소 필요 자원")
	assert_eq(spec.get("production", {}).size(), 0, "벌목소 flat 생산 없음(1차 생산)")
	assert_true(spec.get("primary_production", false), "벌목소는 1차 생산")
	assert_eq(spec.get("produces", ""), "목재", "벌목소 산출 목재")
	assert_eq(spec.get("buildable_terrains", []), [Terrain.FOREST], "벌목소는 숲에만")

func test_iron_mine_spec() -> void:
	var spec: Dictionary = types.get_type("iron_mine")
	assert_eq(spec["label"], "철광", "라벨은 철광")
	assert_eq(spec["build_cost"], {"목재": 15}, "철광 필요 자원")
	assert_true(spec.get("primary_production", false), "철광은 1차 생산")
	assert_eq(spec.get("produces", ""), "철", "철광 산출 철")
	assert_eq(spec.get("buildable_terrains", []), [Terrain.IRON_VEIN], "철광은 철맥에만")
	assert_eq(spec["prerequisite"], "camp", "철광 선행 = 캠프")

func test_gold_mine_spec() -> void:
	var spec: Dictionary = types.get_type("gold_mine")
	assert_eq(spec["label"], "금광", "라벨은 금광")
	assert_eq(spec["build_cost"], {"목재": 15, "철": 5}, "금광 필요 자원")
	assert_true(spec.get("primary_production", false), "금광은 1차 생산")
	assert_eq(spec.get("produces", ""), "금", "금광 산출 금")
	assert_eq(spec.get("buildable_terrains", []), [Terrain.GOLD_VEIN], "금광은 금맥에만")

func test_town_hall_spec() -> void:
	var spec: Dictionary = types.get_type("town_hall")
	assert_eq(spec["label"], "마을회관", "라벨은 마을회관")
	assert_eq(spec["vision"], 6, "시야 6")
	assert_eq(spec["footprint"], 7, "마을회관 footprint 7헥스")
	assert_eq(spec["build_turns"], 8, "마을회관 필요 턴 8")
	assert_eq(spec["build_cost"], {"목재": 20, "식량": 20}, "마을회관 필요 자원")
	assert_eq(spec["prerequisite"], "camp", "마을회관 선행 = 캠프")
	assert_eq(spec.get("production", {}).size(), 0, "마을회관은 생산 없음")

func test_castle_spec() -> void:
	var spec: Dictionary = types.get_type("castle")
	assert_eq(spec["label"], "성", "라벨은 성")
	assert_eq(spec["vision"], 8, "시야 8")
	assert_eq(spec["footprint"], 7, "성 footprint 7헥스")
	assert_eq(spec["build_turns"], 12, "성 필요 턴 12")
	assert_eq(spec["build_cost"], {"목재": 40, "식량": 30, "철": 20}, "성 필요 자원")
	assert_eq(spec["demolish_refund"], {"목재": 4, "철": 2}, "성 파괴 환산")
	assert_eq(spec["prerequisite"], "town_hall", "성 선행 = 마을회관")
	assert_eq(spec.get("production", {}).size(), 0, "성은 생산 없음")

# --- 선행건물(prerequisite) ---

func test_prerequisite_fields() -> void:
	assert_eq(types.get_type("camp").get("prerequisite", ""), "", "캠프는 선행 없음")
	for id in ["castle", "house"]:
		assert_eq(types.get_type(id)["prerequisite"], "town_hall", "%s 선행 = 마을회관" % id)
	for id in ["farm", "lumberjack", "iron_mine", "gold_mine"]:
		assert_eq(types.get_type(id)["prerequisite"], "camp", "%s 선행 = 캠프(1차 생산)" % id)

# --- 건설 · 경제 ---

func test_farm_economy() -> void:
	var spec: Dictionary = types.get_type("farm")
	assert_eq(spec["build_turns"], 3, "농장 필요 턴 3")
	assert_eq(spec["build_cost"], {"목재": 5}, "농장 필요 자재")
	assert_eq(spec["demolish_refund"], {"목재": 1}, "농장 파괴 환산(자재만)")
	assert_eq(spec.get("required_pop", 0), 0, "농장 필요인원 0(폐지)")
	assert_eq(spec.get("production", {}).size(), 0, "농장 flat 생산 없음")
	assert_true(spec.get("primary_production", false), "농장은 1차 생산")
	assert_eq(spec.get("produces", ""), "식량", "농장 산출 식량")
	assert_eq(spec.get("buildable_terrains", []), [Terrain.GRASS], "농장은 초원에만")

func test_required_pop_abolished() -> void:
	# required_pop 폐지 — 모든 건물 0.
	for id in ["farm", "lumberjack", "iron_mine", "gold_mine", "camp", "town_hall", "castle", "house"]:
		assert_eq(types.get_type(id).get("required_pop", 0), 0, "%s 필요인원 0" % id)

func test_camp_economy() -> void:
	var spec: Dictionary = types.get_type("camp")
	assert_eq(spec["build_turns"], 8, "캠프 필요 턴 8")
	assert_eq(spec["build_cost"], {"목재": 10, "식량": 10}, "캠프 필요 자원")
	assert_eq(spec["demolish_refund"], {"목재": 2}, "캠프 파괴 환산")

func test_unknown_type_empty() -> void:
	assert_eq(types.get_type("없는id").size(), 0, "없는 종류는 빈 Dictionary")

func test_removed_types_empty() -> void:
	# 제거된 종류(잉여 1차·2차 생산)는 빈 Dictionary.
	for id in ["quarry", "hunting_ground", "fishing_spot", "silver_mine", "sawmill", "mill", "bakery", "stable", "ranch", "smelter"]:
		assert_eq(types.get_type(id).size(), 0, "제거된 종류 %s는 빈 Dictionary" % id)

# --- 거점(center) ---

func test_center_ids() -> void:
	assert_eq(types.CENTER_IDS, ["camp", "town_hall", "castle"], "거점 세트")

func test_is_center() -> void:
	for id in ["camp", "town_hall", "castle"]:
		assert_true(types.is_center(id), "%s는 거점" % id)
	for id in ["farm", "house", "lumberjack", "iron_mine", "없는id"]:
		assert_false(types.is_center(id), "%s는 거점 아님" % id)

func test_buildable_ids() -> void:
	assert_eq(types.BUILDABLE_IDS, ["farm", "lumberjack", "iron_mine", "gold_mine", "house"], "건축 가능 목록(거점·제거 종류 제외)")
	for id in ["camp", "town_hall", "castle"]:
		assert_does_not_have(types.BUILDABLE_IDS, id, "거점 %s는 건축 목록 제외" % id)
