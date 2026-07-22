extends GutTest
## 랑그릿사 1 전투 Resolver 검증 — 격리 구현(scenes/lang_battle).
## RNG 재현성(§2.5) + 교전 결정론(§2.2) + 전장 타겟팅 우선순위(§106, 원본 0xE5DA)를 확인한다.

const Battlefield = preload("res://scenes/lang_battle/lang_battlefield.gd")
const Presenter = preload("res://scenes/lang_battle/lang_battle.gd")

## make_unit 은 이제 전투 스탯 블록을 직접 받는다(class_id 참조 제거).
## Resolver 순수함수 검증은 튜닝 가능한 unit_types.csv 값에서 **의도적으로 격리**한다 — 여기 고정 스탯 블록을
## 주입해 밸런스 조정이 Resolver 단위 테스트를 깨지 않게 한다. 값은 과거 class_stats.csv(1/4/8/27)에서
## 옮긴 것(다양한 at/df 조합으로 RNG·조립 결정론 검증). kind 는 미포함 → make_unit 기본 ""(상성 중립).
func _stats(class_no: int) -> Dictionary:
	match class_no:
		1: return {"at": 23, "df": 21, "cmd_range": 3, "cmd_at": 2, "cmd_df": 2}
		4: return {"at": 27, "df": 24, "cmd_range": 4, "cmd_at": 2, "cmd_df": 4}
		8: return {"at": 31, "df": 28, "cmd_range": 4, "cmd_at": 6, "cmd_df": 4}
		27: return {"at": 31, "df": 17, "cmd_range": 4, "cmd_at": 9, "cmd_df": 2}
	return {}

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
	var a := LangResolver.make_unit(_stats(8), 0, 10)
	var d := LangResolver.make_unit(_stats(1), 1, 10)
	var r1 := LangResolver.resolve_engagement(LangRng.new(12345), a.duplicate(true), d.duplicate(true))
	var r2 := LangResolver.resolve_engagement(LangRng.new(12345), a.duplicate(true), d.duplicate(true))
	assert_eq(r1["final_a_soldiers"], r2["final_a_soldiers"], "최종 병력(A)이 재현되어야 한다")
	assert_eq(r1["final_d_soldiers"], r2["final_d_soldiers"], "최종 병력(D)이 재현되어야 한다")
	assert_eq(r1["rounds"].size(), r2["rounds"].size(), "라운드 시퀀스 길이가 재현되어야 한다")

func test_stat_assembly_uses_class_data() -> void:
	# classId 8: at=31, df=28, cmdAT=6, cmdDF=4 (본인 지휘 → 거리 0 보정 적용).
	var a := LangResolver.make_unit(_stats(8), 0, 10)
	var d := LangResolver.make_unit(_stats(1), 1, 10)
	var s := LangResolver.assemble_stats(a, d)
	# 기본 at 31 + 자기 지휘 at 6 = 37 (상성 vsTier0 = 0)
	assert_eq(s["base_at"], 31, "기본 AT는 클래스 데이터에서 온다")
	assert_eq(s["at"], 37, "자기 지휘 보정이 가산되어야 한다 (31+6)")

func test_final_soldiers_within_bounds() -> void:
	var a := LangResolver.make_unit(_stats(8), 0, 10)
	var d := LangResolver.make_unit(_stats(1), 1, 10)
	var r := LangResolver.resolve_engagement(LangRng.new(777), a, d)
	assert_between(r["final_a_soldiers"], 0, 10, "A 최종 병력은 0~10")
	assert_between(r["final_d_soldiers"], 0, 10, "D 최종 병력은 0~10")

func test_counter_requires_attack_count() -> void:
	# 방어자 attack_count=0 이면 반격 없음 (스펙 §2.2, 부록A 궁수 무반격).
	var a := LangResolver.make_unit(_stats(8), 0, 10)
	var d := LangResolver.make_unit(_stats(1), 1, 10)
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
	# 겹쳐 있는(거리 3 < SEP_DIST) CHARGE·MELEE 한 쌍.
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
	# 복귀는 마지막 교전(retreat_swings==0) + 공방(strike_t≤0) + 핑퐁 밀림(push_rem 잦아듦)이 모두 끝나야 시작.
	var bf = Battlefield.new()
	bf._retreating = true
	var swinging := {"state": Battlefield.MELEE, "strike_t": 0.0, "push_rem": 0.0, "retreat_swings": 2}  # 마지막 교전 남음
	var mid := {"state": Battlefield.MELEE, "strike_t": 0.15, "push_rem": 0.0, "retreat_swings": 0}
	var pushing := {"state": Battlefield.MELEE, "strike_t": 0.0, "push_rem": 5.0, "retreat_swings": 0}  # 핑퐁 밀림 진행 중
	var done := {"state": Battlefield.MELEE, "strike_t": 0.0, "push_rem": 0.0, "retreat_swings": 0}
	var charging := {"state": Battlefield.CHARGE, "strike_t": 0.0, "push_rem": 0.0, "retreat_swings": -1}
	var r_swinging := bf._retreat_ready(swinging)
	var r_mid := bf._retreat_ready(mid)
	var r_pushing := bf._retreat_ready(pushing)
	var r_done := bf._retreat_ready(done)
	var r_charge := bf._retreat_ready(charging)
	bf.free()
	assert_false(r_swinging, "마지막 교전(retreat_swings>0) 남았으면 복귀 대기")
	assert_false(r_mid, "공방 중(strike_t>0)엔 복귀 대기")
	assert_false(r_pushing, "핑퐁 밀림(push_rem) 남았으면 마저 끝낼 때까지 복귀 대기")
	assert_true(r_done, "마지막 교전·공방·밀림 모두 끝난 접전 병사는 복귀 시작")
	assert_true(r_charge, "아직 접근 중(CHARGE)이던 병사는 마무리 교전 없이 바로 복귀")

# ── all_settled: 대열 정렬 완료 + 시체 소멸 완료 (종료 여운 진입 판단) ──────────
func test_all_settled_waits_for_corpses() -> void:
	# all_returned은 시체(DYING)를 제외해 통과하지만, all_settled는 시체가 다 사라져야(전원 IDLE) 참.
	var bf = Battlefield.new()
	var idle := {"state": Battlefield.IDLE}
	var dying := {"state": Battlefield.DYING}   # 페이드 중 시체
	bf._soldiers = {0: [idle], 1: [dying]}
	var returned_with_corpse := bf.all_returned()
	var settled_with_corpse := bf.all_settled()
	bf._soldiers = {0: [idle], 1: [{"state": Battlefield.IDLE}]}   # 시체 소멸(제거) 후
	var settled_after := bf.all_settled()
	bf.free()
	assert_true(returned_with_corpse, "생존자 IDLE이면 시체(DYING) 남아도 복귀는 완료(all_returned)")
	assert_false(settled_with_corpse, "시체(DYING) 남아있으면 아직 안 잦아듦(all_settled=false)")
	assert_true(settled_after, "시체 다 소멸(전원 IDLE)이면 all_settled=true")

# ── _foe_alive: 복귀 중 "살아있는 적"만 마지막 교전 대상 (헛칼질 방지) ──────────
func test_foe_alive() -> void:
	var bf = Battlefield.new()
	var melee_foe := {"target": {"state": Battlefield.MELEE}}
	var charge_foe := {"target": {"state": Battlefield.CHARGE}}
	var dying_foe := {"target": {"state": Battlefield.DYING}}
	var duel_foe := {"target": {"state": Battlefield.DUEL}}
	var return_foe := {"target": {"state": Battlefield.RETURN}}
	var no_foe := {"target": null}
	var alive_melee := bf._foe_alive(melee_foe)
	var alive_charge := bf._foe_alive(charge_foe)
	var alive_dying := bf._foe_alive(dying_foe)
	var alive_duel := bf._foe_alive(duel_foe)
	var alive_return := bf._foe_alive(return_foe)
	var alive_none := bf._foe_alive(no_foe)
	bf.free()
	assert_true(alive_melee, "접전 중(MELEE) 적은 살아있는 교전 대상")
	assert_true(alive_charge, "접근 중(CHARGE) 적도 살아있는 교전 대상")
	assert_false(alive_dying, "죽는 중(DYING) 적은 교전 대상 아님 → 헛칼질 금지")
	assert_false(alive_duel, "듀얼(DUEL) 중 적은 교전 대상 아님")
	assert_false(alive_return, "이미 이탈(RETURN)한 적은 교전 대상 아님")
	assert_false(alive_none, "타겟 없음(null)은 교전 대상 아님")

# ── 킬 스케줄(_build_plan): CLASH 킬 + 최후 유예분 = Resolver 사망 수(결과 보존) ──────────
func test_build_plan_matches_result_deaths() -> void:
	# 생존 A5/D3 → 사망 A5/D7. CLASH 플랜엔 유예분 제외, 유예분(_deferred_sides)은 FINALE 최후 1:1로.
	var p = Presenter.new()
	p._result = {"final_a_soldiers": 5, "final_d_soldiers": 3}
	var plan: Array = p._build_plan()
	var deferred: Array = p._deferred_sides
	var kills := {0: 0, 1: 0}
	for ev in plan:
		assert_eq(ev["kind"], "kill", "스케줄은 전부 킬 이벤트")
		kills[ev["side"]] += 1
	var def0 := 1 if 0 in deferred else 0
	var def1 := 1 if 1 in deferred else 0
	p.free()
	# CLASH 킬 + 유예분 = 총 사망 (팀별·총합 모두 보존)
	assert_eq(kills[0] + def0, 5, "공격측 사망 = 10 - 생존5 (CLASH + 유예)")
	assert_eq(kills[1] + def1, 7, "방어측 사망 = 10 - 생존3 (CLASH + 유예)")
	assert_eq(plan.size() + deferred.size(), 12, "총 12 사망(= CLASH 킬 + 유예)")

# ── 최소 전투시간(_melee_duration): basis = max(min(a,b), deaths_a, deaths_b), clamp(0.22×basis, 0.5, 2.2) ──
func test_melee_duration_min_battle_time() -> void:
	var p = Presenter.new()
	# [a_start, b_start, a_final, b_final, expected_sec]
	# 0.22 × basis, clamp(0.5, 2.2)
	var cases := [
		[10, 10, 8, 8, 2.2],   # 저데미지 → min 지배, cap
		[10, 10, 5, 3, 2.2],   # 고데미지 → min 지배
		[4, 5, 1, 2, 0.88],    # 4:5 → basis 4
		[1, 10, 0, 10, 0.5],   # 1 즉패 → floor
		[1, 10, 0, 5, 1.1],    # 1이 5킬 후 사망 → basis 5
		[1, 10, 1, 0, 2.2],    # 1이 전멸 → basis 10, cap
		[1, 1, 1, 1, 0.5],     # 무사망 → floor
	]
	for c in cases:
		var got: float = p._melee_duration(c[0], c[1], c[2], c[3])
		assert_almost_eq(got, c[4], 0.001, "melee_dur(%d:%d, 생존 %d/%d)" % [c[0], c[1], c[2], c[3]])
	p.free()

# ── 킬 타이밍 스케줄(_schedule_times): 지터 있어도 개수·범위·정렬 불변 ──────────────
func test_schedule_times_bounded_and_sorted() -> void:
	var p = Presenter.new()
	var times: Array = p._schedule_times(8, 2.4)  # dur=2.4는 임의값(_schedule_times는 dur 무관, 계약만 검증)
	var empty: Array = p._schedule_times(0, 0.6)  # 킬 0개 → 빈 배열
	p.free()
	assert_eq(times.size(), 8, "킬 수만큼 재생 시각 생성")
	assert_eq(empty.size(), 0, "킬 0개면 빈 스케줄")
	var prev := -1.0
	var in_range := true
	var sorted := true
	for t in times:
		if t < 0.0 or t > 2.4:
			in_range = false
		if t < prev:
			sorted = false
		prev = t
	assert_true(in_range, "모든 시각이 [0, melee_dur] 안")
	assert_true(sorted, "시각이 오름차순 정렬(순서대로 재생)")

# ── 최후 전투 스테이징(stage_final_duel): 1:1 쌍 지정 + 개입 해제 + others_returned ──────────
# 주의: 순환참조 dict(a1.target=b1, b1.target=a1)는 assert_eq로 직접 비교 금지(stringify 무한재귀). id/bool만 검증.
func test_stage_final_duel_isolates_1v1() -> void:
	var bf = Battlefield.new()
	# 팀0 2명(a1 접전, a2 이미 복귀 IDLE), 팀1 2명(b1 접전=a1 상호락, b2 a1 개입→이미 복귀 IDLE)
	var a1 := {"id": 1, "side": 0, "state": Battlefield.MELEE, "pos": Vector2(100, 0), "target": null, "final": false}
	var a2 := {"id": 2, "side": 0, "state": Battlefield.IDLE, "pos": Vector2(0, 0), "target": null, "final": false}
	var b1 := {"id": 3, "side": 1, "state": Battlefield.MELEE, "pos": Vector2(110, 0), "target": a1, "final": false}
	var b2 := {"id": 4, "side": 1, "state": Battlefield.IDLE, "pos": Vector2(0, 0), "target": a1, "final": false}  # a1 노렸지만 복귀함
	a1["target"] = b1
	bf._soldiers = {0: [a1, a2], 1: [b1, b2]}
	var ok := bf.stage_final_duel(0)  # 팀0의 V를 최후 처형 대상으로
	var v_final: bool = a1["final"]
	var w_final: bool = b1["final"]
	var v_tgt_id: int = a1["target"]["id"]
	var w_tgt_id: int = b1["target"]["id"]
	var b2_cleared: bool = b2["target"] == null
	var a2_final: bool = a2["final"]
	var victims_n: int = bf._final_victims.size()
	var others_done := bf.others_returned()
	bf.free()
	assert_true(ok, "최후 1:1 쌍 성립")
	assert_true(v_final and w_final, "V(a1)·W(b1) 최후 쌍으로 마킹")
	assert_eq(v_tgt_id, 3, "V는 W(id3)를 타겟(1:1 락)")
	assert_eq(w_tgt_id, 1, "W는 V(id1)를 타겟(1:1 락)")
	assert_true(b2_cleared, "V/W를 노리던 다른 유닛(b2)의 타겟 해제 → 개입 없는 1:1")
	assert_false(a2_final, "관계없는 복귀 유닛은 final 아님")
	assert_eq(victims_n, 1, "최후 처형 대상 V가 _final_victims에 기록")
	assert_true(others_done, "최후 쌍 제외 나머지(a2·b2 IDLE)가 복귀 완료면 others_returned=true")

# ── 최후 전투 발동(fire_final_duel): 스테이징된 V만 긴 밀당(3~4스텝) 듀얼로 처형 ──────────
func test_fire_final_duel_dramatic_steps() -> void:
	var bf = Battlefield.new()
	var v := {"id": 1, "side": 0, "state": Battlefield.MELEE, "pos": Vector2(100, 0), "target": null, "final": false}
	var w := {"id": 2, "side": 1, "state": Battlefield.MELEE, "pos": Vector2(110, 0), "target": v, "final": false}
	v["target"] = w
	bf._soldiers = {0: [v], 1: [w]}
	bf.stage_final_duel(0)
	bf.fire_final_duel()  # V를 긴 밀당 듀얼로
	var v_state: int = v["state"]
	var steps: int = v["duel_steps"]
	var victims_left: int = bf._final_victims.size()
	bf.free()
	assert_eq(v_state, Battlefield.DUEL, "V는 DUEL 상태로 전환(즉사 아님)")
	assert_true(steps >= Battlefield.DRAMATIC_STEPS_MIN and steps <= Battlefield.DRAMATIC_STEPS_MAX,
		"단일 최후 밀당은 3~4스텝(티격태격 보장)")
	assert_eq(victims_left, 0, "발동 후 _final_victims 소진")

# ── 더블 최후 전투: 두 victim 길이 차등(V0 3~4, V1 5~7) → 시차 사망(동시 사망 어색함 제거) ──────────
func test_fire_final_duel_double_staggered() -> void:
	var bf = Battlefield.new()
	# 최후 쌍 2개 직접 세팅(V0/W0, V1/W1). 순환참조라 id/int만 검증.
	var w0 := {"id": 10, "state": Battlefield.MELEE}
	var w1 := {"id": 11, "state": Battlefield.MELEE}
	var v0 := {"id": 1, "state": Battlefield.MELEE, "target": w0}
	var v1 := {"id": 2, "state": Battlefield.MELEE, "target": w1}
	bf._final_victims = [v0, v1]
	bf.fire_final_duel()
	var steps0: int = v0["duel_steps"]
	var steps1: int = v1["duel_steps"]
	bf.free()
	assert_true(steps0 >= Battlefield.DRAMATIC_STEPS_MIN and steps0 <= Battlefield.DRAMATIC_STEPS_MAX,
		"첫 victim(V0)은 짧게 3~4스텝 → 먼저 쓰러짐")
	assert_true(steps1 >= Battlefield.DRAMATIC_STEPS2_MIN and steps1 <= Battlefield.DRAMATIC_STEPS2_MAX,
		"둘째 victim(V1)은 길게 5~7스텝 → 더 버티다 쓰러짐(시차 사망)")
	assert_true(steps1 > steps0, "V1이 V0보다 오래 버팀(항상 시차)")

# ── 펜싱 밀림(_auto_strike): 공방 시 찌르는 쪽·맞는 쪽에 같은 밀림 예약(즉시이동 아님, 거리 유지) ──
func test_auto_strike_queues_fence_push() -> void:
	var bf = Battlefield.new()
	var b := {"id": 2, "side": 1, "pos": Vector2(110, 0), "face": -1.0, "state": Battlefield.MELEE, "target": null, "push_rem": 0.0, "strike_t": 0.0}
	var a := {"id": 1, "side": 0, "pos": Vector2(100, 0), "face": 1.0, "state": Battlefield.MELEE, "target": b, "push_rem": 0.0, "strike_t": 0.0}
	bf._auto_strike(a)  # a가 오른쪽(face +1) 타겟 b를 침
	bf.free()
	assert_almost_eq(a["push_rem"], Battlefield.FENCE_PUSH, 0.001, "찌르는 쪽 전진 밀림 예약")
	assert_almost_eq(b["push_rem"], Battlefield.FENCE_PUSH, 0.001, "맞는 쪽 뒤로 밀림 예약(같은 벡터→거리 유지)")
	assert_eq(a["pos"], Vector2(100, 0), "즉시 이동 아님 — 애니메이션은 _process가 push_rem 소진")

# ── 듀얼 밀당(_push_kind_for): 60% 무이동 / 30% 패자 / 10% 승자 (임계 0.6/0.9) ──────────
# 반환: 0=PUSH_NONE, 1=PUSH_LOSER, 2=PUSH_WINNER
func test_push_kind_thresholds() -> void:
	var bf = Battlefield.new()
	var r_none_lo := bf._push_kind_for(0.0)
	var r_none_hi := bf._push_kind_for(0.59)
	var r_loser_lo := bf._push_kind_for(0.6)
	var r_loser_hi := bf._push_kind_for(0.89)
	var r_winner_lo := bf._push_kind_for(0.9)
	var r_winner_hi := bf._push_kind_for(0.99)
	bf.free()
	assert_eq(r_none_lo, 0, "r=0.0 → 무이동")
	assert_eq(r_none_hi, 0, "r=0.59 → 무이동")
	assert_eq(r_loser_lo, 1, "r=0.6 → 패자 밀림")
	assert_eq(r_loser_hi, 1, "r=0.89 → 패자 밀림")
	assert_eq(r_winner_lo, 2, "r=0.9 → 승자 밀림")
	assert_eq(r_winner_hi, 2, "r=0.99 → 승자 밀림")

func test_duel_count_in_range() -> void:
	var bf = Battlefield.new()
	var ok := true
	for i in range(50):
		var n: int = bf._duel_count()
		if n < 1 or n > 3:
			ok = false
	bf.free()
	assert_true(ok, "공방 횟수는 [1,3] 범위")

func test_duels_active_flag() -> void:
	# 복귀는 duels_active()가 false여야 시작 → "복귀 중 사망" 방지.
	var bf = Battlefield.new()
	var s := {"id": 1, "side": 0, "state": Battlefield.MELEE}
	bf._soldiers = {0: [s], 1: []}
	var before := bf.duels_active()
	s["state"] = Battlefield.DUEL
	var during := bf.duels_active()
	bf.free()
	assert_false(before, "DUEL 병사 없으면 false")
	assert_true(during, "DUEL 병사 있으면 true")

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

# ── 사격 (resolve_ranged, 원거리 전투 — 슬라이스 1) ─────────────────────────────
# 계산/연출 분리: Resolver가 "어느 화살이 죽이는지" 먼저 결정. shots 로그 + 최종 병력.

func _archer(side: int) -> Dictionary:
	# 경궁병 ≈ 과거 classId 27 (고AT·저DF), 개활지 회피 5.
	return LangResolver.make_unit(_stats(27), side, 10, 0, 0, 0, 3, 5)

func _infantry(side: int) -> Dictionary:
	# 경보병 ≈ 과거 classId 1, 개활지 회피 5.
	return LangResolver.make_unit(_stats(1), side, 10, 0, 0, 0, 3, 5)

## shots 중 (side, round) 조건 개수. round<0 이면 라운드 무시.
func _count_shots(shots: Array, side: int, round: int = -1) -> int:
	var n := 0
	for sh in shots:
		if int(sh["side"]) == side and (round < 0 or int(sh["round"]) == round):
			n += 1
	return n

## shots 중 (side) 의 kill==true 개수. round<0 이면 라운드 무시.
func _count_kills(shots: Array, side: int, round: int = -1) -> int:
	var n := 0
	for sh in shots:
		if int(sh["side"]) == side and bool(sh["kill"]) and (round < 0 or int(sh["round"]) == round):
			n += 1
	return n

func test_ranged_is_deterministic() -> void:
	# 같은 시드·입력 → shots·최종 병력 동일 (스킵 무관, §0).
	var r1 := LangResolver.resolve_ranged(LangRng.new(4242), _archer(0), _archer(1), 2, 2)
	var r2 := LangResolver.resolve_ranged(LangRng.new(4242), _archer(0), _archer(1), 2, 2)
	assert_eq(r1["final_a_soldiers"], r2["final_a_soldiers"], "최종 병력(A) 재현")
	assert_eq(r1["final_d_soldiers"], r2["final_d_soldiers"], "최종 병력(D) 재현")
	assert_eq(r1["shots"], r2["shots"], "shots 로그가 재현되어야 한다")

func test_ranged_defender_zero_rounds() -> void:
	# 시나리오 1: 방어측 0라운드 → 방어측(경보병) 사격 없음, 공격측 불변, 방어측만 사망.
	var r := LangResolver.resolve_ranged(LangRng.new(999), _archer(0), _infantry(1), 2, 0)
	assert_eq(_count_shots(r["shots"], 1), 0, "방어측(side1) 화살이 없어야 한다")
	assert_eq(r["final_a_soldiers"], 10, "공격측은 반격 없어 병력 불변")
	assert_between(r["final_d_soldiers"], 0, 10, "방어측 병력은 0~10")

func test_ranged_shooter_count_equals_survivors() -> void:
	# 슈터 수 = 라운드 시작 생존자. 라운드0 = 시작(10), 라운드1 = 라운드0 후 생존자.
	var r := LangResolver.resolve_ranged(LangRng.new(2024), _archer(0), _archer(1), 2, 2)
	var shots: Array = r["shots"]
	assert_eq(_count_shots(shots, 0, 0), 10, "라운드0 공격측 슈터 = 시작 생존자 10")
	assert_eq(_count_shots(shots, 1, 0), 10, "라운드0 방어측 슈터 = 시작 생존자 10")
	# 라운드1 슈터 수 = 10 − (상대가 라운드0에 낸 킬)
	var d_deaths_r0 := _count_kills(shots, 0, 0)  # side0가 라운드0에 죽인 적(=방어측 사망)
	var a_deaths_r0 := _count_kills(shots, 1, 0)  # side1가 라운드0에 죽인 적(=공격측 사망)
	assert_eq(_count_shots(shots, 1, 1), 10 - d_deaths_r0, "라운드1 방어측 슈터 = 라운드0 생존자")
	assert_eq(_count_shots(shots, 0, 1), 10 - a_deaths_r0, "라운드1 공격측 슈터 = 라운드0 생존자")

func test_ranged_kill_cap_and_invariant() -> void:
	# 킬 cap: 최종 병력 ≥ 0. 불변식: side별 kill 합 = 상대 사망 수(시작−최종).
	for seed in [1, 42, 777, 31337]:
		var r := LangResolver.resolve_ranged(LangRng.new(seed), _archer(0), _archer(1), 2, 2)
		var shots: Array = r["shots"]
		assert_between(r["final_a_soldiers"], 0, 10, "A 최종 0~10 (seed %d)" % seed)
		assert_between(r["final_d_soldiers"], 0, 10, "D 최종 0~10 (seed %d)" % seed)
		assert_eq(_count_kills(shots, 0), 10 - int(r["final_d_soldiers"]),
			"side0 킬 합 = 방어측 사망 (seed %d)" % seed)
		assert_eq(_count_kills(shots, 1), 10 - int(r["final_a_soldiers"]),
			"side1 킬 합 = 공격측 사망 (seed %d)" % seed)

func test_ranged_stats_match_engagement() -> void:
	# 같은 유닛 입력 시 stats(base_at/df·hit)가 근접 resolve_engagement 과 동일 경로.
	var re := LangResolver.resolve_engagement(LangRng.new(5), _archer(0).duplicate(true), _archer(1).duplicate(true))
	var rr := LangResolver.resolve_ranged(LangRng.new(5), _archer(0).duplicate(true), _archer(1).duplicate(true), 2, 2)
	assert_eq(rr["stats_a"]["base_at"], re["stats_a"]["base_at"], "base_at 동일")
	assert_eq(rr["stats_a"]["base_df"], re["stats_a"]["base_df"], "base_df 동일")
	assert_eq(rr["stats_a"]["hit"], re["stats_a"]["hit"], "명중률 동일")

func test_shot_round_pools_only_shooting_sides() -> void:
	# begin_shot_round(사격하는 side들): 사격 안 하는 side(시나리오1 경보병)는 슈터 풀에서 제외
	# → 그 병사는 착탄 시 유예 없이 즉시 사망(_die). 사격하는 side만 풀에 포함.
	var bf = Battlefield.new()
	var a0 := {"id": 1, "side": 0, "state": Battlefield.IDLE}
	var b0 := {"id": 2, "side": 1, "state": Battlefield.IDLE}
	bf._soldiers = {0: [a0], 1: [b0]}
	bf.begin_shot_round([0])   # side0만 사격
	var a_pool: int = bf._round_shooters[0].size()
	var b_pool: int = bf._round_shooters[1].size()
	bf.free()
	assert_eq(a_pool, 1, "사격하는 side0는 슈터 풀에 포함")
	assert_eq(b_pool, 0, "사격 안 하는 side1는 슈터 풀에서 제외(착탄 즉시 사망)")

# ── 병종 상성 (기/보/창/궁 가위바위보) ───────────────────────────────────────
func _assembled_with_kind(self_kind: String, opp_kind: String) -> Dictionary:
	var u := LangResolver.make_unit(_stats(1), 0, 10); u["kind"] = self_kind
	var o := LangResolver.make_unit(_stats(1), 1, 10); o["kind"] = opp_kind
	return LangResolver.assemble_stats(u, o)

func test_type_counter_infantry_beats_archer() -> void:
	# 보병 > 궁병: 보병은 +4/+2, 궁병은 보정 없음(모든 병종에 약함).
	var base := _assembled_with_kind("", "")  # 상성 없음(기준)
	var inf := _assembled_with_kind("infantry", "archer")
	var arc := _assembled_with_kind("archer", "infantry")
	assert_eq(inf["at"], base["at"] + 4, "보병은 궁병 상대로 공격 +4")
	assert_eq(inf["df"], base["df"] + 2, "보병은 궁병 상대로 방어 +2")
	assert_eq(arc["at"], base["at"], "궁병은 상성 우위 없음(공격 보정 0)")
	assert_eq(arc["df"], base["df"], "궁병은 상성 우위 없음(방어 보정 0)")

func test_type_counter_cycle() -> void:
	# 기병>보병>창병>기병 사이클: 이기는 쪽만 +4/+2.
	var base := _assembled_with_kind("", "")
	assert_eq(_assembled_with_kind("cavalry", "infantry")["at"], base["at"] + 4, "기병>보병")
	assert_eq(_assembled_with_kind("infantry", "spear")["at"], base["at"] + 4, "보병>창병")
	assert_eq(_assembled_with_kind("spear", "cavalry")["at"], base["at"] + 4, "창병>기병")
	# 역방향은 보정 없음
	assert_eq(_assembled_with_kind("infantry", "cavalry")["at"], base["at"], "보병<기병(보정 없음)")

func test_type_counter_archer_beats_none() -> void:
	# 궁병은 어떤 병종도 상성으로 못 이김(원거리 이점 대가).
	var base := _assembled_with_kind("", "")
	for foe in ["cavalry", "infantry", "spear", "archer"]:
		assert_eq(_assembled_with_kind("archer", foe)["at"], base["at"], "궁병은 %s에 상성 우위 없음" % foe)

# ── 예측 요격 (_predict_intercept, 시나리오 2 화살) ────────────────────────────
func test_predict_intercept_leads_toward_meeting_point() -> void:
	# 궁수 x80, 좌로 216px/s로 오는 적 x370, 화살 230px/s → 서로 접근 → 중간(~230)에서 요격.
	var bf = Battlefield.new()
	var aim: Vector2 = bf._predict_intercept(Vector2(80, 0), Vector2(370, 0), Vector2(-216, 0), 230.0)
	bf.free()
	assert_true(aim.x > 80.0 and aim.x < 370.0, "요격 지점은 궁수와 적 사이")
	assert_almost_eq(aim.x, 230.0, 25.0, "화살·적이 만나는 중간 부근(바로 앞 아님)")

func test_predict_intercept_static_target_is_current_pos() -> void:
	# 정적 타겟(속도 0)은 현재 위치 겨냥.
	var bf = Battlefield.new()
	var aim: Vector2 = bf._predict_intercept(Vector2(80, 0), Vector2(370, 0), Vector2.ZERO, 230.0)
	bf.free()
	assert_eq(aim.x, 370.0, "정적 타겟은 현재 위치")

func test_make_unit_provides_kind_default_empty() -> void:
	var u := LangResolver.make_unit(_stats(1), 0, 10)
	assert_eq(String(u.get("kind", "?")), "", "make_unit은 kind 기본 빈 문자열(상성 없음)")

# ── 빗나간 화살 박힘 (_update_arrows·_stuck_rotation·_stuck_region_rect) ────────
## 착탄 직전(t≥flight) 상태의 비행 화살 하나 — 스프라이트는 실제 _arrows_node에 붙인다.
func _make_landing_arrow(is_kill: bool, vel: Vector2, node: Node2D) -> Dictionary:
	var spr := Sprite2D.new()
	spr.texture = Battlefield.TEX_ARROW
	node.add_child(spr)
	return {
		"spr": spr, "pos": Vector2(200, 100), "vel": vel, "g": 0.0,
		"t": 1.0, "flight": 0.0, "to": Vector2(200, 100),
		"target": {"state": Battlefield.MELEE}, "is_kill": is_kill,
	}

func test_missed_arrow_sticks_and_accumulates() -> void:
	# 빗나간 화살(is_kill=false)은 착탄해도 소멸하지 않고 _stuck_arrows에 누적.
	var bf = Battlefield.new()
	add_child_autofree(bf)   # _ready → _arrows_node 준비
	bf._arrows = [
		_make_landing_arrow(false, Vector2(120, 60), bf._arrows_node),
		_make_landing_arrow(false, Vector2(120, 60), bf._arrows_node),
	]
	var spr0 = bf._arrows[0]["spr"]
	bf._update_arrows(0.016)
	assert_eq(bf._stuck_arrows.size(), 2, "빗나간 화살 2발이 박혀 누적")
	assert_true(is_instance_valid(spr0), "박힌 화살 스프라이트는 소멸하지 않는다")

func test_hit_arrow_does_not_stick() -> void:
	# 명중 화살(is_kill=true)은 박히지 않는다(기존대로 소멸).
	var bf = Battlefield.new()
	add_child_autofree(bf)
	var ar := _make_landing_arrow(true, Vector2(120, 60), bf._arrows_node)
	ar["target"] = {"state": Battlefield.DYING}   # 이미 죽는 중 → _die 스킵(플래시만)
	bf._arrows = [ar]
	bf._update_arrows(0.016)
	assert_eq(bf._stuck_arrows.size(), 0, "명중 화살은 박히지 않음")

func test_clear_arrows_removes_stuck() -> void:
	var bf = Battlefield.new()
	add_child_autofree(bf)
	bf._arrows = [_make_landing_arrow(false, Vector2(120, 60), bf._arrows_node)]
	bf._update_arrows(0.016)
	assert_eq(bf._stuck_arrows.size(), 1, "선행: 1발 박힘")
	bf._clear_arrows()
	assert_eq(bf._stuck_arrows.size(), 0, "_clear_arrows가 박힌 화살도 비운다")

func test_kill_arrow_on_hero_decrements_hp() -> void:
	# 영웅 vs 궁병 스커미시 볼리: 살상 화살이 영웅에 착탄해도 즉사가 아니라 HP만 −1(마지막 발에서 사망).
	var bf = Battlefield.new()
	add_child_autofree(bf)
	var hero := {"id": 0, "side": 1, "hero": true, "hp": 5, "state": Battlefield.MELEE,
		"pos": Vector2(200, 100), "hit_t": 0.0}
	var ar := _make_landing_arrow(true, Vector2(120, 60), bf._arrows_node)
	ar["target"] = hero
	bf._arrows = [ar]
	bf._update_arrows(0.016)
	assert_eq(int(hero["hp"]), 4, "영웅 살상 화살 착탄 → HP −1")
	assert_ne(int(hero["state"]), Battlefield.DYING, "HP 남으면 사망하지 않고 계속 교전")

func test_kill_arrow_kills_hero_on_last_hp() -> void:
	# HP 1인 영웅에 살상 화살 → 실제 사망(DYING).
	var bf = Battlefield.new()
	add_child_autofree(bf)
	var hero := {"id": 0, "side": 1, "hero": true, "hp": 1, "state": Battlefield.MELEE,
		"pos": Vector2(200, 100), "hit_t": 0.0, "face": -1.0, "attack_t": 0.0, "push_rem": 0.0}
	var ar := _make_landing_arrow(true, Vector2(120, 60), bf._arrows_node)
	ar["target"] = hero
	bf._arrows = [ar]
	bf._update_arrows(0.016)
	assert_eq(int(hero["hp"]), 0, "마지막 HP → 0")
	assert_eq(int(hero["state"]), Battlefield.DYING, "HP 0 → 실제 사망")

func test_stuck_rotation_points_downward() -> void:
	var bf = Battlefield.new()
	var r: float = bf._stuck_rotation(Vector2(100, 40))
	bf.free()
	assert_true(sin(r) > 0.0, "화살촉이 아래를 향한다(회전 y성분>0)")
	assert_true(absf(r - PI / 2.0) > 0.01, "정확한 수직이 아니라 소폭 틀어짐")

func test_stuck_rotation_tilts_by_travel_direction() -> void:
	var bf = Battlefield.new()
	var r_right: float = bf._stuck_rotation(Vector2(100, 40))
	var r_left: float = bf._stuck_rotation(Vector2(-100, 40))
	bf.free()
	assert_true(r_right < PI / 2.0, "우진(vel.x>0) 화살은 회전 < PI/2")
	assert_true(r_left > PI / 2.0, "좌진(vel.x<0) 화살은 회전 > PI/2")

func test_stuck_region_rect_crops_arrowhead() -> void:
	var bf = Battlefield.new()
	var rect: Rect2 = bf._stuck_region_rect()
	bf.free()
	assert_eq(rect.position.x, 0.0, "오늬(꽁지) 쪽 x=0에서 시작")
	assert_true(rect.size.x < float(Battlefield.ARROW_PX), "너비<전체 → 화살촉 쪽 크롭")
	assert_true(rect.size.x > 0.0, "노출 영역은 양수")

func test_stuck_arrow_joins_units_ysort() -> void:
	# 박힌 화살은 _units(y-sort)로 옮겨져 착탄 지점 y로 병사와 앞뒤 정렬된다.
	var bf = Battlefield.new()
	add_child_autofree(bf)
	var ar := _make_landing_arrow(false, Vector2(120, 0), bf._arrows_node)  # vel.y=0 → 착탄 전 적분해도 y 불변
	ar["pos"] = Vector2(200, 137)
	bf._arrows = [ar]
	var spr = ar["spr"]
	bf._update_arrows(0.016)
	assert_eq(spr.get_parent(), bf._units, "박힌 화살은 _units(y-sort) 자식")
	# 정렬 기준(origin)은 지면보다 GROUND_SORT_DY 위 — 병사 원점(발밑−8px) 규약과 일치.
	assert_eq(spr.position.y, 137.0 - Battlefield.GROUND_SORT_DY, "정렬 기준 y = 착탄 지면 − GROUND_SORT_DY")

func test_miss_scatter_bounds() -> void:
	# x는 좌우(±), y는 아래(+)로만 — 여러 번 뽑아 범위·부호 검증.
	var bf = Battlefield.new()
	for i in 30:
		var o: Vector2 = bf._miss_scatter()
		assert_between(o.x, -Battlefield.ARROW_MISS_SCATTER_X, Battlefield.ARROW_MISS_SCATTER_X, "x는 ± 범위 내")
		assert_between(o.y, 0.0, Battlefield.ARROW_MISS_SCATTER_Y, "y는 0~+ 범위(아래로만, 음수 없음)")
	bf.free()

# ── AT/DF 표시 보간 (_atdf_tick_t) ───────────────────────────────────────────
func test_atdf_tick_ramps_for_pure_melee() -> void:
	# 순수 근접(시나리오 0): base→조립값 틱업(_timer/STEP).
	var p = Presenter.new()
	p._fast_melee = false
	p._timer = 0.0
	assert_eq(p._atdf_tick_t(), 0.0, "돌격 시작(t=0)은 base 표시")
	p._timer = Presenter.STEP
	assert_eq(p._atdf_tick_t(), 1.0, "STEP 경과면 조립값(t=1)")
	p.free()

func test_atdf_tick_instant_for_scenario2_melee() -> void:
	# 시나리오 2 근접(_fast_melee): 사격 때 조립값을 이미 보였으므로 즉시 t=1(떨어짐 없음).
	var p = Presenter.new()
	p._fast_melee = true
	p._timer = 0.0
	assert_eq(p._atdf_tick_t(), 1.0, "_timer=0이어도 조립값 유지")
	p._timer = Presenter.STEP * 0.5
	assert_eq(p._atdf_tick_t(), 1.0, "중간 시점에도 base로 떨어지지 않음")
	p.free()

# ── 영웅 전투 (시나리오 5): 자기 지휘보정 토글 + 1인 유닛 HP ─────────────────────
func test_self_cmd_false_disables_self_bonus() -> void:
	# classId 4: base 27/24, cmdAT/cmdDF=2/4. 자기 지휘보정 O면 29/28, self_cmd=false면 27/24 유지.
	var d := LangResolver.make_unit(_stats(1), 1, 10)
	var with_cmd := LangResolver.make_unit(_stats(4), 0, 10)
	var s_with := LangResolver.assemble_stats(with_cmd, d)
	assert_eq(s_with["at"], 29, "자기 지휘보정 O: 27+2=29")
	assert_eq(s_with["df"], 28, "자기 지휘보정 O: 24+4=28")
	var lone := LangResolver.make_unit(_stats(4), 0, 10)
	lone["self_cmd"] = false
	var s_lone := LangResolver.assemble_stats(lone, d)
	assert_eq(s_lone["base_at"], 27, "base는 클래스 데이터 그대로")
	assert_eq(s_lone["at"], 27, "self_cmd=false: 자기 지휘보정 없이 27 유지")
	assert_eq(s_lone["df"], 24, "self_cmd=false: 24 유지")

func test_hero_engagement_bounds_and_takes_damage() -> void:
	# 영웅(class4, self_cmd=false, kind"") vs 경보병 10 — HP 0~10, 여러 시드 중 영웅이 피해 입는 판이 존재.
	var took_damage := false
	for seed in range(50):
		var hero := LangResolver.make_unit(_stats(4), 0, 10, 0, 0, 0, 3, 0)
		hero["kind"] = ""
		hero["self_cmd"] = false
		var inf := LangResolver.make_unit(_stats(1), 1, 10, 0, 0, 0, 3, 5)
		inf["kind"] = "infantry"
		var r := LangResolver.resolve_engagement(LangRng.new(seed * 7919 + 3), hero, inf)
		assert_between(r["final_a_soldiers"], 0, 10, "영웅 HP는 0~10")
		assert_between(r["final_d_soldiers"], 0, 10, "보병 잔여는 0~10")
		if r["final_a_soldiers"] < 10:
			took_damage = true
	assert_true(took_damage, "영웅은 27/24(자기보정 없음)면 보병 물량에 피해를 입는다(HP<10 발생)")

func test_setup_hero_spawns_single_unit() -> void:
	var bf = Battlefield.new()
	bf.setup_hero(10, 10)
	assert_eq(bf._soldiers[0].size(), 1, "영웅 side는 1스프라이트")
	assert_eq(bf._soldiers[1].size(), 10, "보병 side는 10스프라이트")
	assert_true(bf._soldiers[0][0]["hero"], "영웅 플래그")
	assert_eq(int(bf._soldiers[0][0]["hp"]), 10, "영웅 HP=10")
	bf.free()

func test_hero_kill_decrements_hp_until_last_hit() -> void:
	# 영웅은 kill(0)마다 죽지 않고 HP만 −1, 마지막(hp 1→0)에서 실제 사망(듀얼/DYING) 진입.
	var bf = Battlefield.new()
	var hero := {"id": 0, "side": 0, "hero": true, "hp": 10, "state": Battlefield.MELEE,
		"pos": Vector2(100, 96), "face": 1.0, "push_rem": 0.0, "hit_t": 0.0}
	var foe := {"id": 1, "side": 1, "state": Battlefield.MELEE, "pos": Vector2(110, 96)}
	hero["target"] = foe
	bf._soldiers = {0: [hero], 1: [foe]}
	for i in 9:
		bf.kill(0)
	assert_eq(int(hero["hp"]), 1, "9번 피격 → HP 1 남음")
	assert_eq(int(hero["state"]), Battlefield.MELEE, "HP 남으면 죽지 않고 계속 교전")
	bf.kill(0)
	assert_eq(int(hero["hp"]), 0, "10번째 피격 → HP 0")
	assert_true(hero["state"] == Battlefield.DUEL or hero["state"] == Battlefield.DYING,
		"HP 0에서 실제 사망(듀얼→사망) 진입")
	bf.free()

func test_hero_holds_ground_no_push() -> void:
	# 영웅은 보병에게 밀리지 않는다 — 접전 펜싱 밀림·듀얼 밀당에서 push_rem 누적 안 함(보병만 밀림).
	var bf = Battlefield.new()
	var infantry := {"id": 1, "side": 1, "state": Battlefield.MELEE, "pos": Vector2(110, 96),
		"face": -1.0, "push_rem": 0.0}
	var hero := {"id": 0, "side": 0, "hero": true, "hp": 10, "state": Battlefield.MELEE,
		"pos": Vector2(100, 96), "face": 1.0, "push_rem": 0.0, "hit_t": 0.0, "attack_t": 0.0}
	# 보병이 영웅을 침 → 영웅은 밀림 예약 안 됨, 보병(공격측)만 전진 밀림.
	infantry["target"] = hero
	bf._auto_strike(infantry)
	assert_eq(hero["push_rem"], 0.0, "영웅은 피격돼도 뒤로 밀리지 않는다")
	assert_ne(infantry["push_rem"], 0.0, "보병(공격측)은 전진 밀림 예약")
	# 듀얼 밀당에서도 영웅(패자든 승자든)은 밀리지 않음.
	hero["push_rem"] = 0.0
	infantry["push_rem"] = 0.0
	bf._apply_duel_push(hero, infantry, Battlefield.PUSH_LOSER)
	assert_eq(hero["push_rem"], 0.0, "영웅은 듀얼 밀당에서도 제자리 사수")
	bf.free()

func test_reduce_to_keeps_hero_sprite() -> void:
	# force_result가 영웅 side를 HP로 트림하지 않는다(스프라이트 1개 유지). 보병 side만 트림.
	var bf = Battlefield.new()
	var hero := {"id": 0, "side": 0, "hero": true, "hp": 4, "state": Battlefield.MELEE}
	bf._soldiers = {0: [hero], 1: []}
	for i in 10:
		bf._soldiers[1].append({"id": 10 + i, "side": 1, "state": Battlefield.MELEE})
	bf._reduce_to(0, 4)   # 영웅 HP 4 — 스프라이트 수와 무관, 트림 스킵
	bf._reduce_to(1, 6)   # 보병 10→6
	assert_eq(bf._soldiers[0].size(), 1, "영웅 스프라이트는 HP와 무관하게 1개 유지")
	assert_eq(bf._soldiers[1].size(), 6, "보병 side는 정상 트림")
	bf.free()

# ── 커스텀 전투 설정(설정 화면 → lang_battle) ────────────────────────────────────
func test_config_holder_set_and_take_once() -> void:
	# LangBattleConfig: set 후 take 1회 소비 → 두 번째 take는 빈 dict(기본 시나리오 진입).
	LangBattleConfig.set_config(
		{"kind": "hero", "count": 8},
		{"kind": "archer", "count": 6},
		"ranged")
	var c := LangBattleConfig.take()
	assert_eq(String(c["a"]["kind"]), "hero", "side A 병종 전달")
	assert_eq(int(c["b"]["count"]), 6, "side B 숫자 전달")
	assert_eq(String(c["mode"]), "ranged", "공용 교전 방식 전달")
	assert_true(LangBattleConfig.take().is_empty(), "두 번째 take는 소비되어 빈 dict")

func test_config_holder_mode_defaults_melee() -> void:
	LangBattleConfig.set_config({"kind": "infantry", "count": 5}, {"kind": "infantry", "count": 5})
	var c := LangBattleConfig.take()
	assert_eq(String(c["mode"]), "melee", "mode 미지정 시 근접 기본값")

func test_mk_custom_unit_maps_kinds() -> void:
	var p = Presenter.new()
	var hero := p._mk_custom_unit({"kind": "hero", "count": 7}, 0)
	assert_eq(int(hero["at"]), UnitTypes.base_at("hero"), "영웅=지휘관 클래스 스탯(at27)")
	assert_false(hero["self_cmd"], "단독 영웅은 자기 지휘보정 없음")
	assert_eq(String(hero["kind"]), "hero", "영웅 kind(상성 중립 — TypeAdvantage에 hero 행 없음)")
	assert_eq(int(hero["max_soldiers"]), 7, "영웅 count=HP/몫")
	var arc := p._mk_custom_unit({"kind": "archer", "count": 4}, 1)
	assert_eq(String(arc["kind"]), "archer", "경궁병 kind")
	assert_eq(int(arc["max_soldiers"]), 4, "경궁병 인원")
	var inf := p._mk_custom_unit({"kind": "infantry", "count": 10}, 0)
	assert_eq(String(inf["kind"]), "infantry", "경보병 kind")
	p.free()

func test_kind_label() -> void:
	var p = Presenter.new()
	assert_eq(p._kind_label("hero"), "영웅")
	assert_eq(p._kind_label("archer"), "경궁병")
	assert_eq(p._kind_label("infantry"), "경보병")
	p.free()

func test_setup_custom_spawns_per_side() -> void:
	# 영웅 1스프라이트(HP=count) + 경궁병 count명(kind=archer). 근접 스폰.
	var bf = Battlefield.new()
	bf.setup_custom({"kind": "hero", "count": 5}, {"kind": "archer", "count": 8})
	assert_eq(bf._soldiers[0].size(), 1, "영웅 side는 1스프라이트")
	assert_true(bf._soldiers[0][0]["hero"], "영웅 플래그")
	assert_eq(int(bf._soldiers[0][0]["hp"]), 5, "영웅 HP=count")
	assert_eq(bf._soldiers[1].size(), 8, "경궁병 side는 count명")
	assert_eq(String(bf._soldiers[1][0]["kind"]), "archer", "경궁병 kind 지정")
	bf.free()

func test_setup_custom_infantry_default_kind() -> void:
	var bf = Battlefield.new()
	bf.setup_custom({"kind": "infantry", "count": 3}, {"kind": "infantry", "count": 9})
	assert_eq(bf._soldiers[0].size(), 3, "side A 인원")
	assert_eq(bf._soldiers[1].size(), 9, "side B 인원")
	assert_eq(String(bf._soldiers[0][0]["kind"]), "infantry", "경보병 기본 kind")
	bf.free()

func test_setup_ranged_hero_target_stands_passive() -> void:
	# 궁병 vs 영웅 원거리: 영웅은 진형에 1스프라이트(HP)로 제자리(IDLE) 대기, 궁병 n명.
	var bf = Battlefield.new()
	bf.setup_ranged("archer", "hero", 10, 8)
	assert_eq(bf._soldiers[0].size(), 10, "궁병 10 진형 배치")
	assert_eq(bf._soldiers[1].size(), 1, "영웅 표적은 1스프라이트")
	assert_true(bf._soldiers[1][0]["hero"], "영웅 플래그")
	assert_eq(int(bf._soldiers[1][0]["hp"]), 8, "영웅 HP=count")
	assert_eq(int(bf._soldiers[1][0]["state"]), Battlefield.IDLE, "제자리 대기(돌격 없음)")
	bf.free()

func test_setup_skirmish_hero_charger() -> void:
	# 영웅 vs 궁병 스커미시: 돌격측(영웅)은 1스프라이트(HP), 슈터측은 궁병 n명.
	var bf = Battlefield.new()
	bf.setup_skirmish(0, 1, 10, 8, "hero")  # side0 궁병 10, side1 영웅(HP8) 돌격
	assert_eq(bf._soldiers[0].size(), 10, "궁병(슈터) 10 스폰")
	assert_eq(String(bf._soldiers[0][0]["kind"]), "archer", "슈터는 궁병")
	assert_eq(bf._soldiers[1].size(), 1, "영웅 돌격측은 1스프라이트")
	assert_true(bf._soldiers[1][0]["hero"], "영웅 플래그")
	assert_eq(int(bf._soldiers[1][0]["hp"]), 8, "영웅 HP=돌격 count")
	bf.free()
