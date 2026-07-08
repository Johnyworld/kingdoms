class_name Party extends Node2D
## 부대. 맵에서 실제로 움직이는 유닛으로, 여러 Human을 멤버로 거느린다.
## 이동력은 멤버 중 최소(가장 느린 멤버), 시야는 멤버 중 최대를 따른다.
## 맵 토큰으로서 위치·선택·이번 턴 이동 상태·마커 그리기를 담당한다(예전 Human의 역할 이관).
## 지금은 임시 플레이스홀더(원형 마커)로 그려지며, 이후 스프라이트로 교체한다.

# --- 정체 ---
## 이름. 엔진 내장 프로퍼티 `name`(노드 이름)과 충돌하므로 별도 변수로 둔다.
@export var party_name := ""

## 맵 토큰 몸통 색. 플레이어는 기본 금색, NPC 부대는 소속 세력 색으로 설정한다.
@export var token_color := Color(0.92, 0.78, 0.35)

# --- 멤버 ---
var members: Array = []   # 이 부대에 속한 Human 목록.
var commander = null      # 부대를 이끄는 Human(멤버 중 하나). 편성 UI가 없어 코드로 지정한다.

const _RADIUS := 12.0

# 이번 턴에 이동을 마치면 반투명하게 그릴 때 곱할 알파.
const _MOVED_ALPHA := 0.4

var selected := false
var moved_this_turn := false   # 이번 턴에 이미 이동했는지. true면 재선택·재이동 불가.

## 멤버를 부대에 추가한다. 이미 포함된 멤버는 중복 추가하지 않는다.
func add_member(human) -> void:
	if human in members:
		return
	members.append(human)

## 지휘관 이름. 지휘관이 없으면(null) "—". 부대 일람(party_roster.gd) 표시에 사용.
func commander_name() -> String:
	return commander.human_name if commander else "—"

## 부대 이동력 = 멤버 이동력의 최소값(가장 느린 멤버). 멤버 없으면 0.
func movement() -> int:
	if members.is_empty():
		return 0
	var m: int = members[0].movement
	for h in members:
		m = mini(m, h.movement)
	return m

## 부대 시야 = 멤버 시야의 최대값. 멤버 없으면 0.
func vision() -> int:
	if members.is_empty():
		return 0
	var v: int = members[0].vision
	for h in members:
		v = maxi(v, h.vision)
	return v

## 선택 상태를 바꾸고 다시 그린다.
func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

## 이번 턴에 이동 가능한지(아직 이동 안 함).
func can_move() -> bool:
	return not moved_this_turn

## 이동 완료 표시. 흐리게(반투명) 다시 그린다.
func mark_moved() -> void:
	if moved_this_turn:
		return
	moved_this_turn = true
	queue_redraw()

## 턴 종료 시 호출. 이동 상태를 리셋하고 불투명하게 다시 그린다.
func reset_turn() -> void:
	if not moved_this_turn:
		return
	moved_this_turn = false
	queue_redraw()

func _draw() -> void:
	# 이번 턴에 이동을 마쳤으면 전체를 반투명하게.
	var a := _MOVED_ALPHA if moved_this_turn else 1.0

	# 선택되면 발밑에 강조 링을 먼저 그린다.
	if selected:
		draw_arc(Vector2(0, 4), _RADIUS * 1.4, 0.0, TAU, 40, Color(1.0, 0.95, 0.4, a), 3.0, true)

	# 임시 플레이스홀더: 발밑 그림자 + 몸통 원(token_color) + 외곽선.
	draw_circle(Vector2(0, 4), _RADIUS * 0.9, Color(0, 0, 0, 0.25 * a))
	var body := token_color
	body.a *= a
	draw_circle(Vector2.ZERO, _RADIUS, body)
	draw_arc(Vector2.ZERO, _RADIUS, 0.0, TAU, 32, Color(0.25, 0.18, 0.08, a), 2.0, true)
