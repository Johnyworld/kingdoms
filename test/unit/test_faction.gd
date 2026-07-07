extends GutTest
## 세력(Faction) 엔티티 테스트 — 속성과 캠프 양방향 연결.

const BLUE := Color(0.2, 0.3, 0.8)

var camp: Node2D

func before_each() -> void:
	camp = load("res://scenes/camp/camp.gd").new()
	add_child_autofree(camp)

func _faction(name := "프랑스", color := BLUE) -> Object:
	return load("res://scenes/faction/faction.gd").new(name, color)

func test_init_sets_name_and_color() -> void:
	var f := _faction("프랑스", BLUE)
	assert_eq(f.name, "프랑스", "생성 시 이름 설정")
	assert_eq(f.color, BLUE, "생성 시 색상 설정")

func test_camps_empty_on_create() -> void:
	var f := _faction()
	assert_eq(f.camps.size(), 0, "생성 직후 소속 캠프는 없음")

func test_add_camp_links_both_ways() -> void:
	var f := _faction()
	f.add_camp(camp)
	assert_true(camp in f.camps, "camps에 캠프가 추가된다")
	assert_eq(camp.faction, f, "camp.faction이 이 세력을 가리킨다(양방향)")

func test_add_camp_no_duplicate() -> void:
	var f := _faction()
	f.add_camp(camp)
	f.add_camp(camp)
	assert_eq(f.camps.size(), 1, "같은 캠프 중복 추가 방지")
