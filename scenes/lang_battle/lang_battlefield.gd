extends Node2D
## 전장 렌더러 (픽셀아트) — 384×216 논리 공간에 안티앨리어싱 없는 사각형 픽셀로만 그린다.
## 노드 scale=×5(씬 지정)로 확대 → 1920×1080. draw_rect 는 하드엣지라 확대해도 도트가 선명.
##
## 연출은 랑그릿사 1(MD) 롬 디스어셈블 결과를 그대로 재현한다(연출 전용, Resolver 무관):
##  - 병사는 개별 스프라이트. 진영 기준 X(원본 56/264, center 160)에서 스폰.       [0x156E/0xF4C2]
##  - 각 병사는 적 병사(타겟)를 향해 **등속** 접근. **X를 먼저 좁히고(≤36px) → Y 접근**. [0xE30E]
##  - 속도 X=3.0 / Y=2.0 px/frame (원본 16.16 고정소수 0x30000/0x20000).             [0x156E]
##  - 근접하면 공격(찌르기/타격 이펙트). 병력 감소는 하단 패널에서 별도.
##  - 병사 색/도형은 플레이스홀더(원본 스프라이트 재배포 지양).

const FIELD_W := 384.0
const FIELD_H := 216.0
const ACTION_TOP := 44.0
const ACTION_BOT := 158.0

const BASE_Y := 96.0
# 진형: 각 병사의 복귀 위치. 진영 끝(가장자리)에 앵커 → 중앙 방향으로 균일한 3행 [3,3,4] 열. 화면 안.
# 전투 후 각자 이 자리로 그대로 복귀한다(죽은 자리는 비워짐). 스폰은 화면 밖(_spawn_slots).
const FORM_EDGE_X := 40.0  # 진영 끝에서 이만큼 안쪽에 뒷 열
const FORM_DEPTH := 28.0   # 열 간격(균일)
const DIAG_STEP := 13.0    # 가운데 행이 중앙 쪽으로 튀어나오는 쐐기 오프셋
# 스폰: 화면 밖(진영 바깥)에서 좌우 간격을 3배로 넓게 → 여기서 돌격해 들어온다.
const SPAWN_EDGE_X := 8.0               # 진영 바깥 가장자리 여백
const SPAWN_DEPTH := FORM_DEPTH * 3.0   # 스폰 시 좌우(열) 간격 = 진형의 3배
const UNIT_W := 10.0                    # 병사 스프라이트 대략 너비(px)
const SPAWN_XJIT := UNIT_W * 2.5        # 스폰 X 지터 진폭(±) → 좌우 합 500% width

# ── 스프라이트(임시 경보병 에셋) ─────────────────────────────────────────────
# 원본 프레임 100×100(여백 포함), 실제 몸통 ≈17×22px. 몸통을 바닥 타일 1칸(16px)에 맞춰 축소.
const FRAME_PX := 100                   # 시트 한 프레임 크기(정사각)
const BODY_PX := 17.0                   # 프레임 안 실제 몸통 너비(측정값)
const SPRITE_SCALE := 16.0 / BODY_PX    # 몸통 ≈16px(내부좌표=바닥 타일 1칸)로 축소
const WALK_FRAMES := 8
const IDLE_FRAMES := 6
const ATTACK_FRAMES := 6   # Attack01 (제자리 전방 찌르기)
const HURT_FRAMES := 4     # 피격 뒤로 젖힘 → 넉백 비행 자세로 사용
const DEATH_FRAMES := 4    # 제자리 주저앉기(collapse)
const WALK_FPS := 10.0
const IDLE_FPS := 6.0
const ATTACK_FPS := 18.0
const HURT_FPS := 12.0
const DEATH_FPS := 10.0
const ATTACK_DUR := ATTACK_FRAMES / ATTACK_FPS  # 공격 애니 1회 길이(≈0.33s)
const HIT_FLASH_DUR := 0.12  # 피격 흰색 플래시 지속(초) — 이 시간동안 flash를 1→0 감쇠
const HIT_FLASH_SHADER := preload("res://scenes/lang_battle/hit_flash.gdshader")
# 팀 0=Soldier, 팀 1=Orc (임시 플레이스홀더). 재배포 지양 애셋이지만 개발용.
const TEX_WALK := {
	0: preload("res://assets/units/soldier_walk.png"),
	1: preload("res://assets/units/orc_walk.png"),
}
const TEX_IDLE := {
	0: preload("res://assets/units/soldier_idle.png"),
	1: preload("res://assets/units/orc_idle.png"),
}
const TEX_ATTACK := {
	0: preload("res://assets/units/soldier_attack.png"),
	1: preload("res://assets/units/orc_attack.png"),
}
const TEX_HURT := {
	0: preload("res://assets/units/soldier_hurt.png"),
	1: preload("res://assets/units/orc_hurt.png"),
}
const TEX_DEATH := {
	0: preload("res://assets/units/soldier_death.png"),
	1: preload("res://assets/units/orc_death.png"),
}

# 원본 등속 이동 속도 (px/frame @60fps) → 초당으로 환산(×60, ×1.2 스케일)
const VX := 3.0 * 1.2 * 60.0   # ≈ 216 px/s (원본 등속 3px/frame)
const VY := 2.0 * 1.2 * 60.0   # ≈ 144 px/s (원본 2px/frame)
const CLOSE_X := 36.0 * 1.2    # X가 이 안이면 Y 접근 시작 (원본 0x240000=36px)
const GAP_X := 21.0            # 근접 시 좌우 간격(마주섬) — 스프라이트 몸통 ~16px 감안해 살짝 띄움
const GAP_Y := 5.0
const STRIKE_INTERVAL := 0.34  # 접전 중 자동 공방 주기(초) — 전투 내내 계속 주고받게(idle 방지)
const STRIKE_JITTER := 0.18    # 공방 주기 무작위 편차(위상차)

const STRIKE_DUR := 0.22
const FENCE_PUSH := 8.0        # 공방 1회당 실제 밀림(px) — 찌르는 쪽 전진 + 맞는 쪽 뒤로(거리 유지, 좌우 밀림)
const PUSH_SMOOTH := 15.0      # 밀림 이징 계수(초당) — push_rem을 매 프레임 이 비율로 소진(순간이동 대신 슬라이드)
const DUEL_STEP := 0.18        # 듀얼 밀림 스텝 간격(초)
# 사망: ① 넉백 — Hurt 자세로 위로+뒤로 포물선 비행(원본 0x1976/0x19EA) → ② 착지하면 Death(제자리 주저앉기) → ③ 페이드 소멸.
const DEATH_GRAV := 540.0                # 중력 px/s² (원본 +0x2000/frame ×1.2×3600)
const DEATH_VX := Vector2(40.0, 105.0)   # 뒤로 넉백 속도 범위 px/s (원본 0.5~1.5px/f ×1.2×60)
const DEATH_VY := Vector2(175.0, 250.0)  # 위로 launch 속도 범위 px/s (원본 2.5~3.5px/f ×1.2×60)
const DEATH_COLLAPSE := DEATH_FRAMES / DEATH_FPS  # 착지 후 주저앉는 애니 길이(≈0.4s)
const DEATH_FADE := 0.35                          # 주저앉은 뒤 소멸(페이드) 시간

# 병사 상태
enum { CHARGE, MELEE, DYING, RETURN, IDLE, DUEL }
# 듀얼 밀당 스텝 결과: 60% 무이동 / 30% 패자 밀림 / 10% 승자 밀림
enum { PUSH_NONE, PUSH_LOSER, PUSH_WINNER }

# ── 팔레트 (16비트풍) — 지형 전용. 병사는 스프라이트라 도트 팔레트 불필요. ──────
const WOOD := Color8(126, 84, 42)
const FLOOR := Color8(58, 84, 50)
const FLOOR_HI := Color8(74, 104, 62)
const FLOOR_DK := Color8(40, 60, 36)
const MORTAR := Color8(34, 50, 32)
const MOSS := Color8(96, 132, 66)
const WALL := Color8(70, 66, 58)
const WALL_HI := Color8(96, 90, 78)
const WALL_DK := Color8(44, 40, 34)
const PIT := Color8(24, 22, 20)

var _soldiers := {0: [], 1: []}
var _flashes: Array = []
var _effects: Array = []  # 전방으로 날아가는 공격 이펙트 [0x1860]
var _shake := 0.0
var _t := 0.0
var _charging := false
var _retreating := false
var _next_id := 0
var _rng := RandomNumberGenerator.new()
var _final_victims: Array = []  # 최후 전투에서 처형될 victim(V) 목록 — fire_final_duel에서 소비

# 스프라이트 렌더: 병사 id → AnimatedSprite2D. 팀별 SpriteFrames 공유. _units 아래 y-sort로 정렬.
var _units: Node2D
var _frames := {}          # side -> SpriteFrames("walk"/"idle")
var _sprites := {}         # soldier id -> AnimatedSprite2D

func _ready() -> void:
	_rng.randomize()
	_units = Node2D.new()
	_units.y_sort_enabled = true   # 병사 스프라이트끼리 y로 정렬(뒤→앞). 지형(_draw)은 항상 뒤.
	add_child(_units)
	for side in [0, 1]:
		_frames[side] = _build_frames(side)

## 시트(가로 나열)로 SpriteFrames 구성. walk/idle=루프, attack/death=1회(마지막 프레임 유지).
func _build_frames(side: int) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_add_anim(sf, TEX_WALK[side], "walk", WALK_FRAMES, WALK_FPS, true)
	_add_anim(sf, TEX_IDLE[side], "idle", IDLE_FRAMES, IDLE_FPS, true)
	_add_anim(sf, TEX_ATTACK[side], "attack", ATTACK_FRAMES, ATTACK_FPS, false)
	_add_anim(sf, TEX_HURT[side], "hurt", HURT_FRAMES, HURT_FPS, false)
	_add_anim(sf, TEX_DEATH[side], "death", DEATH_FRAMES, DEATH_FPS, false)
	return sf

func _add_anim(sf: SpriteFrames, tex: Texture2D, anim_name: String, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_loop(anim_name, loop)
	sf.set_animation_speed(anim_name, fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_PX, 0, FRAME_PX, FRAME_PX)
		sf.add_frame(anim_name, at)

func setup(a_count: int, b_count: int) -> void:
	_soldiers = {0: [], 1: []}
	_effects = []
	_final_victims = []
	_retreating = false
	_spawn_side(0, a_count)
	_spawn_side(1, b_count)
	_retarget_all()
	queue_redraw()

# 대형: 위→아래 3행 [3,3,4]. 진영 끝에서 중앙 방향으로 열을 쌓는다.
const ROW_SPACE := 16.8   # 3행 사이 세로(상하) 간격 (24의 70%)

# 분리(separation): 원본 16px 충돌 박스(0xE87A)를 근사 — 겹치면 서로 밀어내 부피를 만든다.
const SEP_DIST := 15.0   # 이 거리보다 가까우면 밀어냄 (스프라이트 몸통 ~16px 감안 — 겹침 완화)
const SEP_RATE := 9.0    # 분리 속도 계수(초당) — delta 기반으로 부드럽게 수렴(옛 프레임상수 0.4 대체, 미끄러짐 완화)

## 3행 분배: 남는 인원은 아래 행부터 → n=10 이면 [3,3,4].
func _row_counts(n: int) -> Array:
	var rows := [n / 3, n / 3, n / 3]
	var rem := n % 3
	var ri := 2
	while rem > 0:
		rows[ri] += 1
		ri -= 1
		rem -= 1
	return rows

func _spawn_side(side: int, n: int) -> void:
	# 스폰은 화면 밖에서 넓게(_spawn_slots) → 돌격해 들어온다. 복귀 위치(home)는 화면 안 진형 자리.
	var homes := _formation_slots(side, n)
	var spawns := _spawn_slots(side, n)
	for i in range(n):
		_soldiers[side].append({
			"id": _next_id,
			"side": side,
			"pos": spawns[i],
			"home": homes[i],     # 복귀 목표 = 화면 안 진형 자리. 죽으면 그 자리는 비워짐.
			"target": null,
			"state": CHARGE,
			"strike_t": 0.0,
			"strike_cd": _rng.randf_range(0.0, STRIKE_INTERVAL),  # 자동 공방 쿨다운(위상 분산)
			"push_rem": 0.0,  # 펜싱 밀림 잔여(X, 애니메이션으로 소진)
			"attack_t": 0.0,  # 공격 애니 잔여 시간(>0이면 attack 재생)
			"atk_fire": false,  # 이번 프레임 공격 시작 신호(스프라이트가 소비 → attack 0프레임부터 재생)
			"hit_t": 0.0,  # 피격 흰색 플래시 잔여(>0이면 셰이더 flash>0)
			"retreat_swings": -1,  # 복귀 시작 후 남은 마지막 교전 횟수(-1=미배정)
			"final": false,        # 최후 전투 쌍(V/W) — 복귀 제외, 필드에 남아 1:1 지속
			"death_t": 0.0,
			"airborne": false,  # 사망 넉백 비행 중(Hurt 자세) — 착지하면 Death로 전환
			"dvx": 0.0,
			"dvy": 0.0,
			"land_y": 0.0,
			"alpha": 1.0,
			"seed": _rng.randf() * TAU,
			"face": 1.0 if side == 0 else -1.0,
		})
		_next_id += 1

## 타겟 선택 (원본 0xE5DA 재현): 상대 적의 타겟 상태로 3단계 우선순위 → 동순위 최근접(맨해튼).
##  P3: 그 적이 '나'를 노림(상호 락) > P2: 미교전 적 > P1: 딴 아군과 교전 중인 적.
##  높은 순위 우선, 같으면 맨해튼 최근접(동거리는 먼저 만난=인덱스 낮은 적). 상호 락(P3)+교전 회피(P1)로
##  1:1 레인 대치가 창발한다 — 마주 선 진형에선 같은 행 적이 최근접이라 "정면 적 최우선"이 된다.
##  양쪽이 같은 프레임 상태를 보도록 직전 target을 읽어 new_targets에 모은 뒤 일괄 커밋.
func _retarget_all() -> void:
	var new_targets := {}  # soldier id -> foe(Dictionary) or null
	for side in [0, 1]:
		var foes: Array = _soldiers[1 - side]
		for s in _soldiers[side]:
			if s["state"] == DYING or s["state"] == RETURN or s["state"] == IDLE or s["state"] == DUEL:
				new_targets[s["id"]] = null  # 죽는 중/복귀 중/정렬 완료/듀얼 중 병사는 교전 안 함
				continue
			var sp: Vector2 = s["pos"]
			var best: Variant = null
			var best_pri := 0
			var best_d := 1.0e9
			for f in foes:
				if f["state"] == DYING or f["state"] == RETURN or f["state"] == IDLE or f["state"] == DUEL:
					continue  # 전장에서 빠지는 적은 타겟 후보에서 제외
				var ft: Variant = f["target"]  # 그 적이 직전 프레임에 노리던 대상
				var pri := 1                    # 딴 놈과 교전 중
				if ft == null:
					pri = 2                     # 미교전
				elif ft["id"] == s["id"]:
					pri = 3                     # 나를 노림(상호 락)
				var fp: Vector2 = f["pos"]
				var d: float = absf(sp.x - fp.x) + absf(sp.y - fp.y)  # 맨해튼
				var better := false
				if best == null:
					better = true
				elif pri > best_pri:            # 높은 우선순위 우선
					better = true
				elif pri == best_pri and d < best_d:  # 동순위는 최근접(strict → 낮은 인덱스 승)
					better = true
				if better:
					best = f
					best_pri = pri
					best_d = d
			new_targets[s["id"]] = best
	for side in [0, 1]:
		for s in _soldiers[side]:
			s["target"] = new_targets[s["id"]]

# ── 연출 트리거 ────────────────────────────────────────────────────────────
func begin_advance() -> void:
	_charging = true

## 전투 종료: 이후 각 병사는 **마지막 교전(유닛별 랜덤 1~N회 공방) + 진행 중 공방·핑퐁 밀림**을 마치면 home으로 복귀(RETURN).
## 마지막 교전 횟수가 유닛마다 달라 **동시에가 아니라 순차적으로(줄줄이) 이탈**한다 — 전투 중 이탈은 없다(끝까지 싸운 뒤 복귀).
func begin_retreat() -> void:
	_retreating = true

## 아직 싸울 수 있는 적(타겟이 MELEE 또는 CHARGE)인가 — 복귀 중 헛칼질/즉시복귀 판단용.
## 상대가 죽는 중(DYING)·이미 이탈(RETURN/IDLE)·없음(null)이면 마무리할 교전이 없다.
func _foe_alive(s: Dictionary) -> bool:
	var t: Variant = s["target"]
	return t != null and (t["state"] == MELEE or t["state"] == CHARGE)

## 복귀 준비: 복귀 시작 후 각 유닛은 **마지막 교전(랜덤 1~N회 공방)** 을 마쳐야 이탈한다 → 유닛별로 어긋난 순차 복귀.
##  - CHARGE(접근만 하던 병사): 마무리할 교전 없음 → 바로 복귀.
##  - MELEE: `retreat_swings`(begin_retreat 후 유닛별 randi[1,MAX] 배정)가 0으로 소진되고,
##    진행 중이던 공방(strike_t)·핑퐁 밀림(push_rem)까지 잦아들면 복귀. 상대가 죽으면 즉시 소진(헛칼질 방지, _process 참조).
const RETREAT_PUSH_EPS := 1.0        # 밀림이 이 px 안으로 잦아들면 핑퐁 종료로 간주
const RETREAT_SWINGS_MAX := 2        # 복귀 전 마지막 교전 최대 공방 횟수(유닛별 randi[1,이 값]) — 죽음 없는 복귀 꼬리 최소화
func _retreat_ready(s: Dictionary) -> bool:
	if not _retreating:
		return false
	if s.get("final", false):
		return false  # 최후 전투 쌍은 필드에 남아 1:1 지속(복귀 안 함)
	if s["state"] == CHARGE:
		return true  # 접근만 하던 병사는 마무리 교전 없이 바로 복귀
	if s["state"] != MELEE:
		return false
	# 마지막 교전 다 하고(retreat_swings==0), 현재 공방·밀림까지 잦아들면 이탈
	return s.get("retreat_swings", -1) == 0 \
		and s["strike_t"] <= 0.0 and absf(s.get("push_rem", 0.0)) < RETREAT_PUSH_EPS

## 최후 전투 스테이징: loser_side의 유닛 V + 적 유닛 W 를 1:1 최후 쌍으로 지정(복귀 제외, 서로 락).
## 다른 유닛이 V/W를 노리면 해제 → 개입 없는 1:1 보장. 성립 못하면 false.
func stage_final_duel(loser_side: int) -> bool:
	var v: Variant = _pick_final(loser_side)
	if v == null:
		return false
	var w: Variant = _pick_final_opponent(v, loser_side)
	if w == null:
		return false
	v["final"] = true
	w["final"] = true
	v["target"] = w   # 서로 락 → 1:1
	w["target"] = v
	_final_victims.append(v)  # 최후 킬 대상(정확히 이 V) — fire_final_duel이 처형
	for side in [0, 1]:   # 다른 유닛이 V/W 노리면 해제(최후 전투에 개입 금지)
		for s in _soldiers[side]:
			if s.get("final", false):
				continue
			if s["target"] == v or s["target"] == w:
				s["target"] = null
	return true

## 최후 쌍 후보: 아직 안 정해진(비-final) 접전/접근 유닛.
func _pick_final(side: int) -> Variant:
	var pool: Array = _soldiers[side].filter(func(s):
		return (s["state"] == MELEE or s["state"] == CHARGE) and not s.get("final", false))
	if pool.is_empty():
		return null
	return pool[_rng.randi() % pool.size()]

## V의 최후 상대: 현재 타겟이 유효(비-final 적)면 우선(인접), 아니면 최근접 적.
func _pick_final_opponent(v: Dictionary, loser_side: int) -> Variant:
	var enemies: Array = _soldiers[1 - loser_side].filter(func(s):
		return (s["state"] == MELEE or s["state"] == CHARGE) and not s.get("final", false))
	if enemies.is_empty():
		return null
	var cur: Variant = v["target"]
	if cur != null and cur in enemies:
		return cur
	var best: Dictionary = enemies[0]
	var bd := 1.0e18
	for e in enemies:
		var d: float = v["pos"].distance_squared_to(e["pos"])
		if d < bd:
			bd = d
			best = e
	return best

## 최후 쌍 외 나머지가 모두 복귀(IDLE) 또는 사망 중(DYING)인가 — FINALE 최후 킬 발동 시점 판단.
func others_returned() -> bool:
	for side in [0, 1]:
		for s in _soldiers[side]:
			if s.get("final", false):
				continue
			if s["state"] != IDLE and s["state"] != DYING:
				return false
	return true

## 진형 좌표: 진영 끝에 앵커, 중앙 방향으로 균일한 3행 [3,3,4] 열(가운데 행 쐐기). 각 병사의 복귀 위치.
func _formation_slots(side: int, n: int) -> Array:
	var anchor_x := FORM_EDGE_X if side == 0 else (FIELD_W - FORM_EDGE_X)
	var to_center := 1.0 if side == 0 else -1.0
	var rows := _row_counts(n)
	var out: Array = []
	for r in range(3):
		var ry := BASE_Y + (float(r) - 1.0) * ROW_SPACE
		var diag := DIAG_STEP if r == 1 else 0.0   # 가운데 행만 중앙 쪽으로 튀어나온 쐐기
		var sz: int = rows[r]
		for k in range(sz):
			out.append(Vector2(anchor_x + to_center * (float(k) * FORM_DEPTH + diag), ry))
	return out

## 스폰 좌표: 화면 밖(진영 바깥)에서 좌우 간격 3배로 넓게. 뒤 열일수록 더 바깥 → 돌격해 들어온다.
## _formation_slots 와 같은 (r, k) 순서라 index 가 1:1 대응 → 각 병사가 자기 진형 자리로 복귀.
func _spawn_slots(side: int, n: int) -> Array:
	var edge_x := -SPAWN_EDGE_X if side == 0 else (FIELD_W + SPAWN_EDGE_X)
	var to_center := 1.0 if side == 0 else -1.0
	var to_out := -to_center                       # 화면 바깥 방향
	var rows := _row_counts(n)
	var out: Array = []
	for r in range(3):
		var ry := BASE_Y + (float(r) - 1.0) * ROW_SPACE
		var diag := DIAG_STEP if r == 1 else 0.0   # 가운데 행만 중앙 쪽으로 튀어나온 쐐기
		var sz: int = rows[r]
		for k in range(sz):
			var jx := _rng.randf_range(-SPAWN_XJIT, SPAWN_XJIT)  # 유닛별 X 좌우 지터
			out.append(Vector2(edge_x + to_out * float(k) * SPAWN_DEPTH + to_center * diag + jx, ry))
	return out

## 복귀가 끝났는가 — 생존자가 모두 제자리(IDLE)인가. 대기(peel off 전)·이동(RETURN) 중이면 아직.
func all_returned() -> bool:
	for side in [0, 1]:
		for s in _soldiers[side]:
			if s["state"] != IDLE and s["state"] != DYING:
				return false
	return true

## 진행 중인 듀얼(밀당→사망)이 있는가. 복귀는 이게 다 끝난 뒤 시작해야 "복귀 중 사망"이 안 생긴다.
func duels_active() -> bool:
	for side in [0, 1]:
		for s in _soldiers[side]:
			if s["state"] == DUEL:
				return true
	return false

## 양쪽 모두 최소 1명씩 접전에 들어갔는가(첫 충돌). 이때부터 바로 교전 시작.
func any_engaged() -> bool:
	return _has_melee(0) and _has_melee(1)

func _has_melee(side: int) -> bool:
	for s in _soldiers[side]:
		if s["state"] == MELEE:
			return true
	return false

## 사망/타격 대상은 실제 접전 중(MELEE)인 병사 우선, 없으면 아무 생존자.
func _pick_engaged(side: int) -> Variant:
	var pool: Array = _soldiers[side].filter(func(s): return s["state"] == MELEE)
	if pool.is_empty():
		pool = _soldiers[side].filter(func(s): return s["state"] == MELEE or s["state"] == CHARGE)
	if pool.is_empty():
		return null
	return pool[_rng.randi() % pool.size()]

## 접전 중 병사가 자기 타겟(없으면 앞쪽)을 향해 자동 공방(연출). 데미지는 presenter의 kill이 별도 처리.
## 모션이 꺼져 있어도 보이도록 접점에 작은 섬광 + 약한 흔들림. strike_t는 찌르기/창 뻗기 재활성 시 사용.
func _auto_strike(s: Dictionary) -> void:
	var tgt: Variant = s["target"]
	var toward: Vector2 = s["pos"] + Vector2(s["face"] * 10.0, 0.0)
	# 밀림 예약은 아직 싸우는 적(MELEE/CHARGE)에게만 — 죽는 중(DYING/DUEL)이거나 이미 이탈한(RETURN/IDLE) 적은 제외.
	if tgt != null and (tgt["state"] == MELEE or tgt["state"] == CHARGE):
		toward = tgt["pos"]
		if toward.x != s["pos"].x:
			s["face"] = signf(toward.x - s["pos"].x)
		# 펜싱 밀림 예약: 찌르는 쪽 전진 + 맞는 쪽 뒤로(같은 벡터 → 거리 유지). 실제 이동은 _process가
		# push_rem을 이징으로 소진(순간이동 대신 슬라이드).
		var push: float = s["face"] * FENCE_PUSH
		s["push_rem"] = s.get("push_rem", 0.0) + push
		tgt["push_rem"] = tgt.get("push_rem", 0.0) + push
		tgt["hit_t"] = HIT_FLASH_DUR  # 맞는 쪽 흰색 피격 플래시
	s["strike_t"] = STRIKE_DUR
	s["attack_t"] = ATTACK_DUR   # 공격 애니 재생 예약
	s["atk_fire"] = true         # 스프라이트가 이번 프레임 attack 0프레임부터 재생
	# [임시 비활성] ③ 전방 슬래시 이펙트 [0x1860] — 재활성 시 아래 블록 주석 해제
	#var dir: float = s["face"]
	#_effects.append({"pos": s["pos"] + Vector2(dir * 6.0, -6.0), "vx": dir * 3.0 * 1.2 * 60.0,
	#	"life": 0.22, "side": s["side"]})
	var hit: Vector2 = (s["pos"] + toward) * 0.5
	_flashes.append({"pos": hit, "life": 0.1, "max": 0.1, "big": false})
	_shake = maxf(_shake, 0.8)

## Presenter가 결과대로 지정하는 킬 → 즉사 대신 **듀얼**을 연다. 패자 V(접전 병사) + 승자 W(=V의 타겟 적).
## 공방 N=randi(1..3)회 → N-1번 밀림 스텝(_process) 후 V 사망(_die). W 없으면 즉사.
func kill(side: int) -> void:
	var v: Variant = _pick_engaged(side)
	if v == null:
		return
	_open_duel(v, v["target"], _duel_count() - 1)

## 최후 전투 발동: 스테이징된 victim(V)들을 긴 밀당 듀얼로 처형. FINALE에서 나머지 복귀 후 호출.
## 더블(양 팀 각 1:1)이면 **길이를 다르게** 부여 — 첫 victim 짧게(3~4), 둘째 victim 길게(5~7)
## → 동시 시작이지만 **먼저 하나 쓰러지고, 다른 하나가 더 버티다 쓰러짐**(동시 사망 어색함 제거).
const DRAMATIC_STEPS_MIN := 3   # 첫 victim 밀당 최소 스텝
const DRAMATIC_STEPS_MAX := 4   # 첫 victim 밀당 최대 스텝
const DRAMATIC_STEPS2_MIN := 5  # 둘째 victim(더블) 밀당 최소 스텝 — 더 오래 버팀
const DRAMATIC_STEPS2_MAX := 7  # 둘째 victim(더블) 밀당 최대 스텝
func fire_final_duel() -> void:
	for i in range(_final_victims.size()):
		var v: Dictionary = _final_victims[i]
		if v["state"] != MELEE and v["state"] != CHARGE:
			continue  # 방어: V가 이미 죽었거나 이탈했으면 스킵(정상 흐름에선 발생 안 함)
		var steps: int = _rng.randi_range(DRAMATIC_STEPS_MIN, DRAMATIC_STEPS_MAX) if i == 0 \
			else _rng.randi_range(DRAMATIC_STEPS2_MIN, DRAMATIC_STEPS2_MAX)  # 둘째부터 길게 → 시차 사망
		_open_duel(v, v["target"], steps)
	_final_victims = []

## 듀얼 개시: V가 승자 W와 steps회 밀당 후 사망(_die). W가 유효 접전 적이 아니면 즉사 fallback.
func _open_duel(v: Dictionary, w: Variant, steps: int) -> void:
	if w != null and (w["state"] == MELEE or w["state"] == CHARGE):
		v["state"] = DUEL
		v["duel_winner"] = w
		v["duel_steps"] = maxi(0, steps)
		v["duel_timer"] = DUEL_STEP
	else:
		_die(v)  # 승자 없음 → 즉사 fallback

## 실제 전사: ① Hurt 자세로 위로+뒤로 포물선 넉백 비행(원본 0x1976/0x19EA) → ② 착지 후 Death(주저앉기) → ③ 페이드.
## _process가 airborne 적분 → 착지 시 airborne=false·death_t=0 → COLLAPSE 뒤 FADE 동안 alpha↓ → 제거.
func _die(s: Dictionary) -> void:
	s["state"] = DYING
	s["death_t"] = 0.0
	s["attack_t"] = 0.0
	s["push_rem"] = 0.0  # 넉백으로 대체 — 남은 펜싱 밀림 취소
	s["airborne"] = true
	s["land_y"] = s["pos"].y
	var back: float = -float(s["face"])  # 적 반대 방향(뒤)
	s["dvx"] = back * _rng.randf_range(DEATH_VX.x, DEATH_VX.y)
	s["dvy"] = -_rng.randf_range(DEATH_VY.x, DEATH_VY.y)  # 위로 launch
	s["hit_t"] = HIT_FLASH_DUR  # 치명타 흰색 플래시
	_flashes.append({"pos": s["pos"], "life": 0.24, "max": 0.24, "big": true})
	_shake = maxf(_shake, 2.5)

## 듀얼 공방 횟수 N (1~3). N-1이 밀림 스텝 수.
func _duel_count() -> int:
	return _rng.randi_range(1, 3)

## 밀림 스텝 결과: r<0.6 무이동 / <0.9 패자 밀림 / else 승자 밀림.
func _push_kind_for(r: float) -> int:
	if r < 0.6:
		return PUSH_NONE
	if r < 0.9:
		return PUSH_LOSER
	return PUSH_WINNER

## 한 스텝 밀림 적용: 밀리는 쪽이 상대 반대로 물러나고 상대가 따라감(같은 벡터 → 거리 유지). push_rem 재사용.
func _apply_duel_push(v: Dictionary, w: Variant, kind: int) -> void:
	if kind == PUSH_NONE or w == null or w["state"] == DYING:
		return
	var dir: float
	if kind == PUSH_LOSER:   # 패자 v 뒤로(w 반대), 승자 w 따라감
		dir = signf(v["pos"].x - w["pos"].x)
	else:                    # PUSH_WINNER: 승자 w 뒤로(v 반대), 패자 v 따라감
		dir = signf(w["pos"].x - v["pos"].x)
	if dir == 0.0:
		dir = 1.0
	var push: float = dir * FENCE_PUSH
	v["push_rem"] = v.get("push_rem", 0.0) + push
	w["push_rem"] = w.get("push_rem", 0.0) + push

func force_result(a_final: int, b_final: int) -> void:
	_reduce_to(0, a_final)
	_reduce_to(1, b_final)
	queue_redraw()

func _reduce_to(side: int, final_n: int) -> void:
	# 죽는 중(DYING)·듀얼 중(DUEL) 병사는 이미 사망 예정 → 생존 트림 대상에서 빼고 유지(애니 끝까지).
	var alive: Array = _soldiers[side].filter(func(s): return s["state"] != DYING and s["state"] != DUEL)
	var dying: Array = _soldiers[side].filter(func(s): return s["state"] == DYING or s["state"] == DUEL)
	while alive.size() > final_n:
		alive.pop_back()
	alive.append_array(dying)
	_soldiers[side] = alive

# ── 업데이트 ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_t += delta

	if _charging and not _retreating:
		_retarget_all()  # 매 프레임 3단계 우선순위 타겟팅(원본 0xE5DA: 상호 락>미교전>교전 중, 동순위 최근접)

	for side in [0, 1]:
		var keep: Array = []
		for s in _soldiers[side]:
			if s["strike_t"] > 0.0:
				s["strike_t"] = maxf(0.0, s["strike_t"] - delta)
			if s.get("attack_t", 0.0) > 0.0:
				s["attack_t"] = maxf(0.0, s["attack_t"] - delta)
			if s.get("hit_t", 0.0) > 0.0:
				s["hit_t"] = maxf(0.0, s["hit_t"] - delta)
			# 접전(MELEE) 병사 자동 공방: 계속 주고받게(idle 방지). 전투 종료(_retreating) 후엔 새 공방 안 시작.
			# 펜싱 밀림 애니메이션: 예약된 push_rem을 이징으로 소진(순간이동 대신 슬라이드). 사망 중 제외.
			var pr: float = s.get("push_rem", 0.0)
			if s["state"] != DYING and pr != 0.0:
				var mv: float = pr * (1.0 - exp(-PUSH_SMOOTH * delta))
				if absf(pr) < 0.1:  # 잔여가 작으면 한 번에 소진 → 잔량 누적 드리프트 방지
					mv = pr
				var pp: Vector2 = s["pos"]
				pp.x += mv
				s["pos"] = pp
				s["push_rem"] = pr - mv
			# 최후 전투 승자: 상대(V)가 죽으면(DYING) final 해제 → 이제 이 승자도 복귀 대상이 됨.
			if s.get("final", false):
				var ft: Variant = s["target"]
				if ft == null or ft["state"] == DYING:
					s["final"] = false
			# 접전 자동 공방: 평시엔 계속. 복귀 시작 후엔 **살아있는 적이 있을 때만** 유닛별 "마지막 교전(retreat_swings)"을 하고 멈춤.
			# 상대가 죽거나(DYING) 이미 이탈했으면 retreat_swings=0 → 헛칼질 없이 바로 복귀.
			# 단, 최후 전투 쌍(final)은 복귀 안 하고 끝까지 1:1 교전을 계속한다.
			if s["state"] == MELEE:
				var is_final: bool = s.get("final", false)
				if _retreating and not is_final:
					if not _foe_alive(s):
						s["retreat_swings"] = 0                                       # 상대 없음 → 헛칼질 없이 복귀
					elif s.get("retreat_swings", -1) < 0:
						s["retreat_swings"] = _rng.randi_range(1, RETREAT_SWINGS_MAX)  # 유닛별 마지막 교전 횟수
				if is_final or not _retreating or s.get("retreat_swings", 0) > 0:
					s["strike_cd"] = s.get("strike_cd", 0.0) - delta
					if s["strike_cd"] <= 0.0:
						_auto_strike(s)
						if _retreating and not is_final:
							s["retreat_swings"] -= 1  # 마지막 교전 1회 소진
						s["strike_cd"] = STRIKE_INTERVAL + _rng.randf_range(0.0, STRIKE_JITTER)
			if s["state"] == DYING:
				if s["airborne"]:
					# ① 넉백 비행: 중력 가속 + 등속 뒤로(Hurt 자세). 착지하면 주저앉기 단계로.
					s["dvy"] += DEATH_GRAV * delta
					var p: Vector2 = s["pos"]
					p.x += s["dvx"] * delta
					p.y += s["dvy"] * delta
					if p.y >= s["land_y"]:
						p.y = s["land_y"]
						s["airborne"] = false
						s["death_t"] = 0.0  # 착지 순간부터 collapse 타이머 시작
					s["pos"] = p
				else:
					# ② 착지 후 주저앉기(death 애니) → ③ COLLAPSE 뒤 FADE 동안 소멸.
					s["death_t"] += delta
					if s["death_t"] >= DEATH_COLLAPSE:
						var ft: float = (s["death_t"] - DEATH_COLLAPSE) / DEATH_FADE
						s["alpha"] = clampf(1.0 - ft, 0.0, 1.0)
					if s["death_t"] >= DEATH_COLLAPSE + DEATH_FADE:
						continue  # 제거
			elif s["state"] == DUEL:
				# 듀얼 밀당: 스텝마다 확률 밀림(60/30/10), N-1 스텝 뒤 실제 사망(_die).
				s["duel_timer"] = s.get("duel_timer", DUEL_STEP) - delta
				if s["duel_timer"] <= 0.0:
					if s.get("duel_steps", 0) > 0:
						_apply_duel_push(s, s["duel_winner"], _push_kind_for(_rng.randf()))
						s["hit_t"] = HIT_FLASH_DUR  # 패자가 매 스텝 맞으며 흰색 플래시
						s["duel_steps"] -= 1
						s["duel_timer"] = DUEL_STEP
					else:
						_die(s)
			elif s["state"] == RETURN:
				_return_step(s, delta)  # 본인 진영으로 복귀
			elif _retreat_ready(s):
				# 마지막 교전(retreat_swings)·공방·밀림 다 끝난 병사부터 순차적으로 복귀 시작.
				s["state"] = RETURN
				s["target"] = null
			elif _charging and not _retreating:
				_move_step(s, delta)
			keep.append(s)
		_soldiers[side] = keep

	if _charging and not _retreating:
		_separate(delta)  # 겹침 방지 → 난전에 부피 생김(원본 충돌 박스 0xE87A 근사). MELEE 제외로 제자리 교전.

	# 살아있는 병사는 보이는 전장 안으로 클램프(원본 0xE48E). 화면 밖(특히 아래 HUD 뒤)으로 안 나가게.
	# 단, 돌격 중(CHARGE)은 화면 밖 스폰→진입이라 X는 클램프하지 않는다.
	for side in [0, 1]:
		for s in _soldiers[side]:
			if s["state"] == DYING:
				continue
			var p: Vector2 = s["pos"]
			p.y = clampf(p.y, ACTION_TOP + 8.0, ACTION_BOT - 10.0)
			if s["state"] != CHARGE:
				p.x = clampf(p.x, 16.0, 368.0)
			s["pos"] = p

	# 공격 이펙트 전진
	for e in _effects:
		e["pos"].x += e["vx"] * delta
		e["life"] -= delta
	_effects = _effects.filter(func(e): return e["life"] > 0.0)

	for fl in _flashes:
		fl["life"] -= delta
	_flashes = _flashes.filter(func(f): return f["life"] > 0.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 12.0)

	_sync_sprites()
	queue_redraw()

## 흔들림 오프셋(내부좌표). _draw(지형/이펙트)와 _units(스프라이트)가 같은 값을 쓴다.
func _shake_offset() -> Vector2:
	if _shake > 0.0:
		return Vector2(round(sin(_t * 60.0) * _shake), 0)
	return Vector2.ZERO

## 병사 dict ↔ AnimatedSprite2D 풀 동기화. 상태별 애니:
##  DYING=hurt(넉백 비행)→death(착지 주저앉기), 이동(CHARGE/RETURN)=walk, 공격(attack_t>0)=attack, 그 외=idle.
func _sync_sprites() -> void:
	_units.position = _shake_offset()
	var live := {}
	for side in [0, 1]:
		for s in _soldiers[side]:
			var id: int = s["id"]
			live[id] = true
			var spr: AnimatedSprite2D = _sprites.get(id)
			if spr == null:
				spr = AnimatedSprite2D.new()
				spr.sprite_frames = _frames[side]
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 픽셀 선명하게
				spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
				var mat := ShaderMaterial.new()          # 피격 흰색 플래시용(병사별 flash 파라미터)
				mat.shader = HIT_FLASH_SHADER
				spr.material = mat
				spr.play("walk")
				spr.frame = _rng.randi() % WALK_FRAMES   # 위상 분산 — 병사들이 발맞춰 걷지 않게
				_units.add_child(spr)
				_sprites[id] = spr
			spr.position = _draw_pos(s)
			spr.flip_h = s["face"] < 0.0            # 애셋은 우측을 봄 → 좌향일 때만 뒤집기
			spr.modulate.a = s["alpha"]
			# 피격 플래시: hit_t 를 1→0 으로 감쇠시켜 셰이더 flash 로 전달(맞은 순간 흰색 팝).
			var fl: float = clampf(s.get("hit_t", 0.0) / HIT_FLASH_DUR, 0.0, 1.0)
			(spr.material as ShaderMaterial).set_shader_parameter("flash", fl)
			if s["state"] == DYING:
				var danim := "hurt" if s["airborne"] else "death"  # 비행=Hurt, 착지=Death(주저앉기)
				if spr.animation != danim:
					spr.play(danim)                 # 1회 재생 → 마지막 프레임 유지, alpha로 소멸
			elif s["state"] == CHARGE or s["state"] == RETURN:
				_play_loop(spr, "walk")
			elif s.get("atk_fire", false):
				spr.play("attack")                  # 공격 시작 신호 → 0프레임부터 재생
				s["atk_fire"] = false
			elif s.get("attack_t", 0.0) > 0.0:
				pass                                # 공격 애니 진행 중 — 그대로 둠
			else:
				_play_loop(spr, "idle")
	for id in _sprites.keys():
		if not live.has(id):
			_sprites[id].queue_free()
			_sprites.erase(id)

## 루프 애니 전환(같으면 유지, 멈췄으면 재개). walk/idle 전용.
func _play_loop(spr: AnimatedSprite2D, anim: String) -> void:
	if spr.animation != anim:
		spr.play(anim)
	elif not spr.is_playing():
		spr.play()

## 적 타겟을 향해 등속 접근 — X를 먼저 좁히고 → Y 접근 [원본 0xE30E]. CHARGE↔MELEE 동적 전환.
func _move_step(s: Dictionary, delta: float) -> void:
	var tgt: Variant = s["target"]
	if tgt == null or tgt["state"] == DYING:
		s["state"] = MELEE  # 적 없음(다음 프레임 retarget 대기)
		return
	var pos: Vector2 = s["pos"]
	var tp: Vector2 = tgt["pos"]
	var dx := tp.x - pos.x
	var dy := tp.y - pos.y
	var adx := absf(dx)
	var ady := absf(dy)
	if adx > GAP_X:
		pos.x += signf(dx) * minf(VX * delta, adx - GAP_X)
	if dx != 0.0:
		s["face"] = signf(dx)
	if adx <= CLOSE_X and ady > GAP_Y:
		pos.y += signf(dy) * minf(VY * delta, ady - GAP_Y)
	s["pos"] = pos
	s["state"] = MELEE if (adx <= GAP_X + 2.0 and ady <= GAP_Y + 2.0) else CHARGE

## 본인 진영 복귀 위치(home)로 등속 이동. 도착하면 IDLE(정렬 완료).
func _return_step(s: Dictionary, delta: float) -> void:
	var home: Vector2 = s["home"]
	var pos: Vector2 = s["pos"]
	var d := home - pos
	var dist := d.length()
	if dist < 2.0:
		s["pos"] = home
		s["state"] = IDLE
		s["face"] = 1.0 if s["side"] == 0 else -1.0  # 정렬 후 적(중앙)을 바라봄
		return
	var step := minf(VX * delta, dist)
	s["pos"] = pos + d / dist * step
	if absf(d.x) > 0.5:
		s["face"] = signf(d.x)

## 겹치는 병사끼리 서로 밀어냄(원본 16px 충돌 박스 근사). 난전이 한 점에 뭉치지 않게 함.
## 접전(MELEE) 병사는 밀리지 않고 제자리에서 교전 — 미끄러짐 방지. 단 obstacle(부피)로는 남아 CHARGE가 피해간다.
## delta 기반이라 프레임레이트와 무관하게 부드럽게 수렴한다.
func _separate(delta: float) -> void:
	var all: Array = []
	all.append_array(_soldiers[0])
	all.append_array(_soldiers[1])
	var n := all.size()
	for i in range(n):
		var s: Dictionary = all[i]
		if s["state"] == DYING or s["state"] == MELEE:
			continue  # 죽는 중/접전 중은 밀지 않음(접전은 제자리)
		var sp: Vector2 = s["pos"]
		var push := Vector2.ZERO
		for j in range(n):
			if i == j:
				continue
			var o: Dictionary = all[j]
			if o["state"] == DYING:
				continue
			var diff: Vector2 = sp - o["pos"]
			var dist := diff.length()
			if dist < SEP_DIST:
				if dist > 0.05:
					push += diff / dist * (SEP_DIST - dist)
				else:
					push += Vector2(cos(s["seed"]), sin(s["seed"]))
		if push != Vector2.ZERO:
			s["pos"] = sp + push * SEP_RATE * delta

# ── 위치(그리기용) ─────────────────────────────────────────────────────────
func _draw_pos(s: Dictionary) -> Vector2:
	var base: Vector2 = s["pos"]
	# 근접 중 미세 몸싸움(제자리 흔들림) — 미끄러짐 인상 줄이려 진폭 축소
	if s["state"] == MELEE:
		base += Vector2(sin(_t * 6.0 + s["seed"]) * 0.6, cos(_t * 5.0 + s["seed"]) * 0.4)
	# 사망 중엔 pos 를 직접 적분(넉백 점프)하므로 여기선 그대로 사용.
	return base

# ── 그리기 (사각형 픽셀 전용, 정수 좌표) ──────────────────────────────────
func _draw() -> void:
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(round(sin(_t * 60.0) * _shake), 0)

	_draw_terrain(sh)

	# 병사 몸통은 스프라이트(_units)가 그린다. 여기선 발밑 그림자만(사망 중이면 alpha로 함께 소멸).
	var all: Array = []
	all.append_array(_soldiers[0])
	all.append_array(_soldiers[1])
	for s in all:
		_draw_shadow(_draw_pos(s) + sh, s)

	for e in _effects:
		_draw_effect(e["pos"] + sh, e["side"], e["life"])
	for fl in _flashes:
		_draw_impact(fl["pos"] + sh, fl["life"] / fl["max"], fl["big"])

func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(round(x), round(y), round(w), round(h)), c)

func _draw_terrain(sh: Vector2) -> void:
	var ox := sh.x
	_px(-4 + ox, 0, FIELD_W + 8, FIELD_H, FLOOR)
	var tile := 16
	for ry in range(0, int(FIELD_H) + tile, tile):
		for rx in range(-tile, int(FIELD_W) + tile, tile):
			var hsh := int(abs(sin((rx + 1) * 12.9 + (ry + 1) * 78.2) * 1000.0)) % 5
			var stagger := (tile / 2) if (ry / tile) % 2 == 0 else 0
			var bx := rx + stagger + ox
			var base := FLOOR
			if hsh == 0:
				base = FLOOR_HI
			elif hsh == 1:
				base = FLOOR_DK
			_px(bx, ry, tile, tile, base)
			_px(bx, ry + tile - 1, tile, 1, MORTAR)
			_px(bx + tile - 1, ry, 1, tile, MORTAR)
			_px(bx, ry, tile, 1, FLOOR_HI)
			if hsh == 2:
				_px(bx + 3, ry + 5, 3, 2, MOSS)
			elif hsh == 3:
				_px(bx + 9, ry + 9, 2, 2, MOSS)
	_px(-4 + ox, 0, FIELD_W + 8, 40, WALL)
	for rx in range(-tile, int(FIELD_W) + tile, tile):
		var bx2 := rx + ox
		_px(bx2, 0, tile, 20, WALL_DK)
		_px(bx2, 0, tile, 1, WALL_HI)
		_px(bx2 + tile - 1, 0, 1, 20, WALL_DK)
	_px(-4 + ox, 20, FIELD_W + 8, 8, PIT)
	for lx in [40, 150, 300]:
		var x: float = float(lx) + ox
		_px(x, 6, 2, 30, WOOD)
		_px(x + 8, 6, 2, 30, WOOD)
		for yy in range(9, 34, 5):
			_px(x, yy, 10, 2, WOOD)
	_px(-4 + ox, 38, FIELD_W + 8, 2, WALL_HI)

## 발밑 그림자(스프라이트 발끝 ≈ pos.y+8 에 정렬). 몸통은 스프라이트가 그린다.
## 넉백 비행 중(airborne)엔 그림자를 지면(land_y)에 고정 → 점프처럼 보이게(몸만 떠오름).
func _draw_shadow(pos: Vector2, s: Dictionary) -> void:
	var a: float = s["alpha"]
	var gy: float = pos.y
	if s["state"] == DYING and s["airborne"]:
		gy = s["land_y"] + (pos.y - s["pos"].y)  # (pos.y - s.pos.y) = 흔들림 sh.y 보정
	_px(round(pos.x) - 5, round(gy) + 8, 10, 2, Color(0, 0, 0, 0.28 * a))

func _draw_effect(pos: Vector2, side: int, life: float) -> void:
	var a := clampf(life / 0.22, 0.0, 1.0)
	var c := Color(1, 1, 0.8, a)
	var x: float = round(pos.x)
	var y: float = round(pos.y)
	# 짧은 사선 슬래시
	_px(x - 1, y - 2, 3, 1, c)
	_px(x, y - 1, 3, 1, c)
	_px(x + 1, y, 3, 1, c)

func _draw_impact(pos: Vector2, t: float, big: bool) -> void:
	var a := clampf(t, 0.0, 1.0)
	var x: float = round(pos.x)
	var y: float = round(pos.y)
	var col := Color(1, 1, 0.85, a)
	var r := (5.0 if big else 3.0) * t + 1.0
	_px(x - r, y - 1, r * 2, 2, col)
	_px(x - 1, y - r, 2, r * 2, col)
	if big:
		_px(x - 2, y - 2, 4, 4, Color(1, 0.95, 0.7, a))
		_px(x - r, y - r, 2, 2, Color(1, 0.8, 0.4, a))
		_px(x + r - 2, y + r - 2, 2, 2, Color(1, 0.8, 0.4, a))
