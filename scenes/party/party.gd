class_name Party extends Node2D
## 부대. 맵에서 실제로 움직이는 유닛. 전투·이동력·시야·지휘범위·공격거리는 아키타입(UnitTypes→lang 클래스) 기반.
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
## 멤버 수로 파생하지 않고 명시 저장한다(사상으로 인원이 줄어도 종류는 유지). 카탈로그 생성 시 설정. → docs/spec/data/factions.md
const KIND_HERO := "hero"
const KIND_TROOP := "troop"
var kind := KIND_TROOP

## 병종(아키타입) id. UnitTypes(unit_types.csv)의 병종 id("light_infantry"/"light_archer" …). 일반부대 생성·분할 시 설정.
## 한 부대는 하나의 병종으로 동질하며(병합은 같은 병종끼리만), 병합 가능 판정(can_merge_with)의 기준이다.
## 영웅부대는 설정하지 않아 "". archetype()(스프라이트 세트·클래스 스탯 키)와 별개인 명시 필드. → docs/spec/entities/Party.md 병종
var troop_type := ""

## 이 일반부대가 소속된 영웅부대(Party) 참조. 독립 부대·영웅부대 자신은 null.
## 소속돼도 부대는 독립 토큰으로 자유 이동한다(소속은 메타데이터 — 버프는 미구현). → Party.md 소속(Lord)
var lord = null

# --- 병력 (순수 class+count 모델) ---
## 병력수(HP 풀). 일반부대=병사 수(기본 10), 영웅부대=클래스 HP(UnitTypes.max_hp("hero")). 0이면 전멸.
## 전투 결과(final_soldiers)로 갱신되고, 배지·전투 파워·lang 유닛 병력의 단일 출처.
var soldiers: int = 0
## 부대 지휘관 이름(표시용). 영웅부대=영웅 이름, 일반부대=병종 이름. 개별 Human은 없다(순수 랑그릿사).
var commander_name := ""


# --- 맵 토큰 스프라이트 (→ docs/spec/entities/Party.md 맵 토큰 외형) ---
## 스프라이트 축소 배율 — 100px 프레임을 16px 헥스에 맞춘다(전투씬 몸통≈16px 참조, 맵은 더 작게).
const _SPRITE_SCALE := 0.55
## 스프라이트 세로 오프셋(texel) — 머리를 기준으로 크기를 키우려 발을 원점보다 살짝 아래로 둔다(머리 고정, 아래로 성장).
## (발끝 texel 56이 원점에 딱 오는 값은 -6. 이보다 크게(위로 덜) 두면 발이 내려가고 머리는 유지.)
const _SPRITE_OFFSET_Y := -2.4
## 튜닉에 칠할 세력색을 흰색으로 살짝 섞는 비율(0=원색 그대로, 클수록 옅음). 작은 맵 토큰 채도 확보용.
const _TINT_MIX := 0.15
## 세력색 팀컬러 셰이더 — 붉은 튜닉 존만 token_color로 치환하고 몸통 나머지는 원색 유지(명암 보존). → team_color.gdshader
const _TEAM_SHADER := preload("res://scenes/party/team_color.gdshader")
## 발밑 오버레이(선택/공격 하이라이트 링) 반지름 — 16px 헥스 규모.
const _RING_R := 8.0

## 발밑 그림자 — 전투씬처럼 납작한 타원 3겹(정원 X). (반경x, 반경y) 바깥(옅음)→안쪽(진함).
const _SHADOW := [[4.5, 1.6, 0.10], [3.4, 1.2, 0.15], [2.5, 0.9, 0.20]]
const _SHADOW_Y := 2.5   # 발밑 그림자 세로 위치 — 발이 원점보다 내려간 만큼 함께 내림

## 지휘 배지(▲) — 캐릭터 머리 바로 위에 작은 삼각형. y는 발=원점 기준 음수(위), 반폭·꼭짓점 높이·밑변 깊이.
const _CMD_BADGE_Y := 10.5
const _CMD_BADGE_W := 2.5
const _CMD_BADGE_TOP := 2.5
const _CMD_BADGE_BOT := 1.0

## 인원수 배지 — 발=중심 기준 아래-우측(빈 땅)에 작게. 배경 원 중심·반지름·숫자 폰트 크기(월드).
## 숫자 렌더는 MapText 공용 헬퍼(갈무리14+합성 볼드+슈퍼샘플)가 담당 — 작아도 선명.
const _COUNT_BADGE_POS := Vector2(4, 4)
const _COUNT_BADGE_R := 3.0
const _COUNT_BADGE_FS := 4

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
var move_points: int = 0          # 이번 턴 잔여 이동력. reset_turn에서 movement()로 채우고 이동할 때마다 차감. 0이면 이번 턴 이동 끝.
var attacked_this_turn := false   # 이번 턴에 이미 공격했는지. true면 이동·공격 모두 끝.
var waited := false               # 이번 턴 [대기]로 강제 소진했는지. 공격 불가로 만들되 흐림엔 안 건다(E 배지만). reset_turn에서 리셋.
## 영웅부대 지휘 설정(하위부대 대상, 턴 지속 — reset_turn에서 안 바뀜). → docs/spec/features/squad-stance.md
var command_follow := false       # true=따라옴(하위부대 자동 추종), false=직접명령.
var command_engage := false       # true=전투우선(따라오다 사거리 적 교전), false=전투회피. 따라옴일 때만 의미.
## 지난 이동에서 찍었지만 아직 도달 못 한 목적지(범위 밖 최대 전진). 없으면 (-1,-1). 턴 지속. → docs/spec/features/selection-and-movement.md
var move_goal := Vector2i(-1, -1)
## 이번 턴 더 할 게 없는지(이동력 0 + 현재 칸 공격 대상 없음). game.gd가 계산해 설정하는 표시 전용 플래그(맵 "E" 배지).
var exhausted := false

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
## 합쳐도 병력 상한(FactionCatalog.TROOP_SIZE, 10)을 넘지 않을 때만 참(예: 4+6·5+5 가능, 6+5 불가).
func can_merge_with(other) -> bool:
	if other == null:
		return false
	if kind != KIND_TROOP or other.kind != KIND_TROOP:
		return false
	if troop_type != other.troop_type:
		return false
	return soldiers + other.soldiers <= FactionCatalog.TROOP_SIZE

## 이 부대의 아키타입 id(UnitTypes 카탈로그 키). troop_type에 자기 아키타입을 저장한다
## (일반부대=병종, 영웅부대=hero/dark_hero 등). 미지정 영웅부대는 기본 "hero"(하위호환). → unit_types.gd
func archetype() -> String:
	if troop_type != "":
		return troop_type
	return "hero" if kind == KIND_HERO else ""

## 이 부대 병종이 원거리인지 — 클래스 기반(경궁병). 전투·NPC AI 파워/사격 판별에 쓴다(월드맵 근접/원거리 구분은 스프라이트로 드러남). → Party.md
func is_ranged() -> bool:
	return UnitTypes.is_ranged(archetype())

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
	return UnitTypes.command_range(archetype())

## 다른 부대(other)의 병력을 이 부대로 흡수한다(병합). other는 병력 0이 된다(호출부가 제거).
## 이 부대 지휘관 이름은 유지된다. 빈 other면 변화 없음.
func merge_from(other) -> void:
	soldiers += other.soldiers
	other.soldiers = 0
	other.queue_redraw()
	queue_redraw()

## 기본 이동력 = 클래스 이동력(lang mv). → unit_types.gd
func base_movement() -> int:
	return UnitTypes.movement(archetype())

## 부대 이동력 = 클래스 이동력. 이동 범위·NPC 경로·정보 패널에 쓰인다. (공성 삭제로 견인 규칙 제거)
func movement() -> int:
	return base_movement()

## 부대 시야 = 클래스 시야(fog). → unit_types.gd
func vision() -> int:
	return UnitTypes.vision(archetype())

## 부대 공격거리 = 클래스 공격거리(근접 0·원거리 3). → unit_types.gd
func attack_range() -> int:
	return UnitTypes.attack_range(archetype())

## 부대 근접 파워 = 근접 병종이면 클래스 AT × 병력수, 아니면 0(교전 선호 판정·NPC AI). → npc-movement.md
func melee_power() -> int:
	return 0 if UnitTypes.is_ranged(archetype()) else UnitTypes.base_at(archetype()) * soldiers

## 부대 원거리 파워 = 원거리 병종이면 클래스 AT × 병력수, 아니면 0. → npc-movement.md
func ranged_power() -> int:
	return UnitTypes.base_at(archetype()) * soldiers if UnitTypes.is_ranged(archetype()) else 0

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

## "할 것 없음(E)" 표시 플래그를 바꾸고, 값이 달라졌으면 다시 그린다(맵 토큰 "E" 배지). 판정은 game.gd. → selection-and-movement.md
func set_exhausted(value: bool) -> void:
	if exhausted == value:
		return
	exhausted = value
	queue_redraw()

## 이번 턴에 이동 가능한지 = 이동력이 남았으면. 공격 여부와 무관(이동·공격 독립). → turn.md
func can_move() -> bool:
	return move_points > 0

## 이번 턴에 공격 가능한지. 이동만 했으면 아직 가능, 공격했거나 [대기]했으면 불가.
func can_attack() -> bool:
	return not attacked_this_turn and not waited

## 이번 턴에 아직 행동(대기 등)이 가능한지 — 공격/[대기]/행동 종료 전이면 참. 선택 가능 판정에 쓴다.
func can_rest() -> bool:
	return not attacked_this_turn and not waited

## 이동력을 cost만큼 차감한다(0 미만으로 내려가지 않음). 다중 클릭 이동·ESC 정지가 실제 이동한 누적비용만큼 부른다. 흐리게 다시 그린다.
func spend_movement(cost: int) -> void:
	move_points = maxi(0, move_points - cost)
	queue_redraw()

## 이동력을 0으로 만들어 이번 턴 이동을 끝낸다. NPC 1회 이동·공격 접근처럼 "더 못 움직임"을 확정할 때 쓴다. 흐리게 다시 그린다.
func mark_moved() -> void:
	if move_points == 0:
		return
	move_points = 0
	queue_redraw()

## 공격 완료 표시(그 부대의 행동 종료). 흐리게 다시 그린다.
func mark_attacked() -> void:
	if attacked_this_turn:
		return
	attacked_this_turn = true
	queue_redraw()

## [대기]: 남은 이동력과 공격 기회를 모두 포기하고 이번 턴을 끝낸다(강제 소진). 흐림 대신 E 배지로만 표시(공격 후 흐림과 구분). 다음 턴 reset_turn으로 복원. → turn.md
func wait() -> void:
	move_points = 0
	waited = true
	queue_redraw()

## 턴 종료(및 생성 시) 호출. 이동력을 movement()로 채우고 공격·[대기] 상태를 리셋한 뒤 불투명하게 다시 그린다.
func reset_turn() -> void:
	move_points = movement()
	attacked_this_turn = false
	waited = false
	queue_redraw()

## 병종 idle 스프라이트 자식을 만든다(빈 프레임). 아키타입은 아직 미정이라 _draw에서 맞춘다.
func _ready() -> void:
	# 부모 캔버스(_draw)도 NEAREST — draw_string(인원 배지 숫자) 글리프가 줌 확대 시 흐려지지 않게.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	# 부모(_draw) 오버레이(선택 링·지휘 배지·인원 배지)가 스프라이트 위에 오도록 스프라이트를 뒤로 보낸다.
	_sprite.show_behind_parent = true
	_sprite.scale = Vector2(_SPRITE_SCALE, _SPRITE_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 축소해도 픽셀 선명(전투 화면과 동일, Linear면 흐릿)
	# 머리 고정·아래로 성장 오프셋(_SPRITE_OFFSET_Y). 발은 원점보다 살짝 아래.
	_sprite.offset = Vector2(0, _SPRITE_OFFSET_Y)
	# 팀컬러 셰이더 머티리얼(부대마다 team_color가 달라 인스턴스별로 둔다). 세력색은 _sync_sprite에서 갱신.
	var mat := ShaderMaterial.new()
	mat.shader = _TEAM_SHADER
	_sprite.material = mat
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
	# 세력색은 셰이더가 튜닉 존만 치환(몸통 나머지는 원색). modulate는 이동/공격 페이드(알파)에만 쓴다.
	var mat := _sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("team_color", token_color.lerp(Color.WHITE, _TINT_MIX))
	_sprite.modulate = Color(1, 1, 1, a)
	_sprite.show()

func _draw() -> void:
	if soldiers <= 0:
		if _sprite != null:
			_sprite.hide()   # 병력 0(전멸)이면 스프라이트도 숨긴다 — "사라짐".
		return

	# 이동력을 다 썼고 공격까지 마쳤으면(이번 턴 더 할 게 없으면) 전체를 반투명하게.
	var a := _MOVED_ALPHA if (move_points == 0 and attacked_this_turn) else 1.0

	# 병종 스프라이트(몸통)를 현재 상태에 맞춘다. 오버레이는 그 위/아래로 캔버스에 얹는다.
	_sync_sprite(a)

	# 발밑 그림자 — 전투씬처럼 납작한 타원 3겹(정원 X, 소프트 엣지 근사).
	for layer in _SHADOW:
		_draw_ellipse(Vector2(0, _SHADOW_Y), layer[0], layer[1], Color(0, 0, 0, layer[2] * a))

	# NPC 공격 연출 하이라이트(공격자·대상 발밑 링). 선택 링과 별개, 살짝 더 크게.
	# 이동/공격 fade(a)를 곱하지 않는다 — 주의를 끄는 신호라 mark_attacked 후에도 선명해야 한다. → npc-movement.md
	if highlight.a > 0.0:
		MapDraw.ring(self, Vector2.ZERO, _RING_R * 1.25, highlight, 1.5)

	# 선택되면 발밑에 강조 링.
	if selected:
		MapDraw.ring(self, Vector2.ZERO, _RING_R, Color(1.0, 0.95, 0.4, a), 1.25)

	# 지휘 범위 버프 중이면 머리 위에 작은 금색 갈매기(▲) 배지. → command-range.md
	if command_buffed:
		var gold := Color(1.0, 0.85, 0.2, a)
		var ty := -_CMD_BADGE_Y   # 머리 위(작게·가깝게)
		MapDraw.polygon(self, PackedVector2Array([
			Vector2(0, ty - _CMD_BADGE_TOP),
			Vector2(_CMD_BADGE_W, ty + _CMD_BADGE_BOT),
			Vector2(-_CMD_BADGE_W, ty + _CMD_BADGE_BOT),
		]), gold)

	# 일반부대면 헥스 아래쪽(빈 땅)에 남은 인원수 배지(어두운 배경 원 + 흰 숫자). → Party.md
	if shows_member_count():
		var bpos := _COUNT_BADGE_POS   # 발 오른쪽·아래(헥스 안)
		MapDraw.disc(self, bpos, _COUNT_BADGE_R, Color(0.1, 0.08, 0.05, 0.85 * a))
		# 숫자는 MapText(갈무리14+볼드+슈퍼샘플)로 선명하게. baseline을 원 중앙에 맞춤(fs*0.36).
		MapText.draw_centered(self, str(soldiers), bpos.x, bpos.y + _COUNT_BADGE_FS * 0.36, _COUNT_BADGE_FS, Color(1, 1, 1, a))

	# 이번 턴 더 할 게 없으면(game.gd 판정) 인원 배지 왼쪽에 회색 "E"(플레이어 부대만 set_exhausted). 페이드(a) 무관하게 선명. → selection-and-movement.md
	if exhausted:
		MapText.draw_centered(self, "E", -_COUNT_BADGE_POS.x, _COUNT_BADGE_POS.y + _COUNT_BADGE_FS * 0.36, _COUNT_BADGE_FS, Color(0.75, 0.75, 0.75, 0.95))

## 납작한 타원 채우기(중심 c, 반경 rx·ry) — 단위원을 (rx,ry)로 스케일해 그린 뒤 변환 원복. 전투씬 그림자와 동일 방식.
func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(rx, ry))
	draw_circle(Vector2.ZERO, 1.0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
