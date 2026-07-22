@tool
extends EditorPlugin
## Barriers 노드를 선택하면 활성화되는 경계(강·벽) 편집 툴.
##
## - 캔버스에서 헥스 **경계선**을 클릭하면 그 경계 장벽을 토글한다(현재 kind로 추가 / 이미 있으면 제거).
## - 선택 중일 때만 클릭 가능한 헥스 경계 그리드(옅게)를 그린다. 설정된 장벽 자체는 Barriers._draw가
##   씬이 열려 있는 동안 항상 색선으로 보여준다(플러그인과 무관).
## - 상단 툴바에서 kind 선택(강/벽/영구벽). Undo/Redo 지원.
## → scenes/game/barriers.gd · docs/spec/features/selection-and-movement.md

const Barriers := preload("res://scenes/game/barriers.gd")

const KIND_NAMES := ["강", "벽", "영구벽"]
const FAINT := Color(1, 1, 1, 0.18)
const GRID_CELL_CAP := 4000   # 보이는 칸이 이보다 많으면(줌아웃) 그리드 생략, 장벽만 표시

var _edited: Node = null            # 편집 중인 Barriers 노드
var _terrain: TileMapLayer = null   # 헥스 지오메트리(../TerrainLayer)
var _kind: int = 0                  # 현재 그릴 종류
var _toolbar: HBoxContainer = null
var _kind_buttons: Array = []


func _enter_tree() -> void:
	_toolbar = HBoxContainer.new()
	var label := Label.new()
	label.text = "경계 장벽: "
	_toolbar.add_child(label)
	for k in KIND_NAMES.size():
		var btn := Button.new()
		btn.text = KIND_NAMES[k]
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_select_kind.bind(k))
		_toolbar.add_child(btn)
		_kind_buttons.append(btn)
	_kind_buttons[0].button_pressed = true
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.hide()


func _exit_tree() -> void:
	if _toolbar != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _select_kind(k: int) -> void:
	_kind = k
	for i in _kind_buttons.size():
		_kind_buttons[i].button_pressed = (i == k)


func _handles(object) -> bool:
	return object is Barriers


func _edit(object) -> void:
	_edited = object as Node
	_terrain = null
	if _edited != null:
		_terrain = _edited.get_node_or_null("../TerrainLayer") as TileMapLayer
	update_overlays()


func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible
	if not visible:
		_edited = null
		_terrain = null
	update_overlays()


## 월드 → 에디터 스크린 좌표 변환(뷰포트 pan/zoom 반영).
func _xform() -> Transform2D:
	return _edited.get_viewport_transform() * _edited.get_global_transform()


func _forward_canvas_gui_input(event) -> bool:
	if _edited == null or _terrain == null:
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world: Vector2 = _xform().affine_inverse() * event.position
		var pair := _nearest_edge(world)
		if pair.is_empty():
			return false
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var ur := get_undo_redo()
		if _edited.has_edge(a, b):
			var old_kind: int = _edited.kind_of(a, b)
			ur.create_action("경계 장벽 제거")
			ur.add_do_method(_edited, "remove_edge", a, b)
			ur.add_undo_method(_edited, "add_edge", a, b, old_kind)
		else:
			ur.create_action("경계 장벽 추가")
			ur.add_do_method(_edited, "add_edge", a, b, _kind)
			ur.add_undo_method(_edited, "remove_edge", a, b)
		ur.commit_action()
		update_overlays()
		return true
	return false


## 커서 아래 칸 + 6이웃 중, 두 칸 중심의 중점(=공유 변 중점)이 커서에 가장 가까운 (칸, 이웃) 쌍.
func _nearest_edge(world: Vector2) -> Array:
	var cell: Vector2i = _terrain.local_to_map(_terrain.to_local(world))
	var cc: Vector2 = _terrain.map_to_local(cell)
	var best_n := Vector2i.ZERO
	var best_d := INF
	for n in _terrain.get_surrounding_cells(cell):
		var mid: Vector2 = (cc + _terrain.map_to_local(n)) * 0.5
		var d: float = world.distance_squared_to(mid)
		if d < best_d:
			best_d = d
			best_n = n
	if best_d == INF:
		return []
	return [cell, best_n]


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _edited == null or _terrain == null:
		return
	var xform := _xform()
	# 클릭 가능한 헥스 경계(옅게) — 화면에 보이는 범위만. 설정된 장벽은 Barriers._draw가 따로 그린다.
	var inv := xform.affine_inverse()
	var rect := overlay.get_rect()
	var c0: Vector2i = _terrain.local_to_map(_terrain.to_local(inv * rect.position))
	var c1: Vector2i = _terrain.local_to_map(_terrain.to_local(inv * (rect.position + rect.size)))
	var minx: int = min(c0.x, c1.x) - 1
	var maxx: int = max(c0.x, c1.x) + 1
	var miny: int = min(c0.y, c1.y) - 1
	var maxy: int = max(c0.y, c1.y) + 1
	if (maxx - minx + 1) * (maxy - miny + 1) > GRID_CELL_CAP:
		return
	for cy in range(miny, maxy + 1):
		for cx in range(minx, maxx + 1):
			var cell := Vector2i(cx, cy)
			for n in _terrain.get_surrounding_cells(cell):
				if n.x < cx or (n.x == cx and n.y < cy):
					continue   # 같은 경계 두 번 그리지 않도록 한 방향만
				var seg := HexGrid.edge_segment(_terrain, cell, n)
				if seg.size() >= 2:
					overlay.draw_line(xform * seg[0], xform * seg[1], FAINT, 1.0)
