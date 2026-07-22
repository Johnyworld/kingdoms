extends GutTest
## Terrain 카탈로그: 지형별 진입비용(enter_cost)·진입 가능 여부·라벨.
## 규칙: 칸마다 진입비용 누적 — 초원 1·숲 2·습지 3, 산·물 진입 불가(BLOCKED).

# --- enter_cost ---

func test_grass_and_desert_cost_one() -> void:
	assert_eq(Terrain.enter_cost(Terrain.PLAINS), 1, "초원 진입비용 1")
	assert_eq(Terrain.enter_cost(Terrain.DESERT), 1, "사막 진입비용 1")

func test_unknown_source_treated_as_grass() -> void:
	# 미도색 셀은 get_cell_source_id가 -1을 준다 → 초원(1) 취급.
	assert_eq(Terrain.enter_cost(-1), 1, "알 수 없는 지형(-1)은 초원처럼 비용 1")

func test_forest_costs_two() -> void:
	assert_eq(Terrain.enter_cost(Terrain.FOREST), 2, "숲 진입비용 2")

func test_swamp_costs_three() -> void:
	assert_eq(Terrain.enter_cost(Terrain.SWAMP), 3, "습지 진입비용 3")

func test_mountain_and_water_blocked() -> void:
	assert_eq(Terrain.enter_cost(Terrain.MOUNTAIN), Terrain.BLOCKED, "산은 진입 불가(BLOCKED)")
	assert_eq(Terrain.enter_cost(Terrain.WATER), Terrain.BLOCKED, "물은 진입 불가(BLOCKED)")
	assert_true(Terrain.BLOCKED < 0, "BLOCKED는 음수(가중 BFS가 진입 불가로 취급)")

# --- is_passable / label ---

func test_mountain_and_water_impassable() -> void:
	assert_false(Terrain.is_passable(Terrain.MOUNTAIN), "산은 진입 불가")
	assert_false(Terrain.is_passable(Terrain.WATER), "물은 진입 불가")
	for id in [Terrain.PLAINS, Terrain.FOREST, Terrain.SWAMP, Terrain.DESERT]:
		assert_true(Terrain.is_passable(id), "산·물 외 지형은 진입 가능: %d" % id)

func test_impassable_list_is_mountain_and_water() -> void:
	assert_eq(Terrain.IMPASSABLE, [Terrain.MOUNTAIN, Terrain.WATER], "이동 통과 불가 목록은 산·물")

func test_labels() -> void:
	assert_eq(Terrain.label(Terrain.FOREST), "숲")
	assert_eq(Terrain.label(Terrain.MOUNTAIN), "산")
	assert_eq(Terrain.label(Terrain.WATER), "물")
	assert_eq(Terrain.label(-1), "초원", "알 수 없는 지형은 초원 라벨")

# --- 생산 지형(철맥·금맥) → docs/spec/features/production.md ---
# 자원 4종 축소: 돌·동물·물가·은맥 제거, 철맥(8)·금맥(9)만 유지.

func test_production_terrain_ids_and_labels() -> void:
	assert_eq(Terrain.IRON_VEIN, 8, "철맥 id 8(재번호 없음)")
	assert_eq(Terrain.GOLD_VEIN, 9, "금맥 id 9")
	assert_eq(Terrain.label(Terrain.IRON_VEIN), "철맥")
	assert_eq(Terrain.label(Terrain.GOLD_VEIN), "금맥")

func test_production_terrain_passable_and_normal_move() -> void:
	for id in [Terrain.IRON_VEIN, Terrain.GOLD_VEIN]:
		assert_true(Terrain.is_passable(id), "생산 지형 통행 가능: %d" % id)
		assert_eq(Terrain.enter_cost(id), 1, "생산 지형 진입비용 1: %d" % id)

# 돌(5)·동물(6)·물가(7)·은맥(10) 상수는 제거됐다 — 참조 시 parse 에러이므로 테스트에서도 참조하지 않는다.
