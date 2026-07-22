extends GutTest
## lang_battle presenter의 게임 오버레이 API — start_overlay(cfg)로 시작해 종료 시 finished(병력수) 방출.
## 판정은 LangResolver(순수)라 test_lang_bridge가 커버. 여기선 오버레이 구동·종료·결과 방출 계약을 확인.

const OverlayScene = preload("res://scenes/lang_battle/lang_battle.tscn")
const PartyScript = preload("res://scenes/party/party.gd")

var battle
var _fin_a := -1
var _fin_b := -1
var _fin_count := 0

func before_each() -> void:
	battle = OverlayScene.instantiate()
	battle.overlay_mode = true   # add_child 전에 설정 → _ready 자동 로드 안 함
	battle.rng_seed = 20260721   # 고정 시드 — 시간 기반 시드의 순서 의존 flaky 제거(결정론적 결과)
	add_child_autofree(battle)
	battle.finished.connect(_on_finished)
	_fin_a = -1
	_fin_b = -1
	_fin_count = 0

func _on_finished(a: int, b: int) -> void:
	_fin_a = a
	_fin_b = b
	_fin_count += 1

## 스킵으로 상태를 전진시켜 DONE(finished)까지 구동한다. 필드 애니 의존 전이는 헤드리스 단위 테스트에서
## 필드 노드 _process가 안 돌아 멈추므로(실제 게임 루프는 정상), 스킵으로 결정론적으로 결과까지 몬다.
## _skip은 DONE에서 재전투(_restart)라, 매 단계 finished를 확인해 그 전에 멈춘다.
func _drive_to_done(max_iter := 40) -> void:
	for i in max_iter:
		if _fin_count > 0:
			return
		battle._skip()
		if _fin_count > 0:
			return
		battle._process(0.1)

func _cfg(a_kind: String, a_n: int, b_kind: String, b_n: int, mode := "melee") -> Dictionary:
	return {"a": {"kind": a_kind, "count": a_n}, "b": {"kind": b_kind, "count": b_n}, "mode": mode}

func test_overlay_ready_does_not_autoload() -> void:
	# overlay_mode면 _ready가 시나리오/설정을 로드하지 않는다(전투 미시작).
	assert_eq(_fin_count, 0, "start_overlay 전엔 종료 방출 없음")

func test_melee_overlay_finishes_and_emits() -> void:
	battle.start_overlay(_cfg("infantry", 10, "infantry", 10))
	_drive_to_done()
	assert_eq(_fin_count, 1, "근접 오버레이가 종료돼 finished 1회 방출")
	assert_between(_fin_a, 0, 10, "side0 최종 병력 0~10")
	assert_between(_fin_b, 0, 10, "side1 최종 병력 0~10")
	assert_gt(_fin_a + _fin_b, 0, "근접 1교전 — 양측 동시 전멸 아님")

func test_settle_holds_before_finish() -> void:
	# 복귀 완료(RETREAT→SETTLE) 후 SETTLE_PAUSE(1초) 여운이 지나야 종료(finished) 방출.
	battle.start_overlay(_cfg("infantry", 10, "infantry", 10))
	battle._state = battle.St.SETTLE
	battle._timer = 0.0
	battle._process(0.05)
	assert_eq(_fin_count, 0, "SETTLE 여운 중엔 종료 안 함")
	# SETTLE_PAUSE 경과(delta 상한 0.05라 여러 프레임) → DONE·finished.
	for i in 40:
		if _fin_count > 0:
			break
		battle._process(0.05)
	assert_eq(_fin_count, 1, "SETTLE_PAUSE 경과 후 종료·finished 1회")

func test_hero_vs_infantry_overlay() -> void:
	battle.start_overlay(_cfg("hero", 10, "infantry", 10))
	_drive_to_done()
	assert_eq(_fin_count, 1, "영웅 vs 경보병 오버레이 종료")
	assert_between(_fin_a, 0, 10, "영웅측 병력 범위")

func test_ranged_overlay_finishes() -> void:
	# 원거리(경궁병 → 경보병, mode ranged) 오버레이도 종료·finished 방출.
	battle.start_overlay(_cfg("archer", 10, "infantry", 10, "ranged"))
	_drive_to_done()
	assert_eq(_fin_count, 1, "원거리(사격) 오버레이 종료")
	assert_between(_fin_a, 0, 10, "궁병측 병력 범위")
	assert_between(_fin_b, 0, 10, "표적측 병력 범위")

# --- LangBridge.battle_config (부대 → 오버레이 cfg) ---

func _party(kind: String, troop_type: String, n: int) -> Node2D:
	var p: Node2D = PartyScript.new()
	add_child_autofree(p)
	p.kind = kind
	p.troop_type = troop_type
	p.soldiers = n
	return p

func test_battle_config_from_parties() -> void:
	var atk := _party(PartyScript.KIND_TROOP, "light_infantry", 10)
	var deff := _party(PartyScript.KIND_TROOP, "light_archer", 6)
	var cfg: Dictionary = LangBridge.battle_config(atk, deff, 1)
	assert_eq(cfg["a"], {"kind": "infantry", "count": 10}, "공격측 = 경보병 10")
	assert_eq(cfg["b"], {"kind": "archer", "count": 6}, "방어측 = 경궁병 6")
	assert_eq(cfg["mode"], "melee", "거리 1 → 근접")
	assert_eq(LangBridge.battle_config(atk, deff, 3)["mode"], "ranged", "거리 3 → 원거리")

func test_battle_config_hero_count_from_soldiers() -> void:
	# 영웅부대는 생성 시 soldiers = UnitTypes.max_hp("hero")로 세팅된다.
	var hero := _party(PartyScript.KIND_HERO, "", UnitTypes.max_hp("hero"))
	var cfg: Dictionary = LangBridge.battle_config(hero, hero, 1)
	assert_eq(cfg["a"]["kind"], "hero", "영웅 kind")
	assert_eq(cfg["a"]["count"], UnitTypes.max_hp("hero"), "영웅 병력 = 클래스 HP 풀(party.soldiers)")
