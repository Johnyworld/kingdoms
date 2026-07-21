extends GutTest
## LangFieldMath — 전장 렌더러에서 추출한 순수 기하/분배 수학(M4-D). 결정적이라 씬 없이 검증.

# --- row_counts: n명을 3행 [뒤,중,앞]로 분배(나머지는 앞 행부터) ---

func test_row_counts_ten() -> void:
	assert_eq(LangFieldMath.row_counts(10), [3, 3, 4], "10 → [3,3,4]")

func test_row_counts_even_split() -> void:
	assert_eq(LangFieldMath.row_counts(9), [3, 3, 3], "9 → [3,3,3]")

func test_row_counts_remainder_fills_front_first() -> void:
	assert_eq(LangFieldMath.row_counts(11), [3, 4, 4], "11 → 나머지 2는 앞·중 행")
	assert_eq(LangFieldMath.row_counts(1), [0, 0, 1], "1 → 앞 행에만")

func test_row_counts_zero() -> void:
	assert_eq(LangFieldMath.row_counts(0), [0, 0, 0], "0 → 전부 0")

func test_row_counts_sum_preserved() -> void:
	for n in range(0, 21):
		var rows: Array = LangFieldMath.row_counts(n)
		assert_eq(rows[0] + rows[1] + rows[2], n, "행 합 = %d" % n)

# --- predict_intercept: 화살(속도 speed)이 (tpos, tvel) 타겟과 만나는 지점 ---

func test_intercept_static_target_returns_target() -> void:
	# 정지 타겟이면 요격점 = 타겟 위치(속도 0 → V·V=0, 해는 |R|/speed>0이지만 tpos+0 = tpos).
	var hit := LangFieldMath.predict_intercept(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 10.0)
	assert_eq(hit, Vector2(100, 0), "정지 타겟은 현재 위치가 요격점")

func test_intercept_leads_moving_target() -> void:
	# 타겟이 +x로 이동 → 요격점은 타겟 앞쪽(현재 x보다 큼).
	var hit := LangFieldMath.predict_intercept(Vector2.ZERO, Vector2(100, 0), Vector2(5, 0), 20.0)
	assert_gt(hit.x, 100.0, "이동 타겟은 앞을 겨냥(리드)")

func test_intercept_unreachable_returns_target() -> void:
	# 타겟이 화살보다 빨리 달아나면(요격 불가) 현재 위치 반환.
	var hit := LangFieldMath.predict_intercept(Vector2.ZERO, Vector2(100, 0), Vector2(50, 0), 5.0)
	assert_eq(hit, Vector2(100, 0), "요격 불가 → 현재 위치")

func test_intercept_meeting_point_consistent() -> void:
	# 요격점까지 화살 비행시간 t_arrow = |hit-from|/speed 와 타겟 도달시간이 일치해야 한다.
	var from := Vector2(0, 0)
	var tpos := Vector2(100, 20)
	var tvel := Vector2(-3, 4)
	var speed := 15.0
	var hit := LangFieldMath.predict_intercept(from, tpos, tvel, speed)
	var t_arrow := from.distance_to(hit) / speed
	var t_target := (hit - tpos).length() / tvel.length()
	assert_almost_eq(t_arrow, t_target, 0.05, "화살 비행시간 ≈ 타겟 도달시간(같은 점에서 만남)")
