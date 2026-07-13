class_name Party extends Node2D
## 부대. 맵에서 실제로 움직이는 유닛으로, 여러 Human을 멤버로 거느린다.
## 이동력은 멤버 중 최소(가장 느린 멤버), 시야는 멤버 중 최대를 따른다.
## 맵 토큰으로서 위치·선택·이번 턴 이동 상태·마커 그리기를 담당한다(예전 Human의 역할 이관).
## 지금은 임시 플레이스홀더(원형 마커)로 그려지며, 이후 스프라이트로 교체한다.

# --- 정체 ---
## 이름. 엔진 내장 프로퍼티 `name`(노드 이름)과 충돌하므로 별도 변수로 둔다.
@export var party_name := ""

## 소속 세력 이름. 정보 패널에 표시해 아군/적을 구분한다. 카탈로그 생성 시 설정한다.
@export var faction_name := ""

## 맵 토큰 몸통 색. 플레이어는 기본 금색, NPC 부대는 소속 세력 색으로 설정한다.
@export var token_color := Color(0.92, 0.78, 0.35)

# --- 멤버 ---
var members: Array = []   # 이 부대에 속한 Human 목록.
var commander = null      # 부대를 이끄는 Human(멤버 중 하나). 편성 UI가 없어 코드로 지정한다.

## 거점 주둔 부대([Garrison](../../docs/spec/features/garrison.md))가 가리키는 방어 영지(그 외 부대는 null).
var home_territory = null

# --- 화물(캐러반) ---
## 부대가 운반하는 자원(자원명→수량). 거점에서 적재/하역한다. 부대와 함께 이동하고, 전멸하면 소실된다.
var cargo: Dictionary = {}
const CARGO_CAPACITY := 50   # 총 적재 상한(모든 자원 수량 합).

# --- 노획 장비 ---
## 전투로 전멸시킨 패자 전사자의 장비 아이템 id 목록(무기·방어구·방패). 장착 안 된 채 보관한다.
## 중복 허용(같은 id 여러 개), 용량 제한 없음. 멤버에게 장착·탈착(장비 관리)하거나 캠프에서 금으로 판매할 수 있다.
var loot_items: Array = []

# --- 공성 유닛 ---
## 부대에 실린 공성 유닛(SiegeUnit) 목록 — 투석기 등. members(사람)와 별개, 인구 비소모.
## 실으면 부대가 느려지고(견인 이동력 상한), 끌 인력(SiegeTypes.CREW_MIN명)이 있어야 움직인다. → docs/spec/features/siege-engines.md
var siege_units: Array = []

const _RADIUS := 12.0

# 이번 턴에 이동을 마치면 반투명하게 그릴 때 곱할 알파.
const _MOVED_ALPHA := 0.4

var selected := false
var moved_this_turn := false      # 이번 턴에 이미 이동했는지. true면 재이동 불가(공격은 아직 가능).
var attacked_this_turn := false   # 이번 턴에 이미 공격했는지. true면 이동·공격 모두 끝.
var rested_this_turn := false     # 이번 턴 휴식/대기 선택했는지. 회복 연동은 미구현(party_action_menu).
var stationed := false             # 거점에서 주둔(대기) 중인지. true면 이동·공격 불가, reset_turn에도 유지. → garrison.md

## 멤버를 부대에 추가한다. 이미 포함된 멤버는 중복 추가하지 않는다. 다시 그린다(빈→유 전환 시 토큰 부활).
## 지휘관이 없으면(빈 부대에 첫 멤버) 그 멤버를 지휘관으로 삼는다.
func add_member(human) -> void:
	if human in members:
		return
	members.append(human)
	if commander == null:
		commander = human
	queue_redraw()

## 멤버를 부대에서 뺀다(수비대 편성). 지휘관이면 남은 첫 멤버로 재지정(없으면 null). 없는 멤버는 no-op.
func remove_member(human) -> void:
	if not (human in members):
		return
	members.erase(human)
	if commander == human:
		commander = members[0] if not members.is_empty() else null
	queue_redraw()

## 지휘관 이름. 지휘관이 없으면(null) "—". 부대 일람(party_roster.gd) 표시에 사용.
func commander_name() -> String:
	return commander.human_name if commander else "—"

## 현재 적재 화물 총량(모든 자원 수량 합).
func cargo_total() -> int:
	var t := 0
	for res_name in cargo:
		t += cargo[res_name]
	return t

## 화물 여유 공간(CARGO_CAPACITY - 현재 총량).
func cargo_space() -> int:
	return CARGO_CAPACITY - cargo_total()

## 화물에 자원 n만큼 싣는다(0 이하·용량 초과분은 무시하지 않고 호출부가 상한을 지킨다). 실제 실은 양을 반환.
## 용량을 넘지 않도록 min(n, 여유)만 싣는다. 음수 n은 0으로 취급.
func add_cargo(res_name: String, n: int) -> int:
	var amount := mini(maxi(n, 0), cargo_space())
	if amount > 0:
		cargo[res_name] = cargo.get(res_name, 0) + amount
	return amount

## 화물에서 자원 n만큼 내린다(보유분까지만). 실제 내린 양을 반환. 0이 되면 키를 지운다.
func remove_cargo(res_name: String, n: int) -> int:
	var amount := mini(maxi(n, 0), cargo.get(res_name, 0))
	if amount > 0:
		cargo[res_name] -= amount
		if cargo[res_name] <= 0:
			cargo.erase(res_name)
	return amount

## 다른 부대(source)의 화물에서 자원 n만큼을 약탈해 이 부대로 옮긴다(전투 승자가 전멸한 패자 화물 노획).
## source 보유분까지만(min(n, 보유)), 음수 n은 0. 승자 용량(CARGO_CAPACITY)은 무시 — 초과 허용(병합과 동일).
## 실제 옮긴 양을 반환. source 보유가 0이 되면 키를 지운다.
func take_loot(source, res_name: String, n: int) -> int:
	var amount := mini(maxi(n, 0), source.cargo.get(res_name, 0))
	if amount > 0:
		cargo[res_name] = cargo.get(res_name, 0) + amount
		source.cargo[res_name] -= amount
		if source.cargo[res_name] <= 0:
			source.cargo.erase(res_name)
	return amount

## source의 모든 화물을 전량 이 부대로 약탈한다(NPC/자동 약탈). source 화물은 빈 Dictionary가 된다.
func take_all_loot(source) -> void:
	for res_name in source.cargo.keys():
		take_loot(source, res_name, source.cargo[res_name])

## 이 부대 전 멤버가 장착한 장비 id 평탄 목록(각 멤버 weapons + armor + shield). 빈 방패("")는 제외, 중복 유지.
## 약탈 시 패자 전사자 장비 스냅샷으로 쓴다. 멤버·장비 자체는 바꾸지 않는다(읽기 전용).
func equipment_ids() -> Array:
	var ids: Array = []
	for h in members:
		ids.append_array(h.weapons)
		ids.append_array(h.armor)
		if h.shield != "":
			ids.append(h.shield)
	return ids

## source의 장비(equipment_ids)를 전부 이 부대 loot_items에 더한다(NPC/자동 장비 약탈). source는 바뀌지 않는다.
func take_all_equipment(source) -> void:
	loot_items.append_array(source.equipment_ids())

## 이 부대 화물의 자원 res_name을 other 부대로 n만큼 옮긴다(부대 분할 분배). min(n, 보유)만큼, 음수 n은 0.
## 받는 부대 CARGO_CAPACITY 초과 허용(병합·약탈과 동일 — 다음 적재만 막힘). 실제 옮긴 양 반환.
func transfer_cargo_to(other, res_name: String, n: int) -> int:
	var amount := mini(maxi(n, 0), cargo.get(res_name, 0))
	if amount > 0:
		remove_cargo(res_name, amount)
		other.cargo[res_name] = other.cargo.get(res_name, 0) + amount
	return amount

## 이 부대 loot_items의 장비 id 하나를 other.loot_items로 옮긴다(부대 분할 분배). 미보유면 false(no-op).
func transfer_loot_to(other, id: String) -> bool:
	if not (id in loot_items):
		return false
	loot_items.erase(id)   # 첫 일치 하나
	other.loot_items.append(id)
	return true

## member가 인벤토리(loot_items)의 장비 id를 장착할 수 있는지(dry-run). 장착 성공 조건의 단일 출처.
## id가 인벤토리에 있고, 슬롯 종류가 명확하며, 그 슬롯에 여유가 있어야(무기 MAX_WEAPONS·방어구 MAX_ARMOR·방패 빈칸) true.
## equip_from_loot의 판정과 장비 관리 UI([장착] 버튼 활성)가 모두 이 함수를 쓴다.
func can_equip_from_loot(member, id: String) -> bool:
	if not (id in loot_items):
		return false
	match ItemTypes.item_slot(id):
		"weapon":
			return member.weapons.size() < Human.MAX_WEAPONS
		"armor":
			return member.armor.size() < Human.MAX_ARMOR
		"shield":
			return member.shield == ""
		_:
			return false

## 인벤토리(loot_items)의 장비 id를 member에게 장착한다(장비 관리). 슬롯은 ItemTypes.item_slot로 판별.
## 스왑 없음 — can_equip_from_loot이 false면 no-op으로 false. 성공 시 슬롯에 넣고 loot_items에서 그 id 하나 제거.
func equip_from_loot(member, id: String) -> bool:
	if not can_equip_from_loot(member, id):
		return false
	match ItemTypes.item_slot(id):
		"weapon":
			member.weapons.append(id)
		"armor":
			member.armor.append(id)
		"shield":
			member.shield = id
	loot_items.erase(id)   # 첫 일치 하나 제거
	return true

## member가 장착한 장비 id를 빼서 인벤토리(loot_items)로 되돌린다. 주무기[0]를 빼면 다음 무기가 주무기.
## 멤버가 그 장비를 안 갖고 있으면 false(no-op). 성공 시 loot_items에 더하고 true.
func unequip_to_loot(member, id: String) -> bool:
	match ItemTypes.item_slot(id):
		"weapon":
			if not (id in member.weapons):
				return false
			member.weapons.erase(id)
		"armor":
			if not (id in member.armor):
				return false
			member.armor.erase(id)
		"shield":
			if member.shield != id:
				return false   # item_slot이 "shield"면 id는 빈 문자열이 아니다(카탈로그 방패 id)
			member.shield = ""
		_:
			return false
	loot_items.append(id)
	return true

## 다른 부대(other)의 멤버를 이 부대로 흡수한다(병합). other는 빈 부대가 된다(호출부가 제거).
## 이 부대 지휘관은 유지된다(없으면 add_member가 첫 합류 멤버로 지정). 빈 other면 변화 없음.
## other의 화물도 합친다(소실 방지) — 병합은 합산이라 CARGO_CAPACITY를 넘길 수 있다(다음 적재만 막힘).
func merge_from(other) -> void:
	for h in other.members.duplicate():
		add_member(h)
	for res_name in other.cargo:
		cargo[res_name] = cargo.get(res_name, 0) + other.cargo[res_name]
	other.cargo = {}
	other.members = []
	other.commander = null
	other.queue_redraw()
	queue_redraw()

## 기본 이동력 = 멤버 이동력의 최소값(가장 느린 멤버). 멤버 없으면 0. 과적 반영 전 값.
func base_movement() -> int:
	if members.is_empty():
		return 0
	var m: int = members[0].movement
	for h in members:
		m = mini(m, h.movement)
	return m

## 화물 과적 이동력 감소량. 화물이 용량(CARGO_CAPACITY) 초과 시 step(=용량÷기본이동력)마다 −1.
## 정수식 (초과량 × 기본) ÷ 용량 (= floor(초과 ÷ (용량÷기본)), 부동소수점 오차 없음). 용량 이하·멤버 없으면 0.
## 화물이 용량의 2배면 페널티 = 기본 이동력(→ movement 0, 정지).
func overload_penalty() -> int:
	var base := base_movement()
	if base <= 0:
		return 0
	var excess := cargo_total() - CARGO_CAPACITY
	if excess <= 0:
		return 0
	return excess * base / CARGO_CAPACITY   # 정수 나눗셈(내림)

## 부대 이동력 = 기본 이동력 − 과적 페널티(하한 0). 이동 범위·NPC 경로·정보 패널에 쓰인다.
## 공성 유닛을 실었으면 견인 규칙을 마저 적용: 사람 < CREW_MIN이면 0(견인 인력 부족),
## 아니면 견인 이동력(가장 느린 공성 유닛)으로 상한. → docs/spec/features/siege-engines.md
func movement() -> int:
	var m := maxi(0, base_movement() - overload_penalty())
	if has_siege():
		if members.size() < SiegeTypes.CREW_MIN:
			return 0   # 끌 인력 부족 → 정지
		m = mini(m, _siege_haul_speed())
	return m

## 실은 공성 유닛 중 가장 느린 견인 이동력(모두 투석기면 2). 공성 유닛이 없으면 0(호출 안 됨).
## s를 -1로 시작해 첫 유닛으로 시딩 — 이동력 0인 유닛도 무시하지 않고 최소로 반영(향후 0속도 유닛 대비).
func _siege_haul_speed() -> int:
	var s := -1
	for u in siege_units:
		var mv: int = u.movement()
		s = mv if s < 0 else mini(s, mv)
	return maxi(s, 0)

## 공성 유닛을 실었는지(견인 이동 규칙·정보 표시 판정).
func has_siege() -> bool:
	return not siege_units.is_empty()

## 실은 공성 유닛의 최대 투석 사거리(없으면 0). [투석] 대상 밴드 상한. → siege-engines.md
func siege_fire_range() -> int:
	var r := 0
	for u in siege_units:
		r = maxi(r, u.fire_range())
	return r

## 실은 공성 유닛의 최소 투석 사거리(없으면 0). [투석] 대상 밴드 하한 — 이보다 가까운 표적은 못 친다. → siege-engines.md
func siege_min_range() -> int:
	var r := 0
	for u in siege_units:
		r = u.min_range() if r == 0 else mini(r, u.min_range())
	return r

## 실은 공성 유닛의 최대 공격력(없으면 0). 투석 데미지 기준값. → siege-engines.md
func siege_attack() -> int:
	var a := 0
	for u in siege_units:
		a = maxi(a, u.attack())
	return a

## 공성 유닛(SiegeUnit)을 부대에 싣는다(공성 작업장 생산). 인구·멤버에는 영향 없다.
func add_siege_unit(unit) -> void:
	siege_units.append(unit)

## hit_points <= 0인 공성 유닛(투석 결투로 파괴)을 siege_units에서 제거하고 제거 수를 반환한다. → siege-engines.md
func prune_destroyed_siege() -> int:
	var kept: Array = []
	var removed := 0
	for u in siege_units:
		if u.hit_points > 0:
			kept.append(u)
		else:
			removed += 1
	siege_units = kept
	return removed

## 부대 시야 = 멤버 시야의 최대값. 멤버 없으면 0.
func vision() -> int:
	if members.is_empty():
		return 0
	var v: int = members[0].vision
	for h in members:
		v = maxi(v, h.vision)
	return v

## 부대 공격거리 = 멤버 무기 공격거리의 최대값(가장 사거리 긴 멤버). 멤버 없으면 0.
func attack_range() -> int:
	if members.is_empty():
		return 0
	var r := 0
	for h in members:
		r = maxi(r, ItemTypes.max_range(h.weapons))
	return r

## 선택 상태를 바꾸고 다시 그린다.
func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

## 이번 턴에 이동 가능한지. 이동했거나 공격했거나 주둔 중이면(행동 종료·대기) 불가.
func can_move() -> bool:
	return not moved_this_turn and not attacked_this_turn and not stationed

## 이번 턴에 공격 가능한지. 이동만 했으면 아직 가능, 공격했거나 주둔 중이면 불가.
func can_attack() -> bool:
	return not attacked_this_turn and not stationed

## 이번 턴에 휴식(대기) 가능한지. 아직 행동을 끝내지 않았으면 가능.
func can_rest() -> bool:
	return not attacked_this_turn

## 이동 완료 표시. 흐리게(반투명) 다시 그린다.
func mark_moved() -> void:
	if moved_this_turn:
		return
	moved_this_turn = true
	queue_redraw()

## 공격 완료 표시(그 부대의 행동 종료). 흐리게 다시 그린다.
func mark_attacked() -> void:
	if attacked_this_turn:
		return
	attacked_this_turn = true
	queue_redraw()

## 휴식(대기) 표시. 행동을 끝낸다(attacked_this_turn=true). 이동 여부(moved_this_turn)는 유지.
func mark_rested() -> void:
	if rested_this_turn:
		return
	rested_this_turn = true
	attacked_this_turn = true
	queue_redraw()

## 이동 되돌리기. moved_this_turn을 해제해 다시 이동 가능하게 한다(위치 복원은 game.gd). 다시 그린다.
func undo_move() -> void:
	moved_this_turn = false
	queue_redraw()

## 턴 종료 시 호출. 이동·공격·휴식 상태를 리셋하고 불투명하게 다시 그린다.
func reset_turn() -> void:
	if not moved_this_turn and not attacked_this_turn and not rested_this_turn:
		return
	moved_this_turn = false
	attacked_this_turn = false
	rested_this_turn = false
	queue_redraw()

func _draw() -> void:
	if members.is_empty():
		return   # 멤버 없는 부대(전부 수비대로 이동/전멸)는 토큰을 그리지 않는다 — "사라짐".

	# 이번 턴에 이동·공격 중 하나라도 했으면 전체를 반투명하게.
	var a := _MOVED_ALPHA if (moved_this_turn or attacked_this_turn) else 1.0

	# 선택되면 발밑에 강조 링을 먼저 그린다.
	if selected:
		draw_arc(Vector2(0, 4), _RADIUS * 1.4, 0.0, TAU, 40, Color(1.0, 0.95, 0.4, a), 3.0, true)

	# 임시 플레이스홀더: 발밑 그림자 + 몸통 원(token_color) + 외곽선.
	draw_circle(Vector2(0, 4), _RADIUS * 0.9, Color(0, 0, 0, 0.25 * a))
	var body := token_color
	body.a *= a
	draw_circle(Vector2.ZERO, _RADIUS, body)
	draw_arc(Vector2.ZERO, _RADIUS, 0.0, TAU, 32, Color(0.25, 0.18, 0.08, a), 2.0, true)
