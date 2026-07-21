extends GutTest
## Terrain 카탈로그: 지형별 이동 상한(move_cap)·진입 가능 여부·라벨.
## 규칙: 목적지 지형이 이동력을 반감 — 숲 ceil, 습지 floor, 산 도달 불가.

# --- move_cap ---

func test_grass_and_desert_keep_full_movement() -> void:
	assert_eq(Terrain.move_cap(Terrain.PLAINS, 3), 3, "초원은 이동력 그대로")
	assert_eq(Terrain.move_cap(Terrain.DESERT, 3), 3, "사막은 이동력 그대로")

func test_unknown_source_treated_as_grass() -> void:
	# 미도색 셀은 get_cell_source_id가 -1을 준다 → 초원 취급.
	assert_eq(Terrain.move_cap(-1, 3), 3, "알 수 없는 지형(-1)은 초원처럼 이동력 그대로")

func test_forest_halves_round_up() -> void:
	assert_eq(Terrain.move_cap(Terrain.FOREST, 3), 2, "숲: ceil(3/2)=2")
	assert_eq(Terrain.move_cap(Terrain.FOREST, 2), 1, "숲: ceil(2/2)=1")
	assert_eq(Terrain.move_cap(Terrain.FOREST, 4), 2, "숲: ceil(4/2)=2")
	assert_eq(Terrain.move_cap(Terrain.FOREST, 1), 1, "숲: ceil(1/2)=1")

func test_swamp_halves_round_down() -> void:
	assert_eq(Terrain.move_cap(Terrain.SWAMP, 3), 1, "습지: floor(3/2)=1")
	assert_eq(Terrain.move_cap(Terrain.SWAMP, 2), 1, "습지: floor(2/2)=1")
	assert_eq(Terrain.move_cap(Terrain.SWAMP, 4), 2, "습지: floor(4/2)=2")
	assert_eq(Terrain.move_cap(Terrain.SWAMP, 1), 0, "습지: floor(1/2)=0 (이동력 1이면 진입 불가)")

func test_mountain_and_water_unreachable() -> void:
	assert_eq(Terrain.move_cap(Terrain.MOUNTAIN, 5), -1, "산은 도달 거리 -1")
	assert_eq(Terrain.move_cap(Terrain.WATER, 5), -1, "물은 도달 거리 -1")

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
		assert_eq(Terrain.move_cap(id, 3), 3, "기본 이동(이동력 그대로): %d" % id)

# 돌(5)·동물(6)·물가(7)·은맥(10) 상수는 제거됐다 — 참조 시 parse 에러이므로 테스트에서도 참조하지 않는다.
