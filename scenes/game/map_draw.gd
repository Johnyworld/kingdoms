class_name MapDraw
## 지도 위 world-space 벡터 오버레이(선택/하이라이트 링·이동 경로선·공격 표식 등)를
## 기본 카메라 3배 줌(16px→48px)에서 뭉개지지 않게 그리는 공용 헬퍼. [MapText]의 벡터판(짝).
##
## draw_arc/draw_line/draw_polyline의 안티에일리어싱 feather·세그먼트는 **로컬 좌표 해상도** 기준이라,
## 16px 헥스 월드에 작게(반경 8·선폭 2) 그린 뒤 카메라로 3~8배 확대하면 feather까지 같이 커져 계단처럼 깨진다.
## → 좌표·선폭·반경을 SUPERSAMPLE배로 키워 그린 뒤 draw_set_transform으로 1/배 축소한다(고해상도 래스터 후 축소).
## 화면상 크기·위치는 그대로면서 feather는 1/배로 얇아지고 세그먼트가 촘촘해져 확대에도 선명하다.
##
## ⚠️ 벡터 도형이라 texture_filter와 무관(텍스처 없음). 텍스트는 [MapText]를 쓴다.
## → docs/spec/features/selection-and-movement.md, docs/spec/entities/Party.md

const SUPERSAMPLE := 3

## 링(테두리 원) — 중심 center, 반경 radius, 색 color, 선폭 width. 선택/하이라이트 발밑 링용.
static func ring(ci: CanvasItem, center: Vector2, radius: float, color: Color, width: float, segments := 64) -> void:
	var ss := float(SUPERSAMPLE)
	ci.draw_set_transform(center, 0.0, Vector2.ONE / ss)
	ci.draw_arc(Vector2.ZERO, radius * ss, 0.0, TAU, segments, color, width * ss, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 채운 원 — 중심 center, 반경 radius. 인원수 배지 배경 등.
static func disc(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var ss := float(SUPERSAMPLE)
	ci.draw_set_transform(center, 0.0, Vector2.ONE / ss)
	ci.draw_circle(Vector2.ZERO, radius * ss, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 폴리라인 — world-space 점들을 잇는 선(이동 경로선 등). points는 부대 노드 로컬(=월드) 좌표.
static func polyline(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var ss := float(SUPERSAMPLE)
	var scaled := PackedVector2Array()
	scaled.resize(points.size())
	for i in points.size():
		scaled[i] = points[i] * ss
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ss)
	ci.draw_polyline(scaled, color, width * ss, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 선분 — a에서 b로. 공격 표식(칼/화살)의 획.
static func segment(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var ss := float(SUPERSAMPLE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ss)
	ci.draw_line(a * ss, b * ss, color, width * ss, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 채운 다각형 — 지휘 버프 갈매기(▲) 배지 등 작은 도형의 가장자리를 확대에도 선명하게.
static func polygon(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var ss := float(SUPERSAMPLE)
	var scaled := PackedVector2Array()
	scaled.resize(points.size())
	for i in points.size():
		scaled[i] = points[i] * ss
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ss)
	ci.draw_colored_polygon(scaled, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
