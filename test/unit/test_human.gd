extends GutTest
## Human 회복·버프(휴식/경계) — 순수 데이터 메서드. docs/spec/entities/Human.md 참조.

func _human(strength := 80, hp := 40, stam := 40, max_stam := 40) -> Object:
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = strength        # 힘 80 → max_hp() = floor(80/2) = 40
	h.hit_points = hp
	h.max_stamina = max_stam
	h.stamina = stam
	return h

func test_max_hp_scales_with_strength() -> void:
	# max_hp = floor(힘/2) × level (고정 바탕 없음, 힘 비례). → stats.md
	var h: Object = load("res://scenes/human/human.gd").new()
	h.strength = 46
	assert_eq(h.max_hp(), 23, "힘 46 → HP 23 (보병)")
	h.strength = 234
	assert_eq(h.max_hp(), 117, "힘 234 → HP 117 (배율 적용 영웅)")
	h.strength = 80
	h.level = 2
	assert_eq(h.max_hp(), 80, "힘 80 × Lv2 = 80")

func test_apply_rest_recovers_25pct() -> void:
	var h := _human(80, 10, 10, 40)
	h.apply_rest()
	assert_eq(h.hit_points, 20, "hp +25%(=10) → 20")
	assert_eq(h.stamina, 20, "스태미나 +25%(=10) → 20")

func test_apply_rest_clamps_to_max() -> void:
	var h := _human(80, 40, 40, 40)
	h.apply_rest()
	assert_eq(h.hit_points, 40, "이미 최대면 hp 불변(상한 clamp)")
	assert_eq(h.stamina, 40, "이미 최대면 스태미나 불변")

func test_apply_rest_hp_clamps_partial() -> void:
	var h := _human(80, 35, 40, 40)   # 35 + 10 = 45 → 40
	h.apply_rest()
	assert_eq(h.hit_points, 40, "35+10=45 → max_hp 40으로 clamp")

func test_apply_alert_recovers_and_buffs() -> void:
	var h := _human(80, 40, 10, 40)
	h.apply_alert()
	assert_eq(h.stamina, 14, "스태미나 +10%(round(4)) → 14")
	assert_true(h.alert, "경계 → alert = true")

func test_max_stamina_default() -> void:
	var h: Object = load("res://scenes/human/human.gd").new()
	assert_eq(h.max_stamina, 20, "최대 스태미나 기본 20")
	assert_false(h.alert, "alert 기본 false")
