class_name PartyActionMenu
extends CanvasLayer
## 부대 행동 팝업. 대상(거점/인접 아군) 근처에 버튼을 띄운다(거점: [흡수][파괴], 아군: [병합], 작전: [추종]…).
## 중앙 메뉴·적 공격 팝업은 삭제됨 — 공격은 적 직접 클릭, [소속]은 부대 정보 박스로 이동(→ party-action-menu.md).
## 버튼만 클릭을 흡수하고 나머지 화면은 맵으로 통과시킨다. UI는 코드로 구성(camp_menu·party_info 패턴, 별도 .tscn 없음).

signal action_selected(id: String)

const CLICK_OFFSET := Vector2(24, 12)   # 클릭 지점 기준 패널 좌상단 오프셋(우측 하단으로)

var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer

## 적 거점 클릭 팝업 버튼 [흡수][파괴]. 인접 가능한 캠프에서만 열리므로 둘 다 활성.
static func capture_actions() -> Array:
	return [
		{"id": "absorb", "label": "흡수", "enabled": true},
		{"id": "destroy", "label": "파괴", "enabled": true},
	]

## 인접 아군 부대 클릭 팝업 버튼 [병합]. 인접 아군에서만 열리므로 활성.
static func merge_actions() -> Array:
	return [{"id": "merge", "label": "병합", "enabled": true}]

func _ready() -> void:
	layer = 50
	_build()
	hide()

## 버튼 패널. 루트는 클릭을 통과(IGNORE)시키고, 패널(버튼)만 흡수한다. 패널은 클릭 지점 근처에 둔다.
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_root.add_child(_panel)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_panel.add_child(_list)

## 버튼 목록({id,label,enabled})으로 채우고, 클릭한 부대 토큰의 화면 좌표(screen_pos) 근처에 띄운다.
func open(buttons: Array, screen_pos: Vector2) -> void:
	for child in _list.get_children():
		child.queue_free()
	for a in buttons:
		var btn := Button.new()
		btn.text = a["label"]
		btn.disabled = not a["enabled"]
		btn.custom_minimum_size = Vector2(120, 0)
		btn.pressed.connect(_on_pressed.bind(a["id"]))
		_list.add_child(btn)
	show()
	_place_at(screen_pos)

## 패널 좌상단을 screen_pos + 오프셋에 두되, 화면 밖으로 넘치지 않게 클램프한다.
func _place_at(screen_pos: Vector2) -> void:
	await get_tree().process_frame   # 패널 크기가 잡힌 뒤 클램프
	var vp := _root.size
	var sz := _panel.size
	var pos := screen_pos + CLICK_OFFSET
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - sz.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - sz.y))
	_panel.position = pos

func close() -> void:
	hide()

func _on_pressed(id: String) -> void:
	action_selected.emit(id)
