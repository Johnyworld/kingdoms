extends GutTest
## PartyManager — 부대 목록·생성·전멸/세력 소멸 제거·칸 조회 테스트.
## host = 테스트 노드(생성 부대가 트리에 붙고 테스트 종료 시 함께 정리). 선택/일람/패배 확인은 game.gd 몫이라 여기 없음.

const MAP := 41
const ManagerScript = preload("res://scenes/party/party_manager.gd")

var terrain: TileMapLayer
var host: Node2D
var mgr

func before_each() -> void:
	terrain = TileMapLayer.new()
	terrain.tile_set = load("res://tiles/terrain_tileset.tres")
	add_child_autofree(terrain)
	host = Node2D.new()
	add_child_autofree(host)
	mgr = ManagerScript.new(terrain, host)

func _center() -> Vector2i:
	return Vector2i(MAP / 2, MAP / 2)

## 병력 n인 부대를 만들어 지정 목록에 등록한다.
func _party(fn: String, cell: Vector2i, n := 1, npc := false) -> Node2D:
	var p: Node2D = mgr.make_party(fn + " 부대", fn, cell)
	p.soldiers = n
	if npc:
		mgr.npc_parties.append(p)
	else:
		mgr.units.append(p)
	return p

# --- 생성 ---

func test_make_party_sets_identity_and_parent() -> void:
	var p: Node2D = mgr.make_party("분할 부대", "A", _center())
	assert_eq(p.get_parent(), host, "host에 노드 부착")
	assert_eq(p.party_name, "분할 부대", "이름")
	assert_eq(p.faction_name, "A", "세력")
	assert_eq(terrain.local_to_map(p.position), _center(), "지정 셀 배치")
	assert_eq(p.soldiers, 0, "병력 0으로 시작(목록 등록도 호출부 몫)")

# --- 조회 ---

func test_cell_queries() -> void:
	var mine := _party("A", _center())
	var foe := _party("B", _center() + Vector2i(2, 0), 1, true)
	assert_eq(mgr.all(), [mine, foe], "all = 플레이어 + NPC")
	assert_eq(mgr.party_on_cell(_center()), mine, "칸 위 부대(공용)")
	assert_eq(mgr.player_party_at(_center()), mine, "플레이어 부대 조회")
	assert_null(mgr.player_party_at(terrain.local_to_map(foe.position)), "NPC 칸은 플레이어 조회 제외")
	assert_eq(mgr.npc_at(terrain.local_to_map(foe.position)), foe, "보이는 NPC 조회")
	foe.visible = false
	assert_null(mgr.npc_at(terrain.local_to_map(foe.position)), "안개에 가려진 NPC 제외")

func test_empty_party_excluded_from_cell_queries() -> void:
	var empty: Node2D = mgr.make_party("빈 부대", "A", _center())
	mgr.units.append(empty)
	assert_null(mgr.party_on_cell(_center()), "병력 0 부대는 party_on_cell 제외")
	assert_null(mgr.player_party_at(_center()), "병력 0 부대는 선택 대상 아님")
	assert_null(mgr.first_living_unit(), "살아있는 부대 없음")
	var alive := _party("A", _center() + Vector2i(1, 0))
	assert_eq(mgr.first_living_unit(), alive, "병력 있는 첫 부대")

# --- 전멸 반영(apply_survivors) ---

func test_apply_survivors_alive_updates_soldiers() -> void:
	var p := _party("A", _center(), 5)
	assert_eq(mgr.apply_survivors(p, 3), ManagerScript.ALIVE, "생존 → ALIVE")
	assert_eq(p.soldiers, 3, "최종 병력수로 갱신")
	assert_true(p in mgr.units, "부대 유지")

func test_apply_survivors_wipes_player_party() -> void:
	var p := _party("A", _center())
	assert_eq(mgr.apply_survivors(p, 0), ManagerScript.WIPED_PLAYER, "플레이어 전멸 → WIPED_PLAYER")
	assert_false(p in mgr.units, "목록에서 제거")
	assert_true(p.is_queued_for_deletion(), "노드 해제 예약")

func test_apply_survivors_wipes_npc_party() -> void:
	var p := _party("B", _center(), 1, true)
	assert_eq(mgr.apply_survivors(p, 0), ManagerScript.WIPED_NPC, "NPC 전멸 → WIPED_NPC")
	assert_false(p in mgr.npc_parties, "목록에서 제거")

func test_apply_survivors_invalid_party_noop() -> void:
	var p := _party("A", _center())
	p.free()   # await 사이 이미 해제된 부대 시뮬레이션
	assert_eq(mgr.apply_survivors(p, 0), ManagerScript.INVALID, "해제된 부대 → INVALID(no-op)")

# --- 제거 ---

func test_remove_party_from_either_list() -> void:
	var a := _party("A", _center())
	var b := _party("B", _center() + Vector2i(2, 0), 1, true)
	mgr.remove_party(a)
	mgr.remove_party(b)
	assert_true(mgr.units.is_empty() and mgr.npc_parties.is_empty(), "양쪽 목록에서 제거")
	assert_true(a.is_queued_for_deletion() and b.is_queued_for_deletion(), "노드 해제 예약")

func test_eliminate_faction_parties_only_that_faction() -> void:
	var b1 := _party("B", _center(), 1, true)
	var c1 := _party("C", _center() + Vector2i(2, 0), 1, true)
	mgr.eliminate_faction_parties("B")
	assert_false(b1 in mgr.npc_parties, "소멸 세력 부대 제거")
	assert_true(c1 in mgr.npc_parties, "다른 세력 부대 유지")
	assert_true(b1.is_queued_for_deletion(), "제거 부대 해제 예약")
