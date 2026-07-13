extends CanvasLayer
## 성벽 투석 관전 오버레이(신규, battle.gd와 별개). 투석기가 성벽에 투사체를 날리고 내구도 바가 줄어든다.
## 방어 멤버가 없는 성벽 전용이라 기존 전투 씬(두 부대 교전)을 개조하지 않는다. 판정은 하지 않고 연출만 —
## 실제 wall_hp 반영·붕괴는 game.gd가 종료(finished) 후 처리한다. → docs/spec/features/siege-engines.md

signal finished

const FLIGHT_TIME := 0.55    # 투사체 비행 시간(초)
const ARC_HEIGHT := 120.0    # 포물선 최고 높이(px)
const HOLD_AFTER := 0.7      # 착탄 후 종료까지 여유(초)
const BAR_SIZE := Vector2(200, 16)

var _view: Control
var _bar_fill: ColorRect
var _projectile: ColorRect
var _wall: ColorRect
var _from_ratio := 1.0
var _to_ratio := 1.0
var _cat_pos: Vector2
var _wall_pos: Vector2

## 관전 시작 — 투석기(공격측 색)와 성벽 표적·내구도 바를 그리고 투사체 한 발을 날린다.
## from_hp/damage로 내구도 바가 from → from−damage로 준다(연출용, 실제 반영은 game.gd).
func start(party, building, from_hp: int, damage: int) -> void:
	layer = 60
	var maxhp := float(Siege.WALL_MAX_HP)
	_from_ratio = clampf(from_hp / maxhp, 0.0, 1.0)
	_to_ratio = clampf(float(maxi(0, from_hp - damage)) / maxhp, 0.0, 1.0)
	_build(party, building)
	_run()

func _build(party, building) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # 아래 월드맵 클릭 흡수(관전)
	add_child(dim)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	var vp := get_viewport().get_visible_rect().size
	_cat_pos = Vector2(vp.x * 0.24, vp.y * 0.6)
	_wall_pos = Vector2(vp.x * 0.72, vp.y * 0.52)

	# 투석기 토큰(공격 부대 색).
	var cat := ColorRect.new()
	cat.color = party.token_color
	cat.size = Vector2(44, 30)
	cat.position = _cat_pos - cat.size * 0.5
	_view.add_child(cat)
	_view.add_child(_label("투석기", _cat_pos + Vector2(-24, 26)))

	# 성벽 표적.
	_wall = ColorRect.new()
	_wall.color = Color(0.62, 0.62, 0.68)
	_wall.size = Vector2(48, 100)
	_wall.position = _wall_pos - _wall.size * 0.5
	_view.add_child(_wall)
	var wname: String = building.territory.name if building.territory != null else "성벽"
	_view.add_child(_label("%s 성벽" % wname, _wall_pos + Vector2(-30, 62)))

	# 내구도 바(성벽 위).
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.15)
	bar_bg.size = BAR_SIZE
	bar_bg.position = _wall_pos + Vector2(-BAR_SIZE.x * 0.5, -86)
	_view.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.3, 0.25)
	_bar_fill.size = Vector2(BAR_SIZE.x * _from_ratio, BAR_SIZE.y)
	_bar_fill.position = bar_bg.position
	_view.add_child(_bar_fill)

	# 투사체(투석기 → 성벽).
	_projectile = ColorRect.new()
	_projectile.color = Color(0.9, 0.85, 0.6)
	_projectile.size = Vector2(14, 14)
	_projectile.position = _cat_pos - _projectile.size * 0.5
	_view.add_child(_projectile)

func _label(text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	return l

func _run() -> void:
	var tw := create_tween()
	tw.tween_method(_fly, 0.0, 1.0, FLIGHT_TIME)   # 포물선 비행
	await tw.finished
	# 착탄 — 내구도 바 감소 + 성벽 흔들림.
	var base_x := _wall.position.x
	var tw2 := create_tween()
	tw2.tween_property(_bar_fill, "size:x", BAR_SIZE.x * _to_ratio, 0.25)
	tw2.parallel().tween_property(_wall, "position:x", base_x + 6.0, 0.05)
	tw2.tween_property(_wall, "position:x", base_x, 0.08)
	await tw2.finished
	await get_tree().create_timer(HOLD_AFTER).timeout
	finished.emit()

## 투사체 위치 — 직선 보간에 포물선(sin) 높이를 얹는다.
func _fly(t: float) -> void:
	var p := _cat_pos.lerp(_wall_pos, t)
	p.y -= ARC_HEIGHT * sin(t * PI)
	_projectile.position = p - _projectile.size * 0.5
