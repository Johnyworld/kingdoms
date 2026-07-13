class_name BattleSim
extends RefCounted
## 오버레이 없이 두 부대의 교전 결과만 계산하는 순수 함수(테스트 용이).
## 시간 기반 결산: BATTLE_TIME 동안 각 유닛이 최종 공격속도(초) 간격마다 상대에 1회 공격(resolve_hit)한다.
## 위치·리치·투척은 무시하는 근사(공간 전투는 오버레이가 재현). 플레이어가 안 보는 NPC끼리 전투에만 쓴다.

const BATTLE_TIME := 10.0   # 한 전투 지속 시간(초).

## a_members·b_members(Human 목록)의 교전을 결산한다. 반환: {a: 생존 human 목록, b: 생존 human 목록}.
## 각 유닛은 자기 공격 간격마다 상대 팀의 살아있는 유닛 하나를 공격한다(이산 이벤트 시뮬).
static func resolve_battle(a_members: Array, b_members: Array, rng: RandomNumberGenerator, distance := 1, a_siege := [], b_siege := []) -> Dictionary:
	# 투석 볼리 프리페이즈(공성 유닛 있을 때, NPC↔NPC 투석기 결투 — 5g-B) → docs/spec/features/battle.md
	if not a_siege.is_empty() or not b_siege.is_empty():
		_siege_volley(a_siege, a_members, b_siege, b_members, distance, rng)
		a_members = _living(a_members)   # 볼리로 전투불능된 멤버는 멤버 시뮬에서 제외
		b_members = _living(b_members)

	var units: Array = []
	for h in a_members:
		units.append(_make_unit(h, "a", distance))
	for h in b_members:
		units.append(_make_unit(h, "b", distance))

	# 다음 공격 시점(next_t)이 가장 이른 유닛부터 처리. BATTLE_TIME을 넘으면 종료.
	# now = 마지막으로 처리한 시각. 이벤트 사이 경과 시간만큼 상태이상(출혈 도트·기절)을 진행한다.
	var now := 0.0
	while true:
		var actor: Dictionary = {}
		var best_t := INF
		for u in units:
			if u["alive"] and u["can_attack"] and u["next_t"] < best_t:
				best_t = u["next_t"]
				actor = u
		if actor.is_empty() or best_t > BATTLE_TIME:
			break
		_advance_effects(units, best_t - now)   # 이 시점까지 도트·지속 진행(사망자 나올 수 있음)
		now = best_t
		if not actor["alive"]:
			continue   # 출혈로 죽었으면 이번 공격 취소, 다음 유닛 재탐색
		if StatusEffects.is_stunned(actor["effects"]):
			actor["next_t"] += actor["interval"]   # 기절이면 이번 공격을 건너뛴다
			continue
		var enemy := _pick_enemy(units, actor["team"])
		if enemy.is_empty():
			break   # 상대 팀 전멸
		var r := CombatResolver.resolve_hit(actor["human"], enemy["human"], enemy["hp"], rng, actor["weapon"])
		enemy["hp"] = r["hp"]
		if r["inflict"] != "":
			StatusEffects.apply(enemy["effects"], r["inflict"])
		if enemy["hp"] <= 0:
			enemy["alive"] = false
		actor["next_t"] += actor["interval"]

	# 시간 만료로 끝났으면(양팀 생존) 마지막 이벤트~종료 사이 잔여 도트를 적용한다.
	# 한 팀이 전멸해 끝났으면 그 시점이 전투 종료라 추가 도트는 없다(오버레이 battle.gd와 동일).
	if _team_alive(units, "a") and _team_alive(units, "b"):
		_advance_effects(units, BATTLE_TIME - now)
	_persist_hp(units)   # 생존자 최종 hp를 Human에 반영(전투 후 지속)
	return {"a": _survivors(units, "a"), "b": _survivors(units, "b")}

## 투석 볼리 표적 — 적 투석기 우선(대포병) → 적 멤버, 최대 n(비공간이라 목록 앞쪽부터). → docs/spec/features/battle.md
static func bombard_pick(enemy_siege: Array, enemy_members: Array, n: int) -> Array:
	return (enemy_siege + enemy_members).slice(0, n)

## 투석 볼리 정산(5g-B) — 양측 투석기가 전투당 1발씩 동시 사격(스냅샷 → 상호 반격 보장).
## 밴드(min~fire) 안일 때만 발사, 표적별 명중(0.1)·명중 시 flat rolled_damage. hit_points는 SiegeUnit·Human에 in-place 반영. → docs/spec/features/battle.md
static func _siege_volley(a_siege: Array, a_members: Array, b_siege: Array, b_members: Array, distance: int, rng: RandomNumberGenerator) -> void:
	# 볼리 전 살아있는 표적을 스냅샷(양측이 같은 상태를 봐 한쪽이 먼저 파괴돼도 반격 1발 보장).
	var a_targets := bombard_pick(_living(b_siege), _living(b_members), Siege.MAX_BOMBARD_TARGETS)
	var b_targets := bombard_pick(_living(a_siege), _living(a_members), Siege.MAX_BOMBARD_TARGETS)
	var pending := {}   # 표적 → 누적 피해(스냅샷 기준으로 모두 계산한 뒤 한 번에 적용)
	_accumulate_volley(a_siege, a_targets, distance, rng, pending)
	_accumulate_volley(b_siege, b_targets, distance, rng, pending)
	for t in pending:
		t.hit_points -= pending[t]

## siege_units 각각을 targets에 전투당 1발 사격해 pending(표적→피해)에 누적. 밴드 밖·파괴된 투석기는 건너뛴다.
static func _accumulate_volley(siege_units: Array, targets: Array, distance: int, rng: RandomNumberGenerator, pending: Dictionary) -> void:
	for su in siege_units:
		if su.hit_points <= 0 or not Siege.in_fire_band(distance, su.min_range(), su.fire_range()):
			continue
		for t in targets:
			if not Siege.hit_succeeds(rng.randf(), Siege.CATAPULT_HIT_CHANCE):
				continue
			pending[t] = pending.get(t, 0) + Siege.rolled_damage(su.attack(), rng.randf())

## hit_points > 0인 유닛만(멤버·투석기 공통). 볼리 표적 스냅샷·볼리 후 생존 멤버 선별에 쓴다.
static func _living(units: Array) -> Array:
	return units.filter(func(u): return u.hit_points > 0)

## 그 팀에 살아있는 유닛이 하나라도 있으면 true.
static func _team_alive(units: Array, team: String) -> bool:
	for u in units:
		if u["team"] == team and u["alive"]:
			return true
	return false

## 생존자의 최종 hp를 Human.hit_points에 되쓴다(전투 후 지속). 사망자는 members에서 빠지므로 무시.
static func _persist_hp(units: Array) -> void:
	for u in units:
		if u["alive"]:
			u["human"].hit_points = maxi(1, int(u["hp"]))

## 살아있는 모든 유닛의 상태이상을 dt만큼 진행하고 출혈 도트를 hp에서 뺀다. 0 이하면 전투불능.
static func _advance_effects(units: Array, dt: float) -> void:
	if dt <= 0.0:
		return
	for u in units:
		if not u["alive"]:
			continue
		var dmg := StatusEffects.advance(u["effects"], dt)
		if dmg > 0:
			u["hp"] -= dmg
			if u["hp"] <= 0:
				u["alive"] = false

## Human을 전투 유닛으로 만든다. distance = 교전 거리, ranged := distance >= 2.
## weapon = 모드별 활성 무기(근접=주무기, 원거리=활). 원거리 교전에선 활성 무기 사거리 ≥ distance일 때만 공격 가능. → docs/spec/features/battle.md
static func _make_unit(h, team: String, distance: int) -> Dictionary:
	var ranged := distance >= 2
	var w: String = ItemTypes.active_weapon(h.weapons, ranged)
	var can: bool = (not ranged) or (w != "" and ItemTypes.weapon_range(w) >= distance)
	var interval: float = CombatResolver.attack_interval(h, w) if can else INF
	return {"human": h, "team": team, "hp": int(h.hit_points), "alive": true, "weapon": w, "can_attack": can, "interval": interval, "next_t": interval, "effects": {}}

## team의 상대 팀에서 살아있는 유닛 하나(없으면 빈 Dictionary). 위치가 없어 목록 앞쪽부터 고른다.
static func _pick_enemy(units: Array, team: String) -> Dictionary:
	for u in units:
		if u["team"] != team and u["alive"]:
			return u
	return {}

static func _survivors(units: Array, team: String) -> Array:
	var out: Array = []
	for u in units:
		if u["team"] == team and u["alive"]:
			out.append(u["human"])
	return out
