class_name BuildPlanner
extends RefCounted
## 건물 배치 유효성 판정 유틸. 시각 요소 없는 static 함수 모음(HexGrid와 같은 성격).
## footprint(7헥스) 계산 · 영지 시야(완성 건물만) 합집합 · 배치 가능 여부를 제공한다.
## 헥스 인접·반경은 엔진(TileMapLayer/HexGrid)에 위임하므로 실제 헥스 타일셋을 가진 TileMapLayer를 넘겨야 한다.

## 건물이 차지하는 셀. hexes <= 1이면 중심 1칸만, 아니면 중심 + 이웃 6칸(총 7헥스).
## hexes는 종류의 카탈로그 footprint. Building의 점유 셀과 같은 규칙.
static func footprint(terrain: TileMapLayer, center: Vector2i, hexes := 7) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	if hexes <= 1:
		return cells
	for n in terrain.get_surrounding_cells(center):
		cells.append(n)
	return cells

## 건물 목록의 완성 건물들 시야(각 center_cell 기준 vision 반경) 합집합 { cell: true }.
## 건설 중 건물은 시야에 기여하지 않는다. fog 계산(맵의 모든 건물)·영지 시야(영지 건물)가 공유한다.
static func buildings_vision(terrain: TileMapLayer, buildings: Array, map_w: int, map_h: int) -> Dictionary:
	var vis := {}
	for building in buildings:
		if not building.is_complete():
			continue
		for c in HexGrid.cells_within(terrain, building.center_cell(), building.vision, map_w, map_h):
			vis[c] = true
	return vis

## 영지의 완성 건물들 시야 합집합. buildings_vision을 영지의 건물 목록으로 부른다.
## territory는 Territory지만 순환 타입 참조를 피하려 untyped로 둔다.
static func territory_vision(terrain: TileMapLayer, territory, map_w: int, map_h: int) -> Dictionary:
	return buildings_vision(terrain, territory.buildings, map_w, map_h)

## type_id의 선행건물(prerequisite)이 그 영지에서 충족됐는지.
## 선행이 ""(없음)이면 항상 참. 아니면 영지에 선행 종류의 완성 건물이 하나라도 있으면 참(건설 중은 미충족).
## territory는 Territory지만 순환 타입 참조를 피하려 untyped로 둔다.
static func prerequisite_met(territory, type_id: String) -> bool:
	var prereq: String = BuildingTypes.get_type(type_id).get("prerequisite", "")
	if prereq == "":
		return true
	for b in territory.buildings:
		if b.building_type == prereq and b.is_complete():
			return true
	return false

## 건물 목록의 점유 셀(building.cells) 합집합 { cell: true }. 겹침 검사에 쓴다.
static func occupied_cells(buildings: Array) -> Dictionary:
	var occ := {}
	for b in buildings:
		for c in b.cells:
			occ[c] = true
	return occ

## center에 건물을 놓을 수 있는지. footprint 7헥스가 모두
## ① 맵 범위 [0, map_w) x [0, map_h) 안 ② 시야(vision_cells) 안 ③ occupied(기존 건물 점유 셀)와 미겹침
## 이면 참. 하나라도 위반하면 거짓(맵 가장자리라 이웃이 범위를 벗어나면 배치 불가).
static func can_place(terrain: TileMapLayer, center: Vector2i, map_w: int, map_h: int, vision_cells: Dictionary, occupied: Dictionary, hexes := 7) -> bool:
	for c in footprint(terrain, center, hexes):
		if c.x < 0 or c.x >= map_w or c.y < 0 or c.y >= map_h:
			return false
		if not vision_cells.has(c):
			return false
		if occupied.has(c):
			return false
	return true
