extends GutTest
## 턴 배너(turn_banner.gd) — 현재 행동 중인 세력 이름·색 표시. 표시/감춤만 확인(연출 타이밍은 game.gd 실행 확인).

const TurnBannerScript = preload("res://scenes/game/turn_banner.gd")

var banner

func before_each() -> void:
	banner = TurnBannerScript.new()
	add_child_autofree(banner)

func test_set_faction_shows_name() -> void:
	banner.set_faction("암흑 제국", Color(0.5, 0.0, 0.0))
	assert_string_contains(banner._label.text, "암흑 제국", "배너 라벨에 세력 이름 표시")
	assert_true(banner.visible, "set_faction 후 배너 보임")

func test_clear_hides() -> void:
	banner.set_faction("초원 칸국", Color(0.2, 0.7, 0.2))
	banner.clear()
	assert_false(banner.visible, "clear 후 배너 감춤")
