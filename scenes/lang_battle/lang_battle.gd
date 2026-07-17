extends Node2D
## 전투 씬 Presenter — 스펙 §3. Resolver(순수 계산) 결과를 상태머신으로 재생한다.
## 계산과 연출이 분리돼 있어 "애니 스킵"이 결과를 바꾸지 않는다(스펙 §0).
##
## 연출: 정보 표시 → 양측 전진 → 중앙 난투(짝지어 찌르기·전사) → 결과.
## 격리 테스트용: 인트로 [새 게임] → 이 씬으로 바로 진입. 10:10 더미 교전.

@onready var _field: Node2D = $Battlefield
@onready var _hud: Control = $HudLayer/Hud
@onready var _hint: Label = $HudLayer/Hint

# 상태 전이 — 원본: 스폰 즉시 돌격, 하단 숫자는 동시에 표시(두 레이어 병렬).
enum St { CHARGE, CLASH, POST, DONE }

# 타이밍
const STEP := 0.75          # AT/DF 지휘보정 틱업 시간(돌격과 동시 진행)
const ADVANCE_TIME := 2.2   # 돌격 최대 시간(상한). 실제로는 접전 도달 시 전환
const CLASH_STEP := 0.11    # 히트 1회당 간격

const START_SOLDIERS := 10

var _rng: LangRng
var _a: Dictionary
var _d: Dictionary
var _result: Dictionary

var _state: int = St.CHARGE
var _timer := 0.0
var _a_cur := START_SOLDIERS
var _b_cur := START_SOLDIERS
var _events: Array = []  # 재생용(양측 볼리 교차)
var _event_i := 0
var _clash_acc := 0.0

func _ready() -> void:
	# 시드는 씬 진입 시각 기반(매 판 다른 전개). 계산 자체는 이 시드에서 결정론적.
	_rng = LangRng.new(Time.get_ticks_msec() * 2654435761 & 0xFFFFFFFF)

	# 더미 부대 — 기존 캐릭터와 무관한 격리 데이터.
	# 공격측: 고화력 창기병(classId 9), 방어측: 유리대포 습격대(classId 27).
	# 공격측은 방어 지형(회피 20) 위에 있어 반격 피해가 적다 → 양측 출혈 + 공격측 우세.
	# make_unit(class_id, side, soldiers, gx, gy, item_id, level, acc_mod)
	_a = LangResolver.make_unit(9, 0, START_SOLDIERS, 3, 5, 0, 5, 20)
	_d = LangResolver.make_unit(27, 1, START_SOLDIERS, 9, 5, 0, 3, 5)

	_result = LangResolver.resolve_engagement(_rng, _a, _d)
	_events = _interleave(_result["rounds"])

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

## 공격 볼리와 반격 볼리를 교차해 "동시 난투"로 보이게 한다(결과 불변, 연출만).
func _interleave(rounds: Array) -> Array:
	var a_vol: Array = rounds.filter(func(e): return e["attacker_side"] == 0)
	var d_vol: Array = rounds.filter(func(e): return e["attacker_side"] == 1)
	var out: Array = []
	var n: int = maxi(a_vol.size(), d_vol.size())
	for i in range(n):
		if i < a_vol.size():
			out.append(a_vol[i])
		if i < d_vol.size():
			out.append(d_vol[i])
	return out

func _enter(s: int) -> void:
	_state = s
	_timer = 0.0
	match s:
		St.CHARGE:
			_hint.text = "[격리 테스트: 랑그릿사 1 전투]   아무 키 = 스킵 / ESC = 타이틀"
		St.CLASH:
			_event_i = 0
			_clash_acc = 0.0
		St.POST:
			_a_cur = _result["final_a_soldiers"]
			_b_cur = _result["final_d_soldiers"]
			_hud.set_count(0, _a_cur)
			_hud.set_count(1, _b_cur)
			_field.call("force_result", _a_cur, _b_cur)
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
			# 돌격과 동시에 AT/DF 지휘보정 틱업(스펙 §4.2). 접전 도달 시 교전 시작.
			var t := clampf(_timer / STEP, 0.0, 1.0)
			_tick_atdf(0, _result["stats_a"], t)
			_tick_atdf(1, _result["stats_d"], t)
			if _field.call("all_engaged") or _timer >= ADVANCE_TIME:
				_enter(St.CLASH)
		St.CLASH:
			_process_clash(delta)
		St.POST:
			if _timer >= 1.1:
				_enter(St.DONE)
		St.DONE:
			pass

func _tick_atdf(side: int, st: Dictionary, t: float) -> void:
	var at := int(round(lerpf(st["base_at"], st["at"], t)))
	var df := int(round(lerpf(st["base_df"], st["df"], t)))
	_hud.set_at_df(side, at, df)

func _process_clash(delta: float) -> void:
	_clash_acc += delta
	while _clash_acc >= CLASH_STEP and _event_i < _events.size():
		_clash_acc -= CLASH_STEP
		_apply_event(_events[_event_i])
		_event_i += 1
	if _event_i >= _events.size():
		_enter(St.POST)

func _apply_event(ev: Dictionary) -> void:
	var atk: int = ev["attacker_side"]
	var tgt: int = ev["target_side"]
	match ev["kind"]:
		LangResolver.Hit.HIT:
			var pos: Variant = _field.call("kill", tgt)
			if pos != null:
				_field.call("strike", atk, pos)
			if tgt == 1:
				_b_cur = maxi(0, _b_cur - 1)
			else:
				_a_cur = maxi(0, _a_cur - 1)
			_hud.set_count(0, _a_cur)
			_hud.set_count(1, _b_cur)
		LangResolver.Hit.NO_KILL:
			_field.call("strike", atk, _field.call("focus", tgt))
			_field.call("spark", tgt)
		LangResolver.Hit.MISS:
			_field.call("strike", atk, _field.call("focus", tgt))
			_field.call("dodge", tgt)
		LangResolver.Hit.SPECIAL:
			_field.call("strike", atk, _field.call("focus", tgt))

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
		St.POST:
			_enter(St.DONE)
		St.DONE:
			# 다시 전투 (씬 리로드)
			SceneManager.change_scene("res://scenes/lang_battle/lang_battle.tscn")
