class_name BuildingManager
extends RefCounted
## 건물·영지 도메인 계층 — 건물/영지 목록(단일 출처), 거점 소유권 이전·파괴·철거, 1차 생산 틱/배정, 캠프 개척.
## game.gd에서 분리했다. 연출·UI(토스트·안개 갱신·정보 패널·확인 다이얼로그·건설 모드 입력)는 game.gd가 맡는다.
## 새 Building 노드는 host(게임 씬 루트)에 add_child로 붙인다. → docs/spec/features/production.md · building.md · camp-capture.md

var terrain: TileMapLayer
var map_w: int
var map_h: int
var host: Node                # 새 Building 노드를 붙일 부모(game 씬 루트)
var buildings_layer: TileMapLayer   # 거점 건물 오토타일 공유 레이어(없으면 폴리곤 폴백 — 테스트 등)
var player_faction: Faction   # 소유권(수입 대상·생산 배정) 판정 기준. game.gd _setup_factions가 채운다.

var buildings: Array = []       # 플레이어 건물(거점 + 생산 건물). 시야 합산·건축·수입 추적 대상.
var npc_buildings: Array = []   # NPC 세력 거점(캠프). 수입 제외, 탐험 표시 대상.
var territories: Array = []     # 자원 수입을 받는 영지(플레이어). NPC 영지는 미포함(경제 미사용).
var _outpost_count := 0         # 캠프 건설로 만든 전초기지 수(이름 단조 증가 카운터).

func _init(p_terrain: TileMapLayer, p_map_w: int, p_map_h: int, p_host: Node, p_buildings_layer: TileMapLayer = null) -> void:
	terrain = p_terrain
	map_w = p_map_w
	map_h = p_map_h
	host = p_host
	buildings_layer = p_buildings_layer

## 맵의 모든 건물(플레이어 + NPC 거점). 건물 전체 순회의 단일 출처.
func all() -> Array:
	return buildings + npc_buildings

## 셀을 점유한 플레이어 건물(없으면 null). 캠프·건설된 농장 모두 buildings에 있다.
func building_at(cell: Vector2i) -> Building:
	for b in buildings:
		if b.contains_cell(cell):
			return b
	return null

## 그 셀을 포함하는 NPC 거점(없으면 null). 아직 발견 안 돼 가려진(visible == false) 거점은 제외한다.
func npc_building_at(cell: Vector2i) -> Building:
	for b in npc_buildings:
		if b.visible and b.contains_cell(cell):
			return b
	return null

# --- 소유권 / 생명주기 ---

## 소유권 이전(점령 흡수, 플레이어·NPC 공용): 캠프의 영지를 new_faction으로 옮기고 건물·수입 목록을 재배치한다.
## 플레이어면 buildings(시야·건축·수입 획득), NPC면 npc_buildings(수입 제외).
## 반환 {territory_name, old_faction_name} — 토스트(점령/함락)·표시 갱신은 호출부(game.gd)가 한다.
func transfer_camp(camp, new_faction) -> Dictionary:
	var territory = camp.territory
	var terr_name: String = territory.name if territory != null else ""
	var old_name: String = camp.faction_name()
	if territory != null:
		territory.transfer_to(new_faction)   # 이전 세력 분리 → 편입(소유권 이전 단일 출처)
	buildings.erase(camp)
	npc_buildings.erase(camp)
	if new_faction == player_faction:
		buildings.append(camp)
		if territory != null and not (territory in territories):
			territories.append(territory)   # 플레이어 영지는 턴 수입 대상
	else:
		npc_buildings.append(camp)
		if territory != null:
			territories.erase(territory)    # 잃은 영지는 수입에서 제외
	return {"territory_name": terr_name, "old_faction_name": old_name}

## 파괴: 캠프를 영지·맵에서 제거한다(획득 없음). 영지·세력은 남지만 캠프 0개가 된다. 영지 이름 반환(토스트용).
func destroy_camp(camp) -> String:
	var terr_name: String = camp.territory.name if camp.territory != null else ""
	if camp.territory != null:
		camp.territory.remove_building(camp)
	npc_buildings.erase(camp)
	camp.queue_free()
	return terr_name

## 건물 철거: 영지에서 떼고 환급(Territory.demolish — refund_on_demolish) 후 목록 제거·노드 지연 free.
## (버튼 pressed 처리 중 즉시 free하면 "locked" 에러라 call_deferred.)
func demolish_building(b) -> void:
	if b.territory != null:
		b.territory.demolish(b)
	buildings.erase(b)
	b.queue_free.call_deferred()

## 캠프 철거(영지 포기): 그 영지의 모든 건물을 제거하고 영지를 세력·수입에서 분리한다(환급 없음). 영지 이름 반환.
func demolish_camp_territory(camp) -> String:
	var territory = camp.territory
	var terr_name: String = territory.name if territory != null else "영지"
	if territory != null:
		for b in territory.buildings.duplicate():   # 캠프 포함 모든 건물
			buildings.erase(b)
			territory.remove_building(b)
			if is_instance_valid(b):
				b.queue_free.call_deferred()
		if territory.faction != null:
			territory.faction.remove_territory(territory)   # 세력에서 영지 분리
		territories.erase(territory)   # 수입·플레이어 영지 목록에서 제외
	return terr_name

# --- 건설 / 개척 ---

## 그 셀에 건물을 배치한다(비용 지불·배치 가능 판정은 호출부가 먼저): 건설 중 건물 생성 → 영지 편입 → 등록.
## 1차 생산 건물이면 최근접 플레이어 거점에 배정(폴백 = territory). 생성한 Building 반환.
func place_building(cell: Vector2i, type_id: String, territory) -> Building:
	var b := Building.new()
	host.add_child(b)
	b.setup(terrain, cell, type_id, true, buildings_layer)   # 건설 중으로 생성(레이어 없으면 폴리곤)
	if b.is_primary_production():
		assign_production_building(b, territory)   # 최근접 거점 배정(거리 계산·소속 영지) → production.md
	else:
		territory.add_building(b)
	buildings.append(b)
	return b

## 새 영지를 개척한다: 자원 0인 새 영지("전초기지 N")를 플레이어 세력에 편입하고, 건설 중 캠프를 세운다.
## 비용은 여는 영지가 이미 지불(build_pay). 생성한 캠프 반환. 안개 갱신은 호출부가 한다.
func found_camp(cell: Vector2i) -> Building:
	var territory := Territory.new(_next_outpost_name(), {})
	player_faction.add_territory(territory)
	var b := Building.new()
	host.add_child(b)
	b.setup(terrain, cell, BuildingTypes.CAMP, true, buildings_layer)   # 건설 중 캠프(레이어 없으면 폴리곤)
	territory.add_building(b)
	buildings.append(b)
	territories.append(territory)
	return b

## 새 전초기지 영지 이름("전초기지 N"). 단조 증가 카운터라 영지를 잃어도 이름이 겹치지 않는다.
func _next_outpost_name() -> String:
	_outpost_count += 1
	return "전초기지 %d" % _outpost_count

# --- 1차 생산 (거리 기반) ---

## 1차 생산 건물을 최근접 플레이어 거점에 배정한다: 소속 영지 = 그 거점 영지. 거점 없으면 fallback_territory. → production.md
func assign_production_building(b, fallback_territory) -> void:
	var center = nearest_player_center(b)
	if center == null or center.territory == null:
		fallback_territory.add_building(b)   # 폴백(거점 없음)
		return
	b.assigned_center = center
	center.territory.add_building(b)

## b에서 이동력 경로(BFS)로 가장 가까운 완성 플레이어 거점. 없으면 null. → production.md
func nearest_player_center(b):
	var dists: Dictionary = HexGrid.bfs_distances(terrain, b.center_cell(), map_w + map_h, map_w, map_h, Terrain.IMPASSABLE)
	var best = null
	var best_d := 1 << 30
	for c in buildings:
		if c == b or not (BuildingTypes.is_center(c.building_type) and c.is_complete()):
			continue
		if c.faction() != player_faction:
			continue
		var cc: Vector2i = c.center_cell()
		if dists.has(cc) and int(dists[cc]) < best_d:
			best_d = int(dists[cc])
			best = c
	return best

## 1차 생산 건물 ↔ 배정 거점 경로 거리(헥스 스텝 BFS, 산 등 이동 불가 지형 우회). 배정 없거나 도달 불가면 0(생산 정지). → production.md
func center_distance(b) -> int:
	if b.assigned_center == null:
		return 0
	var dists: Dictionary = HexGrid.bfs_distances(terrain, b.center_cell(), map_w + map_h, map_w, map_h, Terrain.IMPASSABLE)
	return int(dists.get(b.assigned_center.center_cell(), 0))

## [거점 변경] — 다음 플레이어 거점으로 배정을 옮긴다(소속 영지 이동, 거리 재계산). 바꿨으면 true. → production.md
func cycle_production_center(b) -> bool:
	if not b.is_primary_production():
		return false
	var centers := player_centers()
	if centers.size() <= 1:
		return false
	var idx: int = centers.find(b.assigned_center)
	var next = centers[(idx + 1) % centers.size()]
	if next == b.assigned_center:
		return false
	if b.territory != null:
		b.territory.buildings.erase(b)
	b.assigned_center = next
	next.territory.add_building(b)   # 소속 영지 = 새 거점 영지(양방향 포인터)
	return true

## 완성 플레이어 거점 목록(배정 대상). → production.md
func player_centers() -> Array:
	var out: Array = []
	for c in buildings:
		if BuildingTypes.is_center(c.building_type) and c.is_complete() \
				and c.faction() == player_faction:
			out.append(c)
	return out

## 턴 종료 시 완성 1차 생산 건물의 생산포인트를 산출해 배정 거점 영지 자원에 더한다. → production.md
func tick_production() -> void:
	for b in buildings:
		if not (b.is_complete() and b.is_primary_production()) or b.assigned_center == null:
			continue
		var produced: int = b.tick_production(center_distance(b))
		if produced > 0 and b.assigned_center.territory != null:
			b.assigned_center.territory.add_resource(b.produces(), produced)   # changed 방출 경유
