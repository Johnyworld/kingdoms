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
