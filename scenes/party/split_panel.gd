class_name SplitPanel
extends CanvasLayer
## 부대 분할 패널. 원 부대 / 새 부대 두 목록을 코드로 구성해(camp_menu 수비대 편성과 같은 패턴)
## 멤버를 양쪽으로 옮긴다. 배경 클릭/닫기로 닫으며, 닫을 때 closed를 방출한다(game이 빈 새 부대를 정리).

signal changed   ## 멤버가 이동할 때 방출. game이 부대 일람·안개를 갱신한다.
signal closed    ## 패널을 닫을 때 방출. game이 빈 새 부대를 취소(제거)할지 판단한다.

var _orig      # 원 부대
var _new       # 새(분할) 부대
var _orig_list: VBoxContainer
var _new_list: VBoxContainer

func _ready() -> void:
	layer = 60
	_build()
	hide()

## 반투명 배경(클릭 시 닫힘) + 중앙 두 목록 패널.
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 260)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "부대 나누기"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	vbox.add_child(cols)

	var orig_col := VBoxContainer.new()
	var ol := Label.new()
	ol.text = "원 부대"
	orig_col.add_child(ol)
	_orig_list = VBoxContainer.new()
	_orig_list.add_theme_constant_override("separation", 4)
	orig_col.add_child(_orig_list)
	cols.add_child(orig_col)

	var new_col := VBoxContainer.new()
	var nl := Label.new()
	nl.text = "새 부대"
	new_col.add_child(nl)
	_new_list = VBoxContainer.new()
	_new_list.add_theme_constant_override("separation", 4)
	new_col.add_child(_new_list)
	cols.add_child(new_col)

	vbox.add_child(HSeparator.new())
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(close_panel)
	vbox.add_child(close_btn)

## 원 부대·새 부대를 받아 목록을 채우고 연다.
func open(orig, new) -> void:
	_orig = orig
	_new = new
	_refresh()
	show()

## 멤버 목록을 비우고 다시 채운다.
func _refresh() -> void:
	for c in _orig_list.get_children():
		c.free()
	for c in _new_list.get_children():
		c.free()
	for h in _orig.members:
		var b := Button.new()
		b.text = "%s →" % h.human_name
		b.pressed.connect(_to_new.bind(h))
		_orig_list.add_child(b)
	for h in _new.members:
		var b := Button.new()
		b.text = "← %s" % h.human_name
		b.pressed.connect(_to_orig.bind(h))
		_new_list.add_child(b)

## 원 부대원을 새 부대로. 리스트 재구성은 지연(버튼 pressed 처리 중 free "locked" 방지).
func _to_new(human) -> void:
	_orig.remove_member(human)
	_new.add_member(human)
	_refresh.call_deferred()
	changed.emit()

## 새 부대원을 원 부대로.
func _to_orig(human) -> void:
	_new.remove_member(human)
	_orig.add_member(human)
	_refresh.call_deferred()
	changed.emit()

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_panel()

func close_panel() -> void:
	hide()
	closed.emit()
