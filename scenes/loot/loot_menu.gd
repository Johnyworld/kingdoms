class_name LootMenu
extends CanvasLayer
## 약탈 패널. 전투로 적 부대를 전멸시킨 승자가 패자의 화물을 골라 노획한다([Raid](../../docs/spec/features/raid.md)).
## 화면 중앙 모달. 자원별 행 [가져오기] + 하단 [모두 가져오기]·[닫기]. 안 가져간 화물은 소실(패자 부대가 곧 제거됨).
## UI는 코드로 구성한다(camp_menu·party_action_menu와 같은 패턴, 별도 .tscn 없음).

## 패널이 닫히면 방출. game.gd가 await로 받아 전투 마무리(사상자 반영·패자 제거)를 이어간다.
signal closed

var _root: Control
var _title: Label       # "약탈 — <패자 부대명>"
var _list: VBoxContainer  # 자원별 노획 행
var _winner = null       # 노획하는 승자 부대(화물을 받는다)
var _loser = null        # 노획당하는 패자 부대(화물 출처)

func _ready() -> void:
	layer = 70   # camp_menu(64)·행동 메뉴(50)보다 위. 전투 오버레이는 열기 전 닫힌다.
	_build()
	hide()

## UI 트리를 코드로 구성한다.
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 반투명 배경 — 클릭하면 닫힘(남은 화물 소실).
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	_root.add_child(bg)

	# 중앙 패널.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = Label.new()
	_title.text = "약탈"
	box.add_child(_title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)

	# 하단 버튼 행.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	var take_all := Button.new()
	take_all.text = "모두 가져오기"
	take_all.pressed.connect(_on_take_all)
	buttons.add_child(take_all)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_close)
	buttons.add_child(close_btn)

## 승자(winner)가 패자(loser) 화물을 노획하도록 패널을 연다. 호출부는 loser 화물이 비어 있지 않음을 보장한다.
func open(winner, loser) -> void:
	_winner = winner
	_loser = loser
	_title.text = "약탈 — %s" % (loser.party_name if loser.party_name != "" else "적 부대")
	show()
	_refresh()   # show() 뒤에 채운다 — 빈 화물이면 _refresh가 다시 닫는다(순서 안전)

## 패자 화물을 자원별 행으로 다시 채운다: "<자원> ×<수량>" + [가져오기]. 화물이 비면 자동으로 닫는다.
func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	if _loser.cargo.is_empty():
		_close()
		return
	for res_name in _loser.cargo.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = "%s ×%d" % [res_name, _loser.cargo[res_name]]
		label.custom_minimum_size = Vector2(160, 0)
		row.add_child(label)
		var take := Button.new()
		take.text = "가져오기"
		take.pressed.connect(_on_take.bind(res_name))
		row.add_child(take)
		_list.add_child(row)

## 한 자원을 전량 승자 화물로 옮긴다(용량 초과 허용). 옮긴 뒤 목록 갱신(비면 닫힘).
func _on_take(res_name: String) -> void:
	_winner.take_loot(_loser, res_name, _loser.cargo.get(res_name, 0))
	_refresh()

## 남은 화물 전량을 승자로 옮긴다. 이후 화물이 비어 _refresh가 패널을 닫는다.
func _on_take_all() -> void:
	_winner.take_all_loot(_loser)
	_refresh()

## 배경 클릭 → 닫기(남은 화물은 소실).
func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

## 패널을 닫고 closed를 방출한다. 남은 화물은 소실(패자 부대가 곧 제거됨).
func _close() -> void:
	if not visible:
		return
	hide()
	_winner = null
	_loser = null
	closed.emit()
