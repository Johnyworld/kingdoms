extends GutTest
## game.gd 의 시작 모서리(start_corner) → 거점 중심 칸 리졸버(corner_cell) 검증.
## factions.csv 의 start_corner 컬럼 + 맵 크기·MARGIN 으로 좌표를 계산한다(NPC_BASES 하드코딩 대체).

var game = load("res://scenes/game/game.gd")

# 50x50 맵, MARGIN 10 기준 — 리팩터 전 PLAYER_BASE/NPC_BASES 하드코딩 좌표와 동일해야 한다.
func test_corner_cell_four_corners() -> void:
	assert_eq(game.corner_cell("SW", 50, 50, 10), Vector2i(10, 39), "남서(플레이어)")
	assert_eq(game.corner_cell("NW", 50, 50, 10), Vector2i(10, 10), "북서(초원 칸국)")
	assert_eq(game.corner_cell("NE", 50, 50, 10), Vector2i(39, 10), "북동(암흑 제국)")
	assert_eq(game.corner_cell("SE", 50, 50, 10), Vector2i(39, 39), "남동(사막 술탄국)")

func test_corner_cell_unknown_defaults_sw() -> void:
	assert_eq(game.corner_cell("???", 50, 50, 10), Vector2i(10, 39), "알 수 없는 모서리 → SW 기본")

func test_corner_cell_scales_with_map_and_margin() -> void:
	# 맵 크기·MARGIN 이 바뀌면 좌표도 따라 계산되는지(하드코딩 아님).
	assert_eq(game.corner_cell("NE", 30, 40, 5), Vector2i(24, 5), "30x40·MARGIN5 북동")
