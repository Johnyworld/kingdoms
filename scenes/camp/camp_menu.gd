extends CanvasLayer
## 캠프 메뉴 오버레이. 좌측에 자원 정보, 우측에 선택 메뉴를 표시한다.
## 배경(어두운 영역)이나 닫기 버튼을 누르면 닫힌다.

## 건설 리스트에서 건물 종류를 선택하면 방출. 게임이 받아 건설 모드로 처리한다(2b, 미구현).
signal build_selected(type_id: String, territory: Territory)

## 업그레이드 버튼 클릭 시 방출. game.gd가 받아 거점을 다음 티어로 업그레이드한다.
signal upgrade_requested(building: Building)

## 성벽 건설 버튼 클릭 시 방출. game.gd가 받아 자재 지불 + wall_level 설정을 처리한다. → wall.md
signal wall_requested(building: Building)

## 공성 유닛 생산 버튼 클릭 시 방출(종류 id 포함). game.gd가 받아 금·자재 지불 + 주둔 부대에 편입을 처리한다. → siege-engines.md
signal siege_produced(building: Building, type_id: String)

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
var _siege_btn: Button     # 투석기 생산 버튼(거점 + 주둔 부대 + 완성 공성 작업장) → siege-engines.md
var _ram_btn: Button       # 충차 생산 버튼(같은 조건) → siege-engines.md
var _found_camp_btn: Button  # 캠프 건설(새 영지) 버튼
var _demolish_btn: Button    # 캠프 철거 버튼(can_demolish일 때만)
var _build_list: VBoxContainer  # 건설 가능 건물 리스트(기본 숨김)
var _territory: Territory  # 현재 열려 있는 건물의 영지(비용 지불 주체)

var _building: Building            # 현재 열려 있는 거점
var _party = null                  # 그 거점 주둔 부대(없으면 보급 패널 숨김) → garrison.md

# 보급(화물) 패널(부대 있을 때만). 영지 자원 ↔ 부대 화물 적재/하역.
# (상거래(판매·구매·병사) 패널은 제거됨. 화물운반은 자원 세력 통합 시(Slice 2) 함께 제거 예정.)
var _cargo_panel: PanelContainer
var _cargo_list: VBoxContainer     # 자원별 적재/하역 행
const CARGO_STEP := 5              # 적재/하역 버튼 한 번당 이동량

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
	hbox.add_child(_build_cargo_panel())

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

	# 공성 유닛 생산 버튼(거점 + 주둔 부대 + 완성 공성 작업장일 때만 표시). open()에서 갱신. → siege-engines.md
	_siege_btn = Button.new()
	_siege_btn.pressed.connect(func() -> void: siege_produced.emit(_building, SiegeTypes.CATAPULT))
	_siege_btn.hide()
	vbox.add_child(_siege_btn)

	_ram_btn = Button.new()
	_ram_btn.pressed.connect(func() -> void: siege_produced.emit(_building, SiegeTypes.BATTERING_RAM))
	_ram_btn.hide()
	vbox.add_child(_ram_btn)

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

## 우측: 보급(화물) 패널(부대 있을 때만 표시). 영지 자원 ↔ 부대 화물 적재/하역.
func _build_cargo_panel() -> Control:
	_cargo_panel = PanelContainer.new()
	_cargo_panel.custom_minimum_size = Vector2(260, 260)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_cargo_panel.add_child(vbox)

	var title := Label.new()
	title.text = "보급 (화물)"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	_cargo_list = VBoxContainer.new()
	_cargo_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_cargo_list)

	_cargo_panel.hide()
	return _cargo_panel

## 클릭한 건물이 속한 영지 정보(이름 · 세력 · 자원)를 채우고 메뉴를 연다.
## party(그 거점 주둔 부대)가 주어지고 건물이 거점이면 보급 패널도 띄운다. → garrison.md
func open(building: Building, party = null, can_demolish := false) -> void:
	_building = building
	_party = party
	var territory := building.territory
	_territory = territory

	# 정보 화면으로 초기화(이전 오픈에서 건설 리스트가 열려 있던 상태를 지운다).
	_build_list.hide()
	_build_btn.show()
	_refresh_upgrade_button()
	_refresh_wall_button()
	_refresh_siege_buttons()
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

	# 보급(화물) 패널: 주둔 부대가 있고 거점일 때만.
	if _party != null and BuildingTypes.is_center(building.building_type):
		_refresh_cargo_lists()
		_cargo_panel.show()
	else:
		_cargo_panel.hide()
	show()

## 좌측 자원 그리드를 비우고 영지 자원으로 다시 채운다(인구는 "현재/상한"). 적재/하역 뒤에도 갱신.
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

## 보급(화물) 목록을 비우고 다시 채운다. 자원별 행: "이름 영지량/화물량" + [적재][하역] 버튼.
## 인구는 노동력이라 운반 대상에서 제외한다.
func _refresh_cargo_lists() -> void:
	for c in _cargo_list.get_children():
		c.free()
	if _territory == null or _party == null:
		return
	var names: Array = []
	for r in _territory.resources:
		if r != "인구" and r != "금" and not (r in names):
			names.append(r)
	for r in _party.cargo:
		if r != "인구" and r != "금" and not (r in names):
			names.append(r)
	for res_name in names:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s  %d / %d" % [res_name, _territory.resources.get(res_name, 0), _party.cargo.get(res_name, 0)]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var load_btn := Button.new()
		load_btn.text = "적재"
		load_btn.pressed.connect(_load_cargo.bind(res_name))
		row.add_child(load_btn)
		var unload_btn := Button.new()
		unload_btn.text = "하역"
		unload_btn.pressed.connect(_unload_cargo.bind(res_name))
		row.add_child(unload_btn)
		_cargo_list.add_child(row)

## 영지 자원을 부대 화물로 CARGO_STEP만큼 적재(영지 재고·화물 용량으로 상한).
func _load_cargo(res_name) -> void:
	var want: int = mini(CARGO_STEP, _territory.resources.get(res_name, 0))
	var moved: int = _party.add_cargo(res_name, want)   # 용량 초과분은 add_cargo가 잘라냄
	if moved > 0:
		_territory.resources[res_name] = _territory.resources.get(res_name, 0) - moved
	_after_cargo_change()

## 부대 화물을 영지 자원으로 CARGO_STEP만큼 하역(화물 보유분으로 상한).
func _unload_cargo(res_name) -> void:
	var moved: int = _party.remove_cargo(res_name, CARGO_STEP)
	if moved > 0:
		_territory.resources[res_name] = _territory.resources.get(res_name, 0) + moved
	_after_cargo_change()

## 적재/하역 뒤 목록·자원 그리드 갱신. 버튼 pressed 처리 중이라 지연 호출(그 버튼 free 시 locked 방지).
func _after_cargo_change() -> void:
	_refresh_cargo_lists.call_deferred()
	_fill_resource_grid.call_deferred()

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

## 공성 유닛 생산 버튼 갱신(투석기·충차): 거점 + 주둔 부대 + 영지에 완성 공성 작업장이 있을 때만 표시. → siege-engines.md
func _refresh_siege_buttons() -> void:
	_refresh_produce_button(_siege_btn, SiegeTypes.CATAPULT)
	_refresh_produce_button(_ram_btn, SiegeTypes.BATTERING_RAM)

## 종류 id의 생산 버튼 갱신. 라벨 = "<이름>  <금·자재>", 조건 미충족이면 숨김, 자원 부족이면 비활성. 인구 비소모.
func _refresh_produce_button(btn: Button, type_id: String) -> void:
	if _building == null or _party == null or _territory == null \
			or not BuildingTypes.is_center(_building.building_type) \
			or not _territory.has_completed_building("siege_workshop"):
		btn.hide()
		return
	var cost := SiegeTypes.produce_full_cost(type_id)
	btn.text = "%s  %s" % [SiegeTypes.type_name(type_id), _format_cost(cost)]
	btn.disabled = not _territory.can_afford(cost)
	btn.show()

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
