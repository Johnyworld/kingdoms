extends Node2D
## 전투 씬 Presenter — 스펙 §3. Resolver(순수 계산) 결과를 상태머신으로 재생한다.
## 계산과 연출이 분리돼 있어 "애니 스킵"이 결과를 바꾸지 않는다(스펙 §0).
##
## 연출: 정보 표시 → 양측 전진 → 중앙 난투(짝지어 찌르기·전사) → 결과.
## 격리 테스트용: 인트로 [새 게임] → 이 씬으로 바로 진입. 10:10 더미 교전.

@onready var _field: Node2D = $Battlefield
@onready var _hud: Control = $HudLayer/Hud
@onready var _hint: Label = $HudLayer/Hint

# 상태 전이 — 스폰 즉시 돌격 → 접촉 즉시 교전 → 결과 → 본인 진영 복귀.
# RANGED = 사격 전투(경궁병) 전용 상태(근접 상태들과 분리).
enum St { CHARGE, CLASH, POST, RETREAT, DONE, FINALE, RANGED }

# 타이밍
const STEP := 0.75          # AT/DF 지휘보정 틱업 시간(돌격과 동시 진행)
const ADVANCE_TIME := 2.2   # 돌격 최대 시간(상한). 실제로는 접전 도달 시 전환
# 최소 전투시간: CLASH 길이 = clamp(MELEE_PER_UNIT × basis, MELEE_FLOOR, MELEE_CAP),
#   basis = max(min(a_start,b_start), deaths_a, deaths_b). 킬은 그 안에 분산, 남는 시간은 스커미시가 채움.
const MELEE_PER_UNIT := 0.22 # 기준값당 전투시간(초)
const MELEE_FLOOR := 0.5     # 최소 전투시간(초)
const MELEE_CAP := 2.2       # 최대 전투시간(초)
# 빠른 근접(궁병 근접전) — 근접 vs 근접보다 짧게 끝남.
const FAST_MELEE_PER_UNIT := 0.26
const FAST_MELEE_FLOOR := 0.6
const FAST_MELEE_CAP := 1.5
const KILL_JITTER := 0.65    # 킬 타이밍 지터(±, 간격 비율) — 등간격 깨서 리듬 만들기
# 최후 전투: 일정 확률로 마지막 사망을 유예 → 나머지 복귀 후 필드에 남은 1쌍이 1:1 최후 전투.
const DEFER_LAST_CHANCE := 0.25   # 이 확률로 최후 전투(가능할 때만)
const DEFER_DOUBLE_CHANCE := 0.05 # (양 팀 모두 죽음 있을 때) 이 확률로 양 팀 각 1:1 최후 전투 — 레어
const FINALE_STAGE_MAX := 3.5     # 나머지 복귀 대기 상한(초) — 넘으면 강제로 최후 킬 발동
const FINALE_MAX := 4.0           # 최후 전투(듀얼+복귀) 상한(초)
const POST_PAUSE := 0.0     # 결과 표시 후 복귀 시작까지 — 0=마지막 킬 직후 바로 순차 복귀(얼음 구간 제거)
const RETREAT_MAX := 4.0    # 복귀 최대 시간(상한) — 스커미시 대기 + 순차 peel-off 감안

const START_SOLDIERS := 10

# 사격(RANGED) 타이밍
const SHOT_STAGGER := 0.06  # 라운드 내 화살 발사 간격(초) — 빠른 볼리(붙기 전 사격 마치게)
const ROUND_GAP := 0.55     # 라운드 사이 간격(초, 사상자 반영 뒤 다음 볼리)
# 병종 매핑(근사): 경궁병 ≈ classId 27(고AT·저DF), 경보병 ≈ classId 1. 개활지 회피 5.
const ARCHER_CLASS := 1   # 경궁병도 경보병과 동일 base 스탯(공정 비교) — 차이는 역할(사격)+근접 배율뿐
const INFANTRY_CLASS := 1
# 궁병 근접 취약은 **병종 상성**(보병>궁병 +4/+2, LangResolver)이 담당 — 별도 at/df 페널티 없음.
const SCENARIO2_CHARGE_EVASION := 25  # 시나리오2 볼리: 돌격 중 보병 화살 회피 → 근접 도달 늘려 보병 우세로

# 영웅 병종: classId 4(지휘관, base at27/df24). 단독 영웅은 자기 지휘보정 없이 27/24 유지.
const HERO_CLASS := 4

var _rng: LangRng
var _a: Dictionary
var _d: Dictionary
var _result: Dictionary

var _state: int = St.CHARGE
var _timer := 0.0
var _a_cur := START_SOLDIERS
var _b_cur := START_SOLDIERS

# 시나리오 선택(직접 진입 시 기본값). 설정 화면 진입 시엔 -1(해당 없음).
var _scenario := 1
var _name_a := ""
var _name_b := ""
# 사격 진행 상태
var _rounds_shots: Array = []  # round → [{side,kill}, ...]
var _then_melee := false       # 사격 후 근접 전환(스커미시: 사격→근접)
var _open_d_surv := 0          # 사격 오프닝 후 근접측(보병) 생존 = 근접 시작 인원
var _sk_archer_side := 0       # 스커미시에서 궁병(사격) 진영(0/1). 근접측 = 1 - 이 값
var _sk_archer_count := START_SOLDIERS  # 스커미시 궁병 인원(볼리에 무피해 → 근접까지 유지)
var _melee_start_a := START_SOLDIERS  # 근접 시작 인원(킬 스케줄·최소전투시간 계산용)
var _melee_start_b := START_SOLDIERS
var _fast_melee := false       # 궁병 근접전 — 짧은 CLASH·유예 생략·헛칼질 제거
var _hero_battle := false       # 영웅 전투(시나리오 5) — 1인 영웅(HP) vs 경보병 10, 최후 1:1 유예 생략
var _cur_round := 0
var _round_started := false
var _round_i := 0
var _shot_cd := 0.0
var _round_gap := 0.0
var _events: Array = []  # 킬 스케줄(전 구간 분산) — _build_plan
var _event_i := 0
var _melee_dur := 0.0        # 이번 CLASH 목표 길이(_melee_duration)
var _event_times: Array = [] # 각 킬의 재생 시각(CLASH 시작 기준, 지터 적용·정렬)
var _deferred_sides: Array = []  # 최후 1:1로 유예한 사망의 팀 목록(0/1). []=없음, [t]=단일, [0,1]=더블
var _finale_fired := false       # FINALE에서 최후 킬을 이미 발동했는가
var _fx_rng := RandomNumberGenerator.new()  # 연출용(킬 타이밍 지터) — 결과와 무관

var _custom_cfg: Dictionary = {}  # 설정 화면에서 넘어온 커스텀 전투 설정({}=기본 시나리오)

func _ready() -> void:
	_fx_rng.randomize()  # 연출용 RNG(타이밍 지터) — 결과에는 영향 없음
	_custom_cfg = LangBattleConfig.take()
	if _custom_cfg.is_empty():
		_load_scenario(1)      # 직접 진입(설정 없음): 기본 시나리오 1
	else:
		_load_custom(_custom_cfg)  # 설정 화면 진입: 커스텀 전투

## 시나리오 로드(직접 진입 시 기본 폴백). 0=근접 난투, 1/3/4=사격, 2=스커미시, 5=영웅 근접.
func _load_scenario(n: int) -> void:
	_scenario = n
	_a_cur = START_SOLDIERS
	_b_cur = START_SOLDIERS
	_then_melee = false
	_fast_melee = false
	_hero_battle = false
	_melee_start_a = START_SOLDIERS
	_melee_start_b = START_SOLDIERS
	match n:
		0:
			_load_melee()
		2:
			_load_scenario2()  # 경궁병 vs 경보병: 사격 오프닝 → 근접
		5:
			_load_hero()       # 영웅(27/24 단독) vs 경보병 10
		_:
			_load_ranged(n)

## 커스텀 전투(설정 화면) — 양 진영 {kind, count} + 공용 교전 방식 mode.
## 원거리(mode="ranged", 최소 한쪽 경궁병):
##   - 양측 경궁병 → 사격 대결
##   - 경궁병 + 경보병 → 스커미시(궁병 사격 오프닝 → 근접)
##   - 경궁병 + 영웅 → 근접 폴백(영웅은 스커미시 스폰 대상 아님)
## 근접(mode="melee"): 병종/인원 임의 근접.
func _load_custom(cfg: Dictionary) -> void:
	var a: Dictionary = cfg["a"]
	var b: Dictionary = cfg["b"]
	var mode := String(cfg.get("mode", "melee"))
	_scenario = -1
	_a_cur = int(a["count"])
	_b_cur = int(b["count"])
	_then_melee = false
	_fast_melee = false
	_hero_battle = false
	_melee_start_a = int(a["count"])
	_melee_start_b = int(b["count"])
	if mode == "ranged":
		var a_arc := String(a["kind"]) == "archer"
		var b_arc := String(b["kind"]) == "archer"
		if a_arc and b_arc:
			_load_custom_ranged(a, b)
		elif a_arc and String(b["kind"]) == "infantry":
			_load_custom_skirmish(a, b, 0)   # side0 궁병 사격 → 근접
		elif b_arc and String(a["kind"]) == "infantry":
			_load_custom_skirmish(a, b, 1)   # side1 궁병 사격 → 근접
		else:
			_load_custom_melee(a, b)         # 경궁병+영웅 등 → 근접 폴백
	else:
		_load_custom_melee(a, b)

## 커스텀 근접 — 병종/인원 임의. resolve_engagement + CHARGE→CLASH→RETREAT 재사용.
func _load_custom_melee(a: Dictionary, b: Dictionary) -> void:
	_rng = _fresh_rng()
	_a = _mk_custom_unit(a, 0)
	_d = _mk_custom_unit(b, 1)
	_hero_battle = String(a["kind"]) == "hero" or String(b["kind"]) == "hero"
	_name_a = _kind_label(String(a["kind"]))
	_name_b = _kind_label(String(b["kind"]))
	_result = LangResolver.resolve_engagement(_rng, _a, _d)
	_events = _build_plan()
	_init_hud_stats(false)
	_hud.set_title("%s  vs  %s (근접)" % [_name_a, _name_b])
	_field.call("setup_custom", {"kind": a["kind"], "count": a["count"]}, {"kind": b["kind"], "count": b["count"]})
	_field.call("begin_advance")
	_enter(St.CHARGE)

## 커스텀 사격 — 양측 경궁병·원거리. resolve_ranged + St.RANGED 재사용(1볼리).
func _load_custom_ranged(a: Dictionary, b: Dictionary) -> void:
	_rng = _fresh_rng()
	_a = _mk_custom_unit(a, 0)
	_d = _mk_custom_unit(b, 1)
	_name_a = "경궁병(청)"
	_name_b = "경궁병(적)"
	_result = LangResolver.resolve_ranged(_rng, _a, _d, 1, 1)
	_init_hud_stats(true)
	_rounds_shots = _group_shots_by_round(_result["shots"])
	_hud.set_title("경궁병  vs  경궁병 (사격)")
	_field.call("setup_ranged", "archer", "archer", int(a["count"]), int(b["count"]))
	_enter(St.RANGED)

## 커스텀 스커미시 — 경궁병(archer_side, 원거리) vs 경보병(원거리 아님). 사격 오프닝 1볼리 → 근접 전환.
## a=side0 설정, b=side1 설정. archer_side가 사격, 상대(1-archer_side)는 경보병.
func _load_custom_skirmish(a: Dictionary, b: Dictionary, archer_side: int) -> void:
	_rng = _fresh_rng()
	var inf_side := 1 - archer_side
	_sk_archer_side = archer_side
	_sk_archer_count = int((a if archer_side == 0 else b)["count"])
	# side0/side1 유닛 조립(궁병은 archer_side에, 보병은 inf_side에).
	_a = _mk_custom_unit(a, 0)
	_d = _mk_custom_unit(b, 1)
	(_a if inf_side == 0 else _d)["acc_mod"] = SCENARIO2_CHARGE_EVASION  # 돌격 중 보병 화살 회피↑(균형)
	_name_a = _kind_label(String(a["kind"]))
	_name_b = _kind_label(String(b["kind"]))
	# 궁병 side만 1볼리, 보병 side 0라운드(반격 없음).
	var a_rounds := 1 if archer_side == 0 else 0
	var d_rounds := 1 if archer_side == 1 else 0
	_result = LangResolver.resolve_ranged(_rng, _a, _d, a_rounds, d_rounds)
	_init_hud_stats(true)
	_rounds_shots = _group_shots_by_round(_result["shots"])
	# 사격 오프닝 후 보병 생존 = 근접 시작 인원.
	_open_d_surv = int(_result["final_a_soldiers"] if inf_side == 0 else _result["final_d_soldiers"])
	_then_melee = true
	_hud.set_title("%s  vs  %s (근접)" % [_name_a, _name_b])
	# 궁병: 진형 대기(사격), 보병: 화면 밖 즉시 돌격.
	_field.call("setup_skirmish", archer_side, inf_side, _sk_archer_count, int((a if inf_side == 0 else b)["count"]))
	_enter(St.RANGED)

## 설정 kind → 전투 유닛(resolve). 영웅=지휘관 클래스 단독(27/24, count=몫/HP), 경보병/경궁병=base 동일·상성만 차이.
func _mk_custom_unit(cfg: Dictionary, side: int) -> Dictionary:
	var kind := String(cfg["kind"])
	var count := int(cfg["count"])
	match kind:
		"hero":
			var u := LangResolver.make_unit(HERO_CLASS, side, count, 0, 0, 0, 3, 0)
			u["kind"] = ""          # 병종 상성 중립
			u["self_cmd"] = false   # 단독 영웅 — 자기 지휘보정 없음(27/24 유지)
			return u
		"archer":
			var u := LangResolver.make_unit(ARCHER_CLASS, side, count, 0, 0, 0, 3, 5)
			u["kind"] = "archer"
			return u
		_:
			var u := LangResolver.make_unit(INFANTRY_CLASS, side, count, 0, 0, 0, 3, 5)
			u["kind"] = "infantry"
			return u

func _kind_label(kind: String) -> String:
	match kind:
		"hero": return "영웅"
		"archer": return "경궁병"
		_: return "경보병"

## 근접 난투(경보병 vs 경보병) — 기존 resolve_engagement + CHARGE→CLASH→RETREAT 재사용.
func _load_melee() -> void:
	_rng = _fresh_rng()
	_a = _mk_infantry(0)
	_d = _mk_infantry(1)
	_name_a = "경보병(청)"
	_name_b = "경보병(적)"
	_result = LangResolver.resolve_engagement(_rng, _a, _d)
	_events = _build_plan()
	_init_hud_stats(false)  # 근접은 base만(돌격 중 _tick_atdf로 틱업)
	_hud.set_title("경보병  vs  경보병 (근접)")
	_field.call("setup", START_SOLDIERS, START_SOLDIERS)
	_field.call("begin_advance")  # 스폰하자마자 돌격
	_enter(St.CHARGE)

## 영웅 전투(시나리오 5) — 영웅(classId 4, 27/24 단독) vs 경보병 10인.
## 영웅은 1스프라이트지만 **병사 10 몫**으로 싸운다(공격 13회·10 병력 factor). 계산은 근접(resolve_engagement) 그대로.
## 영웅 HP=10 → 피격마다 −1, 0에서 사망(battlefield kill 참조). 단독 영웅이라 자기 지휘보정 없음(self_cmd=false → 27/24 유지).
func _load_hero() -> void:
	_hero_battle = true
	_rng = _fresh_rng()
	_a = LangResolver.make_unit(HERO_CLASS, 0, START_SOLDIERS, 0, 0, 0, 3, 0)  # 영웅 회피 기본(acc_mod 0)
	_a["kind"] = ""             # 병종 상성 중립(경보병에 우열 없음)
	_a["self_cmd"] = false      # 단독 영웅 — 자기 지휘보정 없음(27/24 유지, 1:다 스케일 균형)
	_d = _mk_infantry(1)
	_name_a = "영웅"
	_name_b = "경보병"
	_result = LangResolver.resolve_engagement(_rng, _a, _d)
	_events = _build_plan()
	_init_hud_stats(false)      # 근접: base 표시(영웅 base==조립 27/24라 틱업해도 그대로)
	_hud.set_title("영웅  vs  경보병 (근접)")
	_field.call("setup_hero", START_SOLDIERS, START_SOLDIERS)  # 영웅 1 + 보병 10
	_field.call("begin_advance")
	_enter(St.CHARGE)

## 사격 시나리오(1/3/4) — resolve_ranged → 사격 상태머신(St.RANGED).
func _load_ranged(n: int) -> void:
	_rng = _fresh_rng()
	var a_rounds := 1   # 사격은 1회(1라운드)만 연출 — 각 궁병 1발
	var d_rounds := 1
	var b_kind := "archer"
	match n:
		1:  # 경궁병 → 경보병(사격): 방어측 제자리 대기, 반격 없음(0라운드)
			_a = _mk_archer(0)
			_d = _mk_infantry(1)
			d_rounds = 0
			b_kind = "infantry"
			_name_a = "경궁병"
			_name_b = "경보병"
			_hud.set_title("경궁병  →  경보병 (사격)")
		3:  # 경궁병 vs 경궁병(사격): 양측 2라운드, 2라운드는 생존자만
			_a = _mk_archer(0)
			_d = _mk_archer(1)
			_name_a = "경궁병(청)"
			_name_b = "경궁병(적)"
			_hud.set_title("경궁병  vs  경궁병 (사격)")
		_:  # 4: 궁병전 근거리 = 사격으로 해소(시나리오 3과 동일 모델)
			_scenario = 4
			_a = _mk_archer(0)
			_d = _mk_archer(1)
			_name_a = "경궁병(청)"
			_name_b = "경궁병(적)"
			_hud.set_title("경궁병  vs  경궁병 (근거리 — 사격 해소)")

	_result = LangResolver.resolve_ranged(_rng, _a, _d, a_rounds, d_rounds)
	_init_hud_stats(true)  # 사격은 지휘보정 완료값(at/df) 즉시 표시(틱업 없음)
	_rounds_shots = _group_shots_by_round(_result["shots"])
	_field.call("setup_ranged", "archer", b_kind, START_SOLDIERS, START_SOLDIERS)
	_enter(St.RANGED)

## HUD 좌/우 스탯 초기화(공통). 근접(show_assembled=false)은 base만 표시 후 돌격 중 틱업,
## 사격(true)은 지휘보정 완료 at/df를 즉시 표시(틱업 단계 없음).
func _init_hud_stats(show_assembled: bool) -> void:
	var sa: Dictionary = _result["stats_a"]
	var sd: Dictionary = _result["stats_d"]
	_hud.set_side(0, _a["level"], sa["base_at"], sa["base_df"], _melee_start_a)
	_hud.set_side(1, _d["level"], sd["base_at"], sd["base_df"], _melee_start_b)
	_hud.set_hits(sa["hit"], sd["hit"])
	if show_assembled:
		_hud.set_at_df(0, sa["at"], sa["df"])
		_hud.set_at_df(1, sd["at"], sd["df"])

## 시나리오 2(직접 진입 폴백) — 경궁병(side0) vs 경보병(side1): 사격 오프닝 → 근접. 스커미시 일반 경로 사용.
func _load_scenario2() -> void:
	_rng = _fresh_rng()
	_sk_archer_side = 0
	_sk_archer_count = START_SOLDIERS
	_a = _mk_archer(0)
	_d = _mk_infantry(1)
	_d["acc_mod"] = SCENARIO2_CHARGE_EVASION  # 돌격 중 보병은 화살을 더 피함(볼리 명중↓ → 균형)
	_name_a = "경궁병"
	_name_b = "경보병"
	_hud.set_title("경궁병  vs  경보병 (근접)")
	_result = LangResolver.resolve_ranged(_rng, _a, _d, 1, 0)  # 궁병 1발, 보병 0라운드
	_init_hud_stats(true)
	_rounds_shots = _group_shots_by_round(_result["shots"])
	_open_d_surv = int(_result["final_d_soldiers"])
	_then_melee = true
	# 스커미시: 궁병 진형 대기(사격) + 보병 화면 밖 즉시 돌격(실시간 동시)
	_field.call("setup_skirmish", 0, 1, START_SOLDIERS, START_SOLDIERS)
	_enter(St.RANGED)

## 사격 볼리 종료 → 근접 전환(스커미시). 궁병=_sk_archer_side, 보병=반대편(생존 _open_d_surv).
## 병사는 이미 필드에서 이동/교전 중(재스폰 없음) → 근접 결과로 CLASH.
func _begin_skirmish_melee() -> void:
	var archer_side := _sk_archer_side
	var inf_side := 1 - archer_side
	# side별 근접 시작 인원: 궁병은 볼리 무피해로 풀 유지, 보병은 사격 생존자.
	var cnt := {archer_side: _sk_archer_count, inf_side: _open_d_surv}
	_field.call("clear_aiming")  # 남은 궁병도 전진
	_field.call("force_result", cnt[0], cnt[1])  # 사격 사상자 확정(안전, 궁병 무피해)
	_a_cur = cnt[0]
	_b_cur = cnt[1]
	_hud.set_count(0, _a_cur)
	_hud.set_count(1, _b_cur)
	if _open_d_surv <= 0:
		_enter(St.DONE)  # 보병이 화살만으로 전멸 → 근접 없음
		return
	# 궁병 근접 취약은 병종 상성(보병>궁병)이 담당 — 별도 페널티 없음.
	var am := LangResolver.make_unit(ARCHER_CLASS, archer_side, _sk_archer_count, 0, 0, 0, 3, 5)
	am["kind"] = "archer"
	var bm := LangResolver.make_unit(INFANTRY_CLASS, inf_side, _open_d_surv, 0, 0, 0, 3, 5)
	bm["kind"] = "infantry"  # ★ 병종 상성 적용(보병>궁병 +4/+2) — 이게 빠지면 궁병이 압살함
	_a = am if archer_side == 0 else bm
	_d = am if archer_side == 1 else bm
	_result = LangResolver.resolve_engagement(_fresh_rng(), _a, _d)
	_melee_start_a = cnt[0]
	_melee_start_b = cnt[1]
	_fast_melee = true                    # 궁병 근접전은 빨리 끝냄(짧은 CLASH·유예 생략)
	_field.call("set_fast_melee", true)   # 듀얼 밀당 0(즉결) + 복귀 전 헛칼질 제거
	_events = _build_plan()
	_enter(St.CHARGE)  # 이미 필드에서 돌격/교전 중 → any_engaged 시 CLASH

func _fresh_rng() -> LangRng:
	# 씬 진입/전환 시각 기반 시드(매 판 다른 전개). 계산은 이 시드에서 결정론적.
	return LangRng.new(Time.get_ticks_msec() * 2654435761 & 0xFFFFFFFF)

func _mk_archer(side: int) -> Dictionary:
	# make_unit(class_id, side, soldiers, gx, gy, item_id, level, acc_mod). 개활지 회피 5.
	var u := LangResolver.make_unit(ARCHER_CLASS, side, START_SOLDIERS, 0, 0, 0, 3, 5)
	u["kind"] = "archer"  # 병종 상성: 근접 모든 병종에 약함
	return u

func _mk_infantry(side: int) -> Dictionary:
	var u := LangResolver.make_unit(INFANTRY_CLASS, side, START_SOLDIERS, 0, 0, 0, 3, 5)
	u["kind"] = "infantry"  # 병종 상성: 궁병에 우위(+4/+2)
	return u

## shots(발사 순서 배열)를 라운드별로 그룹핑 → [round][{side,kill}].
func _group_shots_by_round(shots: Array) -> Array:
	var out: Array = []
	for sh in shots:
		var r: int = int(sh["round"])
		while out.size() <= r:
			out.append([])
		out[r].append(sh)
	return out

## 킬(사망) 이벤트만 스케줄에 넣는다. 재생 시각은 `_schedule_times`(melee_dur 안에 지터 분산, `_enter(CLASH)`)로
## 최소 전투시간 전 구간에 퍼뜨린다 — 죽음 쏠림·뒷부분 빔 제거. 복귀는 스케줄 소진 후 begin_retreat로 마지막에 일괄.
## 총합은 Resolver 결과 그대로: 사망 = 시작 - 생존.
## 최후 전투(_deferred_sides): 일정 확률로 한 팀(또는 양 팀)의 마지막 사망 1건을 **CLASH 스케줄에서 빼서**
## 유예한다. 나머지가 다 죽고 대형 복귀를 마친 뒤, 필드에 남은 그 1쌍이 **최후의 1:1 듀얼**로 처형된다(FINALE).
##  - 25%: 한 팀(죽음 있는 팀 중 랜덤, 승패 무관)의 1건 유예.
##  - 그중 5%(양 팀 모두 죽음 있을 때): 양 팀 각 1건 유예 → 각자 1:1 최후 전투(레어).
## 총합·팀별 사망 수는 불변(유예분은 FINALE에서 처리).
func _build_plan() -> Array:
	var da: int = _melee_start_a - _result["final_a_soldiers"]  # 공격측 사망
	var dd: int = _melee_start_b - _result["final_d_soldiers"]  # 방어측 사망
	_deferred_sides = []
	var eligible: Array = []            # 죽음 있는 팀만 유예 가능
	if da > 0:
		eligible.append(0)
	if dd > 0:
		eligible.append(1)
	# 빠른 근접(궁병 근접전)·영웅 전투는 최후 1:1 유예(FINALE) 생략 — 뒤 드라마 없이/영웅 1인이라 부적합.
	# 총 사망 2 이상일 때만(1건뿐이면 "나머지 다 죽고 최후 1" 그림이 안 나옴).
	if not _fast_melee and not _hero_battle and da + dd >= 2 and not eligible.is_empty():
		var r := _fx_rng.randf()
		if eligible.size() == 2 and r < DEFER_DOUBLE_CHANCE:
			_deferred_sides = [0, 1]       # 양 팀 각 1건 유예
		elif r < DEFER_LAST_CHANCE:
			_deferred_sides = [eligible[_fx_rng.randi() % eligible.size()]]  # 랜덤 한 팀
	# CLASH 스케줄엔 유예분 제외(각 유예 팀 사망 −1). 유예분은 FINALE 최후 1:1로.
	var da_clash := da - (1 if 0 in _deferred_sides else 0)
	var dd_clash := dd - (1 if 1 in _deferred_sides else 0)
	return _side_list(da_clash, dd_clash, "kill")  # 양쪽 번갈아 → 사망이 한쪽으로 안 쏠림

## 최소 전투시간: CLASH 길이를 킬 수에서 분리 — 적게 죽어도 안 빨리 끝나게.
## basis = max(동시 듀얼 수 min(a,b), 소수가 다수를 잡은 max(deaths)) → clamp(×PER_UNIT, FLOOR, CAP).
func _melee_duration(a_start: int, b_start: int, a_final: int, b_final: int, fast := false) -> float:
	var deaths_a := a_start - a_final
	var deaths_b := b_start - b_final
	var basis := maxi(mini(a_start, b_start), maxi(deaths_a, deaths_b))
	if fast:
		return clampf(FAST_MELEE_PER_UNIT * float(basis), FAST_MELEE_FLOOR, FAST_MELEE_CAP)
	return clampf(MELEE_PER_UNIT * float(basis), MELEE_FLOOR, MELEE_CAP)

## side 0 n0개 + side 1 n1개 이벤트를 양쪽 번갈아 만든다(한쪽으로 안 쏠리게).
func _side_list(n0: int, n1: int, kind: String) -> Array:
	var out: Array = []
	var i0 := 0
	var i1 := 0
	while i0 < n0 or i1 < n1:
		if i0 < n0:
			out.append({"kind": kind, "side": 0})
			i0 += 1
		if i1 < n1:
			out.append({"kind": kind, "side": 1})
			i1 += 1
	return out

func _enter(s: int) -> void:
	_state = s
	_timer = 0.0
	match s:
		St.RANGED:
			_cur_round = 0
			_round_started = false
			_round_i = 0
			_shot_cd = 0.0
			_round_gap = 0.0
			_hint.text = "[사격]   아무 키 = 스킵 / 클릭 = 재전투 / ESC = 설정 화면"
		St.CHARGE:
			_hint.text = "[전투]   아무 키 = 스킵 / 클릭 = 재전투 / ESC = 설정 화면"
		St.CLASH:
			_event_i = 0
			_finale_fired = false
			_melee_dur = _melee_duration(_melee_start_a, _melee_start_b, _result["final_a_soldiers"], _result["final_d_soldiers"], _fast_melee)
			_event_times = _schedule_times(_events.size(), _melee_dur)
		St.POST:
			_a_cur = _result["final_a_soldiers"]
			_b_cur = _result["final_d_soldiers"]
			_hud.set_count(0, _a_cur)
			_hud.set_count(1, _b_cur)
			_field.call("force_result", _a_cur, _b_cur)
		St.RETREAT:
			_field.call("begin_retreat")  # 생존자 본인 진영으로 복귀
		St.DONE:
			var na := _name_a if _name_a != "" else "공격측"
			var nb := _name_b if _name_b != "" else "방어측"
			var win: String
			if _a_cur > _b_cur:
				win = "%s 우세" % na if _b_cur > 0 else "%s 승리 (전멸)" % na
			elif _b_cur > _a_cur:
				win = "%s 우세" % nb if _a_cur > 0 else "%s 승리 (전멸)" % nb
			else:
				win = "무승부"
			_hud.set_title(win)
			_hint.text = "클릭 / 아무 키 = 재전투 / ESC = 설정 화면"

func _process(delta: float) -> void:
	# 큰 프레임 델타(씬 시작 로딩·랙 스파이크)가 상태를 건너뛰지 않도록 상한.
	delta = minf(delta, 0.05)
	_timer += delta
	match _state:
		St.RANGED:
			_process_ranged(delta)
		St.CHARGE:
			# 돌격과 동시에 AT/DF 지휘보정 틱업(스펙 §4.2).
			# 첫 충돌(양쪽 접전 시작)이 생기면 바로 교전 시작 — 전원 도착을 기다리지 않는다.
			var t := _atdf_tick_t()
			_tick_atdf(0, _result["stats_a"], t)
			_tick_atdf(1, _result["stats_d"], t)
			if _field.call("any_engaged") or _timer >= ADVANCE_TIME:
				_enter(St.CLASH)
		St.CLASH:
			_process_clash(delta)
		St.POST:
			if _timer >= POST_PAUSE:
				_enter(St.RETREAT)
		St.RETREAT:
			# 생존자가 진영에 복귀하면(또는 상한) 종료
			if _field.call("all_returned") or _timer >= RETREAT_MAX:
				_enter(St.DONE)
		St.FINALE:
			_process_finale()
		St.DONE:
			pass

## 최후 전투: 나머지가 다 복귀하면 남은 1쌍(들)을 1:1로 처형, 그 뒤 승자까지 복귀하면 종료.
func _process_finale() -> void:
	if not _finale_fired:
		# 나머지 유닛이 전부 대형 복귀했을 때(또는 상한) 최후 처형 발동
		if _field.call("others_returned") or _timer >= FINALE_STAGE_MAX:
			_finale_fired = true
			_field.call("fire_final_duel")   # 스테이징된 V만 정확히 처형(개입 없는 1:1 + 긴 밀당)
			for side in _deferred_sides:      # HUD 병력 −1
				if side == 1:
					_b_cur = maxi(0, _b_cur - 1)
				else:
					_a_cur = maxi(0, _a_cur - 1)
			_hud.set_count(0, _a_cur)
			_hud.set_count(1, _b_cur)
	else:
		# 최후 듀얼 끝나고 승자까지 복귀하면 결과로
		if _field.call("all_returned") or _timer >= FINALE_MAX:
			_enter(St.POST)

## 사격 상태머신: 라운드별로 shots 를 순차 발사 → 화살 착탄으로 사상자 반영 → 다음 라운드.
## HUD 병력은 필드 생존자 폴링(화살이 꽂히는 순간 자연 감소). 모든 라운드·화살 종료 시 결과.
func _process_ranged(delta: float) -> void:
	_a_cur = _field.call("alive_count", 0)
	_b_cur = _field.call("alive_count", 1)
	_hud.set_count(0, _a_cur)
	_hud.set_count(1, _b_cur)

	if _cur_round >= _rounds_shots.size():
		# 시나리오 2(→근접)는 화살 착탄 즉시 근접으로 전환(죽음 애니 대기 X, 헛칼질 겹침 최소).
		# 순수 사격(1/3/4)은 죽음 애니까지 끝나야 결과.
		var done: bool = (not _field.call("arrows_in_flight")) if _then_melee else (not _field.call("arrows_active"))
		if done:
			_finish_ranged()
		return

	if _round_gap > 0.0:                        # 라운드 사이 간격
		_round_gap -= delta
		return

	if not _round_started:
		# 이번 라운드에 사격하는 side만 슈터 풀에 — 사격 안 하는 side는 착탄 즉시 사망(유예 아님).
		var sides := {}
		for sh in _rounds_shots[_cur_round]:
			sides[int(sh["side"])] = true
		_field.call("begin_shot_round", sides.keys())
		_round_started = true
		_round_i = 0
		_shot_cd = 0.0

	var shots: Array = _rounds_shots[_cur_round]
	if _round_i < shots.size():
		_shot_cd -= delta
		if _shot_cd <= 0.0:
			var sh: Dictionary = shots[_round_i]
			if _field.call("shoot", int(sh["side"]), bool(sh["kill"])):
				_round_i += 1
				_shot_cd = SHOT_STAGGER
			else:
				_shot_cd = 0.05                 # 슈터 대기 중 → 곧 재시도
	elif not _field.call("arrows_in_flight"):
		_cur_round += 1                         # 이번 라운드 전부 착탄 → 다음 라운드
		_round_started = false
		_round_gap = ROUND_GAP

func _finish_ranged() -> void:
	if _then_melee:
		_then_melee = false
		_begin_skirmish_melee()  # 스커미시: 사격 종료 → 근접 전환
		return
	_a_cur = _result["final_a_soldiers"]
	_b_cur = _result["final_d_soldiers"]
	_hud.set_count(0, _a_cur)
	_hud.set_count(1, _b_cur)
	_field.call("force_result", _a_cur, _b_cur)  # 안전 트림(잔여 화살 스킵 시)
	_enter(St.DONE)

## AT/DF 표시 보간 계수. 순수 근접(시나리오 0)은 돌격과 함께 base→조립값 틱업(0→1).
## 시나리오 2 근접(_fast_melee)은 사격 단계에서 이미 조립값(29/25)을 보였으므로 즉시 t=1 —
## base(23/21)로 뚝 떨어졌다 되오르는 어색함 방지(같은 부대·같은 버프의 연속 전투).
func _atdf_tick_t() -> float:
	if _fast_melee:
		return 1.0
	return clampf(_timer / STEP, 0.0, 1.0)

func _tick_atdf(side: int, st: Dictionary, t: float) -> void:
	var at := int(round(lerpf(st["base_at"], st["at"], t)))
	var df := int(round(lerpf(st["base_df"], st["df"], t)))
	_hud.set_at_df(side, at, df)

## 킬 재생 시각을 melee_dur 안에 고르게 깔되 **지터를 줘 등간격을 깬다**(버스트·소강 → 덜 기계적).
## base 위치에서 ±KILL_JITTER×interval 흔들고 정렬. 킬 수·총 길이는 불변.
func _schedule_times(count: int, dur: float) -> Array:
	var interval := dur / maxf(1.0, float(count))
	var times: Array = []
	for i in range(count):
		var base := (float(i) + 0.5) * interval
		var t := base + _fx_rng.randf_range(-KILL_JITTER, KILL_JITTER) * interval
		times.append(clampf(t, 0.0, dur))
	times.sort()
	return times

func _process_clash(_delta: float) -> void:
	# 예정 시각이 된 킬을 순서대로 재생(_event_times 오름차순).
	while _event_i < _events.size() and _timer >= _event_times[_event_i]:
		_apply_event(_events[_event_i])
		_event_i += 1
	# 킬 전부 재생 + 최소 전투시간 채움 + **진행 중 듀얼 없음**일 때 CLASH 종료.
	if _event_i >= _events.size() and _timer >= _melee_dur and not _field.call("duels_active"):
		if _deferred_sides.is_empty():
			_enter(St.POST)                     # 유예 없음 → 일반 복귀
		else:
			_begin_finale()                     # 유예 있음 → 최후 1:1 준비

## 최후 전투 준비: 유예 팀별로 1:1 쌍(V+W)을 필드에 남기고(stage_final_duel), 나머지는 대형 복귀 시작.
## 스테이징 실패(1:1 성립 불가 — 예: 더블인데 한 팀 잔여 1명)한 유예분은 여기서 빠지지만,
## 그 사망은 POST의 force_result가 최종 카운트로 보정한다(사망 수 불변식 유지, 해당 연출만 생략 — rare).
func _begin_finale() -> void:
	var staged: Array = []
	for side in _deferred_sides:
		if _field.call("stage_final_duel", side):
			staged.append(side)
	_deferred_sides = staged
	if _deferred_sides.is_empty():
		_enter(St.POST)                          # 1:1 성립 불가 → 일반 복귀(force_result가 카운트 보정)
		return
	_field.call("begin_retreat")                 # 나머지 유닛 대형 복귀(최후 쌍은 제외)
	_enter(St.FINALE)

## 스케줄은 전부 킬 이벤트 — 접전 병사 1명 전사(듀얼) + 병력 카운트 갱신.
func _apply_event(ev: Dictionary) -> void:
	_field.call("kill", ev["side"])  # 넉백+섬광+흔들림
	if ev["side"] == 1:
		_b_cur = maxi(0, _b_cur - 1)
	else:
		_a_cur = maxi(0, _a_cur - 1)
	_hud.set_count(0, _a_cur)
	_hud.set_count(1, _b_cur)

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_pressed() and not event.is_echo()):
		return
	# 마우스 클릭: 언제든 같은 구성으로 재전투.
	if event is InputEventMouseButton:
		_restart()
		return
	# 키보드: ESC = 전투 설정 화면 / 그 외 = 스킵.
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			SceneManager.change_scene("res://scenes/lang_setup/lang_setup.tscn")
		else:
			_skip()

## 같은 구성으로 처음부터 다시(커스텀 전투면 커스텀, 아니면 시나리오 폴백).
func _restart() -> void:
	if _custom_cfg.is_empty():
		_load_scenario(_scenario)
	else:
		_load_custom(_custom_cfg)

func _skip() -> void:
	match _state:
		St.RANGED:
			_finish_ranged()  # 사격 스킵 → 즉시 최종 생존자
		St.CHARGE, St.CLASH, St.FINALE:
			# 돌격/교전/최후 전투 스킵 → 최종 스탯 세팅 후 즉시 결과
			_tick_atdf(0, _result["stats_a"], 1.0)
			_tick_atdf(1, _result["stats_d"], 1.0)
			_enter(St.POST)
		St.POST, St.RETREAT:
			_enter(St.DONE)
		St.DONE:
			_restart()  # 같은 구성 다시 재생
