extends GutTest
## 자원 가치 카탈로그(ResourceTypes) — 자원 판매가. 판매 기능에서 화물→금 환산에 쓴다.

func test_value_sellable_resources() -> void:
	assert_eq(ResourceTypes.value("철괴"), 12, "철괴 판매가 12")
	assert_eq(ResourceTypes.value("밀"), 1, "밀 판매가 1")
	assert_eq(ResourceTypes.value("목재"), 2, "목재 판매가 2")
	assert_eq(ResourceTypes.value("철"), 5, "철 판매가 5")

func test_value_primary_production_resources() -> void:
	assert_eq(ResourceTypes.value("고기"), 2, "고기 판매가 2(사냥터)")
	assert_eq(ResourceTypes.value("생선"), 2, "생선 판매가 2(낚시터)")
	assert_eq(ResourceTypes.value("은"), 8, "은 판매가 8(은광, 희소)")

func test_value_processing_resources() -> void:
	assert_eq(ResourceTypes.value("밀가루"), 2, "밀가루 판매가 2(제분소)")
	assert_eq(ResourceTypes.value("은괴"), 20, "은괴 판매가 20(제련소)")
	assert_eq(ResourceTypes.value("금괴"), 30, "금괴 판매가 30(제련소)")

func test_value_byproduct_resources() -> void:
	assert_eq(ResourceTypes.value("가죽"), 4, "가죽 판매가 4(축사 부산물)")
	assert_eq(ResourceTypes.value("천"), 4, "천 판매가 4(목장 부산물)")

func test_value_non_sellable() -> void:
	assert_eq(ResourceTypes.value("인구"), 0, "인구는 판매 불가(0)")
	assert_eq(ResourceTypes.value("금"), 0, "금은 화폐, 판매 불가(0)")
	assert_eq(ResourceTypes.value("없는자원"), 0, "미등록 자원 0")
