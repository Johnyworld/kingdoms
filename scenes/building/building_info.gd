extends CanvasLayer
## 건물 정보 패널. 캠프가 아닌 건물(농장 등)을 클릭하면 화면 우측 상단에
## 종류·건설 상태·시야·소속 영지·생산량을 표시한다.
## 부대 정보 패널(party_info.gd)·캠프 메뉴(camp_menu.gd)처럼 UI를 코드로 구성한다(별도 .tscn 없음).

const MARGIN := 16

var _title: Label          # 제목 = 건물 종류 라벨(예: "농장")
var _summary: Label        # 요약 = 건설 상태 · 시야
var _info_list: VBoxContainer  # 영지·세력 줄 + 생산 줄

func _ready() -> void:
	layer = 48
	_build()
	hide()

## UI 트리를 코드로 구성한다. 우측 상단 패널(부대 정보 패널과 동일 위치·양식).
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
	_title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_title)

	_summary = Label.new()
	vbox.add_child(_summary)

	vbox.add_child(HSeparator.new())

	_info_list = VBoxContainer.new()
	_info_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_info_list)

## 건물 정보를 채우고 패널을 보인다. 정보 리스트는 비우고 다시 채운다(재오픈 대비).
func open(building) -> void:
	_title.text = building.label()
	if building.is_complete():
		_summary.text = "완성 · 시야 %d" % building.vision
	else:
		_summary.text = "건설 중 %d턴 · 시야 %d" % [building.remaining_turns, building.vision]

	for child in _info_list.get_children():
		child.free()   # 즉시 제거(다음 프레임까지 낡은 줄이 남지 않도록)

	# 영지·세력 줄(있으면). 색상은 map_label_lines가 지정한다.
	for line in building.map_label_lines():
		var label := Label.new()
		label.text = line["text"]
		label.add_theme_color_override("font_color", line["color"])
		_info_list.add_child(label)

	# 생산 줄(있으면). 건설 중에도 완성 시 생산량을 보여준다.
	var production: Dictionary = building.planned_production()
	for res_name in production:
		var label := Label.new()
		label.text = "%s +%d / 턴" % [res_name, production[res_name]]
		_info_list.add_child(label)

	show()

## 패널을 숨긴다.
func close() -> void:
	hide()
