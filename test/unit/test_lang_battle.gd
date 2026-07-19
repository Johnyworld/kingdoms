extends GutTest
## 랑그릿사 1 전투 Resolver 검증 — 격리 구현(scenes/lang_battle).
## RNG 재현성(§2.5) + 교전 결정론(§2.2) + 전장 타겟팅 우선순위(§106, 원본 0xE5DA)를 확인한다.

const Battlefield = preload("res://scenes/lang_battle/lang_battlefield.gd")
const Presenter = preload("res://scenes/lang_battle/lang_battle.gd")

func test_rng_reference_sequence() -> void:
	# 스펙 §2.5 검증 수열: 상태 0에서 next()%100.
	var rng := LangRng.new(0)
	var expected := [43, 43, 79, 79, 51, 99, 99, 3, 27, 63, 3, 51]
	var got: Array = []
	for i in expected.size():
		got.append(rng.next_mod(100))
	assert_eq(got, expected, "RNG 검증 수열이 원본과 일치해야 한다")

func test_engagement_is_deterministic() -> void:
	# 같은 시드 → 같은 결과 (연출 스킵과 무관하게 동일, §0).
	var a := LangResolver.make_unit(8, 0, 10)
	var d := LangResolver.make_unit(1, 1, 10)
	var r1 := LangResolver.resolve_engagement(LangRng.new(12345), a.duplicate(true), d.duplicate(true))
	var r2 := LangResolver.resolve_engagement(LangRng.new(12345), a.duplicate(true), d.duplicate(true))
	assert_eq(r1["final_a_soldiers"], r2["final_a_soldiers"], "최종 병력(A)이 재현되어야 한다")
	assert_eq(r1["final_d_soldiers"], r2["final_d_soldiers"], "최종 병력(D)이 재현되어야 한다")
	assert_eq(r1["rounds"].size(), r2["rounds"].size(), "라운드 시퀀스 길이가 재현되어야 한다")

func test_stat_assembly_uses_class_data() -> void:
	# classId 8: at=31, df=28, cmdAT=6, cmdDF=4 (본인 지휘 → 거리 0 보정 적용).
	var a := LangResolver.make_unit(8, 0, 10)
	var d := LangResolver.make_unit(1, 1, 10)
	var s := LangResolver.assemble_stats(a, d)
	# 기본 at 31 + 자기 지휘 at 6 = 37 (상성 vsTier0 = 0)
	assert_eq(s["base_at"], 31, "기본 AT는 클래스 데이터에서 온다")
	assert_eq(s["at"], 37, "자기 지휘 보정이 가산되어야 한다 (31+6)")

func test_final_soldiers_within_bounds() -> void:
	var a := LangResolver.make_unit(8, 0, 10)
	var d := LangResolver.make_unit(1, 1, 10)
	var r := LangResolver.resolve_engagement(LangRng.new(777), a, d)
	assert_between(r["final_a_soldiers"], 0, 10, "A 최종 병력은 0~10")
	assert_between(r["final_d_soldiers"], 0, 10, "D 최종 병력은 0~10")

func test_counter_requires_attack_count() -> void:
	# 방어자 attack_count=0 이면 반격 없음 (스펙 §2.2, 부록A 궁수 무반격).
	var a := LangResolver.make_unit(8, 0, 10)
	var d := LangResolver.make_unit(1, 1, 10)
	d["attack_count"] = 0
	var r := LangResolver.resolve_engagement(LangRng.new(1), a, d)
	for ev in r["rounds"]:
		assert_eq(ev["attacker_side"], 0, "반격이 없어야 하므로 모든 히트는 공격자(side 0)")

# ── 전장 타겟팅 우선순위 (§106, 원본 0xE5DA 재현) ─────────────────────────────
# _retarget_all 은 RNG 없는 결정론적 판단: 상대 적의 타겟 상태로 P3>P2>P1, 동순위 맨해튼 최근접.

func _soldier(id: int, side: int, pos: Vector2, target = null) -> Dictionary:
	return {"id": id, "side": side, "pos": pos, "state": Battlefield.MELEE, "target": target}

## a0(side 0) 하나를 두고 side1 적들 중 무엇을 고르는지 한 번 돌려 타겟 id를 돌려준다.
func _picked_target_id(a0: Dictionary, foes: Array) -> int:
	var bf = Battlefield.new()
	bf._soldiers = {0: [a0], 1: foes}
	bf._retarget_all()
	var t: Variant = a0["target"]
	bf.free()
	return -1 if t == null else int(t["id"])

func test_target_priority_mutual_lock_beats_nearer_unengaged() -> void:
	# P3(그 적이 나를 노림)는 더 가까운 P2(미교전)보다 우선.
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var f_near := _soldier(2, 1, Vector2(10, 0), null)   # P2, 거리 10
	var f_lock := _soldier(3, 1, Vector2(100, 0), a0)    # P3(a0을 노림), 거리 100
	assert_eq(_picked_target_id(a0, [f_near, f_lock]), 3, "나를 노리는 적(P3)이 더 가까운 미교전 적(P2)보다 우선")

func test_target_priority_unengaged_beats_nearer_engaged() -> void:
	# P2(미교전)는 더 가까운 P1(딴 놈과 교전 중)보다 우선.
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var f_engaged := _soldier(2, 1, Vector2(10, 0), {"id": 99})  # P1(딴 놈 노림), 거리 10
	var f_free := _soldier(3, 1, Vector2(50, 0), null)          # P2, 거리 50
	assert_eq(_picked_target_id(a0, [f_engaged, f_free]), 3, "미교전 적(P2)이 더 가까운 교전 중 적(P1)보다 우선")

func test_target_tiebreak_nearest_manhattan() -> void:
	# 동순위(둘 다 P2)면 맨해튼 최근접.
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var f_far := _soldier(2, 1, Vector2(30, 0), null)    # P2, 거리 30
	var f_close := _soldier(3, 1, Vector2(10, 0), null)  # P2, 거리 10
	assert_eq(_picked_target_id(a0, [f_far, f_close]), 3, "동순위면 맨해튼 최근접이 선택된다")

func test_target_skips_dying_foe() -> void:
	# 죽는 중(DYING)인 적은 후보에서 제외.
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var f_dying := _soldier(2, 1, Vector2(5, 0), null)
	f_dying["state"] = Battlefield.DYING                 # 더 가깝지만 제외돼야
	var f_alive := _soldier(3, 1, Vector2(40, 0), null)
	assert_eq(_picked_target_id(a0, [f_dying, f_alive]), 3, "DYING 적은 건너뛰고 살아있는 적을 고른다")

func test_target_all_engaged_falls_back_to_nearest() -> void:
	# 모든 적이 딴 아군과 교전 중(P1)이면 그래도 최근접을 고른다(best==null 폴백, pri=1).
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var f_far := _soldier(2, 1, Vector2(40, 0), {"id": 90})   # P1, 거리 40
	var f_near := _soldier(3, 1, Vector2(10, 0), {"id": 91})  # P1, 거리 10
	assert_eq(_picked_target_id(a0, [f_far, f_near]), 3, "전원 교전 중(P1)이어도 최근접을 고른다")

func test_target_mutual_lock_disperses_second_ally() -> void:
	# 다중 병사 분산: Fx가 A0을 노리면 A0은 Fx를 되받고(P3),
	# A1은 Fx가 물렸으니(P1) 더 먼 미교전 적(P2)을 택한다 → 1:1 분산이 창발.
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var a1 := _soldier(2, 0, Vector2(0, 0))
	var fx := _soldier(3, 1, Vector2(5, 0), a0)        # A0을 노림(P3 대상), 거리 5
	var f_free := _soldier(4, 1, Vector2(6, 0), null)  # 미교전(P2), 거리 6
	var bf = Battlefield.new()
	bf._soldiers = {0: [a0, a1], 1: [fx, f_free]}
	bf._retarget_all()
	var a0_t := int(a0["target"]["id"])
	var a1_t := int(a1["target"]["id"])
	bf.free()
	assert_eq(a0_t, 3, "A0은 자신을 노리는 Fx를 되받는다(P3)")
	assert_eq(a1_t, 4, "A1은 물린 Fx(P1)를 피해 더 먼 미교전 적(P2)을 택한다")

func test_target_priority_uses_previous_frame_snapshot() -> void:
	# 스냅샷/일괄 커밋 검증: 우선순위는 '직전 프레임' target으로 매긴다(같은 패스의 즉시 반영 아님).
	# 이번 프레임 A0→F, A1→G로 갈리지만, F의 선택은 "A0·A1이 직전엔 둘 다 미교전(P2)"이라는
	# 스냅샷 기준이라 최근접 A1을 고른다. in-place 커밋이면 A0가 방금 F를 물어 P3가 되어 먼 A0를 골라 어긋난다.
	var a0 := _soldier(1, 0, Vector2(0, 0))
	var a1 := _soldier(2, 0, Vector2(12, 0))
	var f := _soldier(3, 1, Vector2(10, 0), null)  # A1(거리2)이 A0(거리10)보다 F에 가까움
	var g := _soldier(4, 1, Vector2(12, 1), null)  # A1 바로 옆(거리1) → A1은 G를 문다
	var bf = Battlefield.new()
	bf._soldiers = {0: [a0, a1], 1: [f, g]}
	bf._retarget_all()
	var a0_t := int(a0["target"]["id"])
	var a1_t := int(a1["target"]["id"])
	var f_t := int(f["target"]["id"])
	bf.free()
	assert_eq(a0_t, 3, "A0의 최근접은 F")
	assert_eq(a1_t, 4, "A1의 최근접은 G")
	assert_eq(f_t, 2, "F는 직전 스냅샷(전원 미교전) 기준 최근접 A1을 고른다 — in-place면 P3인 A0로 어긋남")

# ── 분리(_separate): 접전 중 병사는 밀리지 않고 제자리 교전, CHARGE만 겹침 분리 ──────────
func test_separate_skips_melee_but_moves_charging() -> void:
	var bf = Battlefield.new()
	# 겹쳐 있는(거리 3 < SEP_DIST 11) CHARGE·MELEE 한 쌍.
	var charging := {"id": 1, "side": 0, "pos": Vector2(0, 0), "state": Battlefield.CHARGE, "seed": 0.0}
	var melee := {"id": 2, "side": 1, "pos": Vector2(3, 0), "state": Battlefield.MELEE, "seed": 0.0}
	bf._soldiers = {0: [charging], 1: [melee]}
	var charge_before: Vector2 = charging["pos"]
	var melee_before: Vector2 = melee["pos"]
	bf._separate(0.016)
	var charge_after: Vector2 = charging["pos"]
	var melee_after: Vector2 = melee["pos"]
	bf.free()
	assert_ne(charge_after, charge_before, "CHARGE 병사는 겹치면 밀려난다")
	assert_eq(melee_after, melee_before, "MELEE 병사는 분리로 밀리지 않는다(제자리 교전)")

# ── 순차 복귀(begin_retreat/all_returned): 홈에서 먼 병사부터 하나씩 peel off ──────────
func test_retreat_ready_waits_for_strike() -> void:
	# 전투 종료 후, 진행 중이던 공방(strike_t>0)이면 아직 복귀 대기, 끝나면 복귀 시작 가능.
	var bf = Battlefield.new()
	bf._retreating = true
	var mid := {"state": Battlefield.MELEE, "strike_t": 0.15}
	var done := {"state": Battlefield.MELEE, "strike_t": 0.0}
	var charging := {"state": Battlefield.CHARGE, "strike_t": 0.0}
	var r_mid := bf._retreat_ready(mid)
	var r_done := bf._retreat_ready(done)
	var r_charge := bf._retreat_ready(charging)
	bf.free()
	assert_false(r_mid, "공방 중(strike_t>0)엔 복귀 대기")
	assert_true(r_done, "공방 끝난 접전 병사는 복귀 시작")
	assert_true(r_charge, "아직 접근 중(CHARGE)이던 병사도 복귀")

# ── 킬 스케줄(_build_plan): 킬 총합이 Resolver 사망 수와 정확히 일치(결과 보존) ──────────
func test_build_plan_matches_result_deaths() -> void:
	# 생존 A5/D3 → 사망 A5/D7. 킬 이벤트만, 총 12개.
	var p = Presenter.new()
	p._result = {"final_a_soldiers": 5, "final_d_soldiers": 3}
	var plan: Array = p._build_plan()
	var kills := {0: 0, 1: 0}
	for ev in plan:
		assert_eq(ev["kind"], "kill", "스케줄은 전부 킬 이벤트")
		kills[ev["side"]] += 1
	p.free()
	assert_eq(kills[0], 5, "공격측 사망 = 10 - 생존5")
	assert_eq(kills[1], 7, "방어측 사망 = 10 - 생존3")
	assert_eq(plan.size(), 12, "총 12 킬 이벤트")

func test_all_returned_only_when_all_idle() -> void:
	var bf = Battlefield.new()
	var idle := {"id": 1, "side": 0, "pos": Vector2.ZERO, "home": Vector2.ZERO, "state": Battlefield.IDLE}
	var returning := {"id": 2, "side": 1, "pos": Vector2(50, 0), "home": Vector2.ZERO, "state": Battlefield.RETURN}
	bf._soldiers = {0: [idle], 1: [returning]}
	var mixed := bf.all_returned()
	returning["state"] = Battlefield.IDLE
	var all_idle := bf.all_returned()
	bf.free()
	assert_false(mixed, "아직 이동 중(RETURN)인 병사가 있으면 미완료")
	assert_true(all_idle, "생존자 전원 IDLE이면 복귀 완료")
