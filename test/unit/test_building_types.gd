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
	# 캠프 resources = 생성 영지 초기 자원(인구·금 포함 8종).
	var expected := {"인구": 10, "밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10, "금": 0}
	assert_eq(spec["resources"].size(), expected.size(), "자원 8종")
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

# --- 거점(center) ---

func test_center_ids() -> void:
	assert_eq(types.CENTER_IDS, ["camp", "town_hall", "castle"], "거점 세트")

func test_is_center() -> void:
	for id in ["camp", "town_hall", "castle"]:
		assert_true(types.is_center(id), "%s는 거점" % id)
	for id in ["farm", "house", "lumberjack", "quarry", "없는id"]:
		assert_false(types.is_center(id), "%s는 거점 아님" % id)

func test_buildable_ids() -> void:
	assert_eq(types.BUILDABLE_IDS, ["quarry", "farm", "house", "lumberjack"], "건축 가능 목록(거점 제외)")
	for id in ["camp", "town_hall", "castle"]:
		assert_does_not_have(types.BUILDABLE_IDS, id, "거점 %s는 건축 목록 제외(업그레이드/새영지)" % id)

# --- 성벽 (WALL_COST / can_build_wall) ---

func _terr(res := {}) -> Object:
	return load("res://scenes/territory/territory.gd").new("파리", res)

func _bld(type_id: String, walled := false) -> Node2D:
	var b: Node2D = load("res://scenes/building/building.gd").new()
	add_child_autofree(b)
	b.building_type = type_id   # setup 없이 종류만 지정(can_build_wall은 종류·성벽만 본다)
	b.wall_level = 1 if walled else 0
	return b

func test_wall_cost_is_materials() -> void:
	assert_eq(types.WALL_COST, {"목재": 15, "석재": 10}, "성벽 비용 = 목재15·석재10")

func test_can_build_wall_town_hall_affordable() -> void:
	assert_true(types.can_build_wall(_terr({"목재": 20, "석재": 20}), _bld("town_hall")), "마을회관 + 자재 충분 → 참")

func test_can_build_wall_camp_false() -> void:
	assert_false(types.can_build_wall(_terr({"목재": 20, "석재": 20}), _bld("camp")), "캠프(tier 0)는 성벽 불가")

func test_can_build_wall_already_walled_false() -> void:
	assert_false(types.can_build_wall(_terr({"목재": 20, "석재": 20}), _bld("town_hall", true)), "이미 성벽 → 거짓")

func test_can_build_wall_poor_false() -> void:
	assert_false(types.can_build_wall(_terr({"목재": 5}), _bld("town_hall")), "자재 부족 → 거짓")
