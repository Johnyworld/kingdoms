class_name StatusEffects
extends RefCounted
## 상태이상 — 전투 치명타 연동(출혈·기절)을 초 기반으로 다루는 순수 로직. 씬·시각 요소 없다.
## 효과 상태는 유닛마다 하나의 Dictionary(effects)로 들고 다닌다.
##   예: {"bleed": {"remaining": 2.4, "stacks": 2, "acc": 0.7}, "stun": {"remaining": 1.1}}
## 기획 원본(docs/table/시스템/상태이상.md)의 턴 지속을 초 단위로 재해석한 초안 수치다.

const BLEED_DURATION := 3.0    # 출혈 지속(초)
const BLEED_DPS := 3.0         # 스택당 초당 피해
const BLEED_MAX_STACKS := 3    # 출혈 스택 상한
const STUN_DURATION := 2.0     # 기절 지속(초)

## 치명타로 피해가 들어간 타격이 부여할 효과 id. 참격→출혈, 타격→기절, 그 외 "".
static func on_crit(damage_type: String) -> String:
	match damage_type:
		"참격": return "bleed"
		"타격": return "stun"
		_: return ""

## 효과 부여/갱신. bleed는 지속 리셋 + 스택 +1(상한), stun은 지속만 리셋(스택 없음).
static func apply(effects: Dictionary, id: String) -> void:
	match id:
		"bleed":
			if effects.has("bleed"):
				effects["bleed"]["stacks"] = mini(effects["bleed"]["stacks"] + 1, BLEED_MAX_STACKS)
				effects["bleed"]["remaining"] = BLEED_DURATION
			else:
				effects["bleed"] = {"remaining": BLEED_DURATION, "stacks": 1, "acc": 0.0}
		"stun":
			effects["stun"] = {"remaining": STUN_DURATION}

## 모든 효과를 dt(초)만큼 진행하고 만료된 것을 제거한다. 이 구간 출혈 누적 피해(정수)를 반환.
## 프레임 dt가 작아도 피해가 사라지지 않도록 실수 누적치(acc)를 두고 floor 몫만 떼어낸다.
static func advance(effects: Dictionary, dt: float) -> int:
	var damage := 0
	if effects.has("bleed"):
		var b: Dictionary = effects["bleed"]
		var tick := minf(dt, b["remaining"])   # 남은 지속 안에서만 도트 발생
		b["acc"] += BLEED_DPS * b["stacks"] * tick
		var whole := int(floor(b["acc"]))
		b["acc"] -= whole
		damage += whole
		b["remaining"] -= dt
		if b["remaining"] <= 0.0:
			effects.erase("bleed")
	if effects.has("stun"):
		var s: Dictionary = effects["stun"]
		s["remaining"] -= dt
		if s["remaining"] <= 0.0:
			effects.erase("stun")
	return damage

## 기절 효과가 살아 있으면 true(그동안 공격 불가).
static func is_stunned(effects: Dictionary) -> bool:
	return effects.has("stun")
