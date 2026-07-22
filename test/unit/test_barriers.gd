extends GutTest
## Barriers: 칸 사이 경계 장벽 데이터 — 추가/제거/조회, blocked_edge_set 합성(강·벽).

func _b() -> Barriers:
	return autofree(Barriers.new())

func test_empty() -> void:
	var b := _b()
	assert_eq(b.count(), 0, "초기엔 장벽 0")
	assert_eq(b.blocked_edge_set(), {}, "빈 차단 집합")

func test_add_and_query_order_independent() -> void:
	var b := _b()
	b.add_edge(Vector2i(1, 1), Vector2i(1, 2), Barriers.KIND_RIVER)
	assert_eq(b.count(), 1)
	assert_true(b.has_edge(Vector2i(1, 1), Vector2i(1, 2)), "경계 존재")
	assert_true(b.has_edge(Vector2i(1, 2), Vector2i(1, 1)), "순서 무관하게 같은 경계")
	assert_eq(b.kind_of(Vector2i(1, 1), Vector2i(1, 2)), Barriers.KIND_RIVER)

func test_add_dedup_replaces_kind() -> void:
	var b := _b()
	b.add_edge(Vector2i(0, 0), Vector2i(1, 0), Barriers.KIND_RIVER)
	b.add_edge(Vector2i(1, 0), Vector2i(0, 0), Barriers.KIND_WALL)   # 같은 경계, 순서 반대
	assert_eq(b.count(), 1, "같은 경계는 중복 안 되고 kind만 교체")
	assert_eq(b.kind_of(Vector2i(0, 0), Vector2i(1, 0)), Barriers.KIND_WALL)

func test_remove() -> void:
	var b := _b()
	b.add_edge(Vector2i(0, 0), Vector2i(1, 0), Barriers.KIND_WALL)
	b.add_edge(Vector2i(2, 2), Vector2i(2, 3), Barriers.KIND_WALL_PERMANENT)
	b.remove_edge(Vector2i(1, 0), Vector2i(0, 0))
	assert_eq(b.count(), 1, "하나 제거")
	assert_false(b.has_edge(Vector2i(0, 0), Vector2i(1, 0)), "제거된 경계 없음")
	assert_true(b.has_edge(Vector2i(2, 2), Vector2i(2, 3)), "다른 경계 유지")
	assert_eq(b.kind_of(Vector2i(2, 2), Vector2i(2, 3)), Barriers.KIND_WALL_PERMANENT)

func test_blocked_edge_set_keys_match_hexgrid() -> void:
	var b := _b()
	b.add_edge(Vector2i(3, 4), Vector2i(3, 5), Barriers.KIND_RIVER)
	var s := b.blocked_edge_set()
	var key := HexGrid.edge_key(Vector2i(3, 4), Vector2i(3, 5))
	assert_true(s.has(key), "차단 키가 HexGrid.edge_key와 일치(BFS가 그대로 조회)")
	assert_eq(int(s[key]), Barriers.KIND_RIVER, "값 = kind")
