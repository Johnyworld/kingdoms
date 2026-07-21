class_name LordMenu
extends Node
## 소속 모달. 일반부대(Party KIND_TROOP)의 소속 영웅부대를 설정/해제한다. → docs/spec/features/party-lord.md
## 오버레이 chrome(배경·제목·X·ESC·지도 입력 차단)은 공용 Modal에 위임하고, 콘텐츠(목록)만 주입한다.
## 후보 = 인접 아군 영웅부대(game.gd가 계산해 넘김). 소속은 인접 필요·해제는 자유·턴 무소비.

signal changed   # 소속을 바꾼 뒤 방출. game.gd가 부대 일람·정보를 갱신한다.

const ModalScript = preload("res://scenes/modal/modal.gd")

var _modal: Modal
var _list: VBoxContainer
var _troop = null          # 소속을 관리 중인 일반부대(Party)
var _candidates: Array = []   # 인접 아군 영웅부대(Party) 목록

func _ready() -> void:
	_build()

## 오버레이 = 공용 Modal + 세로 목록(현재 소속 라벨 + 후보 영웅 버튼 + [독립]).
func _build() -> void:
	_modal = ModalScript.new()
	_modal.title = "소속"
	_modal.closed.connect(_on_modal_closed)
	add_child(_modal)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.custom_minimum_size = Vector2(280, 0)
	_modal.set_content(_list)

## troop의 소속 관리를 연다. candidates = 인접 아군 영웅부대 목록.
func open(troop, candidates: Array) -> void:
	_troop = troop
	_candidates = candidates
	_modal.title = "소속 — %s" % (troop.party_name if troop.party_name != "" else "부대")
	_modal.open()
	_refresh()

## 오버레이를 닫는다(Modal 경유 → closed 시 정리).
func close() -> void:
	_modal.close()

## 오버레이가 열려 있는지.
func is_open() -> bool:
	return _modal.is_open()

func _on_modal_closed() -> void:
	_troop = null
	_candidates = []

## 현재 소속 라벨 + 후보 영웅 버튼(현재 소속은 비활성) + [독립](소속 보유 시만 활성)을 그린다.
func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var cur := Label.new()
	cur.text = "현재 소속: %s" % (_troop.lord_name() if _troop.has_lord() else "없음(독립)")
	_list.add_child(cur)
	for hero in _candidates:
		var btn := Button.new()
		btn.text = hero.commander_name
		btn.custom_minimum_size = Vector2(240, 0)
		btn.disabled = (hero == _troop.lord)   # 이미 소속인 영웅은 비활성
		btn.pressed.connect(_on_pick.bind(hero))
		_list.add_child(btn)
	var indep := Button.new()
	indep.text = "독립"
	indep.custom_minimum_size = Vector2(240, 0)
	indep.disabled = not _troop.has_lord()   # 뗄 소속이 있어야 활성
	indep.pressed.connect(_on_independent)
	_list.add_child(indep)

## 후보 영웅 소속 확정 → 그 영웅부대로 소속. 재편(턴 무소비) 후 닫는다.
func _on_pick(hero) -> void:
	_troop.set_lord(hero)
	changed.emit()
	close()

## [독립] → 소속 해제. 재편(턴 무소비) 후 닫는다.
func _on_independent() -> void:
	_troop.clear_lord()
	changed.emit()
	close()
