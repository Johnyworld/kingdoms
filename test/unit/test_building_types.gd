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
	# 캠프 resources = 생성 영지 초기 자원(인구 포함 7종).
	var expected := {"인구": 10, "밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10}
	assert_eq(spec["resources"].size(), expected.size(), "자원 7종")
	for key in expected:
		assert_eq(spec["resources"].get(key), expected[key], "%s 초기값" % key)

func test_farm_spec_values() -> void:
	var spec: Dictionary = types.get_type("farm")
	assert_eq(spec["label"], "농장", "라벨은 농장")
	assert_eq(spec["vision"], 4, "시야 4")
	for key in ["fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "farm 외형 색상 %s 키 존재" % key)

# --- 건설 · 경제 ---

func test_farm_economy() -> void:
	var spec: Dictionary = types.get_type("farm")
	assert_eq(spec["build_turns"], 3, "농장 필요 턴 3")
	assert_eq(spec["build_cost"], {"인구": 2, "목재": 5, "밀": 5}, "농장 필요 자원")
	assert_eq(spec["demolish_refund"], {"인구": 2, "목재": 1}, "농장 파괴 환산")
	assert_eq(spec["production"], {"밀": 1}, "농장 턴당 생산")

func test_camp_economy() -> void:
	var spec: Dictionary = types.get_type("camp")
	assert_eq(spec["build_turns"], 8, "캠프 필요 턴 8")
	assert_eq(spec["build_cost"], {"목재": 10, "밀": 10}, "캠프 필요 자원")
	assert_eq(spec["demolish_refund"], {"목재": 2}, "캠프 파괴 환산")

func test_unknown_type_empty() -> void:
	assert_eq(types.get_type("없는id").size(), 0, "없는 종류는 빈 Dictionary")

# --- 건축 가능 목록 ---

func test_buildable_ids() -> void:
	assert_has(types.BUILDABLE_IDS, "farm", "농장은 건축 가능")
	assert_does_not_have(types.BUILDABLE_IDS, "camp", "캠프는 건축 목록에서 제외")
