extends Control
## 전투 설정 화면 — 양 진영의 병종·숫자를 고르고, 가운데서 교전 방식을 정한 뒤 전투 씬으로 넘긴다.
## 타이틀 [전투 테스트] → 이 화면 → (선택) → lang_battle(LangBattleConfig 로 파라미터 전달).
##
## side0 = 아군(청), side1 = 적군(적).
## 규칙:
##  - 병종: 영웅 / 경보병 / 경궁병 (초기값 경보병) — 진영별
##  - 숫자: 1~10 (초기값 10) — 진영별
##  - 교전: 근접 / 원거리 (초기값 근접) — **양 진영 공용, 가운데 1개**.
##          원거리는 기본 비활성 — **두 진영 중 하나라도 경궁병**이면 켜지고,
##          경궁병이 하나도 없으면 다시 비활성 되며 근접으로 되돌아간다.

const BATTLE_SCENE := "res://scenes/lang_battle/lang_battle.tscn"

# [key, 라벨]
const KINDS := [["hero", "영웅"], ["infantry", "경보병"], ["archer", "경궁병"]]
const MODES := [["melee", "근접"], ["ranged", "원거리"]]

const COL_SEL := Color(1, 0.95, 0.5)   # 선택됨(노란 색조)
const COL_IDLE := Color.WHITE
const COL_BLUE := Color(0.55, 0.75, 1)
const COL_RED := Color(1, 0.55, 0.5)

# side → 병종·숫자 선택값
var _sel := {
	0: {"kind": "infantry", "count": 10},
	1: {"kind": "infantry", "count": 10},
}
var _mode := "melee"   # 교전 방식(양 진영 공용)

# side → 버튼 참조
var _kind_btns := {0: {}, 1: {}}
var _count_btns := {0: {}, 1: {}}
var _mode_btns := {}   # key → Button (공용, 진영 구분 없음)

func _ready() -> void:
	_restore_last()   # 이전에 고른 값이 있으면 복원(ESC로 돌아왔을 때 기억)
	_build_ui()
	_refresh()

## 마지막 선택값 복원. 없으면 초기값 유지.
func _restore_last() -> void:
	var last := LangBattleConfig.last()
	if last.is_empty():
		return
	for side in [0, 1]:
		var key := "a" if side == 0 else "b"
		var s: Dictionary = last[key]
		_sel[side]["kind"] = String(s["kind"])
		_sel[side]["count"] = int(s["count"])
	_mode = String(last.get("mode", "melee"))

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 28)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	var title := Label.new()
	title.theme_type_variation = &"Label2XL"
	title.text = "전투 설정"
	title.add_theme_color_override("font_color", Color(0.91, 0.72, 0.29))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# [아군 패널] [가운데 교전 방식] [적군 패널]
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", 48)
	panels.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(panels)
	panels.add_child(_build_side_panel(0, "아군", COL_BLUE))
	panels.add_child(_build_mode_column())
	panels.add_child(_build_side_panel(1, "적군", COL_RED))

	var start := Button.new()
	start.theme_type_variation = &"ButtonXL"
	start.text = "전투 시작"
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(280, 56)
	start.pressed.connect(_on_start)
	# VBox 중앙정렬에서 버튼이 가로로 늘어나지 않게 감싼다.
	var wrap := CenterContainer.new()
	wrap.add_child(start)
	root.add_child(wrap)

	var hint := Label.new()
	hint.theme_type_variation = &"LabelSM"
	hint.text = "ESC = 타이틀로"
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

## 한 진영 패널(병종 · 숫자) 생성.
func _build_side_panel(side: int, name_ko: String, name_col: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(460, 0)

	var header := Label.new()
	header.theme_type_variation = &"LabelXL"
	header.text = name_ko
	header.add_theme_color_override("font_color", name_col)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)

	# 병종
	box.add_child(_section_label("병종"))
	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 8)
	kind_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in KINDS:
		var b := _make_choice_button(item[1], Vector2(140, 46))
		b.pressed.connect(_on_kind.bind(side, String(item[0])))
		kind_row.add_child(b)
		_kind_btns[side][String(item[0])] = b
	box.add_child(kind_row)

	# 숫자
	box.add_child(_section_label("숫자"))
	var num_row := HBoxContainer.new()
	num_row.add_theme_constant_override("separation", 4)
	num_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for n in range(1, 11):
		var b := _make_choice_button(str(n), Vector2(40, 40))
		b.pressed.connect(_on_count.bind(side, n))
		num_row.add_child(b)
		_count_btns[side][n] = b
	box.add_child(num_row)

	return box

## 가운데 공용 교전 방식(근접/원거리) 세로 배치.
func _build_mode_column() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_section_label("교전"))
	for item in MODES:
		var b := _make_choice_button(item[1], Vector2(120, 46))
		b.pressed.connect(_on_mode.bind(String(item[0])))
		box.add_child(b)
		_mode_btns[String(item[0])] = b
	return box

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"LabelLG"
	l.text = text
	l.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _make_choice_button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	return b

# ── 선택 처리 ────────────────────────────────────────────────────────────────
func _on_kind(side: int, key: String) -> void:
	_sel[side]["kind"] = key
	# 두 진영 모두 경궁병이 아니게 되면 원거리 불가 → 근접으로 되돌린다.
	if not _any_archer() and _mode == "ranged":
		_mode = "melee"
	_refresh()

func _on_count(side: int, n: int) -> void:
	_sel[side]["count"] = n
	_refresh()

func _on_mode(key: String) -> void:
	# 원거리는 경궁병이 하나라도 있을 때만(비활성 버튼은 disabled 라 여기 도달 안 하지만 방어).
	if key == "ranged" and not _any_archer():
		return
	_mode = key
	_refresh()

func _any_archer() -> bool:
	return _sel[0]["kind"] == "archer" or _sel[1]["kind"] == "archer"

## 선택 상태를 버튼 하이라이트/활성에 반영.
func _refresh() -> void:
	for side in [0, 1]:
		var sel: Dictionary = _sel[side]
		for key in _kind_btns[side]:
			_kind_btns[side][key].modulate = COL_SEL if key == sel["kind"] else COL_IDLE
		for n in _count_btns[side]:
			_count_btns[side][n].modulate = COL_SEL if n == sel["count"] else COL_IDLE
	var ranged_ok := _any_archer()
	_mode_btns["ranged"].disabled = not ranged_ok
	for key in _mode_btns:
		var b: Button = _mode_btns[key]
		if b.disabled:
			b.modulate = Color(0.5, 0.5, 0.55)
		else:
			b.modulate = COL_SEL if key == _mode else COL_IDLE

func _on_start() -> void:
	LangBattleConfig.set_config(_sel[0], _sel[1], _mode)
	SceneManager.change_scene(BATTLE_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			SceneManager.change_scene("res://scenes/title/title.tscn")
