extends CanvasLayer
## 부대 일람. 화면 우측 상단에 게임 내 모든 부대를 나열하고, 항목을 누르면
## 그 부대를 실어 party_selected 시그널을 방출한다(카메라 이동은 game.gd가 담당).
## party_info.gd·camp_menu.gd·turn_hud.gd처럼 UI를 코드로 구성한다(별도 .tscn 없음).

signal party_selected(party)   ## 항목 클릭 시 방출 — game.gd가 받아 카메라를 이동시킨다.

const MARGIN := 16

var _list: VBoxContainer   # 부대 한 개당 버튼 한 줄

func _ready() -> void:
	layer = 47
	_build()

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

	var title := Label.new()
	title.text = "부대 일람"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_list)

## 부대 리스트를 비우고 다시 채운다(재구성 대비). 부대당 버튼 한 개.
func set_parties(parties: Array) -> void:
	for child in _list.get_children():
		child.free()   # 즉시 제거(다음 프레임까지 낡은 항목이 남지 않도록)
	for party in parties:
		if party.soldiers <= 0:
			continue   # 전멸해 사라진 부대는 일람에서 제외
		var button := Button.new()
		button.text = "%s\n지휘관 %s · %d명" % [party.party_name, party.commander_name, party.soldiers]
		button.pressed.connect(_on_button_pressed.bind(party))
		_list.add_child(button)

## 버튼을 누르면 그 부대를 실어 시그널을 방출한다.
func _on_button_pressed(party) -> void:
	party_selected.emit(party)
