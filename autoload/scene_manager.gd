extends Node
## 화면 전환을 페이드 인/아웃으로 처리하는 싱글턴.
## 이후 모든 씬 전환은 SceneManager.change_scene(path) 로 통일한다.

const FADE_DURATION := 0.4

var _overlay: ColorRect
var _is_transitioning := false

func _ready() -> void:
	# 최상위 CanvasLayer 위에 전체 화면 검은 오버레이를 만든다.
	var layer := CanvasLayer.new()
	layer.layer = 128  # 항상 최상단
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)  # 시작은 투명
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 평소엔 입력 통과
	layer.add_child(_overlay)

## 검게 페이드아웃 → 씬 교체 → 페이드인.
func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # 전환 중 입력 차단

	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await tween.finished

	get_tree().change_scene_to_file(path)
	# 씬 트리 교체가 반영되도록 한 프레임 대기
	await get_tree().process_frame

	var tween_in := create_tween()
	tween_in.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await tween_in.finished

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
