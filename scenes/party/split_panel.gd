class_name SplitPanel
extends CanvasLayer
## 부대 분할 패널. 원 부대 / 새 부대 두 목록을 코드로 구성해(camp_menu 수비대 편성과 같은 패턴)
## 멤버를 양쪽으로 옮긴다. 배경 클릭/닫기로 닫으며, 닫을 때 closed를 방출한다(game이 빈 새 부대를 정리).

signal changed   ## 멤버가 이동할 때 방출. game이 부대 일람·안개를 갱신한다.
signal closed    ## 패널을 닫을 때 방출. game이 빈 새 부대를 취소(제거)할지 판단한다.

const CARGO_STEP := 5   # 화물 [→]/[←] 한 번당 이동량(camp_menu 보급과 동일).

var _orig      # 원 부대
var _new       # 새(분할) 부대
var _orig_list: VBoxContainer
var _new_list: VBoxContainer
var _cargo_list: VBoxContainer   # 화물 분배 행(자원별)
var _loot_list: VBoxContainer    # 노획 장비 분배 행(아이템별)

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

	# 화물 분배 섹션.
	vbox.add_child(HSeparator.new())
	var cargo_title := Label.new()
	cargo_title.text = "화물"
	vbox.add_child(cargo_title)
	_cargo_list = VBoxContainer.new()
	_cargo_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_cargo_list)

	# 노획 장비 분배 섹션.
	var loot_title := Label.new()
	loot_title.text = "노획 장비"
	vbox.add_child(loot_title)
	_loot_list = VBoxContainer.new()
	_loot_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_loot_list)

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

## 멤버·화물·장비 목록을 비우고 다시 채운다.
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
	_refresh_cargo()
	_refresh_loot()

## 화물 행: 자원별 "자원 원N [→][←] 새M". 인구는 제외(노동력). 보유 0인 방향 비활성.
func _refresh_cargo() -> void:
	for c in _cargo_list.get_children():
		c.free()
	for res_name in _union_keys(_orig.cargo, _new.cargo):
		if res_name == "인구" or res_name == "금":
			continue   # 노동력·화폐는 부대 화물이 아니다(영지 전용)
		var on: int = _orig.cargo.get(res_name, 0)
		var nn: int = _new.cargo.get(res_name, 0)
		_cargo_list.add_child(_transfer_row(res_name, on, nn, _cargo_to_new.bind(res_name), _cargo_to_orig.bind(res_name)))

## 장비 행: 아이템별 "이름 원N [→][←] 새M". 이름은 ItemTypes.item_name.
func _refresh_loot() -> void:
	for c in _loot_list.get_children():
		c.free()
	var counts_o := _counts(_orig.loot_items)
	var counts_n := _counts(_new.loot_items)
	for id in _union_keys(counts_o, counts_n):
		var on: int = counts_o.get(id, 0)
		var nn: int = counts_n.get(id, 0)
		_loot_list.add_child(_transfer_row(ItemTypes.item_name(id), on, nn, _loot_to_new.bind(id), _loot_to_orig.bind(id)))

## "라벨 원N [→][←] 새M" 한 행. [→]는 원 보유>0일 때만, [←]는 새 보유>0일 때만 활성.
func _transfer_row(label_text: String, orig_n: int, new_n: int, to_new: Callable, to_orig: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)
	var on_label := Label.new()
	on_label.text = str(orig_n)
	row.add_child(on_label)
	var to_new_btn := Button.new()
	to_new_btn.text = "→"
	to_new_btn.disabled = orig_n <= 0
	to_new_btn.pressed.connect(to_new)
	row.add_child(to_new_btn)
	var to_orig_btn := Button.new()
	to_orig_btn.text = "←"
	to_orig_btn.disabled = new_n <= 0
	to_orig_btn.pressed.connect(to_orig)
	row.add_child(to_orig_btn)
	var nn_label := Label.new()
	nn_label.text = str(new_n)
	row.add_child(nn_label)
	return row

## 두 Dictionary의 키 합집합(첫 등장 순서 유지 — a 먼저, b의 새 키 뒤).
func _union_keys(a: Dictionary, b: Dictionary) -> Array:
	var keys: Array = a.keys()
	for k in b.keys():
		if not (k in keys):
			keys.append(k)
	return keys

## id 목록을 id→개수 Dictionary로.
func _counts(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for id in ids:
		out[id] = out.get(id, 0) + 1
	return out

func _cargo_to_new(res_name: String) -> void:
	_orig.transfer_cargo_to(_new, res_name, CARGO_STEP)
	_refresh.call_deferred()
	changed.emit()

func _cargo_to_orig(res_name: String) -> void:
	_new.transfer_cargo_to(_orig, res_name, CARGO_STEP)
	_refresh.call_deferred()
	changed.emit()

func _loot_to_new(id: String) -> void:
	_orig.transfer_loot_to(_new, id)
	_refresh.call_deferred()
	changed.emit()

func _loot_to_orig(id: String) -> void:
	_new.transfer_loot_to(_orig, id)
	_refresh.call_deferred()
	changed.emit()

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
