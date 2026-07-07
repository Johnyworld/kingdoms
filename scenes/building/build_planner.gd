class_name BuildPlanner
extends RefCounted
## 건물 배치 유효성 판정 유틸. 시각 요소 없는 static 함수 모음(HexGrid와 같은 성격).
## footprint(7헥스) 계산 · 영지 시야(완성 건물만) 합집합 · 배치 가능 여부를 제공한다.
## 헥스 인접·반경은 엔진(TileMapLayer/HexGrid)에 위임하므로 실제 헥스 타일셋을 가진 TileMapLayer를 넘겨야 한다.

## 중심 + 이웃 6칸(총 7헥스). Building의 점유 셀과 같은 규칙.
static func footprint(terrain: TileMapLayer, center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	for n in terrain.get_surrounding_cells(center):
		cells.append(n)
	return cells

## 영지의 완성 건물들 시야(각 center_cell 기준 vision 반경) 합집합 { cell: true }.
## 건설 중 건물은 시야에 기여하지 않는다.
## territory는 Territory지만 순환 타입 참조를 피하려 untyped로 둔다.
static func territory_vision(terrain: TileMapLayer, territory, map_w: int, map_h: int) -> Dictionary:
	var vis := {}
	for building in territory.buildings:
		if not building.is_complete():
			continue
		for c in HexGrid.cells_within(terrain, building.center_cell(), building.vision, map_w, map_h):
			vis[c] = true
	return vis

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
static func can_place(terrain: TileMapLayer, center: Vector2i, map_w: int, map_h: int, vision_cells: Dictionary, occupied: Dictionary) -> bool:
	for c in footprint(terrain, center):
		if c.x < 0 or c.x >= map_w or c.y < 0 or c.y >= map_h:
			return false
		if not vision_cells.has(c):
			return false
		if occupied.has(c):
			return false
	return true
