extends GutTest
## LangBridge — 게임 부대(Party) ↔ lang 전투 유닛 매핑, lang 결과 → 생존 Human 목록.
## 완전 교체(랑그릿사식 전투) 배선의 단일 매핑. 순수 로직이라 씬 없이 검증한다.

const PartyScript = preload("res://scenes/party/party.gd")
const HumanScript = preload("res://scenes/human/human.gd")

## 멤버 n명 부대를 만든다(kind·troop_type 지정). 노드지만 데이터만 쓰므로 add_child_autofree로 정리.
func _party(kind: String, troop_type: String, n: int) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.kind = kind
	p.troop_type = troop_type
	for i in n:
		p.add_member(HumanScript.new("m%d" % i))
	return p

# --- unit_from_party ---

func test_infantry_unit() -> void:
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_infantry", 7), 0)
	assert_eq(u["class_id"], LangBridge.INFANTRY_CLASS, "경보병 classId")
	assert_eq(u["kind"], "infantry", "병종 infantry")
	assert_eq(u["max_soldiers"], 7, "soldiers = 멤버 수")
	assert_eq(u["side"], 0, "side 반영")
	assert_eq(u["acc_mod"], LangBridge.TROOP_ACC, "개활지 회피 보정")

func test_archer_unit() -> void:
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_archer", 5), 1)
	assert_eq(u["kind"], "archer", "병종 archer(근접 상성 페널티 대상)")
	assert_eq(u["class_id"], LangBridge.ARCHER_CLASS, "경궁병 classId(경보병과 동일 base)")
	assert_eq(u["max_soldiers"], 5, "soldiers = 멤버 수")
	assert_eq(u["side"], 1, "side 반영")

func test_hero_unit() -> void:
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_HERO, "", 1), 0)
	assert_eq(u["class_id"], LangBridge.HERO_CLASS, "영웅 = 지휘관 클래스")
	assert_eq(u["kind"], "", "영웅 병종 중립")
	assert_eq(u["max_soldiers"], LangBridge.HERO_SOLDIERS, "영웅 병력=고정 HP 몫(멤버 수 아님)")
	assert_false(u["self_cmd"], "단독 영웅 — 자기 지휘보정 없음")

# --- survivors ---

func test_survivors_troop_slice() -> void:
	var p := _party(PartyScript.KIND_TROOP, "light_infantry", 7)
	assert_eq(LangBridge.survivors(p, 4).size(), 4, "최종 4 → 앞 4명 생존")
	assert_eq(LangBridge.survivors(p, 0), [], "최종 0 → 전멸")
	assert_eq(LangBridge.survivors(p, 99).size(), 7, "초과분은 실제 멤버 수로 clamp")
	assert_eq(LangBridge.survivors(p, 4)[0], p.members[0], "앞에서부터 유지(멤버 참조 보존)")

func test_survivors_hero() -> void:
	var p := _party(PartyScript.KIND_HERO, "", 1)
	assert_eq(LangBridge.survivors(p, 1).size(), 1, "병력>0 → 영웅 생존(멤버 유지)")
	assert_eq(LangBridge.survivors(p, 5).size(), 1, "영웅은 병력수와 무관하게 Human 1인")
	assert_eq(LangBridge.survivors(p, 0), [], "병력 0 → 영웅 전멸")

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
