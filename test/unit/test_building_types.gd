extends GutTest
## 건물 종류 카탈로그(BuildingTypes) 테스트.

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
	# 캠프 resources = 생성 영지 초기 자원(인구 포함 7종).
	var expected := {"인구": 10, "밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10}
	assert_eq(spec["resources"].size(), expected.size(), "자원 7종")
	for key in expected:
		assert_eq(spec["resources"].get(key), expected[key], "%s 초기값" % key)

func test_farm_spec_values() -> void:
	var spec: Dictionary = types.get_type("farm")
	assert_eq(spec["label"], "농장", "라벨은 농장")
	assert_eq(spec["vision"], 4, "시야 4")
	assert_eq(spec["footprint"], 7, "농장 footprint 7헥스")
	for key in ["fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "farm 외형 색상 %s 키 존재" % key)

# --- 신규 소형 생산 건물 (footprint 1) ---

func test_house_spec() -> void:
	var spec: Dictionary = types.get_type("house")
	assert_eq(spec["label"], "집", "라벨은 집")
	assert_eq(spec["vision"], 2, "시야 2")
	assert_eq(spec["footprint"], 1, "집 footprint 1헥스")
	assert_eq(spec["build_turns"], 4, "집 필요 턴 4")
	assert_eq(spec["build_cost"], {"목재": 8, "석재": 4}, "집 필요 자원")
	assert_eq(spec["pop_cap"], 2, "집 인구 상한 기여 +2")
	assert_eq(spec.get("production", {}).size(), 0, "집은 생산 없음(상한으로 전환)")
	for key in ["fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "집 외형 색상 %s 키 존재" % key)

func test_camp_pop_cap() -> void:
	assert_eq(types.get_type("camp")["pop_cap"], 10, "캠프 기본 인구 상한 10")

func test_lumberjack_spec() -> void:
	var spec: Dictionary = types.get_type("lumberjack")
	assert_eq(spec["label"], "벌목소", "라벨은 벌목소")
	assert_eq(spec["vision"], 3, "시야 3")
	assert_eq(spec["footprint"], 1, "벌목소 footprint 1헥스")
	assert_eq(spec["build_turns"], 3, "벌목소 필요 턴 3")
	assert_eq(spec["build_cost"], {"목재": 5, "석재": 5}, "벌목소 필요 자원")
	assert_eq(spec["production"], {"나무": 2}, "벌목소 턴당 나무 2")

func test_quarry_spec() -> void:
	var spec: Dictionary = types.get_type("quarry")
	assert_eq(spec["label"], "채석장", "라벨은 채석장")
	assert_eq(spec["vision"], 3, "시야 3")
	assert_eq(spec["footprint"], 1, "채석장 footprint 1헥스")
	assert_eq(spec["build_turns"], 4, "채석장 필요 턴 4")
	assert_eq(spec["build_cost"], {"목재": 10}, "채석장 필요 자원(목재만)")
	assert_eq(spec["production"], {"석재": 2}, "채석장 턴당 석재 2")
	assert_eq(spec["prerequisite"], "camp", "채석장 선행 = 캠프(부트스트랩)")

func test_town_hall_spec() -> void:
	var spec: Dictionary = types.get_type("town_hall")
	assert_eq(spec["label"], "마을회관", "라벨은 마을회관")
	assert_eq(spec["vision"], 6, "시야 6")
	assert_eq(spec["footprint"], 7, "마을회관 footprint 7헥스")
	assert_eq(spec["build_turns"], 8, "마을회관 필요 턴 8(조정)")
	assert_eq(spec["build_cost"], {"목재": 10, "석재": 10, "밀": 20}, "마을회관 필요 자원(조정)")
	assert_eq(spec["prerequisite"], "camp", "마을회관 선행 = 캠프")
	assert_eq(spec.get("production", {}).size(), 0, "마을회관은 생산 없음")

func test_castle_spec() -> void:
	var spec: Dictionary = types.get_type("castle")
	assert_eq(spec["label"], "성", "라벨은 성")
	assert_eq(spec["vision"], 8, "시야 8")
	assert_eq(spec["footprint"], 7, "성 footprint 7헥스")
	assert_eq(spec["build_turns"], 12, "성 필요 턴 12(조정)")
	assert_eq(spec["build_cost"], {"석재": 50, "밀": 30}, "성 필요 자원(조정)")
	assert_eq(spec["demolish_refund"], {"석재": 10}, "성 파괴 환산")
	assert_eq(spec["prerequisite"], "town_hall", "성 선행 = 마을회관")
	assert_eq(spec.get("production", {}).size(), 0, "성은 생산 없음")

# --- 선행건물(prerequisite) ---

func test_prerequisite_fields() -> void:
	assert_eq(types.get_type("camp").get("prerequisite", ""), "", "캠프는 선행 없음")
	for id in ["castle", "farm", "house", "lumberjack"]:
		assert_eq(types.get_type(id)["prerequisite"], "town_hall", "%s 선행 = 마을회관" % id)

# --- 건설 · 경제 ---

func test_farm_economy() -> void:
	var spec: Dictionary = types.get_type("farm")
	assert_eq(spec["build_turns"], 3, "농장 필요 턴 3")
	assert_eq(spec["build_cost"], {"목재": 5, "밀": 5}, "농장 필요 자재(인구는 required_pop으로 이동)")
	assert_eq(spec["demolish_refund"], {"목재": 1}, "농장 파괴 환산(자재만)")
	assert_eq(spec["required_pop"], 2, "농장 필요인원 2")
	assert_eq(spec["production"], {"밀": 1}, "농장 턴당 생산")

func test_required_pop_fields() -> void:
	assert_eq(types.get_type("farm")["required_pop"], 2, "농장 필요인원 2")
	assert_eq(types.get_type("lumberjack")["required_pop"], 1, "벌목소 필요인원 1")
	assert_eq(types.get_type("quarry")["required_pop"], 1, "채석장 필요인원 1")
	for id in ["camp", "town_hall", "castle", "house"]:
		assert_eq(types.get_type(id).get("required_pop", 0), 0, "%s 필요인원 0" % id)

func test_camp_economy() -> void:
	var spec: Dictionary = types.get_type("camp")
	assert_eq(spec["build_turns"], 8, "캠프 필요 턴 8")
	assert_eq(spec["build_cost"], {"목재": 10, "밀": 10}, "캠프 필요 자원")
	assert_eq(spec["demolish_refund"], {"목재": 2}, "캠프 파괴 환산")

func test_unknown_type_empty() -> void:
	assert_eq(types.get_type("없는id").size(), 0, "없는 종류는 빈 Dictionary")

# --- 건축 가능 목록 ---

func test_buildable_ids() -> void:
	assert_eq(types.BUILDABLE_IDS, ["town_hall", "quarry", "farm", "house", "lumberjack", "castle"], "건축 가능 목록")
	assert_does_not_have(types.BUILDABLE_IDS, "camp", "캠프는 건축 목록에서 제외")
