extends GutTest
## 전투 하단 HUD(lang_hud) 세력·부대 표기 세터 테스트.
## Control이라 add_child로 _ready(라벨 구성)를 트리거한 뒤 세터 결과를 검증한다.

const HudScript = preload("res://scenes/lang_battle/lang_hud.gd")

func _hud() -> Control:
	var h: Control = HudScript.new()
	add_child_autofree(h)   # _ready → 3분할 라벨·포트레이트 구성
	return h

func test_matchup_title_shows_both_factions() -> void:
	var h := _hud()
	h.set_matchup_title("푸른 왕국", "암흑 제국")
	var t: String = h._mid_title.text
	assert_true(t.contains("푸른 왕국") and t.contains("암흑 제국"), "중앙 제목에 두 세력명 포함")

func test_party_name_label() -> void:
	var h := _hud()
	h.set_party_name(0, "1보병대")
	h.set_party_name(1, "오크 전사대")
	assert_eq(h._party_lbl[0].text, "1보병대", "side0 부대명 라벨")
	assert_eq(h._party_lbl[1].text, "오크 전사대", "side1 부대명 라벨")

func test_banner_color_stored() -> void:
	var h := _hud()
	h.set_banner_color(0, Color.html("#334DCC"))
	h.set_banner_color(1, Color.html("#803D99"))
	assert_eq(h._banner[0], Color.html("#334DCC"), "side0 배너색 저장")
	assert_eq(h._banner[1], Color.html("#803D99"), "side1 배너색 저장")

func test_party_name_default_empty() -> void:
	# 폴백(정체성 없는 전투)에선 세터 미호출 → 부대 라벨은 빈 문자열.
	var h := _hud()
	assert_eq(h._party_lbl[0].text, "", "초기 부대 라벨 빈 문자열")
	assert_eq(h._party_lbl[1].text, "", "초기 부대 라벨 빈 문자열")
