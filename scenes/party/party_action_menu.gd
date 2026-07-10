class_name PartyActionMenu
extends CanvasLayer
## 부대 행동 메뉴. 부대를 선택하면 화면 중앙에 [공격]·[휴식/대기] 버튼을 띄운다.
## 버튼만 클릭을 흡수하고 나머지 화면은 맵으로 통과시킨다(이동·공격 타겟팅은 맵 클릭).
## UI는 코드로 구성한다(camp_menu·party_info와 같은 패턴, 별도 .tscn 없음).

signal action_selected(id: String)

var _list: VBoxContainer

## 중앙 부대 메뉴 버튼. [사격](사격 가능 적 있으면 활성) + [휴식/대기]. 노드 비의존(테스트 용이).
static func party_actions(moved: bool, can_shoot_any: bool) -> Array:
	return [
		{"id": "shoot", "label": "사격", "enabled": can_shoot_any},
		{"id": "rest", "label": ("대기" if moved else "휴식"), "enabled": true},
	]

## 적 클릭 팝업 버튼. [이동][공격][사격]을 각 활성 조건으로.
static func enemy_actions(can_move_adj: bool, can_melee: bool, can_shoot: bool) -> Array:
	return [
		{"id": "move", "label": "이동", "enabled": can_move_adj},
		{"id": "attack", "label": "공격", "enabled": can_melee},
		{"id": "shoot", "label": "사격", "enabled": can_shoot},
	]

func _ready() -> void:
	layer = 50
	_build()
	hide()

## 중앙 버튼 패널. 루트·센터는 클릭을 통과(IGNORE)시키고 버튼만 흡수한다.
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	panel.add_child(_list)

## 버튼 목록({id,label,enabled})으로 채우고 보인다. party_actions/enemy_actions 결과를 넘긴다.
func open(buttons: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	for a in buttons:
		var btn := Button.new()
		btn.text = a["label"]
		btn.disabled = not a["enabled"]
		btn.custom_minimum_size = Vector2(120, 0)
		btn.pressed.connect(_on_pressed.bind(a["id"]))
		_list.add_child(btn)
	show()

func close() -> void:
	hide()

func _on_pressed(id: String) -> void:
	action_selected.emit(id)
