extends GutTest
## BuildingRenderer: 거점 건물의 세력색·티어 → LaPetiteTile 건물 terrain 인덱스 매핑.
## 마을(캠프·마을회관) vs 성, 4세력 색 변형, 비거점(-1) 규칙.

func test_camp_and_town_hall_use_village_variant() -> void:
	assert_eq(BuildingRenderer.terrain_index("camp", "푸른 왕국"), 0, "캠프=마을(White&Terracotta 0)")
	assert_eq(BuildingRenderer.terrain_index("town_hall", "푸른 왕국"), 0, "마을회관도 마을 변형 사용")

func test_castle_uses_castle_variant() -> void:
	assert_eq(BuildingRenderer.terrain_index("castle", "푸른 왕국"), 5, "성=Castle(White&Terracotta 5)")

func test_faction_color_variants() -> void:
	# 마을 인덱스: 푸른 0 · 초원 2 · 암흑 3 · 사막 4
	assert_eq(BuildingRenderer.terrain_index("camp", "초원 칸국"), 2, "초원 칸국 = Wood 마을")
	assert_eq(BuildingRenderer.terrain_index("camp", "암흑 제국"), 3, "암흑 제국 = Gray&Slate 마을")
	assert_eq(BuildingRenderer.terrain_index("camp", "사막 술탄국"), 4, "사막 술탄국 = White&Slate 마을")
	# 성 인덱스: 푸른 5 · 초원 6 · 암흑 7 · 사막 8
	assert_eq(BuildingRenderer.terrain_index("castle", "초원 칸국"), 6, "초원 성")
	assert_eq(BuildingRenderer.terrain_index("castle", "암흑 제국"), 7, "암흑 성")
	assert_eq(BuildingRenderer.terrain_index("castle", "사막 술탄국"), 8, "사막 성")

func test_non_center_uses_village_variant() -> void:
	# 생산·집(footprint 1)도 마을 변형으로 그린다(1칸이라 작은 집). 성만 castle.
	for t in ["farm", "house", "lumberjack", "iron_mine", "gold_mine"]:
		assert_eq(BuildingRenderer.terrain_index(t, "푸른 왕국"), 0, "비거점도 마을(작은 집): %s" % t)

func test_render_cells_tier_sizes() -> void:
	# footprint 7칸: 캠프=작은 마을(3칸), 마을회관·성=풀(7칸).
	var fp: Array[Vector2i] = []
	for i in 7:
		fp.append(Vector2i(i, 0))
	assert_eq(BuildingRenderer.render_cells("camp", fp).size(), 3, "캠프는 3칸(작은 마을)")
	assert_eq(BuildingRenderer.render_cells("town_hall", fp).size(), 7, "마을회관은 풀 7칸")
	assert_eq(BuildingRenderer.render_cells("castle", fp).size(), 7, "성은 풀 7칸")
	# 소형 건물(footprint 1)은 1칸 그대로.
	var one: Array[Vector2i] = [Vector2i(0, 0)]
	assert_eq(BuildingRenderer.render_cells("farm", one).size(), 1, "농장은 1칸")

func test_unknown_faction_defaults_to_first_variant() -> void:
	assert_eq(BuildingRenderer.terrain_index("camp", ""), 0, "무소속/미지정 → 기본(White&Terracotta) 마을")
	assert_eq(BuildingRenderer.terrain_index("castle", "없는세력"), 5, "미지정 → 기본 성")
