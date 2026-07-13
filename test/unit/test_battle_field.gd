extends GutTest
## 전투씬 공간 판정(BattleField) 테스트 — 순수 함수. 유닛은 {team, alive, pos, human} Dictionary.

func _unit(team: String, alive: bool, pos: Vector2, human = null) -> Dictionary:
	return {"team": team, "alive": alive, "pos": pos, "human": human}

func test_nearest_enemy_picks_closest() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var far := _unit("b", true, Vector2(100, 0), "far")
	var near := _unit("b", true, Vector2(10, 0), "near")
	assert_eq(BattleField.nearest_enemy(u, [u, far, near])["human"], "near", "가장 가까운 적을 고른다")

func test_nearest_enemy_ignores_ally_and_dead() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var ally := _unit("a", true, Vector2(5, 0), "ally")       # 같은 팀 — 무시
	var dead := _unit("b", false, Vector2(6, 0), "dead")      # 죽음 — 무시
	var enemy := _unit("b", true, Vector2(50, 0), "enemy")
	assert_eq(BattleField.nearest_enemy(u, [u, ally, dead, enemy])["human"], "enemy", "같은 팀·죽은 유닛 무시")

func test_nearest_enemy_none_returns_empty() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var ally := _unit("a", true, Vector2(5, 0))
	assert_eq(BattleField.nearest_enemy(u, [u, ally]), {}, "적이 없으면 빈 Dictionary")

func test_team_wiped() -> void:
	var units := [_unit("a", false, Vector2.ZERO), _unit("b", true, Vector2.ONE)]
	assert_true(BattleField.team_wiped(units, "a"), "a 전원 사망 → 전멸")
	assert_false(BattleField.team_wiped(units, "b"), "b는 생존자 있음")

func test_survivors_returns_living_humans() -> void:
	var units := [
		_unit("a", true, Vector2.ZERO, "x"),
		_unit("a", false, Vector2.ONE, "y"),
		_unit("b", true, Vector2(2, 2), "z"),
	]
	assert_eq(BattleField.survivors(units, "a"), ["x"], "a의 살아있는 human만")

func test_archer_should_charge() -> void:
	# 사거리 ≥ 2 유닛이 최근접 적과의 거리가 임계 이하이면 근접 전환.
	assert_true(BattleField.archer_should_charge(3, 100.0, 120.0), "사거리3·거리100 ≤ 임계120 → 전환")
	assert_false(BattleField.archer_should_charge(3, 150.0, 120.0), "거리150 > 임계120 → 유지")
	assert_true(BattleField.archer_should_charge(2, 120.0, 120.0), "경계값(거리==임계) 포함 → 전환")

func test_archer_should_charge_melee_never() -> void:
	# 사거리 < 2(이미 근접)면 거리와 무관하게 false.
	assert_false(BattleField.archer_should_charge(1, 10.0, 120.0), "근접 유닛은 전환 판정 대상 아님")

# --- 다중 표적·공성 전투원 제외 → docs/spec/features/siege-engines.md ---

func _siege(team: String, pos: Vector2, human = null) -> Dictionary:
	var u := _unit(team, true, pos, human)
	u["siege"] = true   # 공성 전투원 — nearest_enemy는 제외, bombard_targets는 우선 표적
	return u

func test_bombard_targets_orders_closest_first() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var e1 := _unit("b", true, Vector2(30, 0), "e1")
	var e2 := _unit("b", true, Vector2(10, 0), "e2")
	var e3 := _unit("b", true, Vector2(20, 0), "e3")
	var got := BattleField.bombard_targets(u, [u, e1, e2, e3], 2)
	assert_eq(got.size(), 2, "최대 2명")
	assert_eq(got[0]["human"], "e2", "가장 가까운 e2 먼저")
	assert_eq(got[1]["human"], "e3", "다음 e3")

func test_bombard_targets_prioritizes_enemy_siege() -> void:
	# 적 투석기가 일반 적보다 멀어도 먼저 뽑힌다(대포병 우선).
	var u := _unit("a", true, Vector2(0, 0))
	var near_human := _unit("b", true, Vector2(10, 0), "human")
	var far_siege := _siege("b", Vector2(90, 0), "siege")
	var got := BattleField.bombard_targets(u, [u, near_human, far_siege], 5)
	assert_eq(got.size(), 2, "둘 다 표적")
	assert_eq(got[0]["human"], "siege", "뒤에 있어도 적 투석기 먼저")
	assert_eq(got[1]["human"], "human", "그다음 일반 유닛")

func test_bombard_targets_fewer_than_n() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var e1 := _unit("b", true, Vector2(10, 0), "e1")
	assert_eq(BattleField.bombard_targets(u, [u, e1], 5).size(), 1, "적이 n보다 적으면 있는 만큼")

func test_bombard_targets_none_empty() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	assert_eq(BattleField.bombard_targets(u, [u], 5), [], "적 없으면 빈 배열")

func test_bombard_targets_ignores_ally_dead() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var ally := _unit("a", true, Vector2(5, 0), "ally")
	var dead := _unit("b", false, Vector2(6, 0), "dead")
	var enemy := _unit("b", true, Vector2(50, 0), "enemy")
	var got := BattleField.bombard_targets(u, [u, ally, dead, enemy], 5)
	assert_eq(got.size(), 1, "같은 팀·죽은 유닛 제외")
	assert_eq(got[0]["human"], "enemy", "살아있는 적만")

func test_nearest_enemy_ignores_siege() -> void:
	var u := _unit("a", true, Vector2(0, 0))
	var siege := _siege("b", Vector2(5, 0), "siege")
	var enemy := _unit("b", true, Vector2(50, 0), "enemy")
	assert_eq(BattleField.nearest_enemy(u, [u, siege, enemy])["human"], "enemy", "공성 전투원은 표적 제외")
