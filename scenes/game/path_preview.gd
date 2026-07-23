class_name PathPreview
extends Node2D
## 선택 중 호버한 칸까지의 이동 경로 선. 이동력이 닿는 구간은 파랑, 넘어서는 구간은 빨강.
## 적 위 호버면 경로 끝(공격 위치)에 칼(근접)/화살(원거리) 표식을 그린다(에셋 없이 코드 도형 — 추후 PNG 교체).
## → docs/spec/features/selection-and-movement.md

const BLUE := Color(0.35, 0.7, 1.0, 0.95)     # 이번 턴 이동력이 닿는 구간
const RED := Color(1.0, 0.35, 0.3, 0.95)       # 이동력을 넘어서는 구간
const YELLOW := Color(1.0, 0.85, 0.25, 0.9)    # 기억된 이동 목표선(계속 이동)
const WIDTH := 2.0
const MARKER_R := 5.0                          # 공격 표식 크기(월드)

var _terrain: TileMapLayer
var _blue: PackedVector2Array = PackedVector2Array()
var _red: PackedVector2Array = PackedVector2Array()
var _marker := ""                              # "" | "melee"(칼) | "ranged"(화살)
var _marker_pos := Vector2.ZERO
var _goal: PackedVector2Array = PackedVector2Array()   # 노란 이동 목표선(호버선과 독립 레이어)

func setup(terrain: TileMapLayer) -> void:
	_terrain = terrain

## 경로 선(파랑/빨강 폴리라인)과 공격 표식을 갱신하고 다시 그린다.
func show_path(blue: PackedVector2Array, red: PackedVector2Array, marker := "", marker_pos := Vector2.ZERO) -> void:
	_blue = blue
	_red = red
	_marker = marker
	_marker_pos = marker_pos
	queue_redraw()

## 호버 선·표식을 지운다(노란 목표선은 유지 — clear_goal로 따로 지움).
func clear() -> void:
	_blue = PackedVector2Array()
	_red = PackedVector2Array()
	_marker = ""
	queue_redraw()

## 노란 이동 목표선(현재→목표 전체 경로)을 그린다(호버선과 독립). → squad-stance.md 계속 이동
func show_goal(points: PackedVector2Array) -> void:
	_goal = points
	queue_redraw()

## 노란 목표선을 지운다(선택 해제 시).
func clear_goal() -> void:
	_goal = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if _goal.size() >= 2:
		draw_polyline(_goal, YELLOW, WIDTH, true)   # 목표선(아래 레이어)
	if _blue.size() >= 2:
		draw_polyline(_blue, BLUE, WIDTH, true)
	if _red.size() >= 2:
		draw_polyline(_red, RED, WIDTH, true)
	if _marker == "melee":
		_draw_sword(_marker_pos)
	elif _marker == "ranged":
		_draw_arrow(_marker_pos)

## 칼 표식 — 세로 날 + 가로 코등이(간단한 십자형 검).
func _draw_sword(c: Vector2) -> void:
	var col := Color(1, 1, 1, 0.95)
	draw_line(c + Vector2(0, -MARKER_R), c + Vector2(0, MARKER_R), col, WIDTH, true)          # 날
	draw_line(c + Vector2(-MARKER_R * 0.6, MARKER_R * 0.4), c + Vector2(MARKER_R * 0.6, MARKER_R * 0.4), col, WIDTH, true)  # 코등이

## 화살 표식 — 촉(∧) + 대(짧은 사선).
func _draw_arrow(c: Vector2) -> void:
	var col := Color(1, 1, 1, 0.95)
	var tip := c + Vector2(0, -MARKER_R)
	draw_line(tip, tip + Vector2(-MARKER_R * 0.6, MARKER_R * 0.7), col, WIDTH, true)
	draw_line(tip, tip + Vector2(MARKER_R * 0.6, MARKER_R * 0.7), col, WIDTH, true)
	draw_line(tip, c + Vector2(0, MARKER_R), col, WIDTH, true)   # 대
