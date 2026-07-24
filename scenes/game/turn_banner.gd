class_name TurnBanner
extends CanvasLayer
## 화면 상단 중앙 배너. 두 모드: NPC 세력 진행 배너("○○ 진행 중…", 지속) + 플레이어 턴 시작 알림
## ("플레이어 턴입니다", 양피지·자동 페이드). 두 박스는 동시에 뜨지 않는다. → docs/spec/features/turn.md
## UI는 코드로 구성한다(toast와 같은 패턴, 별도 .tscn 없음). 입력은 통과시킨다(관전).

const HOLD := 2.4    # 알림 표시 유지(초)
const FADE := 0.6    # 알림 페이드 아웃(초) — 합 ≈ 3초
var _label: Label          # NPC 진행 배너 라벨
var _box: Control          # NPC 진행 배너 박스(어두운 브레이드)
var _herald_label: Label   # 플레이어 턴 알림 라벨
var _herald: Control       # 플레이어 턴 알림 박스(양피지, 페이드용 modulate.a)
var _tween: Tween

func _ready() -> void:
	layer = 80
	_build()
	hide()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 배너는 클릭을 막지 않는다
	add_child(root)

	# NPC 진행 배너(어두운 브레이드 박스)
	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 72)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)

	_label = Label.new()
	_label.theme_type_variation = &"LabelXL"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_label)

	# 플레이어 턴 시작 알림(양피지 박스 — toast와 같은 크림 양피지)
	_herald = PanelContainer.new()
	_herald.theme_type_variation = &"ParchmentPanel"   # 크림 양피지 배경(중세풍 테마)
	_herald.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 72)
	_herald.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_herald.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_herald)

	_herald_label = Label.new()
	_herald_label.theme_type_variation = &"LabelXL"   # 굵은 헤딩(28)
	_herald_label.add_theme_color_override("font_color", Color(0.28, 0.2, 0.12))   # 양피지 위 어두운 글자색
	_herald_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_herald.add_child(_herald_label)

## NPC 진행 배너: 그 세력 이름을 세력색으로 채우고 보인다(알림 박스는 감춘다).
func set_faction(text: String, color: Color) -> void:
	_stop_tween()
	_herald.hide()
	_label.text = "%s 진행 중…" % text
	_label.add_theme_color_override("font_color", color)
	_box.show()
	show()

## 플레이어 턴 시작 알림: 양피지 배너를 띄우고 유지 후 페이드 아웃한다(진행 배너 박스는 감춘다).
func announce(text: String) -> void:
	_stop_tween()
	_box.hide()
	_herald_label.text = text
	_herald.modulate.a = 1.0
	_herald.show()
	show()
	_tween = create_tween()
	_tween.tween_interval(HOLD)
	_tween.tween_property(_herald, "modulate:a", 0.0, FADE)
	_tween.tween_callback(hide)

## 배너를 감춘다(두 박스 모두, 진행 중 페이드도 중단).
func clear() -> void:
	_stop_tween()
	hide()

## 진행 중인 알림 페이드 Tween이 있으면 중단한다.
func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
