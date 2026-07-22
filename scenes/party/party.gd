class_name Party extends Node2D
## 부대. 맵에서 실제로 움직이는 유닛. 전투·이동력·시야·지휘범위·공격거리는 아키타입(GameUnits→lang 클래스) 기반.
## (멤버 Human 목록은 병력수/명단으로 남아 있으나 스탯은 미사용 — 순수 랑그릿사 유닛 모델 전환 중, M3에서 정리.)
## 맵 토큰으로서 위치·선택·이번 턴 이동 상태·마커 그리기를 담당한다(예전 Human의 역할 이관).
## 몸통은 병종별 idle 스프라이트(AnimatedSprite2D, UnitSprites 세트)로 그리고, 선택 링·인원 배지 등 오버레이만 _draw에서 캔버스로 얹는다.

# --- 정체 ---
## 이름. 엔진 내장 프로퍼티 `name`(노드 이름)과 충돌하므로 별도 변수로 둔다.
@export var party_name := ""

## 소속 세력 이름. 정보 패널에 표시해 아군/적을 구분한다. 카탈로그 생성 시 설정한다.
@export var faction_name := ""

## 맵 토큰 몸통 색. 플레이어는 기본 금색, NPC 부대는 소속 세력 색으로 설정한다.
@export var token_color := Color(0.92, 0.78, 0.35)

# --- 종류(랑그릿사식 이분화) ---
## 부대 종류. "hero"=영웅부대(지휘관 1명 단독), "troop"=일반부대(동일 능력치 병사 다수, 기본 10명).
## 멤버 수로 파생하지 않고 명시 저장한다(사상으로 인원이 줄어도 종류는 유지). 카탈로그 생성 시 설정. → docs/spec/data/units.md
const KIND_HERO := "hero"
const KIND_TROOP := "troop"
var kind := KIND_TROOP

## 병종(아키타입) id. UnitTypes.TROOPS의 id("light_infantry"/"light_archer" …). 일반부대 생성·분할 시 설정.
## 한 부대는 하나의 병종으로 동질하며(병합은 같은 병종끼리만), 병합 가능 판정(can_merge_with)의 기준이다.
## 영웅부대는 설정하지 않아 "". archetype()(스프라이트 세트·클래스 스탯 키)와 별개인 명시 필드. → docs/spec/entities/Party.md 병종
var troop_type := ""

## 이 일반부대가 소속된 영웅부대(Party) 참조. 독립 부대·영웅부대 자신은 null.
## 소속돼도 부대는 독립 토큰으로 자유 이동한다(소속은 메타데이터 — 버프는 미구현). → Party.md 소속(Lord)
var lord = null

# --- 병력 (순수 class+count 모델) ---
## 병력수(HP 풀). 일반부대=병사 수(기본 10), 영웅부대=클래스 HP(GameUnits.max_hp("hero")). 0이면 전멸.
## 전투 결과(final_soldiers)로 갱신되고, 배지·전투 파워·lang 유닛 병력의 단일 출처.
var soldiers: int = 0
## 부대 지휘관 이름(표시용). 영웅부대=영웅 이름, 일반부대=병종 이름. 개별 Human은 없다(순수 랑그릿사).
var commander_name := ""


# --- 맵 토큰 스프라이트 (→ docs/spec/entities/Party.md 맵 토큰 외형) ---
## 스프라이트 축소 배율 — 100px 프레임을 헥스 타일(64×46)에 맞춘다.
const _SPRITE_SCALE := 0.6
## 프레임 내 발끝 texel(idle 기준). centered 스프라이트를 이만큼 위로 올려 발을 칸 중심에 세운다.
const _FOOT_TEXEL := 56
## 세력색 틴트를 흰색으로 섞는 비율(0=원색, 1=세력색 그대로). 스프라이트 가독성 확보용.
const _TINT_MIX := 0.55
## 발밑 오버레이(선택/공격 하이라이트 링·그림자) 반지름.
const _RING_R := 14.0
## 머리 위 지휘 배지(▲) 세로 위치(발=원점 기준 음수).
const _HEAD_Y := 28.0

# 이번 턴에 이동을 마치면 반투명하게 그릴 때 곱할 알파.
const _MOVED_ALPHA := 0.4

## 병종 idle 스프라이트(자식). _ready에서 빈 채로 만들고, _draw에서 아키타입에 맞춰 프레임·틴트를 맞춘다.
var _sprite: AnimatedSprite2D = null
## 현재 스프라이트에 적용된 아키타입 — 바뀔 때만 SpriteFrames를 교체(64부대 매프레임 재빌드 방지).
var _sprite_key := ""

var selected := false
## 이 부대가 소속 영웅(lord)의 지휘 범위 안이라 전투 버프 중인지. 맵 배지·전투 배율의 출처(game.gd가 갱신). → command-range.md
var command_buffed := false
## 토큰 테두리 강조색(알파 0이면 없음). NPC 공격 연출에서 공격자·대상을 잠깐 표시(game.gd `_npc_engage`). → npc-movement.md
var highlight := Color(0, 0, 0, 0)
var moved_this_turn := false      # 이번 턴에 이미 이동했는지. true면 재이동 불가(공격은 아직 가능).
var attacked_this_turn := false   # 이번 턴에 이미 공격했는지. true면 이동·공격 모두 끝.

## 영웅부대인지(kind == KIND_HERO). 일반부대는 거짓.
func is_hero() -> bool:
	return kind == KIND_HERO

## 토큰 우하단에 남은 병력수 배지를 그릴지 — 일반부대이고 병력이 있을 때만(영웅부대는 단독이라 생략). → Party.md
func shows_member_count() -> bool:
	return kind == KIND_TROOP and soldiers > 0

## 전투 파워(교전/후퇴 판단). = 병력수(HP 풀). 부상하면 낮아진다. → npc-movement.md
func power() -> int:
	return soldiers

## other를 이 부대에 병합할 수 있는지 — 병합 가능 판정의 단일 출처. → party-composition.md
## 둘 다 일반부대(KIND_TROOP)이고(영웅부대는 어느 쪽이든 병합 없음) 같은 병종(troop_type)이며,
## 합쳐도 병력 상한(UnitTypes.TROOP_SIZE, 10)을 넘지 않을 때만 참(예: 4+6·5+5 가능, 6+5 불가).
func can_merge_with(other) -> bool:
	if other == null:
		return false
	if kind != KIND_TROOP or other.kind != KIND_TROOP:
		return false
	if troop_type != other.troop_type:
		return false
	return soldiers + other.soldiers <= UnitTypes.TROOP_SIZE

## 이 부대의 아키타입 id(GameUnits 카탈로그 키). 영웅부대는 "hero", 그 외는 병종(troop_type). → game_units.gd
func archetype() -> String:
	return "hero" if kind == KIND_HERO else troop_type

## 이 부대 병종이 원거리인지 — 클래스 기반(경궁병). 전투·NPC AI 파워/사격 판별에 쓴다(월드맵 근접/원거리 구분은 스프라이트로 드러남). → Party.md
func is_ranged() -> bool:
	return GameUnits.is_ranged(archetype())

## 소속 영웅부대가 있는지(lord != null).
func has_lord() -> bool:
	return lord != null

## 소속 영웅부대의 지휘관 이름. lord가 없으면 "—". → Party.md 소속(Lord)
func lord_name() -> String:
	return lord.commander_name if lord != null else "—"

## 소속 영웅부대를 지정한다(소속 UI의 소속 확정 단일 출처). → party-lord.md
func set_lord(hero) -> void:
	lord = hero

## 소속을 해제한다(독립). → party-lord.md
func clear_lord() -> void:
	lord = null

## 영웅부대의 지휘 반경(헥스). 클래스 기반(lang cmd_range). → command-range.md
func command_range() -> int:
	return GameUnits.command_range(archetype())

## 다른 부대(other)의 병력을 이 부대로 흡수한다(병합). other는 병력 0이 된다(호출부가 제거).
## 이 부대 지휘관 이름은 유지된다. 빈 other면 변화 없음.
func merge_from(other) -> void:
	soldiers += other.soldiers
	other.soldiers = 0
	other.queue_redraw()
	queue_redraw()

## 기본 이동력 = 클래스 이동력(lang mv). → game_units.gd
func base_movement() -> int:
	return GameUnits.movement(archetype())

## 부대 이동력 = 클래스 이동력. 이동 범위·NPC 경로·정보 패널에 쓰인다. (공성 삭제로 견인 규칙 제거)
func movement() -> int:
	return base_movement()

## 부대 시야 = 클래스 시야(fog). → game_units.gd
func vision() -> int:
	return GameUnits.vision(archetype())

## 부대 공격거리 = 클래스 공격거리(근접 0·원거리 3). → game_units.gd
func attack_range() -> int:
	return GameUnits.attack_range(archetype())

## 부대 근접 파워 = 근접 병종이면 클래스 AT × 병력수, 아니면 0(교전 선호 판정·NPC AI). → npc-movement.md
func melee_power() -> int:
	return 0 if GameUnits.is_ranged(archetype()) else GameUnits.base_at(archetype()) * soldiers

## 부대 원거리 파워 = 원거리 병종이면 클래스 AT × 병력수, 아니면 0. → npc-movement.md
func ranged_power() -> int:
	return GameUnits.base_at(archetype()) * soldiers if GameUnits.is_ranged(archetype()) else 0

## 토큰 테두리 강조색을 바꾸고 다시 그린다(알파 0 = 없음). NPC 공격 연출. → npc-movement.md
func set_highlight(color: Color) -> void:
	if highlight == color:
		return
	highlight = color
	queue_redraw()

## 선택 상태를 바꾸고 다시 그린다.
func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

## 이번 턴에 이동 가능한지. 이동했거나 공격했으면(행동 종료) 불가.
func can_move() -> bool:
	return not moved_this_turn and not attacked_this_turn

## 이번 턴에 공격 가능한지. 이동만 했으면 아직 가능, 공격했으면 불가.
func can_attack() -> bool:
	return not attacked_this_turn

## 이번 턴에 아직 행동(대기 등)이 가능한지 — 공격/행동 종료 전이면 참. 선택 가능 판정에 쓴다.
func can_rest() -> bool:
	return not attacked_this_turn

## 이동 완료 표시. 흐리게(반투명) 다시 그린다.
func mark_moved() -> void:
	if moved_this_turn:
		return
	moved_this_turn = true
	queue_redraw()

## 공격 완료 표시(그 부대의 행동 종료). 흐리게 다시 그린다.
func mark_attacked() -> void:
	if attacked_this_turn:
		return
	attacked_this_turn = true
	queue_redraw()

## 이동 되돌리기. moved_this_turn을 해제해 다시 이동 가능하게 한다(위치 복원은 game.gd). 다시 그린다.
func undo_move() -> void:
	moved_this_turn = false
	queue_redraw()

## 턴 종료 시 호출. 이동·공격 상태를 리셋하고 불투명하게 다시 그린다.
func reset_turn() -> void:
	if not moved_this_turn and not attacked_this_turn:
		return
	moved_this_turn = false
	attacked_this_turn = false
	queue_redraw()

## 병종 idle 스프라이트 자식을 만든다(빈 프레임). 아키타입은 아직 미정이라 _draw에서 맞춘다.
func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	# 부모(_draw) 오버레이(선택 링·지휘 배지·인원 배지)가 스프라이트 위에 오도록 스프라이트를 뒤로 보낸다.
	_sprite.show_behind_parent = true
	_sprite.scale = Vector2(_SPRITE_SCALE, _SPRITE_SCALE)
	# 발끝(_FOOT_TEXEL)이 원점(칸 중심)에 오도록 위로 올린다.
	_sprite.offset = Vector2(0, -(_FOOT_TEXEL - UnitSprites.FRAME_PX / 2))
	add_child(_sprite)

## 자식 스프라이트를 현재 아키타입·세력색·페이드에 맞춘다(프레임은 아키타입이 바뀔 때만 교체).
func _sync_sprite(a: float) -> void:
	if _sprite == null:
		return
	var arche := archetype()
	if arche != _sprite_key:
		_sprite.sprite_frames = UnitSprites.idle_frames(arche)
		_sprite_key = arche
		_sprite.play("default")
	elif not _sprite.is_playing():
		_sprite.play("default")
	# 세력색 틴트(흰색으로 섞어 밝기 유지) + 이동/공격 페이드.
	var tint := token_color.lerp(Color.WHITE, _TINT_MIX)
	tint.a = a
	_sprite.modulate = tint
	_sprite.show()

func _draw() -> void:
	if soldiers <= 0:
		if _sprite != null:
			_sprite.hide()   # 병력 0(전멸)이면 스프라이트도 숨긴다 — "사라짐".
		return

	# 이번 턴에 이동·공격 중 하나라도 했으면 전체를 반투명하게.
	var a := _MOVED_ALPHA if (moved_this_turn or attacked_this_turn) else 1.0

	# 병종 스프라이트(몸통)를 현재 상태에 맞춘다. 오버레이는 그 위/아래로 캔버스에 얹는다.
	_sync_sprite(a)

	# 발밑 그림자(스프라이트를 지면에 앉힌다).
	draw_circle(Vector2(0, 2), _RING_R * 0.5, Color(0, 0, 0, 0.22 * a))

	# NPC 공격 연출 하이라이트(공격자·대상 발밑 링). 선택 링과 별개, 살짝 더 크게.
	# 이동/공격 fade(a)를 곱하지 않는다 — 주의를 끄는 신호라 mark_attacked 후에도 선명해야 한다. → npc-movement.md
	if highlight.a > 0.0:
		draw_arc(Vector2.ZERO, _RING_R * 1.25, 0.0, TAU, 40, highlight, 3.0, true)

	# 선택되면 발밑에 강조 링.
	if selected:
		draw_arc(Vector2.ZERO, _RING_R, 0.0, TAU, 40, Color(1.0, 0.95, 0.4, a), 2.5, true)

	# 지휘 범위 버프 중이면 머리 위에 작은 금색 갈매기(▲) 배지. → command-range.md
	if command_buffed:
		var gold := Color(1.0, 0.85, 0.2, a)
		var ty := -_HEAD_Y   # 머리 위
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, ty - 5),
			Vector2(5, ty + 3),
			Vector2(-5, ty + 3),
		]), gold)

	# 일반부대면 우하단에 남은 인원수 배지(어두운 배경 원 + 흰 숫자). → Party.md
	if shows_member_count():
		var bpos := Vector2(11, 2)   # 발 오른쪽
		draw_circle(bpos, 7.0, Color(0.1, 0.08, 0.05, 0.85 * a))
		var font := ThemeDB.fallback_font
		var fs := 11
		var txt := str(soldiers)
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, bpos + Vector2(-tw * 0.5, fs * 0.36), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
