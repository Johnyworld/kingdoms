extends CanvasLayer
## 전투씬 오버레이(관전 전용). 월드맵 위를 어둡게 덮고 양 부대원 토큰이 실시간으로 교전한다.
## 판정은 CombatResolver, 최근접 적 선택·전멸 판정은 BattleField(순수)에 위임한다.
## 한 팀 전멸(또는 상한 시간) 시 finished(a_survivors, b_survivors)를 방출한다.
## UI는 코드로 구성한다(party_info 등과 같은 패턴, 별도 .tscn 없음).

signal finished(a_survivors: Array, b_survivors: Array)

const UNIT_SPEED := 260.0     # 토큰 이동 속도(px/s)
const MELEE_REACH_PX := 46.0  # 근접거리(리치) 1당 공격 개시 거리(px). 리치 긴 무기가 더 멀리서 선제
const THROW_PX := 90.0        # 투척 사거리 1당 추가 거리(px)
const BATTLE_TIME := 10.0        # 근접 전투 지속 시간(초)
const RANGED_BATTLE_TIME := 5.0  # 원거리 전투 지속 시간(초). 2배속 재생(공격 간격 ×0.5)
const RANGED_SPEED := 2.0        # 원거리 모드 배속(공격 간격 나누는 값)
const CHARGE_RANGE_PX := 120.0   # 근접 모드: 이 거리 안에 적이 들면 궁수도 근접 전환·돌격
const MAX_THROWS := 3            # 투척 무기 최대 투척 횟수(이후 근접 전환)
const TOKEN_R := 18.0
const PROJECTILE_TIME := 0.24    # 투사체가 대상까지 나는 시간(초). 기존의 1/2 속도
const PROJECTILE_ARC := 40.0     # 투사체 포물선 최고 높이(px, 중간 지점 기준)
const END_DELAY := 0.6           # 종료 후 결과 방출까지 여유(날아가는 화살 없을 때)
const ARROW_LAND_DELAY := 1.0    # 종료 시 화살이 남아 있으면, 착탄 후 이만큼 더 기다렸다 종료

# 타격 연출(초안 수치) — 판정·생존 결과에 영향 없음. 상세는 combat-feedback.md.
const FLOAT_RISE := 40.0      # 떠오르는 텍스트 상승 높이(px)
const FLOAT_TIME := 0.7       # 떠오름·페이드 시간(초)
const FLASH_TIME := 0.12      # 피격 흰 반짝임 시간(초)
const SHAKE_PX := 5.0         # 피격 흔들림 진폭(px)
const SHAKE_TIME := 0.18      # 피격 흔들림 시간(초)
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
var _view: Control

## 공격측(a)·방어측(b) 부대를 받아 전투를 시작한다. distance = 교전 헥스 거리(1=근접).
## distance >= 2면 원거리 교전 — 사거리 ≥ distance인 유닛만 행동. → docs/spec/features/battle.md
## include_siege면 양 부대의 공성 유닛(투석기)을 전투원으로 스폰([투석] 전투). wall(성벽 거점)이 있으면 성벽을
## 구조물 전투원으로 방어 팀에 스폰(성벽 투석 — defender는 null 허용, 성벽만 방어). → siege-engines.md
func start(attacker, defender, distance := 1, include_siege := false, wall = null) -> void:
	_distance = distance
	_ranged_mode = distance >= 2
	_battle_time = RANGED_BATTLE_TIME if _ranged_mode else BATTLE_TIME
	layer = 60
	_rng.randomize()
	_build_bg()
	var vp := get_viewport().get_visible_rect().size
	_spawn_team(attacker, "a", vp.x * 0.25, vp)
	if defender != null:
		_spawn_team(defender, "b", vp.x * 0.75, vp)
	if include_siege:
		_spawn_siege(attacker, "a", vp.x * 0.1, vp)
		if defender != null:
			_spawn_siege(defender, "b", vp.x * 0.9, vp)
	if wall != null:
		_spawn_structure(wall, "b", vp)
	_running = true

## 성벽을 구조물 전투원으로 방어 팀(b)에 스폰한다. 이동·공격·상태이상 없이 투석 flat 피해만 받는다. → siege-engines.md
func _spawn_structure(building, team: String, vp: Vector2) -> void:
	var pos := Vector2(vp.x * 0.75, vp.y * 0.5)
	var node := _make_token(Color(0.62, 0.62, 0.68))   # 성벽 회색
	(node.get_node("hp") as Label).text = "성벽"
	_view.add_child(node)
	var su := {
		"structure": true, "team": team, "alive": true, "pos": pos,
		"node": node, "hp_label": node.get_node("hp"), "body": node.get_node("body"), "color": Color(0.62, 0.62, 0.68),
		"hp": int(building.wall_hp), "building": building, "effects": {},
	}
	_units.append(su)
	su["node"].position = pos - Vector2(TOKEN_R, TOKEN_R)

## 부대의 공성 유닛(투석기)을 전투원으로 스폰한다(팀 열 바깥쪽·위). 이동·근접 없이 전투당 1발만 쏜다. → siege-engines.md
func _spawn_siege(party, team: String, x: float, vp: Vector2) -> void:
	if not party.has_siege():
		return
	var units: Array = party.siege_units
	var n := units.size()
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var pos := Vector2(x, lerpf(vp.y * 0.16, vp.y * 0.34, t))
		var node := _make_token(party.token_color)
		(node.get_node("hp") as Label).text = units[i].unit_name()   # 초기 라벨은 이름(피격 시 _catapult_volley가 남은 hp로 덮어씀)
		_view.add_child(node)
		var su := {
			"siege": true, "team": team, "alive": true, "pos": pos,
			"node": node, "hp_label": node.get_node("hp"), "body": node.get_node("body"), "color": party.token_color,
			"min_range": units[i].min_range(), "range": units[i].fire_range(), "attack": units[i].attack(),
			"hp": int(units[i].hit_points), "unit": units[i],   # 피격 가능(5d-3a) — 파괴 시 unit에 반영
			"fired": false, "effects": {},
		}
		_units.append(su)
		su["node"].position = pos - Vector2(TOKEN_R, TOKEN_R)

## 투석기 전투원 행동 — 원거리 교전이고 사거리 밴드(min~fire) 안이며 미발사면 전투당 1발 광역 사격. → siege-engines.md
func _siege_act(u: Dictionary) -> void:
	if u["fired"] or not _ranged_mode:
		return
	if _distance < u["min_range"] or _distance > u["range"]:
		return   # 사거리 밴드 밖 — 이번 전투에선 못 쏨
	u["fired"] = true
	_catapult_volley(u)

## 투석 1발 = 가장 가까운 적 최대 MAX_BOMBARD_TARGETS 표적에 개별 판정 — 성벽 구조물은 항상 명중, 유닛은 CATAPULT_HIT_CHANCE(0.1). 명중 시 flat rolled_damage(방어구·회피 무시). → siege-engines.md
func _catapult_volley(u: Dictionary) -> void:
	var targets := BattleField.bombard_targets(u, _units, Siege.MAX_BOMBARD_TARGETS)
	for t in targets:
		_spawn_projectile(u["pos"], t["pos"])   # 투사체 연출(피해는 즉시 적용)
		# 성벽 구조물은 거대·부동이라 항상 명중, 유닛은 명중률 판정. → siege-engines.md
		if not t.get("structure", false) and not Siege.hit_succeeds(_rng.randf(), Siege.CATAPULT_HIT_CHANCE):
			_spawn_float(t["pos"], "빗나감", Color(0.7, 0.7, 0.7), false)
			continue
		var dmg := Siege.rolled_damage(u["attack"], _rng.randf())   # flat(방어구·회피·상성 무시)
		t["hp"] -= dmg
		t["hp_label"].text = str(maxi(0, t["hp"]))
		_spawn_float(t["pos"], str(dmg), Color(1.0, 0.5, 0.3), true)
		_hit_react(t)
		if t["hp"] <= 0:
			if t.get("structure", false):
				_kill(t)   # 성벽은 제자리 붕괴(넉백 없이 페이드)
			else:
				_kill(t, u["pos"])

func _build_bg() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # 아래 월드맵 클릭을 흡수(관전)
	add_child(dim)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

## 한 팀 멤버를 세로 열로 배치하고 토큰을 만든다.
func _spawn_team(party, team: String, x: float, vp: Vector2) -> void:
	var members: Array = party.members
	var n := members.size()
	for i in n:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var pos := Vector2(x, lerpf(vp.y * 0.28, vp.y * 0.72, t))
		var node := _make_token(party.token_color)
		_view.add_child(node)
		# 이 전투에서 쓸 무기(근접=주무기, 원거리=활). range는 그 무기의 공격거리.
		var w: String = ItemTypes.active_weapon(members[i].weapons, _ranged_mode)
		var thrw: String = ItemTypes.throwing_weapon(members[i].weapons)
		var melee_reach: float = ItemTypes.weapon_reach(w) * MELEE_REACH_PX
		var unit := {
			"human": members[i], "team": team, "hp": int(members[i].hit_points),
			"alive": true, "pos": pos, "cooldown": 0.0,
			"node": node, "hp_label": node.get_node("hp"), "body": node.get_node("body"), "color": party.token_color,
			"weapon": w, "range": ItemTypes.weapon_range(w),
			"melee_reach": melee_reach,
			"throw": thrw, "throws": 0,
			"throw_reach": melee_reach + ItemTypes.weapon_throw_range(thrw) * THROW_PX,
			"effects": {},
		}
		_units.append(unit)
		_sync_node(unit)

## 토큰 = 몸통(ColorRect) + 위에 현재 생명점 라벨.
func _make_token(color: Color) -> Control:
	var c := Control.new()
	var body := ColorRect.new()
	body.name = "body"
	body.color = color
	body.size = Vector2(TOKEN_R * 2.0, TOKEN_R * 2.0)
	c.add_child(body)
	var lbl := Label.new()
	lbl.name = "hp"
	lbl.position = Vector2(0, -20)
	c.add_child(lbl)
	return c

func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed >= _battle_time:
		_finish()   # 전투 시간(근접 10초 / 원거리 5초) 종료
		return

	# 상태이상 진행(모든 생존 유닛): 출혈 도트를 hp에서 빼고, 죽으면 전투불능 처리.
	for u in _units:
		if not u["alive"] or u.get("siege", false) or u.get("structure", false):
			continue   # 공성 전투원·성벽 구조물은 상태이상 진행 없음. → siege-engines.md
		var dot := StatusEffects.advance(u["effects"], delta)
		if dot > 0:
			u["hp"] -= dot
			_spawn_float(u["pos"], str(dot), HitFeedback.BLEED_COLOR, false)   # 출혈 도트 붉은 숫자
			if u["hp"] <= 0:
				_kill(u)   # 도트 사망: 공격자 없음 → 넉백 없이 페이드
		_sync_node(u)

	for u in _units:
		if not u["alive"]:
			continue
		if u.get("structure", false):
			continue   # 성벽 구조물 — 이동·공격 없음(맞기만 함)
		if u.get("siege", false):
			_siege_act(u)   # 투석기 전투원 — 사거리 밴드면 전투당 1발 광역 → siege-engines.md
			continue
		if _ranged_mode and u["range"] < _distance:
			continue   # 원거리 교전: 사거리가 거리에 못 미치는 유닛(근접 무기 포함)은 닿지 않아 정지
		if StatusEffects.is_stunned(u["effects"]):
			continue   # 기절: 이번 프레임 이동·공격 안 함
		u["cooldown"] = maxf(0.0, u["cooldown"] - delta)
		var t: Dictionary = BattleField.nearest_enemy(u, _units)   # 매 프레임 최근접 적 재탐색
		if t.is_empty():
			continue
		var dist: float = u["pos"].distance_to(t["pos"])
		if u["range"] >= 2:
			# 근접 모드: 적이 임계거리 안에 들면 근접 전환(다음 프레임부터 돌격). 활만 있으면 활 든 채.
			if not _ranged_mode and BattleField.archer_should_charge(u["range"], dist, CHARGE_RANGE_PX):
				_engage_melee(u)
			elif u["cooldown"] <= 0.0:
				# 원거리(활·완드): 이동 없이 제자리에서 공격속도마다 사격.
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
				u["pos"] += (t["pos"] - u["pos"]).normalized() * UNIT_SPEED * delta
		_sync_node(u)

	# 한 팀 전멸 시 즉시 종료(시간 만료는 위에서 처리).
	if BattleField.team_wiped(_units, "a") or BattleField.team_wiped(_units, "b"):
		_finish()

## 1회 공격(일방). weapon으로 resolve_hit, 피해 적용, 쿨다운을 그 무기의 공격 간격으로 리셋.
## 원거리·투척 무기면 투사체를 날린다.
func _attack(u: Dictionary, t: Dictionary, weapon: String) -> void:
	var r := CombatResolver.resolve_hit(u["human"], t["human"], t["hp"], _rng, weapon)
	t["hp"] = r["hp"]
	t["hp_label"].text = str(maxi(0, t["hp"]))   # 치명타로 죽는 프레임에도 HP 표시가 즉시 0이 되도록
	if r["inflict"] != "":
		StatusEffects.apply(t["effects"], r["inflict"])   # 치명타 → 출혈/기절 부여
	# 원거리 모드는 2배속(공격 간격 ×0.5) — 5초 전투로 같은 발사 수.
	var speed := RANGED_SPEED if _ranged_mode else 1.0
	u["cooldown"] = CombatResolver.attack_interval(u["human"], weapon) / speed
	# --- 타격 연출(combat-feedback.md) ---
	_lunge(u, t["pos"])                                   # 공격자 돌진
	var ht := HitFeedback.hit_text(r)
	_spawn_float(t["pos"], ht["text"], ht["color"], ht["big"])   # 대미지 숫자/빗나감/막기
	if r["hit"] and not r["blocked"] and r["damage"] > 0:
		_hit_react(t)                                     # 피격 반짝임 + 흔들림
	if r["inflict"] != "":
		_spawn_float(t["pos"] + Vector2(0, -18), HitFeedback.status_text(r["inflict"]), HitFeedback.STATUS_COLOR, false)
	if ItemTypes.weapon_range(weapon) >= 2 or ItemTypes.weapon_throw_range(weapon) > 0:
		_spawn_projectile(u["pos"], t["pos"])   # 원거리·투척 연출
	if t["hp"] <= 0:
		_kill(t, u["pos"])   # 공격자 반대쪽으로 넉백

## 사수 위치에서 대상으로 작은 점을 날리는 시각 연출(피해는 이미 적용됨).
func _spawn_projectile(from: Vector2, to: Vector2) -> void:
	_live_projectiles += 1
	var dot := ColorRect.new()
	dot.color = Color(1.0, 0.9, 0.4)
	dot.size = Vector2(6, 6)
	dot.position = from - Vector2(3, 3)
	_view.add_child(dot)
	# 포물선: 진행도 0→1을 tween하며 매 스텝 위치를 계산(수평 보간 − 아치 높이).
	var tw := create_tween()
	tw.tween_method(_arc_projectile.bind(dot, from, to), 0.0, 1.0, PROJECTILE_TIME)
	tw.tween_callback(_on_projectile_done.bind(dot))

## 진행도 t(0~1)에서 포물선 위치 계산. 4·t·(1−t)로 양끝 0·중간 1인 아치를 만든다.
func _arc_projectile(t: float, dot: ColorRect, from: Vector2, to: Vector2) -> void:
	var p := from.lerp(to, t) - Vector2(0, PROJECTILE_ARC * 4.0 * t * (1.0 - t))
	dot.position = p - Vector2(3, 3)

## 투사체 착탄 — 카운트 감소 후 제거(종료 시 착탄 대기 판정에 쓰인다).
func _on_projectile_done(dot: ColorRect) -> void:
	_live_projectiles -= 1
	dot.queue_free()

## 떠오르는 텍스트(대미지·상태이상·도트). center에서 위로 뜨며 페이드 후 스스로 제거.
func _spawn_float(center: Vector2, text: String, color: Color, big: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.position = center
	lbl.scale = Vector2(1.6, 1.6) if big else Vector2.ONE
	lbl.z_index = 10
	_view.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", center + Vector2(0, -FLOAT_RISE), FLOAT_TIME)
	tw.tween_property(lbl, "modulate:a", 0.0, FLOAT_TIME)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

## 피격 반응 — 대상 body를 흰색으로 반짝이고 좌우로 흔든다(node.position 갱신과 무관하게 body만).
## body의 position·color tween은 유닛별 슬롯에 두고, 새로 시작하기 전 이전 것을 정리한다
## (연타로 tween이 겹쳐 body가 중앙/원색에서 어긋난 채 고착되는 것을 막는다).
func _hit_react(u: Dictionary) -> void:
	var body: ColorRect = u["body"]
	_reset_flash(u, body)
	u["flash_tw"] = create_tween()
	u["flash_tw"].tween_property(body, "color", Color(1, 1, 1, 1), FLASH_TIME * 0.4)
	u["flash_tw"].tween_property(body, "color", u["color"], FLASH_TIME * 0.6)
	_reset_body_pos(u, body)
	u["pos_tw"] = create_tween()
	u["pos_tw"].tween_property(body, "position:x", SHAKE_PX, SHAKE_TIME * 0.25)
	u["pos_tw"].tween_property(body, "position:x", -SHAKE_PX, SHAKE_TIME * 0.5)
	u["pos_tw"].tween_property(body, "position:x", 0.0, SHAKE_TIME * 0.25)

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
	var node: Control = u["node"]
	if from_pos == null:
		node.modulate = Color(1.0, 1.0, 1.0, DEATH_ALPHA)   # 넉백 없이 페이드(상태이상 tint 제거)
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

## 토큰 노드 위치·생명점 표시를 상태에 맞춘다(중심이 pos에 오도록).
## 최소 상태이상 표시: 기절=흐림(회색), 출혈=붉은 tint. 전투불능은 _kill이 alpha로 처리.
func _sync_node(u: Dictionary) -> void:
	u["node"].position = u["pos"] - Vector2(TOKEN_R, TOKEN_R)
	u["hp_label"].text = str(maxi(0, u["hp"]))
	if u["alive"]:
		if StatusEffects.is_stunned(u["effects"]):
			u["node"].modulate = Color(0.6, 0.6, 0.6, 1.0)
		elif u["effects"].has("bleed"):
			u["node"].modulate = Color(1.0, 0.5, 0.5, 1.0)
		else:
			u["node"].modulate = Color(1.0, 1.0, 1.0, 1.0)

func _finish() -> void:
	_running = false
	for u in _units:
		if u.get("siege", false):
			u["unit"].hit_points = maxi(0, int(u["hp"]))   # 투석기 hp 이월(파괴면 0 → 전투 후 prune)
		elif u.get("structure", false):
			u["building"].wall_hp = maxi(0, int(u["hp"]))   # 성벽 잔여 내구도 반영(0이면 game.gd가 붕괴 처리)
		elif u["alive"]:
			u["human"].hit_points = maxi(1, int(u["hp"]))   # 생존자 최종 hp를 Human에 반영(전투 후 지속)
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
