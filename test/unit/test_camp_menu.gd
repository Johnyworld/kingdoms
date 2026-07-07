extends GutTest
## 캠프 메뉴 UI — 캠프 이름/세력 표시와 자원 그리드 채움.

const BLUE := Color(0.2, 0.3, 0.8)

var menu: CanvasLayer
var camp: Node2D

func before_each() -> void:
	menu = load("res://scenes/camp/camp_menu.gd").new()
	add_child_autofree(menu)
	camp = load("res://scenes/camp/camp.gd").new()
	add_child_autofree(camp)

func _with_faction() -> void:
	var f = load("res://scenes/faction/faction.gd").new("프랑스", BLUE)
	camp.camp_name = "파리"
	f.add_camp(camp)

func test_shows_camp_name_and_faction() -> void:
	_with_faction()
	menu.open(camp)
	assert_eq(menu._camp_title.text, "파리", "제목 라벨 = 캠프 이름")
	assert_eq(menu._faction_label.text, "프랑스", "세력 라벨 = 세력명")

func test_faction_label_color() -> void:
	_with_faction()
	menu.open(camp)
	assert_eq(menu._faction_label.get_theme_color("font_color"), BLUE, "세력 라벨 색상 = 세력 색상")

func test_no_faction_empty_label() -> void:
	camp.camp_name = "파리"
	menu.open(camp)
	assert_eq(menu._faction_label.text, "", "세력이 없으면 세력 라벨은 빈 문자열")

func test_resource_grid_filled() -> void:
	_with_faction()
	menu.open(camp)
	# 자원 6종 × 2열(이름/값) = 12개 자식.
	assert_eq(menu._res_grid.get_child_count(), 12, "자원 그리드가 6종으로 채워진다")
