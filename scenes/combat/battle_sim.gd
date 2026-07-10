class_name BattleSim
extends RefCounted
## 오버레이 없이 두 부대의 교전 결과만 계산하는 순수 함수(테스트 용이).
## 시간 기반 결산: BATTLE_TIME 동안 각 유닛이 최종 공격속도(초) 간격마다 상대에 1회 공격(resolve_hit)한다.
## 위치·리치·투척은 무시하는 근사(공간 전투는 오버레이가 재현). 플레이어가 안 보는 NPC끼리 전투에만 쓴다.

const BATTLE_TIME := 10.0   # 한 전투 지속 시간(초).

## a_members·b_members(Human 목록)의 교전을 결산한다. 반환: {a: 생존 human 목록, b: 생존 human 목록}.
## 각 유닛은 자기 공격 간격마다 상대 팀의 살아있는 유닛 하나를 공격한다(이산 이벤트 시뮬).
static func resolve_battle(a_members: Array, b_members: Array, rng: RandomNumberGenerator, ranged_mode := false) -> Dictionary:
	var units: Array = []
	for h in a_members:
		units.append(_make_unit(h, "a", ranged_mode))
	for h in b_members:
		units.append(_make_unit(h, "b", ranged_mode))

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
	var a_surv := _survivors(units, "a")
	var b_surv := _survivors(units, "b")
	if not a_surv.is_empty() and not b_surv.is_empty():
		_advance_effects(units, BATTLE_TIME - now)
		a_surv = _survivors(units, "a")
		b_surv = _survivors(units, "b")
	return {"a": a_surv, "b": b_surv}

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

## Human을 전투 유닛으로 만든다. weapon = 모드별 활성 무기(근접=주무기, 원거리=활).
## 원거리 모드에서 원거리 무기가 없으면 공격 불가(can_attack=false).
static func _make_unit(h, team: String, ranged_mode: bool) -> Dictionary:
	var w: String = ItemTypes.active_weapon(h.weapons, ranged_mode)
	var can: bool = (not ranged_mode) or (w != "")
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
