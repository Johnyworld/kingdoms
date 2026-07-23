extends GutTest
## 턴 HUD(turn_hud.gd) — "명령 남음 N" 표시. 표시/숨김·클릭 시그널만 확인
## (다음 유닛 순환·카메라 포커스·선택은 game.gd 배선이라 실제 실행으로 확인).

const TurnHudScript = preload("res://scenes/turn/turn_hud.gd")

var hud

func before_each() -> void:
	hud = TurnHudScript.new()
	add_child_autofree(hud)

func test_set_commands_left_shows_count() -> void:
	hud.set_commands_left(3)
	assert_string_contains(hud._cmd_btn.text, "3", "명령 남음 표시에 부대 수 포함")
	assert_true(hud._cmd_btn.visible, "명령 남음 > 0이면 표시 보임")

func test_zero_hides_indicator() -> void:
	hud.set_commands_left(0)
	assert_false(hud._cmd_btn.visible, "명령 남음 0이면 표시 숨김")

func test_click_emits_next_unit() -> void:
	hud.set_commands_left(2)
	watch_signals(hud)
	hud._cmd_btn.pressed.emit()
	assert_signal_emitted(hud, "next_unit", "명령 남음 클릭 시 next_unit 방출")
