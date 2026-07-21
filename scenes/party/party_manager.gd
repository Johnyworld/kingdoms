class_name PartyManager
extends RefCounted
## 부대 생명주기 계층 — 부대 목록(단일 출처)·노드 생성·전멸/세력 소멸 제거·칸 조회.
## game.gd에서 분리했다. 선택 상태·부대 일람 갱신·패배 확인·연출은 game.gd가 맡는다.
## 새 Party 노드는 host(게임 씬 루트)에 add_child로 붙인다. → docs/spec/features/parties.md · battle.md

const PARTY_SCENE := preload("res://scenes/party/party.tscn")

## apply_survivors 결과 — 후처리(활성 부대 재할당·일람·패배 확인)는 game.gd가 이 값으로 분기한다.
const ALIVE := "alive"                # 생존자 있음(부대 유지)
const WIPED_NPC := "wiped_npc"        # NPC 부대 전멸 → 목록 제거·free 완료
const WIPED_PLAYER := "wiped_player"  # 플레이어 부대 전멸 → 목록 제거·free 완료(활성 재할당은 game.gd)
const INVALID := "invalid"            # 이미 해제된 부대(no-op)

var terrain: TileMapLayer
var host: Node                  # 새 Party 노드를 붙일 부모(game 씬 루트)

var units: Array = []           # 플레이어 부대(턴당 1회 이동). 일람·시야 합산 대상.
var npc_parties: Array = []     # NPC 부대. 안개 표시·턴 리셋·NPC 턴 이동 대상. 일람 제외.

func _init(p_terrain: TileMapLayer, p_host: Node) -> void:
	terrain = p_terrain
	host = p_host

## 부대(Node2D)가 선 맵 셀.
func _cell_of(p) -> Vector2i:
	return terrain.local_to_map(p.position)

# --- 조회 ---

## 모든 부대(플레이어 + NPC) 목록. 부대 전체 순회의 단일 출처.
func all() -> Array:
	return units + npc_parties

## 그 칸에 선 병력 있는 부대(플레이어·NPC 통틀어). 없으면 null. 수비 배지·방어 판정에 쓴다.
func party_on_cell(cell: Vector2i) -> Party:
	for p in all():
		if p.soldiers > 0 and _cell_of(p) == cell:
			return p
	return null

## 그 칸에 선 플레이어 부대(병력 있는 것). 없으면 null. 클릭 선택 판정에 쓴다.
func player_party_at(cell: Vector2i) -> Party:
	for p in units:
		if p.soldiers <= 0:
			continue
		if _cell_of(p) == cell:
			return p
	return null

## 그 셀에 선 NPC 부대(없으면 null). 안개에 가려 보이지 않는(visible == false) NPC는 제외한다.
func npc_at(cell: Vector2i) -> Party:
	for p in npc_parties:
		if p.visible and _cell_of(p) == cell:
			return p
	return null

## units 중 병력이 있는(살아있는) 첫 부대. 없으면 null. 활성 부대 재할당에 쓴다.
func first_living_unit():
	for u in units:
		if u.soldiers > 0:
			return u
	return null

# --- 생성 ---

## 빈 새 부대 노드를 만들어 트리에 넣는다(기본 kind=troop, 금색). 카탈로그 정보·목록 등록은 호출부가 채운다.
func new_party() -> Party:
	var p: Party = PARTY_SCENE.instantiate()
	host.add_child(p)
	return p

## 세력 소속의 빈 새 부대를 만들어 셀에 둔다(분할용 등). 빈 부대라 채우기 전엔 토큰 안 보임. 목록 등록은 호출부.
func make_party(pname: String, faction_name: String, cell: Vector2i) -> Party:
	var p := new_party()
	p.party_name = pname
	p.faction_name = faction_name
	p.position = terrain.map_to_local(cell)
	return p

# --- 제거 ---

## 부대를 목록(양쪽 모두 확인)에서 빼고 노드를 해제한다(병합 흡수·분할 취소 등).
func remove_party(p) -> void:
	units.erase(p)
	npc_parties.erase(p)
	p.queue_free()

## 부대 병력을 전투 최종 병력수로 갱신한다. 전멸(0)이면 목록에서 제거·free.
## 반환: ALIVE / WIPED_NPC / WIPED_PLAYER / INVALID — 활성 부대 재할당·일람·패배 확인은 game.gd가 결과로 분기.
func apply_survivors(p, final_soldiers: int) -> String:
	if not is_instance_valid(p):
		return INVALID   # await 사이 이미 해제된 부대면 반영할 것도 없음(하드닝 일관성)
	p.soldiers = maxi(0, final_soldiers)
	p.queue_redraw()   # 사상 반영 후 토큰 다시 그림 — 병력수 배지가 갱신되도록. → lang-battle.md
	if p.soldiers > 0:
		return ALIVE
	# 전멸 — 부대를 맵에서 제거한다(NPC·플레이어 모두 껍데기 안 남김).
	if p in npc_parties:
		npc_parties.erase(p)
		p.queue_free()
		return WIPED_NPC
	if p in units:
		units.erase(p)
		p.queue_free()
		return WIPED_PLAYER
	return INVALID   # 어느 목록에도 없음(이미 제거됨)

## 세력 소멸(붕괴): 그 세력 소속 NPC 부대를 맵에서 제거한다. 플레이어 세력이면 부대는 그대로 둔다(패배 처리).
func eliminate_faction_parties(faction_name: String) -> void:
	for p in npc_parties.duplicate():
		if p.faction_name == faction_name:
			npc_parties.erase(p)
			p.queue_free()
