class_name LangResolver
extends RefCounted
## 물리 전투 계산 (Resolver) — 스펙 §2. 순수 함수: 렌더링 없음.
## 교전 입력 → 라운드별 히트/전사 시퀀스 + 최종 병력을 결정론적으로 계산한다.
## 이 분리 덕분에 "전투 애니 스킵"이 결과를 바꾸지 않는다(원작 동작, 스펙 §0).

const SUBUNITS_PER_SOLDIER := 8  # 병사 1명 = 8 세부단위 (스펙 §4)
const ACC_BASE := 30             # 명중 기본 (스펙 §2.1 accBase)

# 히트 이벤트 종류 (스펙 §2.7 HitEvent.kind)
enum Hit { HIT, MISS, SPECIAL, NO_KILL }

## Unit 팩토리 — 런타임 유닛 구조체 (스펙 §1.2).
## stats: 전투 스탯 블록 {at, df, cmd_range, cmd_at, cmd_df, kind} — UnitTypes.combat_stats(arche)로 주입.
##   유닛이 스탯을 직접 보유한다(class_id 참조 제거) → Resolver 는 데이터 출처에 독립인 순수 함수.
## commander 는 다른 Unit(Dictionary) 또는 null(=본인이 지휘관).
static func make_unit(stats: Dictionary, side: int, soldiers: int,
		gx: int = 0, gy: int = 0, item_id: int = 0,
		level: int = 1, acc_mod: int = 0) -> Dictionary:
	return {
		"at": int(stats.get("at", 0)),
		"df": int(stats.get("df", 0)),
		"cmd_range": int(stats.get("cmd_range", 0)),
		"cmd_at": int(stats.get("cmd_at", 0)),
		"cmd_df": int(stats.get("cmd_df", 0)),
		"kind": String(stats.get("kind", "")),  # 병종(cavalry/infantry/spear/archer/hero) — 상성용. 기본 중립.
		"level": level,
		"item_id": item_id,
		"side": side,
		"gx": gx,
		"gy": gy,
		"max_soldiers": soldiers,
		"strength": soldiers * SUBUNITS_PER_SOLDIER,  # 1/8 병사 단위
		"attack_count": soldiers + 3,  # 교전 공격 횟수 = 병사수+3 (원작 §1.2/§2.2) — 소수 유닛도 4회 공격
		"acc_mod": acc_mod,         # 방어측 회피 보정(지형 등)
		"commander": null,          # null 이면 self (거리 0 → 항상 자기 지휘보정)
		"self_cmd": true,           # false 면 자기 지휘보정 없음(단독 영웅 — 지휘할 부대 없음)
	}

static func soldier_count(u: Dictionary) -> int:
	return int(u["strength"]) / SUBUNITS_PER_SOLDIER

# ── 스탯 조립 (스펙 §2.1) ────────────────────────────────────────────────

## 상대를 고려한 최종 at/df 를 조립한다. {at, df} 반환.
static func assemble_stats(u: Dictionary, opp: Dictionary) -> Dictionary:
	var at: int = int(u["at"])
	var df: int = int(u["df"])
	# 병종 상성(기/보/창/궁 가위바위보, §2.3) — 유닛 kind 기반(TypeAdvantage 데이터).
	# 궁병 근접 취약이 여기서 나온다. hero·빈 kind 는 중립(ZERO).
	var lb := TypeAdvantage.bonus(String(u.get("kind", "")), String(opp.get("kind", "")))
	at += lb.x
	df += lb.y
	# 지휘범위 보정 (§2.4)
	var cb := _cmd_bonus(u)
	at += cb.x
	df += cb.y
	return {"at": at, "df": df, "base_at": int(u["at"]), "base_df": int(u["df"])}

## 지휘범위 보정 (스펙 §2.4, 원본 0xDC7C). 맨해튼 거리 ≤ range 면 지휘관 보너스.
## `self_cmd=false`(단독 영웅 등)면 본인 지휘보정(거리 0)을 받지 않는다 — 지휘할 부대 없는 1인 유닛.
static func _cmd_bonus(u: Dictionary) -> Vector2i:
	var cmdr: Variant = u["commander"]
	if cmdr == null:
		if not bool(u.get("self_cmd", true)):
			return Vector2i.ZERO  # 자기 지휘보정 없음(단독 영웅)
		cmdr = u  # 본인이 지휘관 (거리 0)
	var dist: int = abs(int(u["gx"]) - int(cmdr["gx"])) + abs(int(u["gy"]) - int(cmdr["gy"]))
	var rng_range: int = int(cmdr["cmd_range"])
	if int(cmdr["item_id"]) == 9:  # 지휘범위+5 아이템
		rng_range += 5
	if dist <= rng_range:
		return Vector2i(int(cmdr["cmd_at"]), int(cmdr["cmd_df"]))
	return Vector2i.ZERO

## 표시용 명중률(%) 근사 — 방어측 회피 반영 (스펙 §2.1).
static func hit_chance_pct(_attacker: Dictionary, defender: Dictionary) -> int:
	return clampi(100 - (ACC_BASE + int(defender["acc_mod"])), 0, 100)

# ── 교전 (스펙 §2.2, 원본 0xEC96/0xED60) ─────────────────────────────────

## 1회 명중 판정. attacker/defender 의 조립된 스탯(at/df)을 미리 넣어 호출한다.
static func _attempt_hit(rng: LangRng, atk_stat: Dictionary, def_unit: Dictionary,
		atk_soldiers: int) -> int:
	if rng.next_mod(100) < (ACC_BASE + int(def_unit["acc_mod"])):
		return Hit.MISS  # 회피
	if rng.next_mod(36) == 0:
		return Hit.SPECIAL  # 특수(효과 미확정, 부록A) — 우선 데미지 없음 처리
	if rng.next_mod(36) == 0:
		return Hit.MISS

	var atk: int = atk_stat["at"]
	var troops := atk_soldiers  # 병사 많을수록 강함
	var base := troops * 3 + 50
	var span: int = 100 - base
	var factor := base + 10
	if span > 0:
		factor += rng.next_mod(span)
	var raw := int(atk * factor / 100.0)
	var def_df: int = atk_stat["_opp_df"]
	if raw >= def_df:
		return Hit.HIT  # 방어측 병사 1명 전사
	return Hit.NO_KILL

## 양방향 교전 실행. 결정론적 시퀀스 + 최종 병력 반환 (스펙 §2.2/§2.7).
## 반환:
## {
##   rounds: [ {attacker_side, target_side, kind}, ... ],
##   final_a_soldiers, final_d_soldiers,
##   stats_a: {at,df,base_at,base_df,hit}, stats_d: {...},
## }
static func resolve_engagement(rng: LangRng, a: Dictionary, d: Dictionary) -> Dictionary:
	var sa := assemble_stats(a, d)
	var sd := assemble_stats(d, a)
	sa["_opp_df"] = sd["df"]
	sd["_opp_df"] = sa["df"]
	sa["hit"] = hit_chance_pct(a, d)
	sd["hit"] = hit_chance_pct(d, a)

	var a_soldiers := soldier_count(a)
	var d_soldiers := soldier_count(d)
	var rounds: Array = []

	# 공격자 -> 방어자
	var surv_d := d_soldiers
	for i in int(a["attack_count"]):
		var ev := _attempt_hit(rng, sa, d, a_soldiers)
		if ev == Hit.HIT:
			surv_d -= 1
		rounds.append({"attacker_side": int(a["side"]), "target_side": int(d["side"]), "kind": ev})

	# 방어자 -> 공격자 (반격): defender.attackCount > 0 일 때만 (스펙 §2.2)
	var surv_a := a_soldiers
	if int(d["attack_count"]) > 0:
		for i in int(d["attack_count"]):
			var ev := _attempt_hit(rng, sd, a, d_soldiers)
			if ev == Hit.HIT:
				surv_a -= 1
			rounds.append({"attacker_side": int(d["side"]), "target_side": int(a["side"]), "kind": ev})

	return {
		"rounds": rounds,
		"final_a_soldiers": maxi(surv_a, 0),
		"final_d_soldiers": maxi(surv_d, 0),
		"stats_a": sa,
		"stats_d": sd,
	}

# ── 사격 (원거리 전투 — 스펙 "경궁병 사격 전투") ─────────────────────────────
## 라운드별로 생존 슈터가 각 1발씩 발사. 명중이면 상대 1명 감소(생존자 초과 킬 불가=cap).
## 슈터 수는 **라운드 시작 생존자로 잠금**(양측 "동시" 근사): 같은 라운드 안에서 공격측 볼리 →
## 방어측 볼리, 각 볼리 슈터 수는 라운드 시작값 고정. 라운드 사이 사망은 다음 라운드 슈터 수에 반영.
## 계산/연출 분리(§0): 여기서 "어느 화살이 죽이는지"(kill 플래그)를 확정, Presenter 는 화살로 재생만 한다.
## 반환: {shots:[{side,round,kill}], final_a_soldiers, final_d_soldiers, stats_a, stats_d}
static func resolve_ranged(rng: LangRng, a: Dictionary, d: Dictionary,
		a_rounds: int, d_rounds: int) -> Dictionary:
	var sa := assemble_stats(a, d)
	var sd := assemble_stats(d, a)
	sa["_opp_df"] = sd["df"]
	sd["_opp_df"] = sa["df"]
	sa["hit"] = hit_chance_pct(a, d)
	sd["hit"] = hit_chance_pct(d, a)

	var surv_a := soldier_count(a)
	var surv_d := soldier_count(d)
	var shots: Array = []
	for r in range(maxi(a_rounds, d_rounds)):
		# 슈터 수 = 라운드 시작 생존자(양측 잠금 → 라운드 내 사망이 슈터 수를 안 줄임).
		var a_shooters := surv_a if r < a_rounds else 0
		var d_shooters := surv_d if r < d_rounds else 0
		for i in range(a_shooters):                        # 공격측 볼리
			var ev := _attempt_hit(rng, sa, d, a_shooters)
			var kill := ev == Hit.HIT and surv_d > 0
			if kill:
				surv_d -= 1
			shots.append({"side": int(a["side"]), "round": r, "kill": kill})
		for i in range(d_shooters):                        # 방어측 볼리
			var ev := _attempt_hit(rng, sd, a, d_shooters)
			var kill := ev == Hit.HIT and surv_a > 0
			if kill:
				surv_a -= 1
			shots.append({"side": int(d["side"]), "round": r, "kill": kill})

	return {
		"shots": shots,
		"final_a_soldiers": maxi(surv_a, 0),
		"final_d_soldiers": maxi(surv_d, 0),
		"stats_a": sa,
		"stats_d": sd,
	}
