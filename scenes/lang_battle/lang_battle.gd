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
enum St { CHARGE, CLASH, POST, RETREAT, DONE }

# 타이밍
const STEP := 0.75          # AT/DF 지휘보정 틱업 시간(돌격과 동시 진행)
const ADVANCE_TIME := 2.2   # 돌격 최대 시간(상한). 실제로는 접전 도달 시 전환
# 최소 전투시간: CLASH 길이 = clamp(MELEE_PER_UNIT × basis, MELEE_FLOOR, MELEE_CAP),
#   basis = max(min(a_start,b_start), deaths_a, deaths_b). 킬은 그 안에 분산, 남는 시간은 스커미시가 채움.
const MELEE_PER_UNIT := 0.22 # 기준값당 전투시간(초)
const MELEE_FLOOR := 0.5     # 최소 전투시간(초)
const MELEE_CAP := 2.2       # 최대 전투시간(초)
const KILL_JITTER := 0.65    # 킬 타이밍 지터(±, 간격 비율) — 등간격 깨서 리듬 만들기
const POST_PAUSE := 0.0     # 결과 표시 후 복귀 시작까지 — 0=마지막 킬 직후 바로 순차 복귀(얼음 구간 제거)
const RETREAT_MAX := 4.0    # 복귀 최대 시간(상한) — 스커미시 대기 + 순차 peel-off 감안

const START_SOLDIERS := 10

var _rng: LangRng
var _a: Dictionary
var _d: Dictionary
var _result: Dictionary

var _state: int = St.CHARGE
var _timer := 0.0
var _a_cur := START_SOLDIERS
var _b_cur := START_SOLDIERS
var _events: Array = []  # 킬 스케줄(전 구간 분산) — _build_plan
var _event_i := 0
var _melee_dur := 0.0        # 이번 CLASH 목표 길이(_melee_duration)
var _event_times: Array = [] # 각 킬의 재생 시각(CLASH 시작 기준, 지터 적용·정렬)
var _fx_rng := RandomNumberGenerator.new()  # 연출용(킬 타이밍 지터) — 결과와 무관

func _ready() -> void:
	# 시드는 씬 진입 시각 기반(매 판 다른 전개). 계산 자체는 이 시드에서 결정론적.
	_rng = LangRng.new(Time.get_ticks_msec() * 2654435761 & 0xFFFFFFFF)
	_fx_rng.randomize()  # 킬 타이밍 지터(연출) — 결과에는 영향 없음

	# 더미 부대 — 기존 캐릭터와 무관한 격리 데이터.
	# 공격측: 고화력 창기병(classId 9), 방어측: 유리대포 습격대(classId 27).
	# 공격측은 방어 지형(회피 20) 위에 있어 반격 피해가 적다 → 양측 출혈 + 공격측 우세.
	# make_unit(class_id, side, soldiers, gx, gy, item_id, level, acc_mod)
	_a = LangResolver.make_unit(9, 0, START_SOLDIERS, 3, 5, 0, 5, 20)
	_d = LangResolver.make_unit(27, 1, START_SOLDIERS, 9, 5, 0, 3, 5)

	_result = LangResolver.resolve_engagement(_rng, _a, _d)
	_events = _build_plan()

	# 스폰 즉시: 병력·명중률 표시 + 돌격 시작 (숫자와 돌격을 동시에 — 원본 병렬 레이어)
	var sa: Dictionary = _result["stats_a"]
	var sd: Dictionary = _result["stats_d"]
	_hud.set_side(0, _a["level"], sa["base_at"], sa["base_df"], START_SOLDIERS)
	_hud.set_side(1, _d["level"], sd["base_at"], sd["base_df"], START_SOLDIERS)
	_hud.set_hits(sa["hit"], sd["hit"])
	_hud.set_title("제국 창기병   VS   반란군 습격대")
	_field.call("setup", _a_cur, _b_cur)
	_field.call("begin_advance")  # 스폰하자마자 바로 돌격
	_enter(St.CHARGE)

## 킬(사망) 이벤트만 스케줄에 넣는다. 재생 시각은 `_schedule_times`(melee_dur 안에 지터 분산, `_enter(CLASH)`)로
## 최소 전투시간 전 구간에 퍼뜨린다 — 죽음 쏠림·뒷부분 빔 제거. 복귀는 스케줄 소진 후 begin_retreat로 마지막에 일괄.
## 총합은 Resolver 결과 그대로: 사망 = 시작 - 생존.
func _build_plan() -> Array:
	var da: int = START_SOLDIERS - _result["final_a_soldiers"]  # 공격측 사망
	var dd: int = START_SOLDIERS - _result["final_d_soldiers"]  # 방어측 사망
	return _side_list(da, dd, "kill")  # 양쪽 번갈아 → 사망이 한쪽으로 안 쏠림

## 최소 전투시간: CLASH 길이를 킬 수에서 분리 — 적게 죽어도 안 빨리 끝나게.
## basis = max(동시 듀얼 수 min(a,b), 소수가 다수를 잡은 max(deaths)) → clamp(×PER_UNIT, FLOOR, CAP).
func _melee_duration(a_start: int, b_start: int, a_final: int, b_final: int) -> float:
	var deaths_a := a_start - a_final
	var deaths_b := b_start - b_final
	var basis := maxi(mini(a_start, b_start), maxi(deaths_a, deaths_b))
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
		St.CHARGE:
			_hint.text = "[격리 테스트: 랑그릿사 1 전투]   아무 키 = 스킵 / ESC = 타이틀"
		St.CLASH:
			_event_i = 0
			_melee_dur = _melee_duration(START_SOLDIERS, START_SOLDIERS, _result["final_a_soldiers"], _result["final_d_soldiers"])
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
			var win: String
			if _a_cur > _b_cur:
				win = "제국 창기병 우세" if _b_cur > 0 else "제국 창기병 승리 (전멸)"
			elif _b_cur > _a_cur:
				win = "반란군 습격대 우세" if _a_cur > 0 else "반란군 습격대 승리 (전멸)"
			else:
				win = "무승부"
			_hud.set_title(win)
			_hint.text = "아무 키 = 다시 전투 / ESC = 타이틀"

func _process(delta: float) -> void:
	# 큰 프레임 델타(씬 시작 로딩·랙 스파이크)가 상태를 건너뛰지 않도록 상한.
	delta = minf(delta, 0.05)
	_timer += delta
	match _state:
		St.CHARGE:
			# 돌격과 동시에 AT/DF 지휘보정 틱업(스펙 §4.2).
			# 첫 충돌(양쪽 접전 시작)이 생기면 바로 교전 시작 — 전원 도착을 기다리지 않는다.
			var t := clampf(_timer / STEP, 0.0, 1.0)
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
		St.DONE:
			pass

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
	# 킬 전부 재생 + 최소 전투시간 채움 + **진행 중 듀얼 없음**일 때 종료(복귀 중 사망 방지).
	# 남는 시간은 전장 스커미시가 채우고, 마지막 듀얼이 사망까지 끝난 뒤에야 복귀 시작.
	if _event_i >= _events.size() and _timer >= _melee_dur and not _field.call("duels_active"):
		_enter(St.POST)

## 스케줄은 전부 킬 이벤트 — 접전 병사 1명 전사 + 병력 카운트 갱신.
func _apply_event(ev: Dictionary) -> void:
	var side: int = ev["side"]
	_field.call("kill", side)  # 넉백+섬광+흔들림
	if side == 1:
		_b_cur = maxi(0, _b_cur - 1)
	else:
		_a_cur = maxi(0, _a_cur - 1)
	_hud.set_count(0, _a_cur)
	_hud.set_count(1, _b_cur)

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_pressed() and not event.is_echo()):
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		SceneManager.change_scene("res://scenes/title/title.tscn")
		return
	_skip()

func _skip() -> void:
	match _state:
		St.CHARGE, St.CLASH:
			# 돌격/교전 스킵 → 최종 스탯 세팅 후 즉시 결과
			_tick_atdf(0, _result["stats_a"], 1.0)
			_tick_atdf(1, _result["stats_d"], 1.0)
			_enter(St.POST)
		St.POST, St.RETREAT:
			_enter(St.DONE)
		St.DONE:
			# 다시 전투 (씬 리로드)
			SceneManager.change_scene("res://scenes/lang_battle/lang_battle.tscn")
