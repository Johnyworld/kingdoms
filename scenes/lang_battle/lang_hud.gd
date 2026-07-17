extends Control
## 하단 전투 정보 HUD — 스펙 §3.2/§4. 3분할 패널(공격측 / 중앙 / 방어측).
## 큰 금색 숫자 = 병력(병사 아이콘 수), 작은 숫자 = AT/DF, 중앙 = 명중률·VS.
## 원작의 금빛 장식 프레임을 도형으로 근사한다(원본 타일 재배포 지양).

const PANEL_H := 312.0
const W := 1920.0

# 팔레트
const GOLD := Color(0.82, 0.66, 0.28)
const GOLD_HI := Color(0.98, 0.86, 0.46)
const GOLD_DK := Color(0.45, 0.34, 0.12)
const NAVY := Color(0.09, 0.11, 0.30)
const NAVY_DK := Color(0.05, 0.06, 0.18)
const REDBOX := Color(0.62, 0.16, 0.14)

# 패널 사각형 (로컬 좌표)
var _p_left := Rect2(10, 8, 620, PANEL_H - 16)
var _p_mid := Rect2(646, 8, 628, PANEL_H - 16)
var _p_right := Rect2(1290, 8, 620, PANEL_H - 16)

# 동적 라벨
var _lv := {}      # side -> Label
var _at := {}
var _df := {}
var _count := {}   # 큰 병력 숫자
var _name := {}    # 진영 이름(포트레이트 아래 X, 대신 중앙 상단 사용)
var _portrait := {}
var _mid_title: Label
var _mid_hit_a: Label
var _mid_hit_b: Label

func _ready() -> void:
	custom_minimum_size = Vector2(W, PANEL_H)
	_build_side(0, _p_left, false)
	_build_side(1, _p_right, true)
	_build_mid()

func _make_label(text: String, size: int, col: Color, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _place(l: Label, r: Rect2) -> void:
	l.position = r.position
	l.size = r.size

func _build_side(side: int, p: Rect2, mirror: bool) -> void:
	# 포트레이트 박스
	var port_w := 150.0
	var port_x: float = p.position.x + (p.size.x - port_w - 14.0 if mirror else 14.0)
	var pr := Rect2(port_x, p.position.y + 20, port_w, p.size.y - 40)
	_portrait[side] = pr  # _draw 에서 사용

	# 스탯 열(작은 AT/DF) — 포트레이트 안쪽
	var stat_x: float = port_x + (-150.0 if mirror else port_w + 6.0)
	var lv := _make_label("LV 1", 30, GOLD_HI, 4)
	_place(lv, Rect2(stat_x, p.position.y + 18, 150, 34))
	_lv[side] = lv
	var at := _make_label("0", 40, Color(0.95, 0.95, 0.98), 5)
	_place(at, Rect2(stat_x, p.position.y + 58, 150, 46))
	_at[side] = at
	var df := _make_label("0", 40, Color(0.95, 0.95, 0.98), 5)
	_place(df, Rect2(stat_x, p.position.y + 108, 150, 46))
	_df[side] = df

	# 큰 병력 숫자 — 패널 안쪽 넓은 곳
	var big_x: float = stat_x + (-190.0 if mirror else 150.0)
	var big := _make_label("0", 170, GOLD_HI, 10)
	_place(big, Rect2(big_x, p.position.y + 40, 210, p.size.y - 60))
	_count[side] = big

func _build_mid() -> void:
	var p := _p_mid
	# 상단 이름 박스
	_mid_title = _make_label("VS", 34, Color(1, 0.92, 0.7), 5)
	_place(_mid_title, Rect2(p.position.x + 40, p.position.y + 16, p.size.x - 80, 48))
	# AT / DF 라벨 + 명중률
	var lab_at := _make_label("AT", 30, GOLD_HI, 4)
	_place(lab_at, Rect2(p.position.x, p.position.y + 96, p.size.x, 36))
	var lab_df := _make_label("DF", 30, GOLD_HI, 4)
	_place(lab_df, Rect2(p.position.x, p.position.y + 136, p.size.x, 36))
	# 명중률(양측)
	_mid_hit_a = _make_label("", 34, Color(0.95, 0.95, 0.98), 5)
	_place(_mid_hit_a, Rect2(p.position.x + 30, p.position.y + 96, 140, 40))
	_mid_hit_b = _make_label("", 34, Color(0.95, 0.95, 0.98), 5)
	_place(_mid_hit_b, Rect2(p.position.x + p.size.x - 170, p.position.y + 96, 140, 40))

# ── 외부 세터 ──────────────────────────────────────────────────────────────
func set_side(side: int, level: int, at: int, df: int, count: int) -> void:
	_lv[side].text = "LV %d" % level
	_at[side].text = str(at)
	_df[side].text = str(df)
	_count[side].text = str(count)
	queue_redraw()

func set_count(side: int, count: int) -> void:
	_count[side].text = str(count)

func set_at_df(side: int, at: int, df: int) -> void:
	_at[side].text = str(at)
	_df[side].text = str(df)

func set_title(text: String) -> void:
	_mid_title.text = text

func set_hits(a_hit: int, b_hit: int) -> void:
	_mid_hit_a.text = "%d%%" % a_hit
	_mid_hit_b.text = "%d%%" % b_hit

# ── 장식 프레임 ────────────────────────────────────────────────────────────
func _draw() -> void:
	# 전체 바 배경
	draw_rect(Rect2(0, 0, W, PANEL_H), NAVY_DK)
	draw_rect(Rect2(0, 0, W, 6), GOLD)
	_draw_panel(_p_left)
	_draw_panel(_p_mid)
	_draw_panel(_p_right)
	# 포트레이트 박스
	_draw_portrait(0, false)
	_draw_portrait(1, true)
	# 중앙 이름 박스 배경
	var mt := Rect2(_p_mid.position.x + 30, _p_mid.position.y + 12, _p_mid.size.x - 60, 54)
	draw_rect(mt, REDBOX)
	_draw_bevel(mt, GOLD_HI, GOLD_DK, 3)
	# 중앙 VS 미니 병사
	var cy := _p_mid.position.y + PANEL_H - 96
	var cx := _p_mid.position.x + _p_mid.size.x * 0.5
	_mini_soldier(Vector2(cx - 70, cy), 0)
	_mini_soldier(Vector2(cx + 70, cy), 1)
	draw_string(ThemeDB.fallback_font, Vector2(cx - 22, cy + 12), "VS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 40, GOLD_HI)

func _draw_panel(r: Rect2) -> void:
	draw_rect(r, NAVY)
	_draw_bevel(r, GOLD_HI, GOLD_DK, 4)
	# 이중 금테
	var inner := r.grow(-8)
	draw_rect(inner, Color(0, 0, 0, 0), false, 2.0)
	draw_rect(inner, GOLD, false, 2.0)

func _draw_bevel(r: Rect2, hi: Color, dk: Color, w: float) -> void:
	# 위/왼쪽 밝게, 아래/오른쪽 어둡게 (양각)
	draw_line(r.position, r.position + Vector2(r.size.x, 0), hi, w)
	draw_line(r.position, r.position + Vector2(0, r.size.y), hi, w)
	draw_line(r.position + Vector2(0, r.size.y), r.position + r.size, dk, w)
	draw_line(r.position + Vector2(r.size.x, 0), r.position + r.size, dk, w)

func _draw_portrait(side: int, _mirror: bool) -> void:
	var r: Rect2 = _portrait[side]
	draw_rect(r, Color(0.12, 0.14, 0.22))
	_draw_bevel(r, GOLD_HI, GOLD_DK, 3)
	# 플레이스홀더 얼굴
	var body := Color(0.31, 0.45, 0.78) if side == 0 else Color(0.72, 0.26, 0.24)
	var cx := r.position.x + r.size.x * 0.5
	draw_rect(Rect2(r.position.x + 20, r.position.y + r.size.y - 70,
		r.size.x - 40, 70), body)  # 어깨/갑옷
	draw_circle(Vector2(cx, r.position.y + r.size.y - 78), 40, Color(0.86, 0.72, 0.56))  # 얼굴
	draw_circle(Vector2(cx, r.position.y + r.size.y - 108), 44, body)  # 투구
	draw_arc(Vector2(cx, r.position.y + r.size.y - 88), 44, PI, TAU, 16, GOLD_HI, 3.0)

func _mini_soldier(pos: Vector2, side: int) -> void:
	var body := Color(0.4, 0.55, 0.9) if side == 0 else Color(0.85, 0.35, 0.32)
	draw_rect(Rect2(pos.x - 10, pos.y - 8, 20, 26), body)
	draw_circle(pos + Vector2(0, -16), 9, Color(0.86, 0.72, 0.56))
