extends SceneTree
## 임시 캡처 스크립트: game.tscn을 띄우고 몇 프레임 뒤 뷰포트를 PNG로 저장한다.
## 실행: godot -s res://tools/capture.gd   (헤드리스 아님 — 렌더 필요)

var _frames := 0

func _initialize() -> void:
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	get_root().add_child(game)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false
	var img := get_root().get_texture().get_image()
	img.save_png("res://_capture.png")
	print("[capture] saved res://_capture.png")
	quit()
	return true
