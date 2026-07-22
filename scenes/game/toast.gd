class_name Toast
extends CanvasLayer
## 화면 상단 중앙에 잠깐 뜨는 알림 메시지(점령/함락/파괴 등). 잠시 표시 후 페이드 아웃한다.
## UI는 코드로 구성한다(result_overlay·party_action_menu와 같은 패턴, 별도 .tscn 없음). 입력은 통과시킨다.

const HOLD := 2.0    # 표시 유지 시간(초)
const FADE := 0.6    # 페이드 아웃 시간(초)

var _label: Label
var _box: Control    # 페이드용 컨테이너(modulate.a)
var _tween: Tween

func _ready() -> void:
	layer = 90
	_build()
	hide()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 알림은 클릭을 막지 않는다
	add_child(root)

	_box = PanelContainer.new()
	_box.theme_type_variation = &"ParchmentPanel"   # 양피지 배경(중세풍 테마)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)

	_label = Label.new()
	_label.theme_type_variation = &"ParchmentLabel"   # 밝은 양피지 위 어두운 글자
	_label.add_theme_font_size_override("font_size", 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_label)

## 메시지를 띄운다. 이전 알림이 떠 있으면 교체하고, 유지 후 페이드 아웃한다.
func show_message(text: String) -> void:
	_label.text = text
	_box.modulate.a = 1.0
	show()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD)
	_tween.tween_property(_box, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)
