extends GutTest
## 상태이상(StatusEffects) 테스트 — 순수 함수. 치명타 연동·출혈 도트·기절을 초 기반으로 검증.
## docs/spec/features/status-effects.md의 테스트 시나리오를 옮긴 것.

# --- on_crit 매핑 ---

func test_on_crit_slash_bleed() -> void:
	assert_eq(StatusEffects.on_crit("참격"), "bleed", "참격 치명타 → 출혈")
	assert_eq(StatusEffects.on_crit(ItemTypes.DT_SLASH), StatusEffects.BLEED, "상수 경유도 동일(단일 출처)")

func test_on_crit_blunt_stun() -> void:
	assert_eq(StatusEffects.on_crit("타격"), "stun", "타격 치명타 → 기절")
	assert_eq(StatusEffects.on_crit(ItemTypes.DT_BLUNT), StatusEffects.STUN, "상수 경유도 동일(단일 출처)")

func test_on_crit_others_none() -> void:
	assert_eq(StatusEffects.on_crit("자돌"), "", "자돌은 상태이상 없음")
	assert_eq(StatusEffects.on_crit("원거리"), "", "원거리는 상태이상 없음")
	assert_eq(StatusEffects.on_crit("마법"), "", "마법은 상태이상 없음")
	assert_eq(StatusEffects.on_crit(""), "", "빈 데미지타입 → 없음")

# --- apply / 중첩 ---

func test_apply_bleed_fresh() -> void:
	var e := {}
	StatusEffects.apply(e, "bleed")
	assert_true(e.has("bleed"), "출혈 부여됨")
	assert_eq(e["bleed"]["stacks"], 1, "첫 부여 스택 1")
	assert_almost_eq(e["bleed"]["remaining"], 3.0, 0.001, "출혈 지속 3.0초")

func test_apply_bleed_stacks_and_refresh() -> void:
	var e := {}
	StatusEffects.apply(e, "bleed")
	StatusEffects.advance(e, 1.0)   # 남은지속 3.0 → 2.0
	StatusEffects.apply(e, "bleed") # 재부여: 스택 +1, 지속 리셋
	assert_eq(e["bleed"]["stacks"], 2, "재부여 시 스택 2")
	assert_almost_eq(e["bleed"]["remaining"], 3.0, 0.001, "재부여 시 지속 3.0으로 리셋")

func test_apply_bleed_stack_cap() -> void:
	var e := {}
	for i in range(4):
		StatusEffects.apply(e, "bleed")
	assert_eq(e["bleed"]["stacks"], 3, "스택 상한 3")

func test_apply_stun_refresh_no_stack() -> void:
	var e := {}
	StatusEffects.apply(e, "stun")
	assert_true(e.has("stun"), "기절 부여됨")
	assert_almost_eq(e["stun"]["remaining"], 2.0, 0.001, "기절 지속 2.0초")
	assert_false(e["stun"].has("stacks"), "기절은 스택 개념 없음")

# --- advance / 출혈 도트 ---

func test_advance_bleed_one_stack_one_second() -> void:
	var e := {}
	StatusEffects.apply(e, "bleed")
	var dmg := StatusEffects.advance(e, 1.0)
	assert_eq(dmg, 3, "3dps × 1s × 1스택 = 3")
	assert_almost_eq(e["bleed"]["remaining"], 2.0, 0.001, "1초 경과 → 남은지속 2.0")

func test_advance_small_dt_no_loss() -> void:
	# 작은 dt로 나눠 진행해도 정수 이월(acc)로 총 피해가 손실 없이 같아야 한다.
	var e1 := {}
	StatusEffects.apply(e1, "bleed")
	var split := StatusEffects.advance(e1, 0.5) + StatusEffects.advance(e1, 0.5)
	var e2 := {}
	StatusEffects.apply(e2, "bleed")
	var once := StatusEffects.advance(e2, 1.0)
	assert_eq(split, once, "0.5초 두 번 = 1초 한 번(이월로 손실 없음)")

func test_advance_two_stacks_double_damage() -> void:
	var e := {}
	StatusEffects.apply(e, "bleed")
	StatusEffects.apply(e, "bleed")   # 스택 2
	var dmg := StatusEffects.advance(e, 1.0)
	assert_eq(dmg, 6, "스택 2 → 6")

func test_advance_full_duration_total() -> void:
	var e := {}
	StatusEffects.apply(e, "bleed")
	var total := 0
	for i in range(6):
		total += StatusEffects.advance(e, 0.5)   # 6 × 0.5 = 3.0초
	assert_eq(total, 9, "3dps × 3.0s × 1스택 = 9")
	assert_false(e.has("bleed"), "지속 끝나면 제거")

func test_advance_dt_larger_than_remaining() -> void:
	var e := {}
	StatusEffects.apply(e, "bleed")
	var dmg := StatusEffects.advance(e, 10.0)   # 유효한 건 남은 3.0초뿐
	assert_eq(dmg, 9, "남은 시간(3.0s)만큼만 = 9")
	assert_false(e.has("bleed"), "만료로 제거")

func test_advance_stun_no_damage_and_expires() -> void:
	var e := {}
	StatusEffects.apply(e, "stun")
	var dmg := StatusEffects.advance(e, 1.0)
	assert_eq(dmg, 0, "기절은 도트 피해 0")
	assert_true(e.has("stun"), "1초 후 아직 유효(2초 지속)")
	StatusEffects.advance(e, 1.0)
	assert_false(e.has("stun"), "2초 경과로 제거")

# --- is_stunned ---

func test_is_stunned_true_then_false() -> void:
	var e := {}
	assert_false(StatusEffects.is_stunned(e), "효과 없으면 기절 아님")
	StatusEffects.apply(e, "stun")
	assert_true(StatusEffects.is_stunned(e), "기절 직후 true")
	StatusEffects.advance(e, 2.0)
	assert_false(StatusEffects.is_stunned(e), "2초 경과 후 false")
