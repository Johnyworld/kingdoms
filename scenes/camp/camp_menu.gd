extends CanvasLayer
## 캠프 메뉴 오버레이. 좌측에 자원 정보, 우측에 선택 메뉴를 표시한다.
## 배경(어두운 영역)이나 닫기 버튼을 누르면 닫힌다.

## 건설 리스트에서 건물 종류를 선택하면 방출. 게임이 받아 건설 모드로 처리한다(2b, 미구현).
signal build_selected(type_id: String, territory: Territory)

## 업그레이드 버튼 클릭 시 방출. game.gd가 받아 거점을 다음 티어로 업그레이드한다.
signal upgrade_requested(building: Building)

## 성벽 건설 버튼 클릭 시 방출. game.gd가 받아 자재 지불 + wall_level 설정을 처리한다. → wall.md
signal wall_requested(building: Building)

## 캠프 건설 버튼 클릭 시 방출. game.gd가 받아 새 영지 캠프 건설 모드(부대 시야 배치)로 진입한다.
signal found_camp_requested(territory: Territory)

## 캠프 철거 버튼 클릭 시 방출. game.gd가 받아 확인 후 캠프 철거(영지 통째 제거)를 처리한다.
signal demolish_requested(building: Building)

var _root: Control
var _res_grid: GridContainer
var _camp_title: Label     # 우측 패널 제목 = 영지 이름
var _faction_label: Label  # 제목 아래 세력명(세력 색상)
var _build_btn: Button     # "건축" 버튼 — 누르면 리스트로 전환
var _upgrade_btn: Button   # 거점 업그레이드 버튼(다음 티어 있을 때만)
var _wall_btn: Button      # 성벽 건설 버튼(마을회관·성 + 성벽 없을 때만) → wall.md
var _found_camp_btn: Button  # 캠프 건설(새 영지) 버튼
var _demolish_btn: Button    # 캠프 철거 버튼(can_demolish일 때만)
var _build_list: VBoxContainer  # 건설 가능 건물 리스트(기본 숨김)
var _territory: Territory  # 현재 열려 있는 건물의 영지(비용 지불 주체)

var _building: Building            # 현재 열려 있는 거점

func _ready() -> void:
	layer = 64
	_build()
	hide()

## UI 트리를 코드로 구성한다.
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 반투명 배경 — 클릭하면 닫힘.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_background_input)
	_root.add_child(bg)

	# 두 패널을 화면 중앙에 나란히.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	center.add_child(hbox)

	hbox.add_child(_build_resource_panel())
	hbox.add_child(_build_menu_panel())

## 좌측: 자원 정보 패널.
func _build_resource_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 260)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "자원"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_res_grid = GridContainer.new()
	_res_grid.columns = 2
	_res_grid.add_theme_constant_override("h_separation", 24)
	_res_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_res_grid)

	return panel

## 우측: 선택 메뉴 패널.
func _build_menu_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 260)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_camp_title = Label.new()
	_camp_title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_camp_title)

	_faction_label = Label.new()
	vbox.add_child(_faction_label)
	vbox.add_child(HSeparator.new())

	# 거점 업그레이드 버튼(다음 티어가 있을 때만 표시). open()에서 텍스트·활성·표시를 갱신.
	_upgrade_btn = Button.new()
	_upgrade_btn.pressed.connect(func() -> void: upgrade_requested.emit(_building))
	_upgrade_btn.hide()
	vbox.add_child(_upgrade_btn)

	# 성벽 건설 버튼(마을회관·성 + 성벽 없을 때만 표시). open()에서 갱신.
	_wall_btn = Button.new()
	_wall_btn.pressed.connect(func() -> void: wall_requested.emit(_building))
	_wall_btn.hide()
	vbox.add_child(_wall_btn)

	# 캠프 건설(새 영지) 버튼 — 활성 부대 시야에 새 캠프를 세운다. open()에서 활성 여부 갱신.
	_found_camp_btn = Button.new()
	_found_camp_btn.pressed.connect(func() -> void: found_camp_requested.emit(_territory))
	vbox.add_child(_found_camp_btn)

	_build_btn = Button.new()
	_build_btn.text = "건축"
	_build_btn.pressed.connect(_on_build_pressed)
	vbox.add_child(_build_btn)

	# 캠프 철거 버튼(can_demolish일 때만 표시). open()에서 표시 여부 갱신.
	_demolish_btn = Button.new()
	_demolish_btn.text = "캠프 철거 (영지 포기)"
	_demolish_btn.pressed.connect(func() -> void: demolish_requested.emit(_building))
	_demolish_btn.hide()
	vbox.add_child(_demolish_btn)

	# 건설 가능 건물 리스트. 건축 버튼을 누르면 채워져 표시된다.
	_build_list = VBoxContainer.new()
	_build_list.add_theme_constant_override("separation", 6)
	_build_list.hide()
	vbox.add_child(_build_list)

	# 남는 공간을 밀어내고 하단에 닫기 버튼.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(close_menu)
	vbox.add_child(close_btn)

	return panel

## 클릭한 건물이 속한 영지 정보(이름 · 세력 · 자원)를 채우고 메뉴를 연다.
func open(building: Building, can_demolish := false) -> void:
	_building = building
	var territory := building.territory
	_territory = territory

	# 정보 화면으로 초기화(이전 오픈에서 건설 리스트가 열려 있던 상태를 지운다).
	_build_list.hide()
	_build_btn.show()
	_refresh_upgrade_button()
	_refresh_wall_button()
	_refresh_found_camp_button()
	_demolish_btn.visible = can_demolish   # 캠프 철거 버튼(game.gd가 조건 판정)

	# 우측 패널: 영지 이름 + 세력.
	_camp_title.text = territory.name if territory != null else ""
	var faction: Faction = territory.faction if territory != null else null
	if faction != null:
		_faction_label.text = faction.name
		_faction_label.add_theme_color_override("font_color", faction.color)
	else:
		# 이전 오픈에서 남은 색상 오버라이드를 지운다(다른 영지로 재오픈 대비).
		_faction_label.text = ""
		_faction_label.remove_theme_color_override("font_color")

	# 좌측 패널: 영지 자원 그리드.
	_fill_resource_grid()
	show()

## 좌측 자원 그리드를 비우고 영지 자원으로 다시 채운다(인구는 "현재/상한").
func _fill_resource_grid() -> void:
	var resources := _territory.resources if _territory != null else {}
	for child in _res_grid.get_children():
		child.free()
	for res_name in resources:
		var name_label := Label.new()
		name_label.text = str(res_name)
		_res_grid.add_child(name_label)

		var value_label := Label.new()
		# 인구는 "현재 / 상한"으로 표시(상한 = 영지 인구 상한). 나머지는 수량만.
		if res_name == "인구" and _territory != null:
			value_label.text = "%d / %d" % [resources[res_name], _territory.population_cap()]
		else:
			value_label.text = str(resources[res_name])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_res_grid.add_child(value_label)

func close_menu() -> void:
	hide()

func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_menu()

## 거점 업그레이드 버튼을 갱신한다. 다음 티어가 있으면(캠프·마을회관) 표시·라벨·활성 설정, 없으면(성·비거점) 숨김.
func _refresh_upgrade_button() -> void:
	var next_id := BuildingTypes.next_center(_building.building_type) if _building != null else ""
	if next_id == "":
		_upgrade_btn.hide()
		return
	var spec := BuildingTypes.get_type(next_id)
	_upgrade_btn.text = "%s으로 업그레이드  %s" % [spec.get("label", next_id), _format_cost(spec.get("build_cost", {}))]
	_upgrade_btn.disabled = not BuildPlanner.can_upgrade(_territory, _building)
	_upgrade_btn.show()

## 성벽 건설 버튼 갱신: 마을회관·성 + 성벽 없을 때만 표시(라벨=비용, 자재 감당 시 활성). → wall.md
func _refresh_wall_button() -> void:
	if _building == null or BuildingTypes.center_tier(_building.building_type) < 1 or _building.is_walled():
		_wall_btn.hide()   # 캠프·비거점·이미 성벽이면 숨김
		return
	_wall_btn.text = "성벽 건설  %s" % _format_cost(BuildingTypes.WALL_COST)
	_wall_btn.disabled = not BuildingTypes.can_build_wall(_territory, _building)
	_wall_btn.show()

## 캠프 건설(새 영지) 버튼 갱신: 라벨(비용)과 활성 여부(여는 영지가 캠프 비용 감당 가능한지).
func _refresh_found_camp_button() -> void:
	var cost: Dictionary = BuildingTypes.get_type(BuildingTypes.CAMP).get("build_cost", {})
	_found_camp_btn.text = "캠프 건설 (새 영지)  %s" % _format_cost(cost)
	_found_camp_btn.disabled = _territory == null or not BuildPlanner.can_build(_territory, BuildingTypes.CAMP)

## 건축 버튼: 우측 패널을 건설 가능 건물 리스트로 전환한다.
func _on_build_pressed() -> void:
	for child in _build_list.get_children():
		child.queue_free()
	for type_id in BuildingTypes.BUILDABLE_IDS:
		var spec := BuildingTypes.get_type(type_id)
		var cost: Dictionary = spec.get("build_cost", {})
		var item := Button.new()
		var label_text = "%s  %s" % [spec.get("label", type_id), _format_cost(cost)]
		# 선행건물 충족 여부(영지 있을 때만 판정 — 없으면 어차피 전부 비활성). 미충족이면 사유를 라벨에 덧붙인다.
		if _territory != null and not BuildPlanner.prerequisite_met(_territory, type_id):
			var prereq_id: String = spec.get("prerequisite", "")
			label_text += "  (선행: %s 필요)" % BuildingTypes.get_type(prereq_id).get("label", prereq_id)
		item.text = label_text
		# 영지가 없거나 · 건축 조건(선행·자재) 미충족이면 비활성.
		item.disabled = _territory == null or not BuildPlanner.can_build(_territory, type_id)
		item.pressed.connect(_on_build_item_selected.bind(type_id))
		_build_list.add_child(item)
	_build_btn.hide()
	_build_list.show()

## 리스트 항목 선택: 종류·영지를 시그널로 알리고 메뉴를 닫는다. 실제 배치는 게임이 처리(2b).
func _on_build_item_selected(type_id: String) -> void:
	build_selected.emit(type_id, _territory)
	close_menu()

## 건설 비용(자원명→수량)을 "인구 2 · 목재 5 · 밀 5" 형태 문자열로.
func _format_cost(cost: Dictionary) -> String:
	var parts := []
	for res_name in cost:
		parts.append("%s %d" % [res_name, cost[res_name]])
	return " · ".join(parts)
