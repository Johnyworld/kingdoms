extends CanvasLayer
## 성벽 투석 관전 오버레이(battle.gd와 별개). 투석기가 성벽(구조물)에 투사체만 날리는 일방 폭격 연출.
## 성벽은 전투원(Human 팀)이 아니라 battle.gd 두-팀 모델에 안 맞으므로 전용 경량 씬으로 둔다(구조물 전투원화·흡수는 5d-3).
## 유닛 투석은 battle.gd 통합 전투로 이관됨(5d-2). 판정은 하지 않고 연출만 — 실제 wall_hp 반영·붕괴는 game.gd가 종료 후 처리. → docs/spec/features/siege-engines.md

signal finished

const FLIGHT_TIME := 0.55    # 투사체 비행 시간(초)
const ARC_HEIGHT := 120.0    # 포물선 최고 높이(px)
const HOLD_AFTER := 0.7      # 착탄 후 종료까지 여유(초)
const WALL_BAR := Vector2(200, 16)

var _view: Control
var _projectile: ColorRect
var _cat_pos: Vector2
var _target_pos: Vector2
var _wall: ColorRect
var _wall_bar: ColorRect
var _wall_to_ratio := 1.0

## 성벽 투석 관전 — 투석기 → 성벽 표적 + 내구도 바(from_hp → from_hp−damage).
func start_wall(party, building, from_hp: int, damage: int) -> void:
	layer = 60
	_build_base(party)
	var vp := get_viewport().get_visible_rect().size
	_target_pos = Vector2(vp.x * 0.72, vp.y * 0.52)
	var maxhp := float(Siege.WALL_MAX_HP)
	var from_ratio := clampf(from_hp / maxhp, 0.0, 1.0)
	_wall_to_ratio = clampf(float(maxi(0, from_hp - damage)) / maxhp, 0.0, 1.0)

	_wall = ColorRect.new()
	_wall.color = Color(0.62, 0.62, 0.68)
	_wall.size = Vector2(48, 100)
	_wall.position = _target_pos - _wall.size * 0.5
	_view.add_child(_wall)
	var wname: String = building.territory.name if building.territory != null else "성벽"
	_view.add_child(_label("%s 성벽" % wname, _target_pos + Vector2(-30, 62)))

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.15, 0.15)
	bar_bg.size = WALL_BAR
	bar_bg.position = _target_pos + Vector2(-WALL_BAR.x * 0.5, -86)
	_view.add_child(bar_bg)
	_wall_bar = ColorRect.new()
	_wall_bar.color = Color(0.85, 0.3, 0.25)
	_wall_bar.size = Vector2(WALL_BAR.x * from_ratio, WALL_BAR.y)
	_wall_bar.position = bar_bg.position
	_view.add_child(_wall_bar)

	_spawn_projectile()
	_run()

func _build_base(party) -> void:
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
	var cat := ColorRect.new()
	cat.color = party.token_color
	cat.size = Vector2(44, 30)
	cat.position = _cat_pos - cat.size * 0.5
	_view.add_child(cat)
	_view.add_child(_label("투석기", _cat_pos + Vector2(-24, 26)))

func _spawn_projectile() -> void:
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
	var t := create_tween()
	t.tween_property(_wall_bar, "size:x", WALL_BAR.x * _wall_to_ratio, 0.25)
	var bx := _wall.position.x
	t.parallel().tween_property(_wall, "position:x", bx + 6.0, 0.05)
	t.tween_property(_wall, "position:x", bx, 0.08)
	await t.finished
	await get_tree().create_timer(HOLD_AFTER).timeout
	finished.emit()

## 투사체 위치 — 직선 보간에 포물선(sin) 높이를 얹는다.
func _fly(t: float) -> void:
	var p := _cat_pos.lerp(_target_pos, t)
	p.y -= ARC_HEIGHT * sin(t * PI)
	_projectile.position = p - _projectile.size * 0.5
