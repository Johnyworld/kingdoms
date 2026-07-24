extends CanvasLayer
## 부대 정보 패널. 부대를 클릭하면 화면 우측 상단에 이름·이동력·시야·멤버를 표시한다.
## 캠프 메뉴(camp_menu.gd)·턴 HUD(turn_hud.gd)처럼 UI를 코드로 구성한다(별도 .tscn 없음).

signal action_selected(id: String)   # 행동 버튼([소속] 등)을 누르면 방출. game.gd가 처리. → party-lord.md
signal command_changed(field: String, value: bool)   # 지휘 토글([따라옴] 등)을 누르면 방출(field="follow"|"engage"). game.gd가 세팅·재렌더. → squad-stance.md

const MARGIN := 16

var _title: Label          # 제목 = 부대 이름
var _faction: Label        # 소속 세력 이름(비면 숨김)
var _summary: Label        # 요약 = "이동력 N · 시야 M"
var _member_list: VBoxContainer  # 멤버 한 명당 라벨 한 줄
var _actions: HBoxContainer      # 행동 버튼 줄([소속] 등). 비면 숨김 — 중앙 메뉴 삭제로 이리 옮김. → party-action-menu.md

# 지휘 토글(영웅부대 전용, 상시 인라인) — 구 [지휘] 모달을 패널로 흡수. → squad-stance.md
var _command_sep: HSeparator
var _command_box: VBoxContainer  # 추종 줄·전투 줄을 담는 박스. 영웅+명령가능 하위부대일 때만 표시.
var _follow_btn: Button
var _direct_btn: Button
var _engage_btn: Button
var _avoid_btn: Button

func _ready() -> void:
	layer = 48
	_build()
	hide()

## UI 트리를 코드로 구성한다. 우측 상단 패널.
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(200, 0)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_title = Label.new()
	_title.theme_type_variation = &"LabelLG"
	vbox.add_child(_title)

	_faction = Label.new()
	vbox.add_child(_faction)

	_summary = Label.new()
	vbox.add_child(_summary)

	vbox.add_child(HSeparator.new())

	_member_list = VBoxContainer.new()
	_member_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_member_list)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	vbox.add_child(_actions)

	# 지휘 토글(추종·전투 2줄) — 영웅 선택 시 상시 노출. 기본 숨김. → squad-stance.md
	_command_sep = HSeparator.new()
	vbox.add_child(_command_sep)
	_command_box = VBoxContainer.new()
	_command_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_command_box)

	_command_box.add_child(_row_label("추종"))
	var follow_row := HBoxContainer.new()
	follow_row.add_theme_constant_override("separation", 8)
	_follow_btn = _toggle("따라옴", func() -> void: command_changed.emit("follow", true))
	_direct_btn = _toggle("직접명령", func() -> void: command_changed.emit("follow", false))
	follow_row.add_child(_follow_btn)
	follow_row.add_child(_direct_btn)
	_command_box.add_child(follow_row)

	_command_box.add_child(_row_label("전투"))
	var combat_row := HBoxContainer.new()
	combat_row.add_theme_constant_override("separation", 8)
	_engage_btn = _toggle("전투우선", func() -> void: command_changed.emit("engage", true))
	_avoid_btn = _toggle("전투회피", func() -> void: command_changed.emit("engage", false))
	combat_row.add_child(_engage_btn)
	combat_row.add_child(_avoid_btn)
	_command_box.add_child(combat_row)

func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _toggle(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	return b

const _CMD_SELECTED_FONT := Color(1, 0.9, 0.55, 1)   # 선택 강조 = 테마 hover 금색

## 지휘 토글 선택 표시: 현재 값인 쪽은 밝게(불투명 + 금색 글자), 반대쪽은 흐리게.
## disabled(어두운 스타일)로 표시하면 "선택=어두움"으로 거꾸로 읽혀, 밝기로 표시한다. → squad-stance.md
func _mark_toggle(btn: Button, selected: bool) -> void:
	btn.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.45)
	if selected:
		btn.add_theme_color_override("font_color", _CMD_SELECTED_FONT)
	else:
		btn.remove_theme_color_override("font_color")

## 부대 정보를 채우고 패널을 보인다. 멤버 리스트·행동 버튼은 비우고 다시 채운다(재오픈 대비).
## actions = [{id, label}, …] 행동 버튼(예: [소속]). 비면 버튼 줄을 숨긴다. → party-lord.md
## show_command=true이고 영웅부대면 지휘 토글(추종·전투)을 상시 노출한다(현재 값 쪽 버튼 밝게 강조=선택 표시). → squad-stance.md
func open(party, actions := [], show_command := false) -> void:
	_title.text = party.party_name
	_faction.text = party.faction_name
	_faction.visible = not party.faction_name.is_empty()   # 세력명이 없으면 줄을 숨긴다.
	_summary.text = "이동력 %d · 시야 %d · 사거리 %s" % [party.movement(), party.vision(), _range_label(party.attack_range())]

	for child in _member_list.get_children():
		child.free()   # 즉시 제거(다음 프레임까지 낡은 행이 남지 않도록)
	# 순수 class+count — 개별 병사 없음. 지휘관 이름 + 병력수만 표시(영웅부대는 병력=클래스 HP).
	var label := Label.new()
	label.text = "지휘관 %s · 병력 %d" % [party.commander_name, party.soldiers]
	_member_list.add_child(label)

	for child in _actions.get_children():
		child.free()
	for a in actions:
		var btn := Button.new()
		btn.text = a["label"]
		btn.pressed.connect(func() -> void: action_selected.emit(a["id"]))
		_actions.add_child(btn)
	_actions.visible = not actions.is_empty()

	var show_cmd: bool = show_command and party.is_hero()
	_command_box.visible = show_cmd
	_command_sep.visible = show_cmd
	if show_cmd:
		# 현재 값인 쪽 버튼을 밝게 강조(선택 표시), 반대쪽은 흐리게. → squad-stance.md
		_mark_toggle(_follow_btn, party.command_follow)
		_mark_toggle(_direct_btn, not party.command_follow)
		_mark_toggle(_engage_btn, party.command_engage)
		_mark_toggle(_avoid_btn, not party.command_engage)

	show()

## 사거리 표기. 0 이하 → "근접", 그 외 "사거리 N".
func _range_label(r: int) -> String:
	return "근접" if r <= 0 else "사거리 %d" % r

## 패널을 숨긴다.
func close() -> void:
	hide()
