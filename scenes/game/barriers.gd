@tool
class_name Barriers
extends Node2D
## 칸 사이 경계(edge)에 걸친 이동 장벽 — 강·벽. 이동 BFS(HexGrid)의 blocked_edges 출처.
##
## 강·벽은 칸이 아니라 **두 칸 사이 경계**에 있다(칸 자체는 통행 가능, 그 경계만 못 건넘).
## 데이터는 flat PackedInt32Array: [ax, ay, bx, by, kind] 반복(장벽당 STRIDE=5개).
## 종류(kind): 강(다리로 해제)·벽(철거)·영구벽. 최종 차단 집합은 게임이 조회 시 합성한다
## (authored 장벽 ∪ 건설벽 − 다리 — 뒤 둘은 후속). → docs/spec/features/selection-and-movement.md
##
## 에디터 오서링: EdgeBarrier 플러그인이 경계를 클릭해 add/remove 한다(kind별 색). → addons/edge_barrier

const KIND_RIVER := 0            # 강 — 다리 건설로 그 경계 해제(후속)
const KIND_WALL := 1             # 벽 — 철거 가능(후속)
const KIND_WALL_PERMANENT := 2   # 영구 벽 — 허물 수 없음

const STRIDE := 5   # 장벽당 int 수: ax, ay, bx, by, kind

const KIND_COLORS := {
	KIND_RIVER: Color(0.3, 0.6, 1.0, 0.9),         # 강 파랑
	KIND_WALL: Color(0.82, 0.82, 0.85, 0.95),      # 벽 밝은 회색
	KIND_WALL_PERMANENT: Color(0.5, 0.5, 0.56, 1), # 영구벽 진회색
}

## flat 장벽 데이터. 에디터 툴이 채우고 씬에 저장된다.
@export var data: PackedInt32Array = PackedInt32Array():
	set(v):
		data = v
		queue_redraw()

## 헥스 지오메트리 기준 레이어(데이터 레이어, 형제 노드). 렌더·경계 계산에 쓴다.
func _terrain() -> TileMapLayer:
	return get_node_or_null("../TerrainLayer") as TileMapLayer

## 에디터에서만 설정된 장벽을 kind 색선으로 그린다. 게임 화면엔 안 나온다(강은 Ocean 타일로 보임).
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var t := _terrain()
	if t == null:
		return
	for i in count():
		var e := at(i)
		var seg := HexGrid.edge_segment(t, e["a"], e["b"])
		if seg.size() >= 2:
			draw_line(seg[0], seg[1], KIND_COLORS.get(e["kind"], Color.RED), 3.0)

## 장벽 개수.
func count() -> int:
	return data.size() / STRIDE

## i번째 장벽 → { a: Vector2i, b: Vector2i, kind: int }.
func at(i: int) -> Dictionary:
	var o := i * STRIDE
	return {
		"a": Vector2i(data[o], data[o + 1]),
		"b": Vector2i(data[o + 2], data[o + 3]),
		"kind": data[o + 4],
	}

## 이동 BFS용 차단 경계 집합 { edge_key: kind }. 지금은 authored 장벽 전부가 차단(다리·철거는 후속).
func blocked_edge_set() -> Dictionary:
	var s := {}
	for i in count():
		var e := at(i)
		s[HexGrid.edge_key(e["a"], e["b"])] = e["kind"]
	return s

## a-b 경계 장벽의 인덱스(없으면 -1). 순서 무관.
func index_of(a: Vector2i, b: Vector2i) -> int:
	var key := HexGrid.edge_key(a, b)
	for i in count():
		var e := at(i)
		if HexGrid.edge_key(e["a"], e["b"]) == key:
			return i
	return -1

## a-b 경계에 장벽이 있나.
func has_edge(a: Vector2i, b: Vector2i) -> bool:
	return index_of(a, b) != -1

## a-b 경계 장벽의 종류(없으면 -1).
func kind_of(a: Vector2i, b: Vector2i) -> int:
	var i := index_of(a, b)
	return data[i * STRIDE + 4] if i != -1 else -1

## a-b 경계에 장벽 추가(이미 있으면 kind만 교체).
func add_edge(a: Vector2i, b: Vector2i, kind: int) -> void:
	var i := index_of(a, b)
	if i != -1:
		data[i * STRIDE + 4] = kind
		queue_redraw()
		return
	data.append_array([a.x, a.y, b.x, b.y, kind])
	queue_redraw()

## a-b 경계 장벽 제거.
func remove_edge(a: Vector2i, b: Vector2i) -> void:
	var i := index_of(a, b)
	if i == -1:
		return
	var o := i * STRIDE
	for _k in range(STRIDE):
		data.remove_at(o)   # 같은 위치를 STRIDE번 제거 = 그 장벽 슬롯 삭제
	queue_redraw()
