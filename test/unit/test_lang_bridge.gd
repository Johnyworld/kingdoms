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
	assert_eq(u["at"], UnitTypes.base_at("light_infantry"), "경보병 at(UnitTypes 단일 출처)")
	assert_eq(u["df"], UnitTypes.base_df("light_infantry"), "경보병 df")
	assert_eq(u["kind"], "infantry", "병종 infantry")
	assert_eq(u["max_soldiers"], 7, "soldiers = party.soldiers")
	assert_eq(u["side"], 0, "side 반영")
	assert_eq(u["acc_mod"], LangBridge.TROOP_ACC, "개활지 회피 보정")

func test_archer_unit() -> void:
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_TROOP, "light_archer", 5), 1)
	assert_eq(u["kind"], "archer", "병종 archer(근접 상성 페널티 대상)")
	assert_eq(u["at"], UnitTypes.base_at("light_archer"), "경궁병 at(경보병과 동일 base)")
	assert_eq(u["df"], UnitTypes.base_df("light_archer"), "경궁병 df")
	assert_eq(u["max_soldiers"], 5, "soldiers = party.soldiers")
	assert_eq(u["side"], 1, "side 반영")

func test_hero_unit() -> void:
	# 영웅부대는 생성 시 soldiers = UnitTypes.max_hp("hero")로 세팅되므로 그 값이 병력으로 전달된다.
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_HERO, "", UnitTypes.max_hp("hero")), 0)
	assert_eq(u["at"], UnitTypes.base_at("hero"), "영웅 = 지휘관 클래스 at")
	assert_eq(u["df"], UnitTypes.base_df("hero"), "영웅 df")
	assert_eq(u["kind"], "hero", "영웅 kind(상성 중립)")
	assert_eq(u["max_soldiers"], UnitTypes.max_hp("hero"), "영웅 병력 = 클래스 HP 풀")
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

# --- battle_config: 스프라이트를 cfg에 실어 전달(전투씬 외형은 병종 데이터로 결정) ---

func test_battle_config_carries_sprite() -> void:
	var atk := _party(PartyScript.KIND_TROOP, "light_infantry", 10)
	var dfd := _party(PartyScript.KIND_TROOP, "light_archer", 10)
	var cfg: Dictionary = LangBridge.battle_config(atk, dfd, 1)
	assert_eq(cfg["a"]["sprite"], "soldier", "공격측 sprite = 경보병 세트")
	assert_eq(cfg["b"]["sprite"], "archer_a", "방어측 sprite = 경궁병 세트")

func test_battle_config_sprite_independent_of_side() -> void:
	# 같은 병종이면 공/방 무관 동일 sprite (side 기반 아님 — 세력 정체성 유지).
	var cfg: Dictionary = LangBridge.battle_config(
		_party(PartyScript.KIND_TROOP, "orc_infantry", 10),
		_party(PartyScript.KIND_TROOP, "orc_infantry", 10), 1)
	assert_eq(cfg["a"]["sprite"], "orc", "공격측 오크")
	assert_eq(cfg["b"]["sprite"], "orc", "방어측도 오크(side 무관)")

func test_battle_config_dark_hero_sprite() -> void:
	# 영웅부대가 자기 아키타입(dark_hero)을 기억해 오크 영웅 세트로 렌더된다.
	var cfg: Dictionary = LangBridge.battle_config(
		_party(PartyScript.KIND_HERO, "dark_hero", UnitTypes.max_hp("dark_hero")),
		_party(PartyScript.KIND_TROOP, "orc_infantry", 10), 1)
	assert_eq(cfg["a"]["sprite"], "eliteorc", "암흑 영웅 → eliteorc")
	assert_eq(cfg["a"]["kind"], "hero", "kind는 여전히 hero(상성 중립)")

# --- battle_config: 세력·부대 정체성을 cfg에 실어 전달(전투 HUD 표기) ---

func test_battle_config_carries_faction_and_party() -> void:
	var atk := _party(PartyScript.KIND_HERO, "hero", UnitTypes.max_hp("hero"))
	atk.faction_name = "푸른 왕국"
	atk.party_name = "아젤 하르윈 부대"
	var dfd := _party(PartyScript.KIND_TROOP, "orc_infantry", 10)
	dfd.faction_name = "암흑 제국"
	dfd.party_name = "오크 전사대"
	var cfg: Dictionary = LangBridge.battle_config(atk, dfd, 1)
	assert_eq(cfg["a"]["faction"], "푸른 왕국", "공격측 세력명")
	assert_eq(cfg["a"]["party"], "아젤 하르윈 부대", "공격측 부대명")
	assert_eq(cfg["b"]["faction"], "암흑 제국", "방어측 세력명")
	assert_eq(cfg["b"]["party"], "오크 전사대", "방어측 부대명")

func test_battle_config_carries_faction_color() -> void:
	# 색은 factions.csv 세력 색(표시명 역조회) — 맵 토큰 색(token_color)이 아님.
	var atk := _party(PartyScript.KIND_TROOP, "light_infantry", 10)
	atk.faction_name = "푸른 왕국"
	var dfd := _party(PartyScript.KIND_TROOP, "orc_infantry", 10)
	dfd.faction_name = "암흑 제국"
	var cfg: Dictionary = LangBridge.battle_config(atk, dfd, 1)
	assert_eq(cfg["a"]["color"], Color.html("#334DCC"), "공격측 = 푸른 왕국 색")
	assert_eq(cfg["b"]["color"], Color.html("#803D99"), "방어측 = 암흑 제국 색")

func test_dark_hero_unit_treated_as_hero() -> void:
	# dark_hero도 hero처럼 처리 — is_hero 판정은 리터럴이 아니라 kind 기준.
	var u: Dictionary = LangBridge.unit_from_party(_party(PartyScript.KIND_HERO, "dark_hero", UnitTypes.max_hp("dark_hero")), 0)
	assert_eq(u["at"], UnitTypes.base_at("dark_hero"), "오크 영웅 at = hero at")
	assert_eq(u["kind"], "hero", "kind hero(상성 중립)")
	assert_false(u["self_cmd"], "단독 영웅 — 자기 지휘보정 없음(dark_hero도 동일)")
