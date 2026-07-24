class_name Modal
extends CanvasLayer
## 공용 모달 기반. 딤 백드롭 + 제목 바 + 우측 상단 X 버튼. 콘텐츠는 호출자가 set_content로 주입(컴포지션).
## 열려 있는 동안 ModalStack에 등록돼 뒤 화면(지도) 입력을 막고, ESC·중첩을 스택 기준으로 처리한다.
## 캠프 메뉴·턴 HUD처럼 chrome을 코드로 구성한다(별도 .tscn 없음). → docs/spec/features/modal.md

signal opened
signal closed

const BASE_LAYER := 100   # 모달은 게임 UI 위. 중첩 시 스택 깊이만큼 더 올린다.
const UI_SHEET := "res://assets/ui/darkages/32x32-Tilesheet@3x.png"
const CLOSE_ICON_REGION := Rect2(228, 708, 21, 24)   # 시트의 X 아이콘(@3x)

var title := "" : set = set_title
var dismissible := true   # false면 X 버튼(또는 콘텐츠 버튼)으로만 닫힘 — 선택 강제 모달용

var _backdrop: ColorRect
var _panel: PanelContainer            # 중앙 창. 중세풍 테마의 OrnatePanel(금장 프레임) 변형을 쓴다
var _title_label: Label
var _close_button: Button
var _content_area: MarginContainer   # 주입 콘텐츠 한 개를 담는다
var _open := false

func _ready() -> void:
	visible = false
	_build()

func set_title(t: String) -> void:
	title = t
	if _title_label != null:
		_title_label.text = t

## 콘텐츠 영역의 자식을 교체한다(기존 콘텐츠 제거 후 새것 추가).
func set_content(control: Control) -> void:
	for c in _content_area.get_children():
		_content_area.remove_child(c)
		c.queue_free()
	_content_area.add_child(control)

## 표시하고 스택에 push한다. layer는 스택 깊이에 따라 부여(뒤 모달 위).
func open() -> void:
	if _open:
		return
	_open = true
	ModalStack.push(self)
	layer = BASE_LAYER + ModalStack.depth()
	visible = true
	opened.emit()

## 숨기고 스택에서 pop한 뒤 closed를 방출한다. 이미 닫혀 있으면 아무것도 안 한다.
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	ModalStack.pop(self)
	closed.emit()

func is_open() -> bool:
	return _open

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.45)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_bg_input)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"OrnatePanel"   # 금장 장식 프레임(중세풍 테마)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	# 제목 바: [제목] ---- [X]
	var header := HBoxContainer.new()
	vbox.add_child(header)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"LabelLG"
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_close_button = Button.new()
	_close_button.icon = _close_icon()   # 중세풍 테마의 X 아이콘(없으면 텍스트 "X" 폴백)
	if _close_button.icon == null:
		_close_button.text = "X"
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	vbox.add_child(HSeparator.new())

	_content_area = MarginContainer.new()
	# 주입 콘텐츠가 EXPAND_FILL을 쓰면 콘텐츠 영역이 늘어나도록(콘텐츠가 스스로 크기를 정하면 무영향).
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content_area)

## 시트에서 X 아이콘 AtlasTexture를 만든다. 시트 로드 실패 시 null(텍스트 "X" 폴백).
func _close_icon() -> Texture2D:
	var sheet := load(UI_SHEET) as Texture2D
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = CLOSE_ICON_REGION
	return atlas

## 배경 좌클릭으로만 닫는다(dismissible일 때). 휠·우클릭은 무시.
func _on_bg_input(event: InputEvent) -> void:
	if not dismissible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

## ESC: dismissible이고 스택 최상단일 때만 닫는다(중첩 시 맨 위 모달만 반응).
func _unhandled_key_input(event: InputEvent) -> void:
	if not _open or not dismissible:
		return
	if ModalStack.top() != self:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## 해제 시 스택에 남지 않도록 정리(모달을 닫지 않고 free한 경우 대비).
func _exit_tree() -> void:
	if _open:
		_open = false
		ModalStack.pop(self)
