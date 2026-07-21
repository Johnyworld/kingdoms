extends GutTest
## 거점 건물 위 세력색 깃발: 완성 거점에만 뜨고(모듈레이트=세력색), 비거점·건설 중엔 없음/숨김.
## 깃발은 buildings_layer가 있을 때만 생성된다(렌더 건물과 짝).

const ELEMENTS := "res://assets/tiles/lapetite/Tilesets/Tileset_Elements.tres"
const BLUE := Color(0.2, 0.3, 0.8)

var _terrain: TileMapLayer
var _blayer: TileMapLayer

func before_each() -> void:
	_terrain = TileMapLayer.new()
	_terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(_terrain)
	_blayer = TileMapLayer.new()
	_blayer.tile_set = load(ELEMENTS)
	add_child_autofree(_blayer)

## 지정 세력색을 가진 영지에 편입된 building을 만든다.
func _building(type_id: String, under_construction: bool) -> Building:
	var b := Building.new()
	add_child_autofree(b)
	b.setup(_terrain, Vector2i(5, 5), type_id, under_construction, _blayer)
	var fac = load("res://scenes/faction/faction.gd").new("푸른 왕국", BLUE)
	var terr = load("res://scenes/territory/territory.gd").new("창천성", {})
	fac.add_territory(terr)
	terr.add_building(b)   # → territory setter → refresh_body → _update_flag
	return b

func test_complete_center_shows_faction_flag() -> void:
	var b := _building("town_hall", false)
	assert_not_null(b._flag, "완성 거점엔 깃발 생성")
	assert_true(b._flag.visible, "깃발 보임")
	assert_eq(b._flag.modulate, BLUE, "깃발 색 = 세력색")

func test_non_center_has_no_flag() -> void:
	var b := _building("farm", false)
	assert_true(b._flag == null or not b._flag.visible, "비거점(농장)은 깃발 없음/숨김")

func test_under_construction_center_has_no_flag() -> void:
	var b := _building("camp", true)
	assert_true(b._flag == null or not b._flag.visible, "건설 중 거점은 깃발 없음/숨김")

func test_flag_color_follows_faction_change() -> void:
	var b := _building("castle", false)
	var red = load("res://scenes/faction/faction.gd").new("사막 술탄국", Color(0.78, 0.28, 0.22))
	var terr2 = load("res://scenes/territory/territory.gd").new("점령지", {})
	red.add_territory(terr2)
	terr2.add_building(b)   # 세력 이전 → setter → 깃발 색 갱신
	assert_eq(b._flag.modulate, Color(0.78, 0.28, 0.22), "세력 바뀌면 깃발 색도 갱신")
