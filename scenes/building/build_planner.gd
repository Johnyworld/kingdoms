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

## type_id의 선행(prerequisite = 거점 티어 id)이 그 영지에서 충족됐는지.
## 선행이 ""(없음)이면 항상 참. 아니면 영지의 거점 티어가 선행 티어 이상인 완성 거점이 있으면 참.
## 건물 존재가 아니라 티어 비교라, 캠프→마을회관→성으로 올려도 하위 티어 선행이 계속 충족된다.
## territory는 Territory지만 순환 타입 참조를 피하려 untyped로 둔다.
static func prerequisite_met(territory, type_id: String) -> bool:
	var prereq: String = BuildingTypes.get_type(type_id).get("prerequisite", "")
	if prereq == "":
		return true
	var need_tier := BuildingTypes.center_tier(prereq)
	if need_tier < 0:
		return false   # 선행은 거점 티어(캠프/마을회관/성)여야 한다. 비거점 선행은 미지원 → 미충족.
	for b in territory.buildings:
		if BuildingTypes.is_center(b.building_type) and b.is_complete() and BuildingTypes.center_tier(b.building_type) >= need_tier:
			return true
	return false

## 그 거점을 다음 티어로 업그레이드할 수 있는지: 다음 티어(next_center)가 있고, 영지가 그 비용(build_cost)을 감당하면 참.
## (거점 업그레이드엔 선행·필요인원 게이트가 없다.) building은 Building이지만 순환 참조를 피해 untyped.
static func can_upgrade(territory, building) -> bool:
	var next_id := BuildingTypes.next_center(building.building_type)
	if next_id == "":
		return false
	return territory != null and territory.can_afford(BuildingTypes.get_type(next_id).get("build_cost", {}))

## 그 영지에 type_id를 지을 수 있는지 종합 판정(자원/조건 게이트, 배치 유효성 can_place와는 별개):
## ① 선행 충족 ② 자재 충분(build_cost). 둘 다 참이어야 참. (required_pop 폐지 — 인구 게이트 없음.)
static func can_build(territory, type_id: String) -> bool:
	if not prerequisite_met(territory, type_id):
		return false
	var spec := BuildingTypes.get_type(type_id)
	return territory.can_afford(spec.get("build_cost", {}))

## 건물 목록의 점유 셀(building.cells) 합집합 { cell: true }. 겹침 검사에 쓴다.
static func occupied_cells(buildings: Array) -> Dictionary:
	var occ := {}
	for b in buildings:
		for c in b.cells:
			occ[c] = true
	return occ

## 완성 건물 발자국의 이동 진입비용 override { cell: cost }. 도시·거점=CITY_MOVE_COST(2), 불가 랜드마크=Terrain.BLOCKED(-1).
## 건설 중 건물은 통행에 영향 없음(제외). HexGrid 이동 계산(cost_distances)의 cell_costs로 넘긴다.
## → docs/spec/features/selection-and-movement.md
static func movement_costs(buildings: Array) -> Dictionary:
	var costs := {}
	for b in buildings:
		if not b.is_complete():
			continue
		var mc := BuildingTypes.move_cost(b.building_type)
		for c in b.cells:
			costs[c] = mc
	return costs

## center에 건물을 놓을 수 있는지. footprint 7헥스가 모두
## ① 맵 범위 [0, map_w) x [0, map_h) 안 ② 시야(vision_cells) 안 ③ occupied(기존 건물 점유 셀)와 미겹침
## 이면 참. 하나라도 위반하면 거짓(맵 가장자리라 이웃이 범위를 벗어나면 배치 불가).
## buildable_terrains(비어 있지 않으면)면 footprint 각 셀의 지형(get_cell_source_id)이 그 리스트에 들어야 한다(1차 생산 지형 제한). → production.md
static func can_place(terrain: TileMapLayer, center: Vector2i, map_w: int, map_h: int, vision_cells: Dictionary, occupied: Dictionary, hexes := 7, buildable_terrains := []) -> bool:
	for c in footprint(terrain, center, hexes):
		if c.x < 0 or c.x >= map_w or c.y < 0 or c.y >= map_h:
			return false
		if not vision_cells.has(c):
			return false
		if occupied.has(c):
			return false
		if not buildable_terrains.is_empty() and not (terrain.get_cell_source_id(c) in buildable_terrains):
			return false
	return true

## 완성 거점(티어 ≥ min_tier)의 footprint에 인접한 셀 집합 { cell: true }. footprint 셀 자체·맵 밖 제외.
## min_tier 0 = 캠프 이상 모든 거점(2차 생산 배치), town_hall 티어 = 마을회관·성(비-생산 건물). → production.md · processing.md
static func center_adjacent_cells(terrain: TileMapLayer, buildings: Array, map_w: int, map_h: int, min_tier := 0) -> Dictionary:
	var own := {}       # 거점 footprint 셀(인접 집합에서 제외)
	var centers := []
	for b in buildings:
		if b.is_complete() and BuildingTypes.is_center(b.building_type) \
				and BuildingTypes.center_tier(b.building_type) >= min_tier:
			centers.append(b)
			for c in b.cells:
				own[c] = true
	var adj := {}
	for b in centers:
		for c in b.cells:
			for n in terrain.get_surrounding_cells(c):
				if n.x < 0 or n.x >= map_w or n.y < 0 or n.y >= map_h:
					continue
				if own.has(n):
					continue
				adj[n] = true
	return adj

## 마을회관 이상(tier ≥ town_hall) 거점 인접 셀 — 비-생산 건물 배치용. → production.md 배치 규칙
static func town_hall_adjacent_cells(terrain: TileMapLayer, buildings: Array, map_w: int, map_h: int) -> Dictionary:
	return center_adjacent_cells(terrain, buildings, map_w, map_h, BuildingTypes.center_tier("town_hall"))
