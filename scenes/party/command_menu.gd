class_name CommandMenu
extends Node
## [지휘] 메뉴. 영웅부대(Party KIND_HERO)의 하위부대 지휘 설정을 지속 토글한다. → docs/spec/features/squad-stance.md
## 추종: [따라옴|직접명령](command_follow), 전투: [전투우선|전투회피](command_engage). 현재 값인 쪽 버튼은 비활성(선택 표시).
## 오버레이 chrome(배경·제목·X·ESC·지도 입력 차단)은 공용 Modal에 위임하고, 콘텐츠(토글 2줄)만 주입한다.

signal changed   # 설정을 바꾼 뒤 방출. game.gd가 정보 패널([지휘] 버튼 상태)을 갱신한다.

const ModalScript = preload("res://scenes/modal/modal.gd")

var _modal: Modal
var _hero = null          # 지휘 설정 중인 영웅부대(Party)
var _follow_btn: Button
var _direct_btn: Button
var _engage_btn: Button
var _avoid_btn: Button

func _ready() -> void:
	_build()

## 오버레이 = 공용 Modal + 세로 콘텐츠(추종 줄·전투 줄).
func _build() -> void:
	_modal = ModalScript.new()
	_modal.title = "지휘"
	_modal.closed.connect(_on_modal_closed)
	add_child(_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(280, 0)

	vbox.add_child(_row_label("추종"))
	var follow_row := HBoxContainer.new()
	follow_row.add_theme_constant_override("separation", 8)
	_follow_btn = _toggle("따라옴", func() -> void: _set_follow(true))
	_direct_btn = _toggle("직접명령", func() -> void: _set_follow(false))
	follow_row.add_child(_follow_btn)
	follow_row.add_child(_direct_btn)
	vbox.add_child(follow_row)

	vbox.add_child(_row_label("전투"))
	var combat_row := HBoxContainer.new()
	combat_row.add_theme_constant_override("separation", 8)
	_engage_btn = _toggle("전투우선", func() -> void: _set_engage(true))
	_avoid_btn = _toggle("전투회피", func() -> void: _set_engage(false))
	combat_row.add_child(_engage_btn)
	combat_row.add_child(_avoid_btn)
	vbox.add_child(combat_row)

	_modal.set_content(vbox)

func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _toggle(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	return b

## hero의 현재 설정을 읽어 토글을 그리고 모달을 연다.
func open(hero) -> void:
	_hero = hero
	_modal.title = "지휘 — %s" % (hero.commander_name if hero.commander_name != "" else "영웅")
	_modal.open()
	_refresh()

func close() -> void:
	_modal.close()

func is_open() -> bool:
	return _modal.is_open()

func _on_modal_closed() -> void:
	_hero = null

## 현재 값인 쪽 버튼을 비활성(선택 표시)으로 둔다.
func _refresh() -> void:
	if _hero == null:
		return
	_follow_btn.disabled = _hero.command_follow
	_direct_btn.disabled = not _hero.command_follow
	_engage_btn.disabled = _hero.command_engage
	_avoid_btn.disabled = not _hero.command_engage

func _set_follow(value: bool) -> void:
	if _hero == null:
		return
	_hero.command_follow = value
	_refresh()
	changed.emit()

func _set_engage(value: bool) -> void:
	if _hero == null:
		return
	_hero.command_engage = value
	_refresh()
	changed.emit()
