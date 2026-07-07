extends Node2D
## 주인공 캐릭터. 능력치를 보유하고 맵 위에 표시된다.
## 지금은 임시 플레이스홀더(원형 마커)로 그려지며, 이후 스프라이트로 교체한다.

# --- 능력치 (초기값) ---
@export var strength := 8      # 힘
@export var wisdom := 5        # 지혜
@export var agility := 6       # 민첩
@export var charm := 10        # 매력
@export var luck := 8          # 행운
@export var movement := 5      # 이동력
@export var vision := 5        # 시야
@export var leadership := 7    # 지휘력
@export var eloquence := 9     # 화술
@export var diligence := 5     # 성실함
@export var sensitivity := 8   # 예민함

# --- 자원 ---
@export var hit_points := 20   # 히트포인트
@export var stamina := 20      # 스태미나
@export var morale := 20       # 사기

const _RADIUS := 12.0

# 이번 턴에 이동을 마치면 반투명하게 그릴 때 곱할 알파.
const _MOVED_ALPHA := 0.4

var selected := false
var moved_this_turn := false   # 이번 턴에 이미 이동했는지. true면 재선택·재이동 불가.

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

	# 임시 플레이스홀더: 발밑 그림자 + 몸통 원 + 외곽선.
	draw_circle(Vector2(0, 4), _RADIUS * 0.9, Color(0, 0, 0, 0.25 * a))
	draw_circle(Vector2.ZERO, _RADIUS, Color(0.92, 0.78, 0.35, a))
	draw_arc(Vector2.ZERO, _RADIUS, 0.0, TAU, 32, Color(0.25, 0.18, 0.08, a), 2.0, true)
