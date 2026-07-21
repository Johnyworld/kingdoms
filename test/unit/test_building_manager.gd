extends GutTest
## BuildingManager — 건물/영지 목록·거점 소유권 이전·파괴·철거·1차 생산·캠프 개척 테스트.
## host = 테스트 노드(생성 건물이 트리에 붙고 테스트 종료 시 함께 정리). 연출(토스트·안개)은 game.gd 몫이라 여기 없음.

const MAP := 41
const BuildingScript = preload("res://scenes/building/building.gd")
const ManagerScript = preload("res://scenes/building/building_manager.gd")

var terrain: TileMapLayer
var host: Node2D
var player: Faction
var mgr

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	host = Node2D.new()
	add_child_autofree(host)   # 생성 건물은 host 자식 → host와 함께 정리
	player = load("res://scenes/faction/faction.gd").new("플레이어", Color.GOLD)
	mgr = ManagerScript.new(terrain, MAP, MAP, host)
	mgr.player_faction = player

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

## faction 소속 영지+거점(type_id)을 만들어 등록한다. faction이 player면 buildings/territories, 아니면 npc_buildings.
func _center_building(faction: Faction, cell: Vector2i, type_id := "camp") -> Node2D:
	var b: Node2D = BuildingScript.new()
	host.add_child(b)
	b.setup(terrain, cell, type_id)
	var t = load("res://scenes/territory/territory.gd").new("%s 영지" % faction.name, {})
	faction.add_territory(t)
	t.add_building(b)
	if faction == player:
		mgr.buildings.append(b)
		mgr.territories.append(t)
	else:
		mgr.npc_buildings.append(b)
	return b

func _npc_faction(pname := "적국") -> Faction:
	return load("res://scenes/faction/faction.gd").new(pname, Color.RED)

# --- 목록 / 조회 ---

func test_all_and_at_queries() -> void:
	var mine := _center_building(player, _center(), "town_hall")
	var enemy := _center_building(_npc_faction(), _center() + Vector2i(10, 0))
	assert_eq(mgr.all(), [mine, enemy], "all = 플레이어 + NPC")
	assert_eq(mgr.building_at(mine.center_cell()), mine, "플레이어 건물 조회")
	assert_null(mgr.building_at(enemy.center_cell()), "NPC 거점은 building_at 대상 아님")
	assert_eq(mgr.npc_building_at(enemy.center_cell()), enemy, "발견된 NPC 거점 조회")
	enemy.visible = false
	assert_null(mgr.npc_building_at(enemy.center_cell()), "미발견(가려진) NPC 거점 제외")

# --- 소유권 이전(transfer_camp) ---

func test_transfer_camp_npc_to_player() -> void:
	var foe := _npc_faction()
	var camp := _center_building(foe, _center())
	var r: Dictionary = mgr.transfer_camp(camp, player)
	assert_eq(r["old_faction_name"], "적국", "이전 소유 세력 이름 반환")
	assert_eq(r["territory_name"], "적국 영지", "영지 이름 반환(토스트용)")
	assert_true(camp in mgr.buildings, "플레이어 건물 목록으로 이동")
	assert_false(camp in mgr.npc_buildings, "NPC 목록에서 제거")
	assert_true(camp.territory in mgr.territories, "플레이어 영지는 수입 대상 편입")
	assert_eq(camp.faction(), player, "영지 세력 = 플레이어")

func test_transfer_camp_player_to_npc() -> void:
	var camp := _center_building(player, _center())
	var terr = camp.territory
	var foe := _npc_faction()
	mgr.transfer_camp(camp, foe)
	assert_true(camp in mgr.npc_buildings, "NPC 목록으로 이동")
	assert_false(camp in mgr.buildings, "플레이어 목록에서 제거")
	assert_false(terr in mgr.territories, "잃은 영지는 수입에서 제외")
	assert_eq(camp.faction(), foe, "영지 세력 = NPC")

# --- 파괴 / 철거 ---

func test_destroy_camp_detaches_and_returns_name() -> void:
	var camp := _center_building(_npc_faction(), _center())
	var terr = camp.territory
	assert_eq(mgr.destroy_camp(camp), "적국 영지", "영지 이름 반환")
	assert_false(camp in mgr.npc_buildings, "목록에서 제거")
	assert_false(camp in terr.buildings, "영지에서 분리")

func test_demolish_building_refunds_and_removes() -> void:
	var center := _center_building(player, _center(), "town_hall")
	var farm: Node2D = BuildingScript.new()
	host.add_child(farm)
	farm.setup(terrain, _center() + Vector2i(5, 0), "farm")   # 완성 농장(salvage 목재 1)
	center.territory.add_building(farm)
	mgr.buildings.append(farm)
	mgr.demolish_building(farm)
	assert_false(farm in mgr.buildings, "목록에서 제거")
	assert_eq(center.territory.resources.get("목재", 0), 1, "salvage 환급(농장 목재 1)")

func test_demolish_camp_territory_removes_all() -> void:
	var camp := _center_building(player, _center())
	var terr = camp.territory
	var farm: Node2D = BuildingScript.new()
	host.add_child(farm)
	farm.setup(terrain, _center() + Vector2i(5, 0), "farm")
	terr.add_building(farm)
	mgr.buildings.append(farm)
	assert_eq(mgr.demolish_camp_territory(camp), "플레이어 영지", "영지 이름 반환")
	assert_false(camp in mgr.buildings, "캠프 제거")
	assert_false(farm in mgr.buildings, "영지의 다른 건물도 제거")
	assert_false(terr in mgr.territories, "수입 목록에서 제외")
	assert_false(terr in player.territories, "세력에서 영지 분리")

# --- 개척(found_camp) ---

func test_found_camp_monotonic_names() -> void:
	var b1: Node2D = mgr.found_camp(_center())
	var b2: Node2D = mgr.found_camp(_center() + Vector2i(10, 0))
	assert_eq(b1.territory.name, "전초기지 1", "첫 전초기지 이름")
	assert_eq(b2.territory.name, "전초기지 2", "이름 단조 증가")
	assert_false(b1.is_complete(), "건설 중 캠프")
	assert_eq(b1.faction(), player, "플레이어 세력 편입")
	assert_true(b1 in mgr.buildings and b1.territory in mgr.territories, "건물·수입 목록 등록")
	assert_eq(b1.get_parent(), host, "host에 노드 부착")

# --- 배치(place_building) / 생산 배정 ---

func test_place_building_primary_assigns_nearest_center() -> void:
	var center := _center_building(player, _center(), "town_hall")
	var far_center := _center_building(player, _center() + Vector2i(15, 0), "town_hall")
	var b: Node2D = mgr.place_building(_center() + Vector2i(3, 0), "lumberjack", center.territory)
	assert_eq(b.assigned_center, center, "최근접 완성 플레이어 거점에 배정")
	assert_ne(b.assigned_center, far_center, "먼 거점 아님")
	assert_eq(b.territory, center.territory, "소속 영지 = 배정 거점 영지")
	assert_true(b in mgr.buildings, "목록 등록")
	assert_false(b.is_complete(), "건설 중으로 생성")

func test_place_building_non_production_joins_given_territory() -> void:
	var center := _center_building(player, _center(), "town_hall")
	var b: Node2D = mgr.place_building(_center() + Vector2i(3, 0), "house", center.territory)
	assert_null(b.assigned_center, "비생산 건물은 배정 없음")
	assert_eq(b.territory, center.territory, "지정 영지 편입")

func test_center_distance_and_cycle() -> void:
	var c1 := _center_building(player, _center(), "town_hall")
	var c2 := _center_building(player, _center() + Vector2i(10, 0), "town_hall")
	var b: Node2D = mgr.place_building(_center() + Vector2i(3, 0), "lumberjack", c1.territory)
	assert_eq(b.assigned_center, c1, "최근접 c1 배정")
	assert_eq(mgr.center_distance(b), 3, "같은 행 3칸 = 헥스 거리 3")
	assert_true(mgr.cycle_production_center(b), "[거점 변경] 성공")
	assert_eq(b.assigned_center, c2, "다음 거점으로 순환")
	assert_eq(b.territory, c2.territory, "소속 영지도 이동")
	# 거점 1개뿐이면 변경 불가
	mgr.buildings.erase(c1)
	assert_false(mgr.cycle_production_center(b), "거점 1개면 변경 없음")

func test_tick_production_accrues_to_assigned_territory() -> void:
	var center := _center_building(player, _center(), "town_hall")
	var b: Node2D = mgr.place_building(_center() + Vector2i(3, 0), "lumberjack", center.territory)
	for i in 10:
		b.advance_construction()   # 완성시켜 생산 개시(건설 중엔 생산 없음)
	assert_true(b.is_complete(), "완성")
	for i in 3:
		mgr.tick_production()   # 거리 3 → 3턴마다 목재 1
	assert_eq(center.territory.resources.get("목재", 0), 1, "3턴 후 목재 1 산출(배정 거점 영지)")
