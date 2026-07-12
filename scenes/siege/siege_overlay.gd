extends Node2D
## 사다리 시각화 — game.gd의 _ladders를 받아 공격자 셀↔대상 셀 경계에 마커 + 남은 턴을 그린다.
## game.gd가 ladders/terrain을 채우고 사다리 변경 시 queue_redraw()한다. → docs/spec/features/wall.md

var terrain: TileMapLayer
var ladders: Array = []   # game.gd._ladders 참조({building, target_cell, from_cell, faction, countdown})

func _draw() -> void:
	if terrain == null:
		return
	var font := ThemeDB.fallback_font
	for L in ladders:
		var from := terrain.map_to_local(L["from_cell"])
		var to := terrain.map_to_local(L["target_cell"])
		var mid := from.lerp(to, 0.5)   # 맞붙는 면(경계) 근처
		draw_line(from.lerp(to, 0.3), from.lerp(to, 0.7), Color(0.75, 0.6, 0.35), 3.0, true)   # 사다리
		var text: String = "준비" if L["countdown"] <= 0 else "%d" % L["countdown"]
		draw_string(font, mid + Vector2(-8, -6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.5))
