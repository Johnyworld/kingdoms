extends CanvasLayer
## 전투씬 오버레이(관전 전용). 월드맵 위를 어둡게 덮고 양 부대원 토큰이 실시간으로 교전한다.
## 판정은 CombatResolver, 최근접 적 선택·전멸 판정은 BattleField(순수)에 위임한다.
## 한 팀 전멸(또는 상한 시간) 시 finished(a_survivors, b_survivors)를 방출한다.
## UI는 코드로 구성한다(party_info 등과 같은 패턴, 별도 .tscn 없음).

signal finished(a_survivors: Array, b_survivors: Array)

const UNIT_SPEED := 260.0     # 토큰 이동 속도(px/s)
const CONTACT_DIST := 46.0    # 이 거리 이하면 교전
const ENGAGE_CD := 0.35       # 교전 후 쿨다운(초)
const MAX_TIME := 20.0        # 안전 상한(무한 교착 방지)
const TOKEN_R := 18.0
const END_DELAY := 0.6        # 종료 후 결과 방출까지 여유(마지막 상태 관전)

var _units: Array = []
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _running := false
var _view: Control

## 공격측(a)·방어측(b) 부대를 받아 전투를 시작한다.
func start(attacker, defender) -> void:
	layer = 60
	_rng.randomize()
	_build_bg()
	var vp := get_viewport().get_visible_rect().size
	_spawn_team(attacker, "a", vp.x * 0.25, vp)
	_spawn_team(defender, "b", vp.x * 0.75, vp)
	_running = true

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
		var unit := {
			"human": members[i], "team": team, "hp": int(members[i].hit_points),
			"alive": true, "pos": pos, "cooldown": 0.0,
			"node": node, "hp_label": node.get_node("hp"),
		}
		_units.append(unit)
		_sync_node(unit)

## 토큰 = 몸통(ColorRect) + 위에 현재 생명점 라벨.
func _make_token(color: Color) -> Control:
	var c := Control.new()
	var body := ColorRect.new()
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
	for u in _units:
		if u["cooldown"] > 0.0:
			u["cooldown"] = maxf(0.0, u["cooldown"] - delta)

	var engaged := {}   # 이번 프레임에 이미 교전한 human(중복 처리 방지)
	for u in _units:
		if not u["alive"]:
			continue
		var t: Dictionary = BattleField.nearest_enemy(u, _units)
		if t.is_empty():
			continue
		var dist: float = u["pos"].distance_to(t["pos"])
		if dist <= CONTACT_DIST:
			if u["cooldown"] <= 0.0 and t["cooldown"] <= 0.0 \
					and not engaged.has(u["human"]) and not engaged.has(t["human"]):
				_engage(u, t)
				engaged[u["human"]] = true
				engaged[t["human"]] = true
		elif u["cooldown"] <= 0.0:
			u["pos"] += (t["pos"] - u["pos"]).normalized() * UNIT_SPEED * delta
		_sync_node(u)

	if BattleField.team_wiped(_units, "a") or BattleField.team_wiped(_units, "b") or _elapsed >= MAX_TIME:
		_finish()

## 접촉한 두 유닛의 1회 교전. u가 접촉해 온 쪽이라 개시자(선공).
func _engage(u: Dictionary, t: Dictionary) -> void:
	var r := CombatResolver.resolve_engagement(u["human"], t["human"], u["hp"], t["hp"], _rng)
	u["hp"] = r["a_hp"]
	t["hp"] = r["b_hp"]
	u["cooldown"] = ENGAGE_CD
	t["cooldown"] = ENGAGE_CD
	if u["hp"] <= 0:
		_kill(u)
	if t["hp"] <= 0:
		_kill(t)

func _kill(u: Dictionary) -> void:
	u["alive"] = false
	u["node"].modulate.a = 0.3   # 전투불능 — 흐리게

## 토큰 노드 위치·생명점 표시를 상태에 맞춘다(중심이 pos에 오도록).
func _sync_node(u: Dictionary) -> void:
	u["node"].position = u["pos"] - Vector2(TOKEN_R, TOKEN_R)
	u["hp_label"].text = str(maxi(0, u["hp"]))

func _finish() -> void:
	_running = false
	var a_surv := BattleField.survivors(_units, "a")
	var b_surv := BattleField.survivors(_units, "b")
	await get_tree().create_timer(END_DELAY).timeout
	finished.emit(a_surv, b_surv)
