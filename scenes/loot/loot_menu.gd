class_name LootMenu
extends CanvasLayer
## 약탈 패널. 전투로 적 부대를 전멸시킨 승자가 패자 전사자 장비를 골라 노획한다([Raid](../../docs/spec/features/raid.md)).
## 화면 중앙 모달. 좌우 2열: 왼쪽 「노획」(패자, [가져오기]) + 오른쪽 「내 인벤토리」(승자, 읽기 전용) + 하단 [모두 가져오기]·[닫기].
## 장비는 승자 loot_items로 들어간다. 안 가져간 건 소실(패자 부대가 곧 제거됨). (화물 노획은 화물 제거로 폐지.)
## UI는 코드로 구성한다(camp_menu·party_action_menu와 같은 패턴, 별도 .tscn 없음).

## 패널이 닫히면 방출. game.gd가 await로 받아 전투 마무리(사상자 반영·패자 제거)를 이어간다.
signal closed

var _root: Control
var _title: Label            # "약탈 — <패자 부대명>"
var _equip_header: Label     # 노획 장비 섹션 제목(장비 있을 때만)
var _equip_list: VBoxContainer  # 장비별 노획 행
var _own_list: VBoxContainer    # 내 인벤토리(승자 보유 노획 장비, 읽기 전용)
var _winner = null           # 노획하는 승자 부대(장비를 받는다)
var _loser = null            # 노획당하는 패자 부대
var _dropped: Array = []     # 아직 안 가져간 패자 전사자 장비 id 스냅샷

func _ready() -> void:
	layer = 70   # camp_menu(64)·행동 메뉴(50)보다 위. 전투 오버레이는 열기 전 닫힌다.
	_build()
	hide()

## UI 트리를 코드로 구성한다.
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 반투명 배경 — 클릭하면 닫힘(남은 장비 소실).
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
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = Label.new()
	_title.text = "약탈"
	box.add_child(_title)

	# 좌우 2열: 왼쪽 = 노획 대상(패자), 오른쪽 = 내 인벤토리(승자).
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	box.add_child(cols)

	# --- 왼쪽 「노획」(패자) ---
	var loot_col := VBoxContainer.new()
	loot_col.add_theme_constant_override("separation", 6)
	loot_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(loot_col)

	var loot_title := Label.new()
	loot_title.text = "노획"
	loot_col.add_child(loot_title)

	_equip_header = Label.new()
	_equip_header.text = "장비"
	loot_col.add_child(_equip_header)
	_equip_list = VBoxContainer.new()
	_equip_list.add_theme_constant_override("separation", 6)
	loot_col.add_child(_equip_list)

	# --- 오른쪽 「내 인벤토리」(승자, 읽기 전용) ---
	var own_col := VBoxContainer.new()
	own_col.add_theme_constant_override("separation", 6)
	own_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(own_col)

	var own_title := Label.new()
	own_title.text = "내 인벤토리"
	own_col.add_child(own_title)
	_own_list = VBoxContainer.new()
	_own_list.add_theme_constant_override("separation", 6)
	own_col.add_child(_own_list)

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

## 승자(winner)가 패자(loser)의 전사자 장비(dropped)를 노획하도록 패널을 연다.
## 호출부는 장비가 하나라도 있음을 보장한다.
func open(winner, loser, dropped: Array) -> void:
	_winner = winner
	_loser = loser
	_dropped = dropped.duplicate()
	_title.text = "약탈 — %s" % (loser.party_name if loser.party_name != "" else "적 부대")
	show()
	_refresh()   # show() 뒤에 채운다 — 빈 노획물이면 _refresh가 다시 닫는다(순서 안전)

## 노획 대상·내 인벤토리 목록을 다시 채운다. 노획 대상이 다 비면 자동으로 닫는다.
func _refresh() -> void:
	for child in _equip_list.get_children():
		child.queue_free()
	if _dropped.is_empty():
		_close()
		return
	# 왼쪽 장비 섹션: "<이름>" + [가져오기](그 아이템 → 승자 loot_items).
	_equip_header.visible = not _dropped.is_empty()
	for id in _dropped:
		_equip_list.add_child(_make_row(ItemTypes.item_name(id), _on_take_equip.bind(id)))
	_refresh_own()

## 오른쪽 내 인벤토리(승자 보유 노획 장비)를 읽기 전용으로 다시 그린다. 비면 "(없음)".
func _refresh_own() -> void:
	for child in _own_list.get_children():
		child.queue_free()
	for line in _grouped_lines(_winner.loot_items):
		_own_list.add_child(_make_label(line))
	if _own_list.get_child_count() == 0:
		_own_list.add_child(_make_label("(없음)"))

## 아이템 id 목록을 "이름 ×개수"로 묶은 라벨 문자열 배열(첫 등장 순서 유지).
func _grouped_lines(ids: Array) -> Array:
	var counts: Dictionary = {}
	var order: Array = []
	for id in ids:
		if not counts.has(id):
			order.append(id)
		counts[id] = counts.get(id, 0) + 1
	var lines: Array = []
	for id in order:
		lines.append("%s ×%d" % [ItemTypes.item_name(id), counts[id]])
	return lines

## "라벨 + [가져오기]" 한 행을 만든다. 버튼 누르면 on_take를 호출한다.
func _make_row(text: String, on_take: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	var take := Button.new()
	take.text = "가져오기"
	take.pressed.connect(on_take)
	row.add_child(take)
	return row

## 읽기 전용 라벨 한 줄.
func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

## 장비 한 점을 승자 loot_items로 옮긴다. 스냅샷(_dropped)에서 그 id 하나를 제거한다(중복이면 첫 개).
func _on_take_equip(id: String) -> void:
	_winner.loot_items.append(id)
	_dropped.erase(id)
	_refresh()

## 남은 장비 전량을 승자로 옮긴다. 이후 노획 대상이 비어 _refresh가 패널을 닫는다.
func _on_take_all() -> void:
	_winner.loot_items.append_array(_dropped)
	_dropped.clear()
	_refresh()

## 배경 클릭(좌클릭) → 닫기(남은 장비 소실).
func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

## 패널을 닫고 closed를 방출한다. 남은 장비는 소실(패자 부대가 곧 제거됨).
func _close() -> void:
	if not visible:
		return
	hide()
	_winner = null
	_loser = null
	_dropped = []
	closed.emit()
