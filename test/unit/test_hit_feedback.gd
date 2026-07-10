extends GutTest
## 전투 연출 텍스트 매핑(HitFeedback) 테스트 — 순수 함수. 판정 결과 → 떠오를 텍스트 사양.
## docs/spec/features/combat-feedback.md의 테스트 시나리오를 옮긴 것.

# resolve_hit 결과 형태의 Dictionary를 만든다(필요한 키만).
func _r(hit := true, blocked := false, crit := false, damage := 0) -> Dictionary:
	return {"hit": hit, "blocked": blocked, "crit": crit, "damage": damage}

# --- hit_text: 판정 → 텍스트 사양 ---

func test_hit_text_normal() -> void:
	var s := HitFeedback.hit_text(_r(true, false, false, 15))
	assert_eq(s["text"], "15", "평타는 피해 숫자")
	assert_eq(s["color"], HitFeedback.HIT_COLOR, "평타는 흰색")
	assert_false(s["big"], "평타는 보통 크기")

func test_hit_text_crit() -> void:
	var s := HitFeedback.hit_text(_r(true, false, true, 22))
	assert_eq(s["text"], "22", "치명타도 피해 숫자")
	assert_eq(s["color"], HitFeedback.CRIT_COLOR, "치명타는 노랑")
	assert_true(s["big"], "치명타는 큰 글씨")

func test_hit_text_miss() -> void:
	var s := HitFeedback.hit_text(_r(false, false, false, 0))
	assert_eq(s["text"], "빗나감", "빗나가면 '빗나감'")
	assert_eq(s["color"], HitFeedback.MISS_COLOR, "빗나감은 회색")
	assert_false(s["big"], "빗나감은 보통 크기")

func test_hit_text_blocked() -> void:
	var s := HitFeedback.hit_text(_r(true, true, false, 0))
	assert_eq(s["text"], "막기", "막으면 '막기'")
	assert_eq(s["color"], HitFeedback.BLOCK_COLOR, "막기는 하늘색")
	assert_false(s["big"], "막기는 보통 크기")

func test_hit_text_miss_priority_over_crit() -> void:
	# 빗나감이면 crit/damage 값과 무관하게 '빗나감'이 우선.
	var s := HitFeedback.hit_text(_r(false, false, true, 99))
	assert_eq(s["text"], "빗나감", "빗나감이 치명·피해보다 우선")
	assert_eq(s["color"], HitFeedback.MISS_COLOR, "회색")

# --- status_text: 상태이상 id → 텍스트 ---

func test_status_text_bleed() -> void:
	assert_eq(HitFeedback.status_text("bleed"), "출혈!", "bleed → 출혈!")

func test_status_text_stun() -> void:
	assert_eq(HitFeedback.status_text("stun"), "기절!", "stun → 기절!")

func test_status_text_empty_and_unknown() -> void:
	assert_eq(HitFeedback.status_text(""), "", "빈 id → 빈 문자열")
	assert_eq(HitFeedback.status_text("poison"), "", "미지정 id → 빈 문자열")
