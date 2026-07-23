extends GutTest
## 턴 배너(turn_banner.gd) — NPC 세력 진행 배너 + 플레이어 턴 시작 알림. 표시/감춤·박스 전환만 확인(연출 타이밍은 game.gd 실행 확인).

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

func test_announce_shows_text() -> void:
	banner.announce("플레이어 턴입니다")
	assert_string_contains(banner._herald_label.text, "플레이어 턴입니다", "알림 라벨에 문구 표시")
	assert_true(banner.visible, "announce 후 배너 보임")

func test_announce_swaps_to_herald_box() -> void:
	banner.announce("플레이어 턴입니다")
	assert_false(banner._box.visible, "announce는 NPC 진행 배너 박스를 숨김")
	assert_true(banner._herald.visible, "announce는 알림 박스를 보임")

func test_set_faction_swaps_to_faction_box() -> void:
	banner.announce("플레이어 턴입니다")
	banner.set_faction("초원 칸국", Color(0.2, 0.7, 0.2))
	assert_true(banner._box.visible, "set_faction은 NPC 진행 배너 박스를 보임")
	assert_false(banner._herald.visible, "set_faction은 알림 박스를 숨김")

func test_clear_hides_after_announce() -> void:
	banner.announce("플레이어 턴입니다")
	banner.clear()
	assert_false(banner.visible, "announce 후 clear 하면 배너 감춤")
