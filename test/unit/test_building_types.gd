extends GutTest
## 건물 종류 카탈로그(BuildingTypes) 테스트.

var types = load("res://scenes/building/building_types.gd")

func test_camp_spec_has_keys() -> void:
	var spec: Dictionary = types.get_type("camp")
	for key in ["label", "vision", "resources", "fill_color", "edge_color", "tent_color"]:
		assert_true(spec.has(key), "camp 스펙에 %s 키 존재" % key)

func test_camp_spec_values() -> void:
	var spec: Dictionary = types.get_type("camp")
	assert_eq(spec["label"], "캠프", "라벨은 캠프")
	assert_eq(spec["vision"], 5, "시야 5")
	var expected := {"밀": 50, "빵": 20, "나무": 20, "목재": 20, "철": 10, "철괴": 10}
	assert_eq(spec["resources"].size(), expected.size(), "자원 6종")
	for key in expected:
		assert_eq(spec["resources"].get(key), expected[key], "%s 초기값" % key)

func test_unknown_type_empty() -> void:
	assert_eq(types.get_type("없는id").size(), 0, "없는 종류는 빈 Dictionary")
