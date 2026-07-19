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

# 원본 등속 이동 속도 (px/frame @60fps) → 초당으로 환산(×60, ×1.2 스케일)
const VX := 3.0 * 1.2 * 60.0   # ≈ 216 px/s (원본 등속 3px/frame)
const VY := 2.0 * 1.2 * 60.0   # ≈ 144 px/s (원본 2px/frame)
const CLOSE_X := 36.0 * 1.2    # X가 이 안이면 Y 접근 시작 (원본 0x240000=36px)
const GAP_X := 13.0            # 근접 시 좌우 간격(마주섬)
const GAP_Y := 5.0
const STRIKE_INTERVAL := 0.42  # 접전 중 자동 공방 주기(초) — 전투 내내 계속 주고받게(idle 방지)
const STRIKE_JITTER := 0.18    # 공방 주기 무작위 편차(위상차)

const STRIKE_DUR := 0.22
# 사망: 원본 0x1976/0x19EA — 위로+뒤로 포물선 넉백 점프 → 착지 후 눕기+점멸 소멸(0x1B24)
const DEATH_GRAV := 540.0            # 중력 px/s² (원본 +0x2000/frame ×1.2×3600)
const DEATH_VX := Vector2(40.0, 105.0)   # 뒤로 넉백 속도 범위 px/s (원본 0.5~1.5px/f ×1.2×60)
const DEATH_VY := Vector2(175.0, 250.0)  # 위로 launch 속도 범위 px/s (원본 2.5~3.5px/f ×1.2×60)
const DEATH_LIE := 0.6               # 착지 후 눕기+점멸 시간

# 병사 상태
enum { CHARGE, MELEE, DYING, RETURN, IDLE }

# ── 팔레트 (16비트풍) ─────────────────────────────────────────────────────
const OUTLINE := Color8(16, 18, 26)
const STEEL := Color8(150, 160, 178)
const STEEL_HI := Color8(214, 224, 238)
const STEEL_DK := Color8(84, 92, 108)
const SKIN := Color8(214, 164, 118)
const BOOT := Color8(58, 42, 28)
const WOOD := Color8(126, 84, 42)
const TEAM := {
	0: [Color8(58, 108, 196), Color8(34, 66, 128), Color8(110, 170, 250)],
	1: [Color8(196, 62, 58), Color8(128, 36, 34), Color8(250, 118, 104)],
}
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

func _ready() -> void:
	_rng.randomize()

func setup(a_count: int, b_count: int) -> void:
	_soldiers = {0: [], 1: []}
	_effects = []
	_spawn_side(0, a_count)
	_spawn_side(1, b_count)
	_retarget_all()
	queue_redraw()

# 대형: 위→아래 3행 [3,3,4]. 진영 끝에서 중앙 방향으로 열을 쌓는다.
const ROW_SPACE := 16.8   # 3행 사이 세로(상하) 간격 (24의 70%)

# 분리(separation): 원본 16px 충돌 박스(0xE87A)를 근사 — 겹치면 서로 밀어내 부피를 만든다.
const SEP_DIST := 11.0   # 이 거리보다 가까우면 밀어냄
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
			"death_t": 0.0,
			"airborne": false,
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
			if s["state"] == DYING or s["state"] == RETURN or s["state"] == IDLE:
				new_targets[s["id"]] = null  # 죽는 중/복귀 중/정렬 완료 병사는 교전 안 함
				continue
			var sp: Vector2 = s["pos"]
			var best: Variant = null
			var best_pri := 0
			var best_d := 1.0e9
			for f in foes:
				if f["state"] == DYING or f["state"] == RETURN or f["state"] == IDLE:
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

## 전투 종료: 이후 각 전투(MELEE/CHARGE) 병사는 진행 중이던 공방을 마치면 home으로 복귀(RETURN)한다.
## 전원이 "마지막에 한 번" 돌아가는 그림 — 전투 중 이탈은 없다(재교전으로 끝까지 싸운 뒤 복귀).
func begin_retreat() -> void:
	_retreating = true

## 전투 종료 후, 전투 병사가 진행 중 공방(strike_t)까지 마쳤으면 복귀 시작 가능.
func _retreat_ready(s: Dictionary) -> bool:
	return _retreating and (s["state"] == MELEE or s["state"] == CHARGE) and s["strike_t"] <= 0.0

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
	if tgt != null and tgt["state"] != DYING:
		toward = tgt["pos"]
		if toward.x != s["pos"].x:
			s["face"] = signf(toward.x - s["pos"].x)
	s["strike_t"] = STRIKE_DUR
	s["_lunge_to"] = toward
	# [임시 비활성] ③ 전방 슬래시 이펙트 [0x1860] — 재활성 시 아래 블록 주석 해제
	#var dir: float = s["face"]
	#_effects.append({"pos": s["pos"] + Vector2(dir * 6.0, -6.0), "vx": dir * 3.0 * 1.2 * 60.0,
	#	"life": 0.22, "side": s["side"]})
	var hit: Vector2 = (s["pos"] + toward) * 0.5
	_flashes.append({"pos": hit, "life": 0.1, "max": 0.1, "big": false})
	_shake = maxf(_shake, 0.8)

func kill(side: int) -> Variant:
	var s: Variant = _pick_engaged(side)
	if s == null:
		return null
	s["state"] = DYING
	s["death_t"] = 0.0
	# 위로+뒤로 포물선 넉백 점프 (원본 0x1976/0x19EA)
	s["airborne"] = true
	s["land_y"] = s["pos"].y
	var back: float = -float(s["face"])  # 적 반대 방향(뒤)
	s["dvx"] = back * _rng.randf_range(DEATH_VX.x, DEATH_VX.y)
	s["dvy"] = -_rng.randf_range(DEATH_VY.x, DEATH_VY.y)  # 위로 launch
	var pos: Vector2 = s["pos"]
	_flashes.append({"pos": pos, "life": 0.24, "max": 0.24, "big": true})
	_shake = maxf(_shake, 2.5)
	return pos

func force_result(a_final: int, b_final: int) -> void:
	_reduce_to(0, a_final)
	_reduce_to(1, b_final)
	queue_redraw()

func _reduce_to(side: int, final_n: int) -> void:
	var alive: Array = _soldiers[side].filter(func(s): return s["state"] != DYING)
	var dying: Array = _soldiers[side].filter(func(s): return s["state"] == DYING)
	while alive.size() > final_n:
		alive.pop_back()
	alive.append_array(dying)  # 죽는 중인 병사는 애니 끝날 때까지 유지
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
			# 접전(MELEE) 병사 자동 공방: 계속 주고받게(idle 방지). 전투 종료(_retreating) 후엔 새 공방 안 시작.
			if s["state"] == MELEE and not _retreating:
				s["strike_cd"] = s.get("strike_cd", 0.0) - delta
				if s["strike_cd"] <= 0.0:
					_auto_strike(s)
					s["strike_cd"] = STRIKE_INTERVAL + _rng.randf_range(0.0, STRIKE_JITTER)
			if s["state"] == DYING:
				if s["airborne"]:
					# 포물선 넉백: 중력 가속 + 등속 뒤로. 착지하면 눕기 단계로.
					s["dvy"] += DEATH_GRAV * delta
					var p: Vector2 = s["pos"]
					p.x += s["dvx"] * delta
					p.y += s["dvy"] * delta
					if p.y >= s["land_y"]:
						p.y = s["land_y"]
						s["airborne"] = false
						s["death_t"] = 0.0
					s["pos"] = p
				else:
					s["death_t"] += delta
					if s["death_t"] >= DEATH_LIE:
						continue  # 제거
			elif s["state"] == RETURN:
				_return_step(s, delta)  # 본인 진영으로 복귀
			elif _retreat_ready(s):
				# 전투 종료: 진행 중이던 공방(strike_t)을 마치면 그때 복귀 시작 → 마지막에 한 번, idle 없이.
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

	queue_redraw()

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
	# [임시 비활성] ① 찌르기 런지(적 방향으로 나갔다 복귀) — 재활성 시 아래 블록 주석 해제
	#if s["strike_t"] > 0.0 and s.has("_lunge_to"):
	#	var lunge_to: Vector2 = s["_lunge_to"]
	#	var p: float = 1.0 - s["strike_t"] / STRIKE_DUR
	#	base = base.lerp(lunge_to, 0.3 * sin(p * PI))
	# 사망 중엔 pos 를 직접 적분(넉백 점프)하므로 여기선 그대로 사용.
	return base

# ── 그리기 (사각형 픽셀 전용, 정수 좌표) ──────────────────────────────────
func _draw() -> void:
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(round(sin(_t * 60.0) * _shake), 0)

	_draw_terrain(sh)

	var all: Array = []
	all.append_array(_soldiers[0])
	all.append_array(_soldiers[1])
	all.sort_custom(func(a, b): return _draw_pos(a).y < _draw_pos(b).y)
	for s in all:
		_draw_soldier(_draw_pos(s) + sh, s)

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

func _draw_soldier(pos: Vector2, s: Dictionary) -> void:
	var side: int = s["side"]
	var a: float = s["alpha"]
	var face: float = s["face"]
	var dying: bool = s["state"] == DYING
	var base: Color = TEAM[side][0]
	var dark: Color = TEAM[side][1]
	var lite: Color = TEAM[side][2]
	base.a = a; dark.a = a; lite.a = a
	var steel := STEEL; steel.a = a
	var steel_hi := STEEL_HI; steel_hi.a = a
	var steel_dk := STEEL_DK; steel_dk.a = a
	var skin := SKIN; skin.a = a
	var boot := BOOT; boot.a = a
	var wood := WOOD; wood.a = a
	var outl := OUTLINE; outl.a = a

	var x: float = round(pos.x)
	var y: float = round(pos.y)

	# 착지 후: 시체 → 후반 절반 점멸 → 소멸 (원본 0x1B24). 공중(넉백 점프) 중이면 아래 일반 그리기.
	if dying and not s["airborne"]:
		var dt: float = s["death_t"]
		if dt >= DEATH_LIE * 0.5 and int(dt * 20.0) % 2 == 1:
			return  # 점멸 off 프레임
		var hx: float = (x + 5.0) if face > 0.0 else (x - 8.0)  # 머리는 바라보던 쪽
		_px(x - 7, y + 4, 14, 4, dark)
		_px(x - 7, y + 4, 14, 1, lite)
		_px(x - 7, y + 7, 14, 1, OUTLINE)
		_px(hx, y + 2, 4, 4, skin)
		_px(hx, y + 2, 4, 1, steel)
		return

	var reach := 0.0
	# [임시 비활성] ② 창 뻗기(공격 시 창끝 전방 연장) — 재활성 시 아래 블록 주석 해제
	#if s["strike_t"] > 0.0:
	#	reach = 3.0 * sin((1.0 - s["strike_t"] / STRIKE_DUR) * PI)

	_px(x - 5, y + 8, 10, 2, Color(0, 0, 0, 0.28 * a))
	_px(x - 3, y + 2, 2, 6, dark)
	_px(x + 1, y + 2, 2, 6, dark)
	_px(x - 3, y + 7, 3, 2, boot)
	_px(x + 1, y + 7, 3, 2, boot)
	_px(x - 5, y - 5, 10, 9, outl)
	_px(x - 4, y - 5, 8, 8, base)
	_px(x - 4, y - 5, 2, 8, lite)
	_px(x + 2, y - 5, 2, 8, dark)
	_px(x - 4, y - 1, 8, 1, dark)
	_px(x - 5, y - 5, 2, 2, steel)
	_px(x + 3, y - 5, 2, 2, steel_dk)
	_px(x - 4, y - 12, 8, 7, outl)
	_px(x - 3, y - 12, 6, 6, steel)
	_px(x - 3, y - 12, 6, 2, steel_hi)
	_px(x - 3, y - 10, 6, 1, steel_dk)
	_px(x - 2 + int(face), y - 8, 4, 3, skin)
	_px(x - 2 + int(face), y - 7, 1, 1, outl)
	_px(x - 1, y - 14, 2, 3, lite)
	_px(x + int(face) * 4, y - 3, 2, 5, base)
	_px(x + int(face) * 4, y - 3, 2, 1, lite)
	var sx: float = x + face * (6 + reach)
	_px(sx - 0.5, y - 13, 1, 18, wood)
	_px(sx - 0.5, y - 15, 1, 3, steel_hi)

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
