extends CanvasLayer
## 캠프 메뉴 오버레이. 좌측에 자원 정보, 우측에 선택 메뉴를 표시한다.
## chrome(딤 배경·제목 바·X·ESC·지도 입력 차단)은 공용 Modal에 위임하고, 콘텐츠(두 패널)만 주입한다.
## 제목 바 = 영지 이름. → docs/spec/features/modal.md

## 건설 리스트에서 건물 종류를 선택하면 방출. 게임이 받아 건설 모드로 처리한다(2b, 미구현).
signal build_selected(type_id: String, territory: Territory)

## 업그레이드 버튼 클릭 시 방출. game.gd가 받아 거점을 다음 티어로 업그레이드한다.
signal upgrade_requested(building: Building)

## 캠프 건설 버튼 클릭 시 방출. game.gd가 받아 새 영지 캠프 건설 모드(부대 시야 배치)로 진입한다.
signal found_camp_requested(territory: Territory)

## 캠프 철거 버튼 클릭 시 방출. game.gd가 받아 확인 후 캠프 철거(영지 통째 제거)를 처리한다.
signal demolish_requested(building: Building)

const ModalScript = preload("res://scenes/modal/modal.gd")

var _modal: Modal          # 공용 chrome(배경·제목=영지 이름·X·ESC·ModalStack 등록)
var _res_grid: GridContainer
var _faction_label: Label  # 메뉴 패널 상단 세력명(세력 색상)
var _build_btn: Button     # "건축" 버튼 — 누르면 리스트로 전환
var _upgrade_btn: Button   # 거점 업그레이드 버튼(다음 티어 있을 때만)
var _found_camp_btn: Button  # 캠프 건설(새 영지) 버튼
var _demolish_btn: Button    # 캠프 철거 버튼(can_demolish일 때만)
var _build_list: VBoxContainer  # 건설 가능 건물 리스트(기본 숨김)
var _territory: Territory  # 현재 열려 있는 건물의 영지(비용 지불 주체). changed 시그널 구독 대상.

var _building: Building            # 현재 열려 있는 거점
var _refresh_queued := false       # 영지 changed 코얼레싱 — 다음 idle 프레임에 한 번만 갱신

func _ready() -> void:
	_build()

## UI 트리를 코드로 구성한다. chrome은 Modal, 콘텐츠는 두 패널(HBox).
func _build() -> void:
	_modal = ModalScript.new()
	_modal.closed.connect(_on_modal_closed)
	add_child(_modal)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.add_child(_build_resource_panel())
	hbox.add_child(_build_menu_panel())
	_modal.set_content(hbox)

## 좌측: 자원 정보 패널.
func _build_resource_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 260)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
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

	_faction_label = Label.new()
	vbox.add_child(_faction_label)
	vbox.add_child(HSeparator.new())

	# 거점 업그레이드 버튼(다음 티어가 있을 때만 표시). open()에서 텍스트·활성·표시를 갱신.
	_upgrade_btn = Button.new()
	_upgrade_btn.pressed.connect(func() -> void: upgrade_requested.emit(_building))
	_upgrade_btn.hide()
	vbox.add_child(_upgrade_btn)

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

	# 건설 가능 건물 리스트. 건축 버튼을 누르면 채워져 표시된다. 닫기는 Modal chrome(X·배경·ESC)이 맡는다.
	_build_list = VBoxContainer.new()
	_build_list.add_theme_constant_override("separation", 6)
	_build_list.hide()
	vbox.add_child(_build_list)

	return panel

## 클릭한 건물이 속한 영지 정보(이름 · 세력 · 자원)를 채우고 메뉴를 연다.
## 열려 있는 동안 영지 changed 시그널을 구독해 자원·건물·세력 변화를 자동 반영한다(game.gd 수동 재-open 불필요). → Territory.md
func open(building: Building) -> void:
	_building = building
	_watch_territory(building.territory)
	_refresh()
	_modal.open()   # 이미 열려 있으면 no-op(내용은 위 _refresh가 갱신)

## 영지 changed 구독을 새 영지로 교체한다(다른 거점으로 재오픈 대비).
func _watch_territory(t: Territory) -> void:
	if _territory == t:
		return
	if _territory != null and _territory.changed.is_connected(_on_territory_changed):
		_territory.changed.disconnect(_on_territory_changed)
	_territory = t
	if _territory != null:
		_territory.changed.connect(_on_territory_changed)

## 영지 변화 → 다음 idle 프레임에 한 번만 갱신. 연속 변화를 코얼레싱하고,
## 같은 프레임에서 시그널 뒤에 오는 건물 변경(예: build_pay 후 upgrade_to)까지 최종 상태로 그린다.
func _on_territory_changed() -> void:
	if not _modal.is_open() or _refresh_queued:
		return
	_refresh_queued = true
	_deferred_refresh.call_deferred()

func _deferred_refresh() -> void:
	_refresh_queued = false
	if _modal.is_open():
		_refresh()

## 현재 _building/_territory 상태로 전체를 다시 그린다(정보 화면으로 초기화 — 이전 재-open과 동일한 동작).
func _refresh() -> void:
	_build_list.hide()
	_build_btn.show()
	_refresh_upgrade_button()
	_refresh_found_camp_button()
	_demolish_btn.visible = _can_demolish()

	# 제목 바 = 영지 이름, 메뉴 패널 상단 = 세력.
	_modal.title = _territory.name if _territory != null else ""
	var faction: Faction = _territory.faction if _territory != null else null
	if faction != null:
		_faction_label.text = faction.name
		_faction_label.add_theme_color_override("font_color", faction.color)
	else:
		# 이전 오픈에서 남은 색상 오버라이드를 지운다(다른 영지로 재오픈 대비).
		_faction_label.text = ""
		_faction_label.remove_theme_color_override("font_color")

	# 좌측 패널: 영지 자원 그리드.
	_fill_resource_grid()

## 캠프 철거 가능 판정 — 캠프(tier 0)·세력 소속·마지막 거점 아님(Faction.center_count > 1, 세력 소멸 방지).
## 캠프 메뉴는 클릭 라우팅상 플레이어 거점에서만 열리므로 "내 세력" 조건은 자동 충족. → camp-menu.md
func _can_demolish() -> bool:
	if _building == null or _building.building_type != BuildingTypes.CAMP:
		return false
	var f: Faction = _building.faction()
	return f != null and f.center_count() > 1

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
	_modal.close()

## 닫히면(X·배경·ESC·close_menu 모두 수렴) 영지 구독을 해제한다 — 분리된 영지를 붙들거나 stale 방출을 받지 않게.
func _on_modal_closed() -> void:
	_watch_territory(null)

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
