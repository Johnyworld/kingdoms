extends CanvasLayer
## 턴 HUD. 화면 우측 아래에 현재 턴 번호와 "턴 종료" 버튼을 표시한다.
## 캠프 메뉴(camp_menu.gd)처럼 UI를 코드로 구성한다(별도 .tscn 없음).

## 턴 종료 버튼을 누르면 방출. game.gd가 받아 TurnManager.end_turn을 실행한다.
signal ended
## "명령 남음 N"을 누르면 방출. game.gd가 받아 다음 명령 가능 부대로 포커스·선택한다. → turn.md
signal next_unit

const MARGIN := 16

var _turn_label: Label
var _grace_box: VBoxContainer   # 소멸 위기 세력 목록(턴 라벨 위)
var _cmd_btn: Button            # "명령 남음 N"(턴 종료 왼쪽). 0이면 숨김. → turn.md

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

	# 소멸 위기 세력 목록(턴 번호 위). 우측 정렬, 기본 비어 있음.
	_grace_box = VBoxContainer.new()
	_grace_box.alignment = BoxContainer.ALIGNMENT_END
	_grace_box.add_theme_constant_override("separation", 2)
	box.add_child(_grace_box)

	_turn_label = Label.new()
	_turn_label.theme_type_variation = &"LabelLG"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_turn_label)

	# 턴 종료 버튼과 그 왼쪽 "명령 남음 N"을 한 줄로. 우측 정렬이라 명령 표시가 버튼 왼쪽에 붙는다.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	_cmd_btn = Button.new()
	_cmd_btn.pressed.connect(func() -> void: next_unit.emit())
	row.add_child(_cmd_btn)

	var end_btn := Button.new()
	end_btn.text = "턴 종료"
	end_btn.custom_minimum_size = Vector2(120, 44)
	end_btn.pressed.connect(func() -> void: ended.emit())
	row.add_child(end_btn)

	set_turn(1)
	set_commands_left(0)

## 표시 턴 번호를 갱신한다.
func set_turn(number: int) -> void:
	_turn_label.text = "턴 %d" % number

## "명령 남음 N" 표시를 갱신한다. 0이면 숨긴다(모두 소진). → turn.md
func set_commands_left(count: int) -> void:
	_cmd_btn.text = "명령 남음 %d" % count
	_cmd_btn.visible = count > 0

## 소멸 위기 세력 목록을 갱신한다. entries: [{text, color}]. 비면 아무것도 표시하지 않는다.
func set_grace(entries: Array) -> void:
	for child in _grace_box.get_children():
		child.free()   # 즉시 제거(다음 프레임까지 낡은 줄이 남지 않도록)
	for e in entries:
		var label := Label.new()
		label.text = e["text"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_color", e["color"])
		_grace_box.add_child(label)
