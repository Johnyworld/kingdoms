class_name BattleSim
extends RefCounted
## 오버레이 없이 두 부대의 교전 결과만 계산하는 순수 함수(테스트 용이).
## 위치·이동을 무시하고 교전만 반복하는 추상 결산이라, 오버레이의 공간 전투와 결과가 다를 수 있다.
## 플레이어가 보지 않는 NPC끼리 전투에만 쓴다. 판정은 CombatResolver 재사용.

const MAX_ROUNDS := 20   # 양측이 계속 빗나가는 교착을 끊는 안전 상한.

## a_members·b_members(Human 목록)의 교전을 결산한다. 반환: {a: 생존 human 목록, b: 생존 human 목록}.
## 라운드마다 각 살아있는 유닛이 상대 팀의 살아있는 유닛 하나와 1회 교전한다.
static func resolve_battle(a_members: Array, b_members: Array, rng: RandomNumberGenerator) -> Dictionary:
	var units: Array = []
	for h in a_members:
		units.append({"human": h, "team": "a", "hp": int(h.hit_points), "alive": true})
	for h in b_members:
		units.append({"human": h, "team": "b", "hp": int(h.hit_points), "alive": true})

	var rounds := 0
	while _living(units, "a") and _living(units, "b") and rounds < MAX_ROUNDS:
		rounds += 1
		for u in units:
			if not u["alive"]:
				continue
			var enemy := _pick_enemy(units, u["team"])
			if enemy.is_empty():
				break   # 상대 팀 전멸 — 라운드 종료
			var r := CombatResolver.resolve_engagement(u["human"], enemy["human"], u["hp"], enemy["hp"], rng)
			u["hp"] = r["a_hp"]
			enemy["hp"] = r["b_hp"]
			if u["hp"] <= 0:
				u["alive"] = false
			if enemy["hp"] <= 0:
				enemy["alive"] = false

	return {"a": _survivors(units, "a"), "b": _survivors(units, "b")}

## team의 살아있는 유닛이 하나라도 있는지.
static func _living(units: Array, team: String) -> bool:
	for u in units:
		if u["team"] == team and u["alive"]:
			return true
	return false

## team의 상대 팀에서 살아있는 유닛 하나(없으면 빈 Dictionary).
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
