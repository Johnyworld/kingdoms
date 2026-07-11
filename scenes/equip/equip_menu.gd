class_name EquipMenu
extends CanvasLayer
## 장비 관리 모달. 부대 노획 장비(loot_items)를 멤버에게 장착·탈착한다([Equipment](../../docs/spec/features/equipment.md)).
## 화면 중앙 좌우 2열: 왼쪽 「멤버」(선택 + 장착 장비 [탈착]) / 오른쪽 「인벤토리」(loot_items [장착]) + 하단 [닫기].
## 슬롯 여유 있을 때만 장착(스왑 없음). UI는 코드로 구성한다(loot_menu·camp_menu 패턴, 별도 .tscn 없음).

var _root: Control
var _member_list: VBoxContainer   # 멤버 선택 버튼
var _equipped_list: VBoxContainer # 선택 멤버의 장착 장비(슬롯별 [탈착])
var _inv_list: VBoxContainer      # 부대 인벤토리(loot_items, [장착])
var _title: Label
var _party = null
var _selected = null              # 선택된 멤버(Human). 기본은 첫 멤버.

func _ready() -> void:
	layer = 70   # loot_menu와 같은 층(동시에 열리지 않는다). 행동 메뉴(50)보다 위.
	_build()
	hide()

## UI 트리를 코드로 구성한다.
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = Label.new()
	_title.text = "장비"
	box.add_child(_title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	box.add_child(cols)

	# --- 왼쪽 「멤버」 ---
	var member_col := VBoxContainer.new()
	member_col.add_theme_constant_override("separation", 6)
	member_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(member_col)

	var member_title := Label.new()
	member_title.text = "멤버"
	member_col.add_child(member_title)
	_member_list = VBoxContainer.new()
	_member_list.add_theme_constant_override("separation", 4)
	member_col.add_child(_member_list)
	_equipped_list = VBoxContainer.new()
	_equipped_list.add_theme_constant_override("separation", 4)
	member_col.add_child(_equipped_list)

	# --- 오른쪽 「인벤토리」 ---
	var inv_col := VBoxContainer.new()
	inv_col.add_theme_constant_override("separation", 6)
	inv_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(inv_col)

	var inv_title := Label.new()
	inv_title.text = "인벤토리"
	inv_col.add_child(inv_title)
	_inv_list = VBoxContainer.new()
	_inv_list.add_theme_constant_override("separation", 4)
	inv_col.add_child(_inv_list)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_close)
	buttons.add_child(close_btn)

## 부대의 장비 관리를 연다. 첫 멤버를 기본 선택한다.
func open(party) -> void:
	_party = party
	_selected = party.members[0] if not party.members.is_empty() else null
	_title.text = "장비 — %s" % (party.party_name if party.party_name != "" else "부대")
	show()
	_refresh()

## 멤버·장착 장비·인벤토리 목록을 다시 그린다.
func _refresh() -> void:
	_refresh_members()
	_refresh_equipped()
	_refresh_inventory()

## 멤버 선택 버튼. 선택된 멤버는 ● 표시.
func _refresh_members() -> void:
	for child in _member_list.get_children():
		child.queue_free()
	for m in _party.members:
		var btn := Button.new()
		btn.text = "%s %s" % ["●" if m == _selected else "○", m.human_name]
		btn.custom_minimum_size = Vector2(200, 0)
		btn.pressed.connect(_on_select_member.bind(m))
		_member_list.add_child(btn)

## 선택 멤버의 장착 장비를 슬롯별로 나열([탈착]). 멤버 없으면 안내.
func _refresh_equipped() -> void:
	for child in _equipped_list.get_children():
		child.queue_free()
	if _selected == null:
		return
	_equipped_list.add_child(_make_label("무기 %d/%d" % [_selected.weapons.size(), Human.MAX_WEAPONS]))
	for id in _selected.weapons:
		_equipped_list.add_child(_make_row(ItemTypes.item_name(id), "탈착", true, _on_unequip.bind(id)))
	_equipped_list.add_child(_make_label("방어구 %d/%d" % [_selected.armor.size(), Human.MAX_ARMOR]))
	for id in _selected.armor:
		_equipped_list.add_child(_make_row(ItemTypes.item_name(id), "탈착", true, _on_unequip.bind(id)))
	_equipped_list.add_child(_make_label("방패"))
	if _selected.shield != "":
		_equipped_list.add_child(_make_row(ItemTypes.item_name(_selected.shield), "탈착", true, _on_unequip.bind(_selected.shield)))

## 부대 인벤토리(loot_items)를 이름별로 묶어 나열([장착]). 선택 멤버의 슬롯이 꽉 차면 비활성.
func _refresh_inventory() -> void:
	for child in _inv_list.get_children():
		child.queue_free()
	var groups := _grouped(_party.loot_items)   # [{id, count}]
	if groups.is_empty():
		_inv_list.add_child(_make_label("(없음)"))
		return
	for g in groups:
		var id: String = g["id"]
		var text := "%s ×%d" % [ItemTypes.item_name(id), g["count"]]
		_inv_list.add_child(_make_row(text, "장착", _can_equip(id), _on_equip.bind(id)))

## 선택 멤버가 이 장비를 장착할 수 있는지([장착] 버튼 활성). 판정은 Party가 단일 출처.
func _can_equip(id: String) -> bool:
	return _selected != null and _party.can_equip_from_loot(_selected, id)

## 아이템 id 목록을 [{id, count}]로 묶는다(첫 등장 순서 유지).
func _grouped(ids: Array) -> Array:
	var counts: Dictionary = {}
	var order: Array = []
	for id in ids:
		if not counts.has(id):
			order.append(id)
		counts[id] = counts.get(id, 0) + 1
	var out: Array = []
	for id in order:
		out.append({"id": id, "count": counts[id]})
	return out

func _on_select_member(m) -> void:
	_selected = m
	_refresh()

func _on_equip(id: String) -> void:
	_party.equip_from_loot(_selected, id)
	_refresh()

func _on_unequip(id: String) -> void:
	_party.unequip_to_loot(_selected, id)
	_refresh()

## "라벨 + [버튼]" 한 행. enabled=false면 버튼 비활성.
func _make_row(text: String, btn_text: String, enabled: bool, on_press: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var btn := Button.new()
	btn.text = btn_text
	btn.disabled = not enabled
	btn.pressed.connect(on_press)
	row.add_child(btn)
	return row

## 읽기 전용 라벨 한 줄.
func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _close() -> void:
	if not visible:
		return
	hide()
	_party = null
	_selected = null
