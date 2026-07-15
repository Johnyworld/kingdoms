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
