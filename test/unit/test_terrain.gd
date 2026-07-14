extends GutTest
## Terrain 카탈로그: 지형별 이동 상한(move_cap)·진입 가능 여부·라벨.
## 규칙: 목적지 지형이 이동력을 반감 — 숲 ceil, 습지 floor, 산 도달 불가.

# --- move_cap ---

func test_grass_and_desert_keep_full_movement() -> void:
	assert_eq(Terrain.move_cap(Terrain.GRASS, 3), 3, "초원은 이동력 그대로")
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

func test_mountain_unreachable() -> void:
	assert_eq(Terrain.move_cap(Terrain.MOUNTAIN, 5), -1, "산은 도달 거리 -1")

# --- is_passable / label ---

func test_only_mountain_impassable() -> void:
	assert_false(Terrain.is_passable(Terrain.MOUNTAIN), "산은 진입 불가")
	for id in [Terrain.GRASS, Terrain.FOREST, Terrain.SWAMP, Terrain.DESERT]:
		assert_true(Terrain.is_passable(id), "산 외 지형은 진입 가능: %d" % id)

func test_impassable_list_is_mountain() -> void:
	assert_eq(Terrain.IMPASSABLE, [Terrain.MOUNTAIN], "이동 통과 불가 목록은 산뿐")

func test_labels() -> void:
	assert_eq(Terrain.label(Terrain.FOREST), "숲")
	assert_eq(Terrain.label(Terrain.MOUNTAIN), "산")
	assert_eq(Terrain.label(-1), "초원", "알 수 없는 지형은 초원 라벨")

# --- 1차 생산 지형(슬라이스 2) → docs/spec/features/production.md ---

func test_production_terrain_ids_and_labels() -> void:
	assert_eq(Terrain.STONE, 5, "돌 id 5")
	assert_eq(Terrain.SILVER_VEIN, 10, "은맥 id 10")
	assert_eq(Terrain.label(Terrain.STONE), "돌")
	assert_eq(Terrain.label(Terrain.ANIMAL), "동물")
	assert_eq(Terrain.label(Terrain.WATER), "물가")
	assert_eq(Terrain.label(Terrain.IRON_VEIN), "철맥")
	assert_eq(Terrain.label(Terrain.GOLD_VEIN), "금맥")
	assert_eq(Terrain.label(Terrain.SILVER_VEIN), "은맥")

func test_production_terrain_passable_and_normal_move() -> void:
	for id in [Terrain.STONE, Terrain.ANIMAL, Terrain.WATER, Terrain.IRON_VEIN, Terrain.GOLD_VEIN, Terrain.SILVER_VEIN]:
		assert_true(Terrain.is_passable(id), "1차 생산 지형 통행 가능: %d" % id)
		assert_eq(Terrain.move_cap(id, 3), 3, "기본 이동(이동력 그대로): %d" % id)
