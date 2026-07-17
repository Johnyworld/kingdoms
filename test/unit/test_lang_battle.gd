extends GutTest
## 랑그릿사 1 전투 Resolver 검증 — 격리 구현(scenes/lang_battle).
## RNG 재현성(§2.5) + 교전 결정론(§2.2)을 확인한다.

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
