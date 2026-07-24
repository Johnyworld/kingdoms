class_name ResultOverlay
extends CanvasLayer
## 결과(승패) 화면 오버레이. 반투명 배경 + 중앙 패널(제목·부제·안내)을 코드로 구성한다
## (camp_menu·party_action_menu와 같은 패턴, 별도 .tscn 없음). 화면 최상단 레이어.
## 배경 아무 곳이나 클릭하면 dismissed를 방출한다(game.gd가 받아 타이틀로 전환).

signal dismissed

var _title: Label      # 큰 제목(예: "패배")
var _subtitle: Label   # 부제(예: "아젤 하르윈 부대가 전멸했다")

func _ready() -> void:
	layer = 100   # 항상 최상단(전투 오버레이·HUD 위)
	_build()
	hide()

## UI 트리를 코드로 구성한다. 반투명 배경 + 화면 중앙 세로 스택(제목·부제·안내).
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# 반투명 배경 — 클릭을 흡수하고, 클릭하면 닫는다.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_input)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	_title = Label.new()
	_title.theme_type_variation = &"LabelHuge"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"LabelLG"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_subtitle)

	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "클릭하면 타이틀로"
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

## 결과를 표시한다. 제목(큰 글씨)·부제를 채우고 오버레이를 보인다.
func show_result(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	show()

## 배경 좌클릭 → 닫기.
func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dismiss()

## 닫기: 오버레이를 숨기고 dismissed를 방출한다(game.gd가 타이틀 전환). 이미 숨김이면 무시(중복 방지).
func dismiss() -> void:
	if not visible:
		return
	hide()
	dismissed.emit()
