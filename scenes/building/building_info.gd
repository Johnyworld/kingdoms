extends CanvasLayer
## 건물 정보 패널. 캠프가 아닌 건물(농장 등)을 클릭하면 화면 우측 상단에
## 종류·건설 상태·시야·소속 영지·생산량을 표시한다.
## 부대 정보 패널(party_info.gd)·캠프 메뉴(camp_menu.gd)처럼 UI를 코드로 구성한다(별도 .tscn 없음).

## 철거 버튼을 누르면 방출. game.gd가 받아 실제 철거(영지에서 제거·환급·안개 갱신)를 처리한다.
signal demolish_requested(building)
## [거점 변경] — 1차 생산 건물. game.gd가 받아 배정 거점 이동을 처리한다. → production.md
signal center_change_requested(building)

const MARGIN := 16

var _title: Label          # 제목 = 건물 종류 라벨(예: "농장")
var _summary: Label        # 요약 = 건설 상태 · 시야
var _info_list: VBoxContainer  # 영지·세력 줄 + 생산 줄
var _distance := 0             # 1차 생산 건물 ↔ 배정 거점 거리(생산력 표시용, game이 넘김) → production.md
var _demolish_btn: Button  # 철거 버튼(내 소유·캠프 아님일 때만 표시)
var _center_btn: Button    # [거점 변경](1차 생산만)
var _building = null        # 현재 표시 중인 건물(철거 대상)

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
	_title.theme_type_variation = &"LabelLG"
	vbox.add_child(_title)

	_summary = Label.new()
	vbox.add_child(_summary)

	vbox.add_child(HSeparator.new())

	_info_list = VBoxContainer.new()
	_info_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_info_list)

	# [거점 변경] 버튼(기본 숨김). open()이 primary_production일 때만 표시. → production.md
	_center_btn = Button.new()
	_center_btn.text = "거점 변경"
	_center_btn.pressed.connect(func() -> void: center_change_requested.emit(_building))
	_center_btn.hide()
	vbox.add_child(_center_btn)

	# 철거 버튼(기본 숨김). open(.., can_demolish)가 표시 여부를 토글한다.
	_demolish_btn = Button.new()
	_demolish_btn.text = "철거"
	_demolish_btn.pressed.connect(func() -> void: demolish_requested.emit(_building))
	_demolish_btn.hide()
	vbox.add_child(_demolish_btn)

## 건물 정보를 채우고 패널을 보인다. 정보 리스트는 비우고 다시 채운다(재오픈 대비).
func open(building, can_demolish := false, distance := 0) -> void:
	_building = building
	_distance = distance
	_demolish_btn.visible = can_demolish
	_center_btn.visible = building.is_primary_production()
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

	# 수비(거점만): "수비대 N명"(중심 타일 점거 방어 부대 인원). 거점 아닌 건물(농장 등)은 표시하지 않는다.
	if BuildingTypes.is_center(building.building_type):
		var g := Label.new()
		g.text = "수비대 %d명" % building.defender_count
		_info_list.add_child(g)

	# 1차 생산 건물: 산출 자원·생산력(1÷거리)·누적·배정 거점. → docs/spec/features/production.md
	if building.is_primary_production():
		var label := Label.new()
		if _distance > 0:
			label.text = "%s 생산력 %.2f/턴 (거리 %d)\n누적 %d/%d" % [building.produces(), building.production_rate(_distance), _distance, building.production_points, _distance]
		else:
			label.text = "%s 생산 (배정 거점 없음/도달 불가)" % building.produces()
		_info_list.add_child(label)
		if building.assigned_center != null and building.assigned_center.territory != null:
			var center_label := Label.new()
			center_label.text = "배정 거점: %s" % building.assigned_center.territory.name
			_info_list.add_child(center_label)

	# 인구 상한 기여 줄(집 등, 있으면). 생산 줄처럼 건설 중에도 완성 시 기여분을 보여준다.
	# 거점(캠프·마을회관·성)은 캠프 메뉴로 라우팅되어 이 패널에 오지 않으므로 제외.
	var cap_bonus: int = BuildingTypes.get_type(building.building_type).get("pop_cap", 0)
	if cap_bonus > 0 and not BuildingTypes.is_center(building.building_type):
		var label := Label.new()
		label.text = "인구 상한 +%d" % cap_bonus
		_info_list.add_child(label)

	show()

## 패널을 숨긴다.
func close() -> void:
	hide()
