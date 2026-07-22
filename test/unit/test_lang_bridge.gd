extends GutTest
## LangBridge — 게임 부대(Party: archetype + soldiers) ↔ lang 전투 유닛 매핑.
## 완전 교체(랑그릿사식 전투) 배선의 단일 매핑. 순수 로직이라 씬 없이 검증한다.

const PartyScript = preload("res://scenes/party/party.gd")

## 병력 n인 부대를 만든다(kind·troop_type 지정). 노드지만 데이터만 쓰므로 add_child_autofree로 정리.
func _party(kind: String, troop_type: String, n: int) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.kind = kind
	p.troop_type = troop_type
	p.soldiers = n
	return p

# --- unit_from_party ---

func test_infantry_unit() -> void:
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_infantry", 7), 0)
	assert_eq(u["at"], GameUnits.base_at("light_infantry"), "경보병 at(GameUnits 단일 출처)")
	assert_eq(u["df"], GameUnits.base_df("light_infantry"), "경보병 df")
	assert_eq(u["kind"], "infantry", "병종 infantry")
	assert_eq(u["max_soldiers"], 7, "soldiers = party.soldiers")
	assert_eq(u["side"], 0, "side 반영")
	assert_eq(u["acc_mod"], LangBridge.TROOP_ACC, "개활지 회피 보정")

func test_archer_unit() -> void:
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_archer", 5), 1)
	assert_eq(u["kind"], "archer", "병종 archer(근접 상성 페널티 대상)")
	assert_eq(u["at"], GameUnits.base_at("light_archer"), "경궁병 at(경보병과 동일 base)")
	assert_eq(u["df"], GameUnits.base_df("light_archer"), "경궁병 df")
	assert_eq(u["max_soldiers"], 5, "soldiers = party.soldiers")
	assert_eq(u["side"], 1, "side 반영")

func test_hero_unit() -> void:
	# 영웅부대는 생성 시 soldiers = GameUnits.max_hp("hero")로 세팅되므로 그 값이 병력으로 전달된다.
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_HERO, "", GameUnits.max_hp("hero")), 0)
	assert_eq(u["at"], GameUnits.base_at("hero"), "영웅 = 지휘관 클래스 at")
	assert_eq(u["df"], GameUnits.base_df("hero"), "영웅 df")
	assert_eq(u["kind"], "hero", "영웅 kind(상성 중립)")
	assert_eq(u["max_soldiers"], GameUnits.max_hp("hero"), "영웅 병력 = 클래스 HP 풀")
	assert_false(u["self_cmd"], "단독 영웅 — 자기 지휘보정 없음")

# --- 브릿지 출력이 LangResolver에 그대로 들어가는지(통합 sanity) ---

func test_bridged_units_resolve() -> void:
	var a := LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_infantry", 10), 0)
	var d := LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_infantry", 10), 1)
	var rng := LangRng.new(12345)
	var res: Dictionary = LangResolver.resolve_engagement(rng, a, d)
	assert_between(res["final_a_soldiers"], 0, 10, "공격측 최종 병력 0~10")
	assert_between(res["final_d_soldiers"], 0, 10, "방어측 최종 병력 0~10")
	# 1교전은 소모전 — 한 번에 전멸시키지 않는다(양측 대부분 생존).
	assert_gt(res["final_a_soldiers"] + res["final_d_soldiers"], 0, "1교전으로 양측 동시 전멸하지 않음")
