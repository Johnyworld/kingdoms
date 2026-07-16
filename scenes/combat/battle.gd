extends CanvasLayer
## 전투씬 오버레이(관전 전용). 월드맵 위를 어둡게 덮고 양 부대원 토큰이 실시간으로 교전한다.
## 판정은 CombatResolver, 최근접 적 선택·전멸 판정은 BattleField(순수)에 위임한다.
## 한 팀 전멸(또는 상한 시간) 시 finished(a_survivors, b_survivors)를 방출한다.
## UI는 코드로 구성한다(party_info 등과 같은 패턴, 별도 .tscn 없음).

signal finished(a_survivors: Array, b_survivors: Array)

const UNIT_SPEED := 520.0     # 토큰 이동 속도(px/s). 유닛별 ±SPEED_JITTER 랜덤 보정이 곱해진다.
const SPEED_JITTER := 0.2     # 이동속도 랜덤 보정 폭(±20%) — 전투 시작 시 유닛마다 1회 굴린다(공격속도는 미적용). → battle.md
const CHARGE_OFFSET := 80.0   # 근접 공격자 화면 밖 스폰: 전투 라인에서 화면 밖으로 밀어낼 x 여백(px). 라인 정지 없이 계속 돌격. → battle.md
const MELEE_REACH_PX := 46.0  # 근접거리(리치) 1당 공격 개시 거리(px). 리치 긴 무기가 더 멀리서 선제
const THROW_PX := 90.0        # 투척 사거리 1당 추가 거리(px)
const BATTLE_TIME := 10.0        # 근접 전투 지속 시간(초)
const RANGED_BATTLE_TIME := 5.0  # 원거리 전투 지속 시간(초). 2배속 재생(공격 간격 ×0.5)
const RANGED_SPEED := 2.0        # 원거리 모드 배속(공격 간격 나누는 값)
const CHARGE_RANGE_PX := 120.0   # 근접 모드: 이 거리 안에 적이 들면 궁수도 근접 전환·돌격
const MAX_THROWS := 3            # 투척 무기 최대 투척 횟수(이후 근접 전환)
const TOKEN_R := 30.0    # 토큰 반지름(px). 랑그릿사 비율에 맞춘 크기 — 분산 난투라 커도 뭉치지 않음. → battle.md
const PROJECTILE_TIME := 0.24    # 화살·투창이 대상까지 나는 시간(초). 기존의 1/2 속도
const SIEGE_PROJECTILE_TIME := 0.72  # [투석] 볼리 투사체 비행 시간(초). 화살의 1/3 속도(더 느림) → siege-engines.md
const SIEGE_COUNTER_GAP := 0.5   # [투석] 공격자 볼리 착탄 후 방어자 반격까지 간격(초)
const PROJECTILE_ARC := 40.0     # 투사체 포물선 최고 높이(px, 중간 지점 기준)
const END_DELAY := 0.6           # 종료 후 결과 방출까지 여유(날아가는 화살 없을 때)
const ARROW_LAND_DELAY := 1.0    # 종료 시 화살이 남아 있으면, 착탄 후 이만큼 더 기다렸다 종료

# 랑그릿사1(MD)식 연출 — 액자·HUD·템포. 판정·생존 결과에 영향 없음. → battle.md
const MELEE_PLAYBACK := 2.0      # 근접 전투 재생 배속(sim delta×2 → 10초 sim을 실시간 ~5초로). 균일 스케일이라 결과 불변
const ARENA_FRACTION := 0.62     # 상단 전장(arena) 높이 비율. 나머지(하단)는 지휘관 HUD
const GROUND_FRACTION := 0.5     # arena 내 하늘/지면 경계 비율(이 아래가 지면). 유닛은 지면에만 배치. → battle.md
const FORMATION_PER_ROW := 3     # 원거리 대열 한 행 인원(궁수 자리잡기). → battle.md
const FORMATION_ARRIVE_PX := 6.0 # 대열 슬롯 도착 판정 거리(px). 도착하면 스냅·정지·사격.
const ENTRY_STAGGER_PX := 170.0  # 화면 밖 진입 시 index마다 벌리는 x 간격(px). 크게 벌려 한 명씩 트리클 진입. → battle.md
const MODIFIER_CYCLE := 1.0      # 중앙 보정 박스 항목 순환 주기(초)
const CORPSE_TILT := 1.3         # 사망 시체가 눕는 회전(라디안) — MD1식 바닥 시체 느낌
# 이펙트 z-index — 토큰 z는 int(pos.y)(≤ arena 높이)라, 투사체·데미지 숫자는 그보다 훨씬 위에 둬 유닛에 안 가리게. → battle.md
const Z_PROJECTILE := 3000
const Z_FLOAT := 4000

# 타격 연출(초안 수치) — 판정·생존 결과에 영향 없음. 상세는 combat-feedback.md.
const FLOAT_RISE := 40.0      # 떠오르는 텍스트 상승 높이(px)
const FLOAT_TIME := 0.7       # 떠오름·페이드 시간(초)
const FLASH_TIME := 0.12      # 피격 흰 반짝임 시간(초)
const HIT_PUSH_PX := 10.0     # 근접 타격 시 피격자가 밀리고 공격자가 같이 전진하는 거리(px). 되돌아오지 않는 실제 위치 이동(달라붙기). → battle.md
const LUNGE_PX := 10.0        # 공격 돌진 거리(px)
const LUNGE_TIME := 0.12      # 공격 돌진 왕복 시간(초)
const KNOCKBACK_PX := 60.0    # 사망 시 뒤로 날아가는 거리(px)
const KNOCKBACK_UP := 30.0    # 사망 넉백 아치 높이(px) — 껑충 뛰듯이
const KNOCKBACK_TIME := 0.35  # 사망 넉백 시간(초)
const DEATH_ALPHA := 0.5      # 사망 후 투명도

var _units: Array = []
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _running := false
var _ranged_mode := false   # distance >= 2에서 참(원거리 교전). 사거리 < _distance 유닛은 정지(공격 불가)
var _distance := 1          # 교전 헥스 거리. 원거리 교전에서 사거리 게이트(range < _distance면 정지) → docs/spec/features/battle.md
var _battle_time := BATTLE_TIME   # 이번 전투 지속 시간(근접 10초 / 원거리 5초)
var _live_projectiles := 0        # 날아가는 중인 투사체 수(종료 시 착탄 대기 판정)
var _siege_battle := false        # [투석] 통합 전투(include_siege) — 순차 연출로 진행(_process·타이머 미사용). → siege-engines.md
var _view: Control
var _playback := 1.0              # 재생 배속(근접=MELEE_PLAYBACK, 원거리=1.0). _process가 delta에 곱해 sim을 진행. → battle.md
var _arena_h := 0.0               # 상단 전장 높이(px). 토큰은 이 높이 안에서만 스폰·이동, 아래는 HUD. → battle.md
var _hud := {}                    # 하단 지휘관 HUD 참조 — {a:{party,total,count_label,bar_fill,bar_w}, b:{...}, mod_name, mod_text}
var _mod_index := 0               # 중앙 보정 박스 현재 순환 인덱스
var _mod_timer := 0.0             # 보정 박스 순환 누적 시간(초)

## 공격측(a)·방어측(b) 부대를 받아 전투를 시작한다. distance = 교전 헥스 거리(1=근접).
## distance >= 2면 원거리 교전 — 사거리 ≥ distance인 유닛만 행동. → docs/spec/features/battle.md
## include_siege면 양 부대의 공성 유닛(투석기)을 전투원으로 스폰([투석] 전투). wall(성벽 거점)이 있으면 성벽을
## 구조물 전투원으로 방어 팀에 스폰(성벽 투석 — defender는 null 허용, 성벽만 방어).
## target_gate면 구조물 HP를 성벽(wall_hp)이 아니라 성문(gate_hp)으로 삼는다(충차 성문 파쇄). → siege-engines.md · wall.md 성문
func start(attacker, defender, distance := 1, include_siege := false, wall = null, target_gate := false) -> void:
	_distance = distance
	_ranged_mode = distance >= 2
	_siege_battle = include_siege
	_battle_time = RANGED_BATTLE_TIME if _ranged_mode else BATTLE_TIME
	_playback = 1.0 if _ranged_mode else MELEE_PLAYBACK   # 근접만 2배속 재생(원거리는 기존 5초 방식). → battle.md
	layer = 60
	_rng.randomize()
	var vp := get_viewport().get_visible_rect().size
	_arena_h = vp.y * ARENA_FRACTION   # 상단 전장 높이 — 토큰은 이 안에만, 아래는 HUD
	_build_bg(vp)
	_spawn_team(attacker, "a", vp.x * 0.25, vp)
	if defender != null:
		_spawn_team(defender, "b", vp.x * 0.75, vp)
	_assign_duels()   # 각 병사에 상대 짝 배정 — 전장에 퍼져 1:1 난투(뭉침 방지). → battle.md
	if include_siege:
		_spawn_siege(attacker, "a", vp.x * 0.1, vp)
		if defender != null:
			_spawn_siege(defender, "b", vp.x * 0.9, vp)
	if wall != null:
		_spawn_structure(wall, "b", vp, target_gate)
	_build_hud(attacker, defender, vp)   # 하단 지휘관 HUD 3분할. → battle.md
	_running = true
	if _siege_battle:
		_run_siege_sequence()   # [투석] 통합 전투 — 공격자 선공 → 방어자 반격 → 종료(_process 미사용) → siege-engines.md

## 성벽(또는 성문)을 구조물 전투원으로 방어 팀(b)에 스폰한다. 이동·공격·상태이상 없이 투석 flat 피해만 받는다.
## gate면 HP를 gate_hp로 삼고 종료 시 gate_hp에 되쓴다(_finish). → siege-engines.md · wall.md 성문
func _spawn_structure(building, team: String, vp: Vector2, gate := false) -> void:
	var pos := Vector2(vp.x * 0.75, _arena_h * 0.78)
	var node := _make_token(Color(0.62, 0.62, 0.68))   # 성벽·성문 회색
	(node.get_node("hp") as Label).text = "성문" if gate else "성벽"
	_view.add_child(node)
	var shp: int = int(building.gate_hp if gate else building.wall_hp)
	var su := {
		"structure": true, "gate": gate, "team": team, "alive": true, "pos": pos,
		"node": node, "hp_label": node.get_node("hp"), "hp_fill": node.get_node("hpfill"), "body": node.get_node("body"), "color": Color(0.62, 0.62, 0.68),
		"hp": shp, "max_hp": shp, "building": building, "effects": {},
	}
	_units.append(su)
	su["node"].position = pos - Vector2(TOKEN_R, TOKEN_R)
	su["node"].z_index = int(pos.y)

## 부대의 공성 유닛(투석기)을 전투원으로 스폰한다(팀 열 바깥쪽·위). 이동·근접 없이 전투당 1발만 쏜다. → siege-engines.md
func _spawn_siege(party, team: String, x: float, vp: Vector2) -> void:
	if not party.has_siege():
		return
	var units: Array = party.siege_units
	var n := units.size()
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var pos := Vector2(x, lerpf(_arena_h * (GROUND_FRACTION + 0.06), _arena_h * 0.72, t))
		var node := _make_token(party.token_color)
		(node.get_node("hp") as Label).text = units[i].unit_name()   # 초기 라벨은 이름(피격 시 _catapult_volley가 남은 hp로 덮어씀)
		_view.add_child(node)
		var su := {
			"siege": true, "team": team, "alive": true, "pos": pos,
			"node": node, "hp_label": node.get_node("hp"), "hp_fill": node.get_node("hpfill"), "body": node.get_node("body"), "color": party.token_color,
			"min_range": units[i].min_range(), "range": units[i].fire_range(), "attack": units[i].attack(),
			"hp": int(units[i].hit_points), "max_hp": int(units[i].hit_points), "unit": units[i],   # 피격 가능(5d-3a) — 파괴 시 unit에 반영
			"effects": {},
		}
		_units.append(su)
		su["node"].position = pos - Vector2(TOKEN_R, TOKEN_R)

## [투석] 통합 전투 순차 연출 — 공격자(a) 선공 → 착탄 → 짧은 간격 뒤 방어자(b) 반격 → 마지막 착탄 +1초 후 종료.
## 밴드 안 공성 유닛·구조물만 참여(사람은 사거리 게이트로 정지). → siege-engines.md · battle.md 투석 순차 연출
func _run_siege_sequence() -> void:
	var attacker_fired := _fire_siege_side("a")   # 공격자 선공(일제 발사)
	await _await_projectiles()                    # 착탄 = 타격 판정(피해 적용)
	# 방어자 반격 — 공격자 볼리에 살아남은 밴드 공성 유닛만(전멸 시 반격 없음, 선제 이점).
	if attacker_fired and not BattleField.firing_siege(_units, "b", _distance).is_empty():
		await get_tree().create_timer(SIEGE_COUNTER_GAP).timeout
		_fire_siege_side("b")
		await _await_projectiles()
	await get_tree().create_timer(ARROW_LAND_DELAY).timeout   # 마지막 착탄 후 1초
	_finish_siege()

## 한 진영(team)의 밴드 안 살아있는 공성 유닛을 일제 발사한다(각 진영 1회 호출). 하나라도 쐈으면 true.
func _fire_siege_side(team: String) -> bool:
	var fired := false
	for u in BattleField.firing_siege(_units, team, _distance):
		_catapult_volley(u)
		fired = true
	return fired

## 날아가는 투사체가 모두 착탄할 때까지 대기(착탄 콜백이 피해를 적용).
func _await_projectiles() -> void:
	while _live_projectiles > 0:
		await get_tree().process_frame

## 투석 1발 = 가장 가까운 적 최대 MAX_BOMBARD_TARGETS 표적에 개별 판정 — 성벽 구조물은 항상 명중, 유닛은 CATAPULT_HIT_CHANCE(0.1).
## 명중·피해는 발사 시 굴려 두고, 실제 hp 차감·연출은 투사체 착탄 시점에 적용한다. → siege-engines.md
func _catapult_volley(u: Dictionary) -> void:
	var targets := BattleField.bombard_targets(u, _units, Siege.MAX_BOMBARD_TARGETS)
	for t in targets:
		# 성벽 구조물은 거대·부동이라 항상 명중, 유닛은 명중률 판정. → siege-engines.md
		var hit: bool = t.get("structure", false) or Siege.hit_succeeds(_rng.randf(), Siege.CATAPULT_HIT_CHANCE)
		var dmg: int = Siege.rolled_damage(u["attack"], _rng.randf()) if hit else 0   # flat(방어구·회피·상성 무시)
		_spawn_projectile(u["pos"], t["pos"], SIEGE_PROJECTILE_TIME, _on_siege_hit.bind(t, dmg, hit, u["pos"]))

## 투석 투사체 착탄 — 피해·연출을 이 시점에 적용(발사 후 대상이 이미 죽었으면 무시).
func _on_siege_hit(t: Dictionary, dmg: int, hit: bool, from_pos: Vector2) -> void:
	if not t["alive"]:
		return
	if not hit:
		_spawn_float(t["pos"], "빗나감", Color(0.7, 0.7, 0.7), false)
		return
	t["hp"] -= dmg
	t["hp_label"].text = str(maxi(0, t["hp"]))
	_refresh_hp_bar(t)
	_spawn_float(t["pos"], str(dmg), Color(1.0, 0.5, 0.3), true)
	_flash(t)
	if t["hp"] <= 0:
		if t.get("structure", false):
			_kill(t)   # 성벽·성문은 제자리 붕괴(넉백 없이 페이드)
		else:
			_kill(t, from_pos)

## 전장 배경 — 검은 dim 대신 하늘/지면 밴드(플레이스홀더). 클릭 흡수는 유지(관전). 지형 아트는 미구현. → battle.md
func _build_bg(vp: Vector2) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # 아래 월드맵 클릭을 흡수(관전)
	add_child(root)
	# 하늘(전장 상단)
	var horizon := _arena_h * GROUND_FRACTION
	var sky := ColorRect.new()
	sky.color = Color(0.36, 0.55, 0.78)
	sky.position = Vector2.ZERO
	sky.size = Vector2(vp.x, horizon)
	root.add_child(sky)
	# 지면(전장 하단) — 유닛은 이 밴드 안에만 배치
	var ground := ColorRect.new()
	ground.color = Color(0.38, 0.5, 0.28)
	ground.position = Vector2(0, horizon)
	ground.size = Vector2(vp.x, _arena_h - horizon)
	root.add_child(ground)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

## 한 팀 멤버를 세로 열로 스폰한다 — 멤버마다 개별 토큰 1개(랑그릿사식 10:10 렌더). → battle.md
func _spawn_team(party, team: String, x: float, vp: Vector2) -> void:
	var members: Array = party.members
	var n := members.size()
	# 근접 공격자 화면 밖 스폰 x — 팀 a는 왼쪽 밖, b는 오른쪽 밖. 라인 x(0.25/0.75 열)는 인자로 받은 x.
	var side := -1.0 if team == "a" else 1.0
	var charge_x := -CHARGE_OFFSET if team == "a" else vp.x + CHARGE_OFFSET
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		# 지면 밴드 안에서 세로 산포 + 소량 지터 — 하늘에 뜨지 않고 지상에서 난투. → battle.md
		var g_top := _arena_h * (GROUND_FRACTION + 0.05)
		var g_bot := _arena_h - TOKEN_R * 1.5
		var y := clampf(lerpf(g_top, g_bot, t) + _rng.randf_range(-_arena_h * 0.03, _arena_h * 0.03), g_top, g_bot)
		# 이 전투에서 쓸 무기(근접=주무기, 원거리=활). range는 그 무기의 공격거리.
		var w: String = ItemTypes.active_weapon(members[i].weapons, _ranged_mode)
		var rng_w := ItemTypes.weapon_range(w)
		var holds := rng_w >= 2                          # 궁수·완드 — 화면 밖 진입 → 대열 자리잡기 → 사격. → battle.md
		var charges := rng_w < 2 and not _ranged_mode    # 근접 유닛 — 화면 밖에서 중앙으로 돌격
		# 돌격·궁수 모두 화면 밖에서 index마다 x를 크게 벌려 스폰(한 명씩 트리클 진입 — 한꺼번에 안 몰림). 원거리 교전의 근접 유닛(대기)만 라인 x에 소량 지터.
		var offscreen := charges or holds
		var pos := Vector2(charge_x + side * i * ENTRY_STAGGER_PX, y) if offscreen else Vector2(x + _rng.randf_range(-vp.x * 0.03, vp.x * 0.03), y)
		var thrw: String = ItemTypes.throwing_weapon(members[i].weapons)
		var melee_reach: float = ItemTypes.weapon_reach(w) * MELEE_REACH_PX
		var node := _make_token(party.token_color)
		(node.get_node("hp") as Label).text = str(int(members[i].hit_points))
		_view.add_child(node)
		var unit := {
			"human": members[i], "team": team, "hp": int(members[i].hit_points),
			"max_hp": int(members[i].max_hp()), "alive": true, "pos": pos, "cooldown": 0.0,
			"speed": UNIT_SPEED * _rng.randf_range(1.0 - SPEED_JITTER, 1.0 + SPEED_JITTER),   # 이동속도 ±20% 랜덤 보정. → battle.md
			"node": node, "body": node.get_node("body"), "hp_label": node.get_node("hp"),
			"hp_fill": node.get_node("hpfill"), "color": party.token_color,
			"weapon": w, "range": ItemTypes.weapon_range(w),
			"melee_reach": melee_reach,
			"throw": thrw, "throws": 0,
			"throw_reach": melee_reach + ItemTypes.weapon_throw_range(thrw) * THROW_PX,
			"engage_off": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * melee_reach * 0.5,   # 대상 주변 개인 교전 지점(겹쳐 쌓임 방지). 리치×0.5라 항상 리치 안 → 접근해도 공격 못 하고 멈추는 stall 방지. → battle.md
			"formation": _formation_slot(team, i, vp) if holds else null,   # 궁수 자리잡을 대열 슬롯(없으면 null). → battle.md
			"formed": not holds,   # 궁수는 슬롯 도착 전까지 false(사격 안 함), 그 외는 대열 단계 없음
			"effects": {},
		}
		_units.append(unit)
		node.position = pos - Vector2(TOKEN_R, TOKEN_R)
		node.z_index = int(pos.y)

## 토큰 = 몸통(ColorRect) + 위에 현재 생명점 라벨 + 아래 HP 바(배경 + 초록 채움). 멤버·공성·구조물 공용.
func _make_token(color: Color) -> Control:
	var w := TOKEN_R * 2.0
	var c := Control.new()
	var body := ColorRect.new()
	body.name = "body"
	body.color = color
	body.size = Vector2(w, w)
	c.add_child(body)
	var lbl := Label.new()
	lbl.name = "hp"
	lbl.position = Vector2(0, -20)
	c.add_child(lbl)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.size = Vector2(w, 4)
	bg.position = Vector2(0, w + 2)
	c.add_child(bg)
	var fill := ColorRect.new()
	fill.name = "hpfill"
	fill.color = Color(0.35, 0.8, 0.35)
	fill.size = Vector2(w, 4)   # 초기 만땅(스폰 시 full hp)
	fill.position = Vector2(0, w + 2)
	c.add_child(fill)
	return c

## HP 바 채움을 현재 hp ÷ max_hp 비율로 갱신(hp_fill 없는 유닛은 무시).
func _refresh_hp_bar(u: Dictionary) -> void:
	if not u.has("hp_fill"):
		return
	var frac := 0.0
	if int(u.get("max_hp", 0)) > 0:
		frac = clampf(float(u["hp"]) / float(u["max_hp"]), 0.0, 1.0)
	(u["hp_fill"] as ColorRect).size.x = TOKEN_R * 2.0 * frac

## 살아있는 멤버 토큰을 시뮬 상태에 맞춰 갱신 — 위치(pos)·hp 숫자·HP 바·상태이상 tint(기절 회색·출혈 빨강).
func _sync_node(u: Dictionary) -> void:
	# 지면 밴드 하한으로 y를 가둔다 — 토큰·HP 바가 하단 HUD를 침범하지 않게. → battle.md
	u["pos"].y = clampf(u["pos"].y, _arena_h * (GROUND_FRACTION + 0.05), _arena_h - TOKEN_R * 1.5)
	u["node"].position = u["pos"] - Vector2(TOKEN_R, TOKEN_R)
	u["node"].z_index = int(u["pos"].y)   # y가 아래일수록 앞에 그림(2.5D 깊이 정렬). → battle.md
	u["hp_label"].text = str(maxi(0, u["hp"]))
	_refresh_hp_bar(u)
	if StatusEffects.is_stunned(u["effects"]):
		u["node"].modulate = Color(0.6, 0.6, 0.6, 1.0)
	elif u["effects"].has("bleed"):
		u["node"].modulate = Color(1.0, 0.5, 0.5, 1.0)
	else:
		u["node"].modulate = Color(1.0, 1.0, 1.0, 1.0)

## 하단 지휘관 HUD(3분할) 생성 — [좌 지휘관][중앙 보정][우 지휘관]. arena 아래 영역을 차지. → battle.md
func _build_hud(attacker, defender, vp: Vector2) -> void:
	var hud_y := _arena_h
	var hud_h := vp.y - _arena_h
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)   # _view 뒤에 추가 → 전장 위에 얹힘
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.22)
	bg.position = Vector2(0, hud_y)
	bg.size = Vector2(vp.x, hud_h)
	root.add_child(bg)
	var wp := vp.x * 0.32   # 좌/우 지휘관 패널 폭
	var wc := vp.x - wp * 2.0   # 중앙 보정 박스 폭
	_hud = {}
	_hud["a"] = _make_panel("a", attacker, 0.0, wp, hud_y, hud_h, root)
	_hud["b"] = _make_panel("b", defender, wp + wc, wp, hud_y, hud_h, root)
	# 중앙 보정 박스
	var cbg := ColorRect.new()
	cbg.color = Color(0.10, 0.13, 0.38)
	cbg.position = Vector2(wp + 6, hud_y + 8)
	cbg.size = Vector2(wc - 12, hud_h - 16)
	root.add_child(cbg)
	var mod_name := Label.new()
	mod_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mod_name.position = Vector2(wp + 6, hud_y + 14)
	mod_name.size = Vector2(wc - 12, 24)
	mod_name.add_theme_font_size_override("font_size", 18)
	root.add_child(mod_name)
	var mod_text := Label.new()
	mod_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mod_text.position = Vector2(wp + 6, hud_y + 44)
	mod_text.size = Vector2(wc - 12, hud_h - 52)
	root.add_child(mod_text)
	var vs := Label.new()
	vs.text = "VS"
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.position = Vector2(wp + 6, hud_y + hud_h - 30)
	vs.size = Vector2(wc - 12, 24)
	root.add_child(vs)
	_hud["mod_name"] = mod_name
	_hud["mod_text"] = mod_text
	_mod_index = 0
	_mod_timer = 0.0
	_refresh_modifier_box()
	_update_hud()

## 한쪽 지휘관 패널 — 초상화 자리(팀색)·부대명·LV·AT/DF·큰 병력 수·병력 바. {party,total,count_label,bar_fill,bar_w} 반환.
func _make_panel(team: String, party, x: float, w: float, hud_y: float, hud_h: float, parent: Control) -> Dictionary:
	var pad := 8.0
	var col: Color = party.token_color if party != null else Color(0.5, 0.5, 0.5)
	var pbg := ColorRect.new()
	pbg.color = Color(0.10, 0.13, 0.38)
	pbg.position = Vector2(x + pad, hud_y + pad)
	pbg.size = Vector2(w - pad * 2.0, hud_h - pad * 2.0)
	parent.add_child(pbg)
	# 병력 바(패널 상단)
	var bar_w := w - pad * 2.0 - 16.0
	var barbg := ColorRect.new()
	barbg.color = Color(0, 0, 0, 0.6)
	barbg.position = Vector2(x + pad + 8, hud_y + pad + 6)
	barbg.size = Vector2(bar_w, 10)
	parent.add_child(barbg)
	var barfill := ColorRect.new()
	barfill.color = col
	barfill.position = barbg.position
	barfill.size = Vector2(bar_w, 10)
	parent.add_child(barfill)
	# 초상화 자리(팀색 사각 플레이스홀더) — 좌팀은 왼쪽, 우팀은 오른쪽
	var port_sz := minf(hud_h - pad * 2.0 - 30.0, 72.0)
	var port_x := (x + pad + 8) if team == "a" else (x + w - pad - 8 - port_sz)
	var port := ColorRect.new()
	port.color = col
	port.position = Vector2(port_x, hud_y + pad + 24)
	port.size = Vector2(port_sz, port_sz)
	parent.add_child(port)
	# 부대명·LV·AT/DF
	var info := Label.new()
	info.position = Vector2((port_x + port_sz + 8) if team == "a" else (x + pad + 8), hud_y + pad + 24)
	if party != null and party.commander != null:
		var c = party.commander
		info.text = "%s\nLV %d\nAT %d  DF %d" % [party.party_name, int(c.level), CombatResolver.attack_power(c), CombatResolver.defense(c)]
	parent.add_child(info)
	# 큰 병력 수 숫자
	var cnt := Label.new()
	cnt.add_theme_font_size_override("font_size", 44)
	cnt.position = Vector2((x + w - pad - 44) if team == "a" else (x + pad + 8), hud_y + hud_h - 60)
	parent.add_child(cnt)
	var total: int = party.members.size() if party != null else 0
	return {"party": party, "total": total, "count_label": cnt, "bar_fill": barfill, "bar_w": bar_w}

## HUD 병력 수·바를 현재 생존 멤버 수로 갱신(매 프레임).
func _update_hud() -> void:
	if _hud.is_empty():
		return
	for team in ["a", "b"]:
		var h = _hud.get(team, null)
		if h == null:
			continue
		var n := _hud_count(team)
		(h["count_label"] as Label).text = str(n)
		var frac := 0.0
		if int(h["total"]) > 0:
			frac = float(n) / float(h["total"])
		(h["bar_fill"] as ColorRect).size.x = float(h["bar_w"]) * frac

## 그 팀의 살아있는 멤버(사람) 수 — HUD 병력 수·바의 출처.
func _hud_count(team: String) -> int:
	var n := 0
	for u in _units:
		if u.get("human") != null and u["team"] == team and u["alive"]:
			n += 1
	return n

## 그 팀 지휘관(없으면 null).
func _commander(team: String):
	var h = _hud.get(team, null)
	if h == null or h["party"] == null:
		return null
	return h["party"].commander

## 패널 표시용 지휘관 실효 AT/DF(버프 반영). CombatResolver는 읽기만 함.
func _panel_at(team: String) -> int:
	var c = _commander(team)
	return CombatResolver.attack_power(c) if c != null else 0

func _panel_df(team: String) -> int:
	var c = _commander(team)
	return CombatResolver.defense(c) if c != null else 0

## 버프 제외 기본 AT/DF(표시용). CombatResolver 공식의 버프 이전 값을 재현한다(읽기 전용).
func _base_at(h) -> int:
	return ItemTypes.weapon_attack(ItemTypes.primary_weapon(h.weapons)) + int(h.strength) / 5

func _base_df(h) -> int:
	return ItemTypes.total_defense(h.armor) + ItemTypes.shield_defense(h.shield)

## 중앙 보정 박스 순환 항목 — 항상 "기본능력", 어느 한쪽이라도 지휘 버프면 "지휘보정" 추가. 레벨/지형은 미구현이라 생략. → battle.md
func _modifier_labels() -> Array:
	var labels := ["기본능력"]
	for team in ["a", "b"]:
		var c = _commander(team)
		if c != null and c.in_command:
			labels.append("지휘보정")
			break
	return labels

## 보정 박스 순환 타이머 진행(주기마다 다음 항목).
func _cycle_modifier(d: float) -> void:
	if _hud.is_empty():
		return
	_mod_timer += d
	if _mod_timer >= MODIFIER_CYCLE:
		_mod_timer = 0.0
		_mod_index += 1
		_refresh_modifier_box()

## 현재 인덱스의 보정 항목 이름·수치를 박스에 그린다.
func _refresh_modifier_box() -> void:
	if _hud.is_empty():
		return
	var labels := _modifier_labels()
	_mod_index = _mod_index % labels.size()
	var label: String = labels[_mod_index]
	(_hud["mod_name"] as Label).text = label
	(_hud["mod_text"] as Label).text = _modifier_text(label)

## 보정 항목별 수치 텍스트 — 기본능력=양측 기본 AT/DF, 지휘보정=양측 실효−기본 델타.
func _modifier_text(label: String) -> String:
	var ca = _commander("a")
	var cb = _commander("b")
	if ca == null or cb == null:
		return ""
	if label == "지휘보정":
		return "AT +%d / +%d\nDF +%d / +%d" % [
			_panel_at("a") - _base_at(ca), _panel_at("b") - _base_at(cb),
			_panel_df("a") - _base_df(ca), _panel_df("b") - _base_df(cb)]
	return "AT %d vs %d\nDF %d vs %d" % [_base_at(ca), _base_at(cb), _base_df(ca), _base_df(cb)]

## 양 팀 멤버를 y 순서로 짝지어 duel(상대 짝)을 배정한다 — 각자 자기 짝을 향해 흩어져 돌격 → 전장 전체에 난투 분산.
## 인원이 다르면 순환(mod)으로 나눠 붙인다. 짝이 죽으면 최근접 적으로 폴백(_target_for). → battle.md
func _assign_duels() -> void:
	var a_units: Array = []
	var b_units: Array = []
	for u in _units:
		if u.get("human") == null:
			continue
		if u["team"] == "a":
			a_units.append(u)
		else:
			b_units.append(u)
	if a_units.is_empty() or b_units.is_empty():
		return
	var by_y := func(x, y): return x["pos"].y < y["pos"].y
	a_units.sort_custom(by_y)
	b_units.sort_custom(by_y)
	for i in a_units.size():
		a_units[i]["duel"] = b_units[i % b_units.size()]
	for i in b_units.size():
		b_units[i]["duel"] = a_units[i % a_units.size()]

## 이번 프레임 이 유닛의 대상 — 배정된 짝(duel)이 살아있으면 그 짝, 아니면 최근접 적으로 폴백.
func _target_for(u: Dictionary) -> Dictionary:
	var duel = u.get("duel", null)
	if duel != null and duel["alive"]:
		return duel
	return BattleField.nearest_enemy(u, _units)

## 원거리 유닛 index i의 대열 슬롯 — 행마다 안쪽으로 들여쓴 계단식. 우측 부대(b) 기준, 좌측(a)은 좌우 반전. → battle.md
func _formation_slot(team: String, i: int, vp: Vector2) -> Vector2:
	var row := i / FORMATION_PER_ROW
	var col := i % FORMATION_PER_ROW
	var col_gap := TOKEN_R * 4.8   # 행 내 x 간격 — 넓게 벌려 난투 느낌(기존 2.4의 2배). → battle.md
	var row_gap := TOKEN_R * 2.4
	var indent := TOKEN_R * 2.8    # 행마다 x 들여쓰기(2배)
	var x_local := float(row) * indent + float(col) * col_gap
	var top := _arena_h * (GROUND_FRACTION + 0.06)
	# 슬롯 y를 지면 밴드 하한(_sync_node 클램프와 동일) 안으로 가둔다 — 깊은 행이 밴드 밑으로 내려가 진동·미형성되는 것 방지.
	var yy := minf(top + float(row) * row_gap, _arena_h - TOKEN_R * 1.5)
	if team == "b":
		return Vector2(vp.x * 0.73 + x_local, yy)   # 우측 부대 — 자기 진영 뒤쪽에서 오른쪽으로 계단
	return Vector2(vp.x * 0.27 - x_local, yy)       # 좌측 부대 — 좌우 반전(자기 진영 뒤쪽)

func _process(delta: float) -> void:
	if not _running or _siege_battle:
		return   # [투석] 통합 전투는 _run_siege_sequence가 구동(프레임 시뮬·타이머 미사용)
	var d := delta * _playback   # 재생 배속 적용(근접 2배속). 균일 스케일이라 공격·RNG 순서 불변 → 결과 동일. → battle.md
	_cycle_modifier(d)           # 중앙 보정 박스 순환
	_elapsed += d
	if _elapsed >= _battle_time:
		_finish()   # 전투 시간(근접 10초 / 원거리 5초, sim 기준) 종료
		return

	# 상태이상 진행(모든 생존 유닛): 출혈 도트를 hp에서 빼고, 죽으면 전투불능 처리.
	for u in _units:
		if not u["alive"] or u.get("siege", false) or u.get("structure", false):
			continue   # 공성 전투원·성벽 구조물은 상태이상 진행 없음. → siege-engines.md
		var dot := StatusEffects.advance(u["effects"], d)
		if dot > 0:
			u["hp"] -= dot
			_spawn_float(u["pos"], str(dot), HitFeedback.BLEED_COLOR, false)   # 출혈 도트(멤버 위치)
			if u["hp"] <= 0:
				_kill(u)   # 도트 사망: 넉백 없이 페이드(공격자 방향 없음)

	for u in _units:
		if not u["alive"]:
			continue
		if u.get("structure", false) or u.get("siege", false):
			continue   # 성벽 구조물·공성 전투원 — 비투석 전투엔 없고, 투석 전투는 위에서 조기 반환
		if _ranged_mode and u["range"] < _distance:
			continue   # 원거리 교전: 사거리가 거리에 못 미치는 유닛(근접 무기 포함)은 닿지 않아 정지
		if StatusEffects.is_stunned(u["effects"]):
			continue   # 기절: 이번 프레임 이동·공격 안 함
		u["cooldown"] = maxf(0.0, u["cooldown"] - d)
		var t: Dictionary = _target_for(u)   # 배정된 짝(살아있으면) → 없으면 최근접 적
		if t.is_empty():
			continue
		var dist: float = u["pos"].distance_to(t["pos"])
		if u["range"] >= 2:
			if u.get("formation") != null and not u["formed"]:
				# 대열 진입 — 슬롯으로 이동, 도착 전엔 사격 안 함. 도착하면 스냅·정지 후 다음 프레임부터 사격. → battle.md
				var slot: Vector2 = u["formation"]
				var to_slot: Vector2 = slot - u["pos"]
				# 근접 돌격과 동일한 화면 속도 — raw delta에 MELEE_PLAYBACK을 곱해 재생 배속(원거리 1.0)을 상쇄. → battle.md
				var step: float = u["speed"] * MELEE_PLAYBACK * delta
				# 한 스텝 안(또는 도착 거리 안)에 들면 슬롯에 스냅 — 스텝이 커도 오버슈트로 진동하지 않게.
				if to_slot.length() <= maxf(step, FORMATION_ARRIVE_PX):
					u["pos"] = slot
					u["formed"] = true
				else:
					u["pos"] += to_slot.normalized() * step
			# 근접 모드: 적이 임계거리 안에 들면 근접 전환(다음 프레임부터 돌격). 활만 있으면 활 든 채.
			elif not _ranged_mode and BattleField.archer_should_charge(u["range"], dist, CHARGE_RANGE_PX):
				_engage_melee(u)
			elif u["cooldown"] <= 0.0:
				# 원거리(활·완드): 자리잡은 뒤 제자리에서 공격속도마다 사격.
				_attack(u, t, u["weapon"])
		else:
			# 근접/투척: 접근하며 투척 사거리에서 투척(최대 MAX_THROWS), 근접거리에서 근접 공격.
			if u["throw"] != "" and u["throws"] < MAX_THROWS and dist > u["melee_reach"] and dist <= u["throw_reach"]:
				if u["cooldown"] <= 0.0:
					_attack(u, t, u["throw"])
					u["throws"] += 1
			if dist <= u["melee_reach"]:
				if u["cooldown"] <= 0.0:
					_attack(u, t, u["weapon"])
			else:
				# 대상 자체가 아니라 대상 주변 개인 교전 지점으로 접근 → 한 점에 겹쳐 쌓이지 않고 둘러싼다.
				var dest: Vector2 = t["pos"] + u.get("engage_off", Vector2.ZERO)
				u["pos"] += (dest - u["pos"]).normalized() * u["speed"] * d

	# 살아있는 각 멤버 토큰을 프레임 끝에 갱신(위치·hp·바·tint). 죽은 유닛은 _kill이 페이드/넉백 처리.
	for u in _units:
		if u.get("human") != null and u.has("node") and u["alive"]:
			_sync_node(u)

	_update_hud()   # 하단 지휘관 HUD 병력 수·바 실시간 갱신. → battle.md

	# 한 팀 전멸 시 즉시 종료(시간 만료는 위에서 처리).
	if BattleField.team_wiped(_units, "a") or BattleField.team_wiped(_units, "b"):
		_finish()

## 1회 공격(일방). weapon으로 resolve_hit, 피해 적용, 쿨다운을 그 무기의 공격 간격으로 리셋.
## 원거리·투척 무기면 투사체를 날린다.
func _attack(u: Dictionary, t: Dictionary, weapon: String) -> void:
	var r := CombatResolver.resolve_hit(u["human"], t["human"], t["hp"], _rng, weapon)
	t["hp"] = r["hp"]
	if r["inflict"] != "":
		StatusEffects.apply(t["effects"], r["inflict"])   # 치명타 → 출혈/기절 부여
	# 원거리 모드는 2배속(공격 간격 ×0.5) — 5초 전투로 같은 발사 수.
	var speed := RANGED_SPEED if _ranged_mode else 1.0
	u["cooldown"] = CombatResolver.attack_interval(u["human"], weapon) / speed
	# --- 타격 연출(combat-feedback.md) — 공격자·표적 모두 개별 멤버(사람). ---
	# 근접 공격만 돌진(lunge). 궁수·투척은 제자리에서 발사 — 자리잡은 대열이 좌우로 흔들리지 않게. → battle.md
	if ItemTypes.weapon_range(weapon) < 2 and ItemTypes.weapon_throw_range(weapon) == 0:
		_lunge(u, t["pos"])                                   # 공격 멤버가 표적 쪽으로 돌진
	var ht := HitFeedback.hit_text(r)
	_spawn_float(t["pos"], ht["text"], ht["color"], ht["big"])   # 대미지 숫자/빗나감/막기(표적 멤버)
	if r["hit"] and not r["blocked"] and r["damage"] > 0:
		if ItemTypes.weapon_range(weapon) < 2 and ItemTypes.weapon_throw_range(weapon) == 0:
			# 근접 타격 — 피격자 뒤로 밀림 + 공격자 같은 방향으로 전진(달라붙기). 되돌아오지 않는 실제 위치 이동. → battle.md
			var away: Vector2 = t["pos"] - u["pos"]
			if away.length() > 0.001:
				var push := away.normalized() * HIT_PUSH_PX
				t["pos"] += push
				u["pos"] += push
		_flash(t)                                             # 표적 반짝임(밀림은 위치로 표현)
	if r["inflict"] != "":
		_spawn_float(t["pos"] + Vector2(0, -18), HitFeedback.status_text(r["inflict"]), HitFeedback.STATUS_COLOR, false)
	if ItemTypes.weapon_range(weapon) >= 2 or ItemTypes.weapon_throw_range(weapon) > 0:
		_spawn_projectile(u["pos"], t["pos"])   # 원거리·투척 연출(멤버→멤버)
	if t["hp"] <= 0:
		_kill(t, u["pos"])   # 멤버 사망: 공격자 반대쪽으로 넉백(랑그릿사1식)

## 사수 위치에서 대상으로 작은 점을 날리는 시각 연출. on_land가 있으면 착탄 시 호출한다([투석]은 피해를 착탄 시 적용).
func _spawn_projectile(from: Vector2, to: Vector2, duration := PROJECTILE_TIME, on_land := Callable()) -> void:
	_live_projectiles += 1
	var dot := ColorRect.new()
	dot.color = Color(1.0, 0.9, 0.4)
	dot.size = Vector2(6, 6)
	dot.z_index = Z_PROJECTILE   # 유닛 토큰(z=int(pos.y)) 위로 날아가게. → battle.md
	dot.position = from - Vector2(3, 3)
	_view.add_child(dot)
	# 포물선: 진행도 0→1을 tween하며 매 스텝 위치를 계산(수평 보간 − 아치 높이).
	var tw := create_tween()
	tw.tween_method(_arc_projectile.bind(dot, from, to), 0.0, 1.0, duration)
	tw.tween_callback(_on_projectile_done.bind(dot, on_land))

## 진행도 t(0~1)에서 포물선 위치 계산. 4·t·(1−t)로 양끝 0·중간 1인 아치를 만든다.
func _arc_projectile(t: float, dot: ColorRect, from: Vector2, to: Vector2) -> void:
	var p := from.lerp(to, t) - Vector2(0, PROJECTILE_ARC * 4.0 * t * (1.0 - t))
	dot.position = p - Vector2(3, 3)

## 투사체 착탄 — 카운트 감소·제거 후, on_land가 있으면 착탄 콜백 호출(종료·투석 피해 판정에 쓰인다).
func _on_projectile_done(dot: ColorRect, on_land := Callable()) -> void:
	_live_projectiles -= 1
	dot.queue_free()
	if on_land.is_valid():
		on_land.call()

## 떠오르는 텍스트(대미지·상태이상·도트). center에서 위로 뜨며 페이드 후 스스로 제거.
func _spawn_float(center: Vector2, text: String, color: Color, big: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.position = center
	lbl.scale = Vector2(1.6, 1.6) if big else Vector2.ONE
	lbl.z_index = Z_FLOAT   # 데미지 숫자는 유닛·투사체 위. → battle.md
	_view.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", center + Vector2(0, -FLOAT_RISE), FLOAT_TIME)
	tw.tween_property(lbl, "modulate:a", 0.0, FLOAT_TIME)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

## 피격 반짝임 — 대상 body를 잠깐 흰색으로 번쩍였다 팀색 복귀(위치 이동 없음). 밀림은 위치(pos) 자체로 표현. → battle.md
func _flash(u: Dictionary) -> void:
	var body: ColorRect = u["body"]
	_reset_flash(u, body)
	u["flash_tw"] = create_tween()
	u["flash_tw"].tween_property(body, "color", Color(1, 1, 1, 1), FLASH_TIME * 0.4)
	u["flash_tw"].tween_property(body, "color", u["color"], FLASH_TIME * 0.6)

## 공격 돌진 — 공격자 body를 대상 쪽으로 살짝 냈다 복귀. body position 슬롯을 흔들림과 공유한다.
func _lunge(u: Dictionary, toward: Vector2) -> void:
	var body: ColorRect = u["body"]
	var from: Vector2 = u["pos"]
	var dir := (toward - from).normalized()
	_reset_body_pos(u, body)
	u["pos_tw"] = create_tween()
	u["pos_tw"].tween_property(body, "position", dir * LUNGE_PX, LUNGE_TIME * 0.5)
	u["pos_tw"].tween_property(body, "position", Vector2.ZERO, LUNGE_TIME * 0.5)

## 진행 중인 body position tween을 멈추고 원위치(0,0)로 되돌린다.
func _reset_body_pos(u: Dictionary, body: ColorRect) -> void:
	if u.has("pos_tw") and u["pos_tw"] != null and u["pos_tw"].is_valid():
		u["pos_tw"].kill()
	body.position = Vector2.ZERO

## 진행 중인 flash tween을 멈추고 팀색으로 되돌린다.
func _reset_flash(u: Dictionary, body: ColorRect) -> void:
	if u.has("flash_tw") and u["flash_tw"] != null and u["flash_tw"].is_valid():
		u["flash_tw"].kill()
	body.color = u["color"]

## 근접 모드 궁수를 근접 교전으로 전환(한 번 전환되면 유지). 근접무기 없으면 활 든 채 돌격.
func _engage_melee(u: Dictionary) -> void:
	var mw: String = ItemTypes.melee_weapon(u["human"].weapons)
	if mw == "":
		mw = u["weapon"]   # 순수 궁수: 활을 근접 무기처럼
	u["weapon"] = mw
	u["range"] = 1   # 이후 프레임부터 근접(접근·근접 공격) 거동
	u["melee_reach"] = ItemTypes.weapon_reach(mw) * MELEE_REACH_PX

## 전투불능 처리. from_pos가 주어지면 그 반대쪽으로 껑충 뛰어(아치) 날아가며 흐려진다(랑그릿사1식).
## from_pos가 없으면(출혈 도트 등) 넉백 없이 흐려지기만 한다.
func _kill(u: Dictionary, from_pos = null) -> void:
	u["alive"] = false
	if u.has("hp_label"):
		u["hp_label"].text = "0"   # 사망 = hp 0 표시(치명타 직전 값이 남지 않게). 죽은 유닛은 이후 _sync_node를 안 타므로 여기서 내린다.
	_refresh_hp_bar(u)            # HP 바 비움(hp ≤ 0)
	if not u.has("node"):
		return   # 노드 없는 전투원(안전 가드) — 개별 토큰 없으면 연출 없음
	var node: Control = u["node"]
	node.pivot_offset = Vector2(TOKEN_R, TOKEN_R)   # 회전 축을 토큰 중심으로(눕는 시체)
	if from_pos == null:
		node.modulate = Color(1.0, 1.0, 1.0, DEATH_ALPHA)   # 넉백 없이 페이드(상태이상 tint 제거)
		node.rotation = CORPSE_TILT   # 바닥에 쓰러진 느낌
		return
	var dir: Vector2 = u["pos"] - from_pos
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.LEFT
	var base: Vector2 = u["pos"] - Vector2(TOKEN_R, TOKEN_R)   # node.position 기준
	var apex := base + dir * (KNOCKBACK_PX * 0.5) - Vector2(0, KNOCKBACK_UP)
	var land := base + dir * KNOCKBACK_PX
	var jump := create_tween()   # 위로 튀었다 뒤로 착지 = 아치
	jump.tween_property(node, "position", apex, KNOCKBACK_TIME * 0.5).set_ease(Tween.EASE_OUT)
	jump.tween_property(node, "position", land, KNOCKBACK_TIME * 0.5).set_ease(Tween.EASE_IN)
	create_tween().tween_property(node, "modulate", Color(1.0, 1.0, 1.0, DEATH_ALPHA), KNOCKBACK_TIME)
	# 넉백 방향으로 눕는 회전(좌/우에 따라 부호). → battle.md
	create_tween().tween_property(node, "rotation", CORPSE_TILT * signf(dir.x if dir.x != 0.0 else 1.0), KNOCKBACK_TIME)

## 비투석(근접·원거리) 전투 종료 — 시간 만료·전멸 시 _process에서 호출. 날아가는 투사체가 남으면 착탄 후 +1초.
func _finish() -> void:
	_running = false
	_writeback()
	var a_surv := BattleField.survivors(_units, "a")
	var b_surv := BattleField.survivors(_units, "b")
	if _live_projectiles > 0:
		# 날아가는 화살이 남아 있으면 모두 착탄할 때까지 기다렸다가 +1초 뒤 종료.
		while _live_projectiles > 0:
			await get_tree().process_frame
		await get_tree().create_timer(ARROW_LAND_DELAY).timeout
	else:
		await get_tree().create_timer(END_DELAY).timeout
	finished.emit(a_surv, b_surv)

## [투석] 순차 연출이 자체 대기(착탄·간격·1초)를 마친 뒤 호출 — 추가 대기 없이 즉시 결과 반영·방출.
func _finish_siege() -> void:
	_running = false
	_writeback()
	finished.emit(BattleField.survivors(_units, "a"), BattleField.survivors(_units, "b"))

## 각 유닛의 최종 hp를 원본(투석기·성벽/성문·Human)에 되쓴다.
func _writeback() -> void:
	for u in _units:
		if u.get("siege", false):
			u["unit"].hit_points = maxi(0, int(u["hp"]))   # 투석기 hp 이월(파괴면 0 → 전투 후 prune)
		elif u.get("structure", false):
			if u.get("gate", false):
				u["building"].gate_hp = maxi(0, int(u["hp"]))   # 성문 잔여 내구도 반영(0이면 game.gd가 통로 개방)
			else:
				u["building"].wall_hp = maxi(0, int(u["hp"]))   # 성벽 잔여 내구도 반영(0이면 game.gd가 붕괴 처리)
		elif u["alive"]:
			u["human"].hit_points = maxi(1, int(u["hp"]))   # 생존자 최종 hp를 Human에 반영(전투 후 지속)
