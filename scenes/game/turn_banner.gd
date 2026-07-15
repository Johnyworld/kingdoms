class_name TurnBanner
extends CanvasLayer
## 현재 행동 중인 세력을 화면 상단 중앙에 표시하는 배너("○○ 진행 중…"). → docs/spec/features/turn.md
## UI는 코드로 구성한다(toast와 같은 패턴, 별도 .tscn 없음). 입력은 통과시킨다(관전).

var _label: Label
var _box: Control

func _ready() -> void:
	layer = 80
	_build()
	hide()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 배너는 클릭을 막지 않는다
	add_child(root)

	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 72)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 26)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_label)

## 배너에 그 세력 이름을 세력색으로 채우고 보인다.
func set_faction(text: String, color: Color) -> void:
	_label.text = "%s 진행 중…" % text
	_label.add_theme_color_override("font_color", color)
	show()

## 배너를 감춘다(플레이어 조작 중 등).
func clear() -> void:
	hide()
