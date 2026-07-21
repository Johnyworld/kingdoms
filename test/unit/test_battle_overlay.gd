extends GutTest
## 전투 오버레이(battle.gd) 스모크 — 개별 병사(멤버당 토큰) 렌더 경로가 크래시 없이 돌고 종료하는지.
## 판정 로직은 test_combat_resolver·test_battle_sim·test_battle_field가 검증. 여기선 오버레이 구동만 확인.

## 멤버(사람) 렌더 토큰을 가진 유닛 수 — 팀당 1개 묶음이 아니라 멤버마다 1개인지 검증용.
func _member_token_count() -> int:
	var count := 0
	for u in battle._units:
		if u.has("human") and u.has("node"):
			count += 1
	return count

const BattleScript = preload("res://scenes/combat/battle.gd")
const PartyScript = preload("res://scenes/party/party.gd")
const HumanScript = preload("res://scenes/human/human.gd")

var battle

func before_each() -> void:
	battle = BattleScript.new()
	add_child_autofree(battle)

func after_each() -> void:
	if is_instance_valid(battle):
		battle._running = false

func _party(pname: String, n: int, strength: int, weapon: String, color: Color) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.party_name = pname
	p.token_color = color
	p.kind = p.KIND_TROOP
	for i in n:
		var h = HumanScript.new("%s-%d" % [pname, i])
		h.strength = strength
		h.agility = 80
		h.weapons = [weapon]
		h.hit_points = h.max_hp()
		p.add_member(h)
	p.commander = p.members[0]
	return p

## _process를 수동 펌프해 종료까지 돌린다(최대 max_frames·delta초). 종료(_running=false)면 조기 반환.
func _run(delta := 0.1, max_frames := 300) -> void:
	for i in max_frames:
		if not battle._running:
			return
		battle._process(delta)

func test_member_battle_finishes_without_crash() -> void:
	var atk := _party("공격", 3, 90, "battleaxe", Color.RED)
	var deff := _party("방어", 3, 10, "sword", Color.BLUE)
	# 승패 단언(아래 "우세")이 RNG에 흔들리지 않게 격차를 압도적으로: 민첩 0 → 회피 없음(피격 ~91%)·최저 공속.
	# (기본 민첩 80이면 명중 ~51%라 드물게 약팀이 우세해 플레이키했다 — 시드는 battle.start가 randomize해 고정 불가.)
	for m in deff.members:
		m.agility = 0
	battle.start(atk, deff, 1)   # 근접 교전
	assert_eq(_member_token_count(), 6, "멤버 6명(3+3) 각각 렌더 토큰")
	_run()
	assert_false(battle._running, "전멸/시간만료로 종료")
	var a_surv: Array = BattleField.survivors(battle._units, "a")
	var b_surv: Array = BattleField.survivors(battle._units, "b")
	assert_true(a_surv.size() <= 3 and b_surv.size() <= 3, "생존자 수는 초기 인원 이하")
	# 강한 공격 팀이 약한 방어 팀보다 생존자가 많다(근접 10초).
	assert_true(a_surv.size() >= b_surv.size(), "강한 공격 팀 우세")

func test_token_per_member_counts() -> void:
	var atk := _party("공격", 5, 60, "sword", Color.RED)
	var deff := _party("방어", 4, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	assert_eq(_member_token_count(), 9, "멤버 9명(5+4) 각각 렌더 토큰(팀 묶음 1개 아님)")

func test_dead_member_shows_zero_hp() -> void:
	# 죽은 멤버 토큰은 hp 0을 표시해야 한다(치명타 직전 값이 남으면 안 됨).
	var atk := _party("공격", 3, 90, "battleaxe", Color.RED)
	var deff := _party("방어", 3, 5, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	_run()
	var checked := 0
	for u in battle._units:
		if u.has("human") and u.has("hp_label") and not u["alive"]:
			assert_eq(u["hp_label"].text, "0", "죽은 멤버는 hp 0 표시")
			checked += 1
	assert_gt(checked, 0, "사망자가 있어야 검증에 의미가 있다")

func test_ranged_battle_runs() -> void:
	var atk := _party("궁수", 3, 60, "bow", Color.RED)
	var deff := _party("궁수2", 3, 60, "bow", Color.BLUE)
	battle.start(atk, deff, 3)   # 원거리 교전(사거리 3 활)
	_run(0.1, 200)
	assert_false(battle._running, "원거리 전투도 종료")

func test_melee_spawns_offscreen_and_charges() -> void:
	# 근접 공격자는 화면 밖(팀 a는 x<0)에서 스폰해 라인 정지 없이 돌격. 이동속도 ±20% 보정.
	var atk := _party("공격", 3, 60, "sword", Color.RED)
	var deff := _party("방어", 3, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)   # 근접 교전
	assert_true(battle._running, "근접 교전은 지연 없이 즉시 시뮬 시작")
	for u in battle._units:
		if u.has("human"):
			assert_between(u["speed"], battle.UNIT_SPEED * 0.8, battle.UNIT_SPEED * 1.2, "이동속도 ±20% 보정")
		if u.has("human") and u["team"] == "a":
			assert_lt(u["pos"].x, 0.0, "근접 공격자(팀 a)는 화면 왼쪽 밖에서 스폰")
	_run()
	assert_false(battle._running, "전멸/시간만료로 종료")

func test_archer_enters_offscreen_then_forms_up() -> void:
	# 궁수(원거리)는 화면 밖에서 진입해 대열 슬롯으로 이동한 뒤 자리잡고(정지) 사격한다.
	var atk := _party("궁수", 3, 60, "bow", Color.RED)
	var deff := _party("궁수2", 3, 60, "bow", Color.BLUE)
	battle.start(atk, deff, 3)   # 원거리 교전
	# 진입 시작 = 화면 밖(팀 a는 왼쪽 밖), 아직 대열 미형성
	for u in battle._units:
		if u.has("human") and u["team"] == "a":
			assert_lt(u["pos"].x, 0.0, "궁수도 화면 밖에서 진입")
			assert_false(u["formed"], "진입 직후엔 아직 대열 미형성")
			assert_ne(u["formation"], null, "궁수는 대열 슬롯을 가진다")
	# 여러 프레임 펌프 → 슬롯 도착(formed)
	for i in 40:
		if not battle._running:
			break
		battle._process(0.1)
	var checked := 0
	for u in battle._units:
		if u.has("human") and u["alive"] and u["formed"]:
			assert_almost_eq(u["pos"].x, u["formation"].x, 0.01, "자리잡은 궁수는 슬롯 x에 스냅")
			var p: Vector2 = u["pos"]
			for j in 5:
				if not battle._running:
					break
				battle._process(0.1)
			if u["alive"]:
				assert_eq(u["pos"], p, "자리잡은 궁수는 제자리 사격(이동 없음)")
			checked += 1
			break
	assert_gt(checked, 0, "자리잡은 궁수가 있어야 검증에 의미")

## --- 랑그릿사1식 연출: 액자 · HUD · 템포 (battle.md) ---

func test_tokens_spawn_within_arena() -> void:
	# 모든 멤버 토큰은 상단 전장(arena) 높이 안에 스폰된다(하단 HUD 영역 침범 금지).
	var atk := _party("공격", 4, 60, "sword", Color.RED)
	var deff := _party("방어", 4, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	assert_gt(battle._arena_h, 0.0, "arena 높이가 설정된다")
	for u in battle._units:
		if u.has("human"):
			assert_lte(u["pos"].y, battle._arena_h, "멤버 토큰은 arena 높이 안에 있다")

func test_hud_count_initial() -> void:
	var atk := _party("공격", 3, 60, "sword", Color.RED)
	var deff := _party("방어", 5, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	assert_eq(battle._hud_count("a"), 3, "좌 패널 병력 수 = 초기 멤버 수")
	assert_eq(battle._hud_count("b"), 5, "우 패널 병력 수 = 초기 멤버 수")

func test_hud_count_decreases_on_death() -> void:
	# 압도적인 공격 팀 → 방어 팀 병력 수가 줄어든다.
	var atk := _party("공격", 3, 90, "battleaxe", Color.RED)
	var deff := _party("방어", 3, 5, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	_run()
	assert_lt(battle._hud_count("b"), 3, "사망으로 방어 팀 병력 수 감소")

func test_playback_melee_vs_ranged() -> void:
	var atk := _party("공격", 2, 60, "sword", Color.RED)
	var deff := _party("방어", 2, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)   # 근접
	assert_eq(battle._playback, battle.MELEE_PLAYBACK, "근접은 2배속 재생")

	var b2 = BattleScript.new()
	add_child_autofree(b2)
	var atk2 := _party("궁수", 2, 60, "bow", Color.RED)
	var deff2 := _party("궁수2", 2, 60, "bow", Color.BLUE)
	b2.start(atk2, deff2, 3)      # 원거리
	assert_eq(b2._playback, 1.0, "원거리는 1배속(기존 5초 방식)")
	b2._running = false

func test_playback_advances_elapsed_double() -> void:
	# 근접 _process 1회가 _elapsed를 delta × MELEE_PLAYBACK만큼 진행한다(즉시 전멸 안 하게 회피 세팅).
	var atk := _party("공격", 5, 60, "sword", Color.RED)
	var deff := _party("방어", 5, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	battle._process(0.1)
	assert_almost_eq(battle._elapsed, 0.1 * battle.MELEE_PLAYBACK, 0.001, "근접 sim은 delta×2로 진행")

func test_panel_at_df_matches_commander() -> void:
	var atk := _party("공격", 3, 60, "sword", Color.RED)
	var deff := _party("방어", 3, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	assert_eq(battle._panel_at("a"), CombatResolver.attack_power(atk.commander), "좌 패널 AT = 지휘관 실효 AT")
	assert_eq(battle._panel_df("a"), CombatResolver.defense(atk.commander), "좌 패널 DF = 지휘관 실효 DF")
	assert_eq(battle._panel_at("b"), CombatResolver.attack_power(deff.commander), "우 패널 AT = 지휘관 실효 AT")

func test_modifier_labels_no_buff() -> void:
	var atk := _party("공격", 2, 60, "sword", Color.RED)
	var deff := _party("방어", 2, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	assert_eq(battle._modifier_labels(), ["기본능력"], "버프 없으면 기본능력만")

func test_modifier_labels_with_command_buff() -> void:
	var atk := _party("공격", 2, 60, "sword", Color.RED)
	var deff := _party("방어", 2, 60, "sword", Color.BLUE)
	atk.commander.in_command = true   # 지휘 버프 상태
	battle.start(atk, deff, 1)
	assert_eq(battle._modifier_labels(), ["기본능력", "지휘보정"], "한쪽이라도 지휘 버프면 지휘보정 추가")

func test_duel_partners_assigned() -> void:
	# 각 멤버는 상대 팀 유닛을 duel 짝으로 배정받는다.
	var atk := _party("공격", 3, 60, "sword", Color.RED)
	var deff := _party("방어", 3, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	for u in battle._units:
		if u.has("human"):
			assert_true(u.has("duel"), "멤버는 duel 짝을 가진다")
			assert_ne(u["duel"]["team"], u["team"], "짝은 상대 팀 유닛")

func test_separation_pushes_overlapping_units_apart() -> void:
	# 발 겹침 분리 — 같은 팀 두 유닛을 가로로 바짝 붙여두고 _process 1프레임 → 서로 밀려 가로 간격이 벌어진다.
	var atk := _party("공격", 3, 3, "sword", Color.RED)   # 약하게(str 3) — 한 프레임에 안 죽게
	var deff := _party("방어", 3, 3, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	var a_units: Array = []
	for u in battle._units:
		if u["team"] == "a" and u["alive"] and u.has("human"):
			a_units.append(u)
	assert_gt(a_units.size(), 1, "팀 a 멤버 2명 이상")
	a_units[0]["pos"] = Vector2(400, 300)
	a_units[1]["pos"] = Vector2(406, 300)   # 가로 6px 겹침(반경 60 안)
	var before: float = absf(a_units[0]["pos"].x - a_units[1]["pos"].x)
	# 실제 프레임 delta(≈1/60)로 여러 프레임 펌프 — 분리가 이동을 이길 만큼 실효적인지 검증(큰 delta로 약함을 가리지 않게).
	for i in 8:
		battle._process(1.0 / 60.0)
	var after: float = absf(a_units[0]["pos"].x - a_units[1]["pos"].x)
	assert_gt(after, before + 30.0, "겹친 두 유닛이 가로로 크게 밀려 간격이 벌어진다(반경 60 쪽으로)")

func test_archer_engage_melee_floors_reach() -> void:
	# 순수 궁수가 근접 전환하면 melee_engaged·range 1, melee_reach가 근접 수준으로 바닥 보정(활 32px보다 큼).
	var atk := _party("궁수", 1, 60, "bow", Color.RED)
	var deff := _party("보병", 1, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	var archer: Dictionary = {}
	for u in battle._units:
		if u["team"] == "a":
			archer = u
	battle._engage_melee(archer)
	assert_true(archer.get("melee_engaged", false), "근접 전환 플래그 설정")
	assert_eq(archer["range"], 1, "근접 거동(range 1)")
	assert_gte(archer["melee_reach"], 1.2 * battle.MELEE_REACH_PX, "근접 리치로 바닥 보정(활 32px보다 큼)")

func test_archer_melee_hit_pushes_victim() -> void:
	# 근접 전환한 궁수의 명중은 근접대근접처럼 피격자를 HIT_PUSH만큼 밀어낸다(투사체 아님).
	var atk := _party("궁수", 1, 60, "bow", Color.RED)
	var deff := _party("보병", 1, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	var archer: Dictionary = {}
	var foot: Dictionary = {}
	for u in battle._units:
		if u["team"] == "a":
			archer = u
		elif u["team"] == "b":
			foot = u
	battle._engage_melee(archer)
	archer["pos"] = Vector2(300, 300)
	var pushed := false
	for s in range(1, 40):
		foot["pos"] = Vector2(320, 300)   # 공격자 오른쪽에 붙음
		foot["voff"] = Vector2.ZERO
		foot["hp"] = 999                  # 안 죽게(밀림만 관찰)
		battle._rng.seed = s
		battle._attack(archer, foot, archer["weapon"])
		if foot["pos"].x > 320.5:         # 공격자 반대쪽(+x)으로 밀림
			pushed = true
			break
	assert_true(pushed, "근접 전환 궁수 명중 → 피격자 밀림(근접 연출)")

func test_engaged_thrower_javelin_stays_projectile() -> void:
	# melee_engaged 유닛이라도 투척(javelin)은 근접 밀림이 아니라 투사체로 처리(연출 일관성).
	var atk := _party("궁수", 1, 60, "bow", Color.RED)
	var deff := _party("보병", 1, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	var archer: Dictionary = {}
	var foot: Dictionary = {}
	for u in battle._units:
		if u["team"] == "a":
			archer = u
		elif u["team"] == "b":
			foot = u
	battle._engage_melee(archer)   # melee_engaged = true
	archer["pos"] = Vector2(300, 300)
	var pushed := false
	for s in range(1, 40):
		foot["pos"] = Vector2(320, 300)
		foot["voff"] = Vector2.ZERO
		foot["hp"] = 999
		battle._rng.seed = s
		battle._attack(archer, foot, "javelin")   # 투척 무기로 공격
		if foot["pos"].x > 320.5:
			pushed = true
			break
	assert_false(pushed, "melee_engaged라도 투척은 밀림 없음(투사체)")

func test_spawn_scattered_not_single_column() -> void:
	# 같은 팀 근접 유닛들의 y가 서로 달라야 한다(한 줄로 겹치지 않음 — 분산 난투).
	var atk := _party("공격", 5, 60, "sword", Color.RED)
	var deff := _party("방어", 5, 60, "sword", Color.BLUE)
	battle.start(atk, deff, 1)
	var ys: Array = []
	for u in battle._units:
		if u.has("human") and u["team"] == "a":
			ys.append(u["pos"].y)
	var unique := {}
	for y in ys:
		unique[y] = true
	assert_gt(unique.size(), 1, "팀 a 유닛 y가 여러 값(산포)")

func test_single_member_hero_one_token() -> void:
	var hero: Node2D = PartyScript.new()
	add_child_autofree(hero)
	hero.party_name = "아젤 부대"
	hero.kind = hero.KIND_HERO
	var h = HumanScript.new("아젤")
	h.weapons = ["longsword"]
	h.hit_points = h.max_hp()
	hero.add_member(h)
	hero.commander = h
	var deff := _party("적", 2, 30, "sword", Color.BLUE)
	battle.start(hero, deff, 1)
	assert_eq(_member_token_count(), 3, "영웅 1명 + 적 2명 = 멤버 토큰 3개")
