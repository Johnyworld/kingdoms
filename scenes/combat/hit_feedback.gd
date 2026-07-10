class_name HitFeedback
extends RefCounted
## 전투 연출 텍스트 매핑 — 판정 결과를 "떠오를 텍스트 사양"으로 바꾸는 순수 로직. 씬·노드 없다.
## 애니메이션(떠오름·반짝임·흔들림 등)은 battle.gd가, 색·문구 결정만 여기서 한다.

# 대미지 숫자 색(초안). BLEED_COLOR·STATUS_COLOR는 battle.gd가 도트·상태이상 텍스트에 쓴다.
const MISS_COLOR := Color(0.7, 0.7, 0.7)     # 빗나감 회색
const BLOCK_COLOR := Color(0.6, 0.8, 1.0)    # 막기 하늘색
const HIT_COLOR := Color(1.0, 1.0, 1.0)      # 평타 흰색
const CRIT_COLOR := Color(1.0, 0.85, 0.2)    # 치명타 노랑
const BLEED_COLOR := Color(1.0, 0.4, 0.4)    # 출혈 도트 붉은색
const STATUS_COLOR := Color(1.0, 0.6, 0.2)   # 상태이상 텍스트 주황

## resolve_hit 결과 → 떠오를 텍스트 사양 {text, color, big}. 빗나감>막기>치명>평타 순.
static func hit_text(r: Dictionary) -> Dictionary:
	if not r["hit"]:
		return {"text": "빗나감", "color": MISS_COLOR, "big": false}
	if r["blocked"]:
		return {"text": "막기", "color": BLOCK_COLOR, "big": false}
	if r["crit"]:
		return {"text": str(r["damage"]), "color": CRIT_COLOR, "big": true}
	return {"text": str(r["damage"]), "color": HIT_COLOR, "big": false}

## 상태이상 id → 떠오를 텍스트. 미지정 id는 "".
static func status_text(id: String) -> String:
	match id:
		"bleed": return "출혈!"
		"stun": return "기절!"
		_: return ""
