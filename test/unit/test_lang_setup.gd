extends GutTest
## 전투 설정 화면(scenes/lang_setup) 상호작용 검증.
## 핵심 규칙: 교전 방식은 양 진영 공용(가운데 1개). 원거리는 두 진영 중 하나라도 경궁병이면 활성,
## 경궁병이 하나도 없으면 비활성 + 근접으로 복귀.

const Setup = preload("res://scenes/lang_setup/lang_setup.gd")

## 정적 상태(마지막 설정)는 테스트 간 누수되므로 각 테스트 전에 초기화.
func before_each() -> void:
	LangBattleConfig._last = {}
	LangBattleConfig._pending = {}

## _ready 에서 UI를 짓는 인스턴스를 트리에 올려 준비.
func _make_setup() -> Node:
	var s = Setup.new()
	add_child_autofree(s)   # _ready → _restore_last + _build_ui + _refresh
	return s

func test_defaults() -> void:
	var s = _make_setup()
	for side in [0, 1]:
		assert_eq(String(s._sel[side]["kind"]), "infantry", "초기 병종 경보병 (side %d)" % side)
		assert_eq(int(s._sel[side]["count"]), 10, "초기 숫자 10 (side %d)" % side)
	assert_eq(String(s._mode), "melee", "초기 교전 근접(공용)")

func test_single_mode_control_not_per_side() -> void:
	# 교전 버튼은 가운데 1세트(공용) — 진영별 딕셔너리가 아니라 key→Button.
	var s = _make_setup()
	assert_true(s._mode_btns.has("melee") and s._mode_btns.has("ranged"), "공용 근접/원거리 버튼 1세트")

func test_ranged_disabled_when_no_archer() -> void:
	var s = _make_setup()
	assert_true(s._mode_btns["ranged"].disabled, "경보병만 → 원거리 비활성")

func test_archer_on_either_side_enables_ranged() -> void:
	# 한 진영만 경궁병이어도 원거리 활성.
	var s = _make_setup()
	s._on_kind(0, "archer")
	assert_false(s._mode_btns["ranged"].disabled, "side0 경궁병 → 원거리 활성")
	s._on_kind(0, "infantry")
	assert_true(s._mode_btns["ranged"].disabled, "다시 경보병 → 비활성")
	s._on_kind(1, "archer")
	assert_false(s._mode_btns["ranged"].disabled, "side1만 경궁병이어도 원거리 활성")

func test_ranged_reverts_when_last_archer_removed() -> void:
	var s = _make_setup()
	s._on_kind(0, "archer")
	s._on_mode("ranged")
	assert_eq(String(s._mode), "ranged", "경궁병 있을 때 원거리 선택됨")
	# 두 진영 모두 경궁병 아님 → 비활성 + 근접 복귀
	s._on_kind(0, "hero")
	assert_true(s._mode_btns["ranged"].disabled, "경궁병 사라짐 → 원거리 비활성")
	assert_eq(String(s._mode), "melee", "경궁병 사라짐 → 근접으로 복귀")

func test_ranged_stays_while_one_archer_remains() -> void:
	# 양쪽 경궁병 → 원거리, 한쪽만 다른 병종으로 바꿔도(다른 한쪽 경궁병 유지) 원거리 유지.
	var s = _make_setup()
	s._on_kind(0, "archer")
	s._on_kind(1, "archer")
	s._on_mode("ranged")
	s._on_kind(0, "infantry")
	assert_false(s._mode_btns["ranged"].disabled, "한쪽 경궁병 남아 있으면 원거리 유지")
	assert_eq(String(s._mode), "ranged", "원거리 선택 유지")

func test_ranged_ignored_when_no_archer() -> void:
	# 경궁병 없을 때 원거리 선택 시도는 무시(방어 로직).
	var s = _make_setup()
	s._on_mode("ranged")
	assert_eq(String(s._mode), "melee", "경궁병 없으면 원거리 선택 무시")

func test_count_selection() -> void:
	var s = _make_setup()
	s._on_count(1, 3)
	assert_eq(int(s._sel[1]["count"]), 3, "숫자 선택 반영")

func test_restores_last_config() -> void:
	# ESC로 돌아왔을 때: 마지막에 고른 값(병종·숫자·교전)을 복원.
	LangBattleConfig.set_config(
		{"kind": "archer", "count": 4},
		{"kind": "hero", "count": 7},
		"ranged")
	var s = _make_setup()   # _ready → _restore_last
	assert_eq(String(s._sel[0]["kind"]), "archer", "side0 병종 복원")
	assert_eq(int(s._sel[0]["count"]), 4, "side0 숫자 복원")
	assert_eq(String(s._sel[1]["kind"]), "hero", "side1 병종 복원")
	assert_eq(int(s._sel[1]["count"]), 7, "side1 숫자 복원")
	assert_eq(String(s._mode), "ranged", "교전 방식 복원")
	assert_false(s._mode_btns["ranged"].disabled, "복원 후 경궁병 있으니 원거리 활성")

func test_defaults_when_no_last_config() -> void:
	# 마지막 설정이 없으면(첫 진입) 초기값 유지.
	var s = _make_setup()
	assert_eq(String(s._sel[0]["kind"]), "infantry", "복원값 없으면 기본 경보병")
	assert_eq(String(s._mode), "melee", "복원값 없으면 기본 근접")
