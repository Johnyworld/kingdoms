extends CanvasLayer
## 턴 HUD. 화면 우측 아래에 현재 턴 번호와 "턴 종료" 버튼을 표시한다.
## 캠프 메뉴(camp_menu.gd)처럼 UI를 코드로 구성한다(별도 .tscn 없음).

## 턴 종료 버튼을 누르면 방출. game.gd가 받아 TurnManager.end_turn을 실행한다.
signal ended

const MARGIN := 16

var _turn_label: Label

func _ready() -> void:
	layer = 32
	_build()

## 우측 아래에 세로로 [턴 번호] + [턴 종료 버튼]을 쌓는다.
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 6)
	root.add_child(box)

	_turn_label = Label.new()
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_turn_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_turn_label)

	var end_btn := Button.new()
	end_btn.text = "턴 종료"
	end_btn.custom_minimum_size = Vector2(120, 44)
	end_btn.pressed.connect(func() -> void: ended.emit())
	box.add_child(end_btn)

	set_turn(1)

## 표시 턴 번호를 갱신한다.
func set_turn(number: int) -> void:
	_turn_label.text = "턴 %d" % number
