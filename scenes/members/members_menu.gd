class_name MembersMenu
extends CanvasLayer
## 구성원 메뉴. 좌측 하단 상시 "구성원" 버튼 + 우리 세력 전 군인 명단 오버레이 + 상세 패널.
## 오버레이 chrome(배경·제목·X·닫기·입력 차단)은 공용 Modal에 위임하고, 콘텐츠(명단+상세)만 주입한다.
## 명단 표는 재사용 위젯 MemberList를 쓴다. 세력을 모르며, 명단은 game.gd가 주입한다.
## → docs/spec/features/members-menu.md

const MemberListScript = preload("res://scenes/members/member_list.gd")
const ModalScript = preload("res://scenes/modal/modal.gd")

## 좌측 하단 버튼을 누르면 방출. game.gd가 받아 open(_player_faction_members())을 호출한다.
signal open_requested

const MARGIN := 16

var _open_button: Button
var _modal: Modal
var _list: MemberList
var _count_label: Label
var _detail: VBoxContainer   # 상세 패널 내용

func _ready() -> void:
	layer = 33
	_build()

## parties 중 faction_name이 일치하는 부대의 members를 순서대로 모아 중복 제거해 반환한다.
## 재사용·테스트 가능한 정적 헬퍼. game.gd._player_faction_members()가 사용한다.
static func collect_faction_members(parties: Array, faction_name: String) -> Array:
	var out: Array = []
	for p in parties:
		if p == null or p.faction_name != faction_name:
			continue
		for h in p.members:
			if not (h in out):
				out.append(h)
	return out

## 명단 오버레이를 연다. 좌측 하단 버튼은 숨긴다. 멤버가 있으면 첫 행을 자동 선택하고 포커스한다.
func open(members: Array) -> void:
	_list.set_members(members)
	_count_label.text = "%d명" % members.size()
	_open_button.hide()
	_modal.open()
	if members.size() > 0:
		_list.move_selection(0)   # 첫 행 선택 → member_selected로 상세 갱신
		_list.grab_focus()        # 키보드 ↑/↓ 이동을 바로 쓰도록 포커스
	else:
		_show_detail(null)

## 오버레이를 닫는다(Modal 경유 → closed 시 버튼 복원).
func close() -> void:
	_modal.close()

## 오버레이가 열려 있는지.
func is_open() -> bool:
	return _modal.is_open()

func _build() -> void:
	# 좌측 하단 상시 버튼(오버레이와 별개 레이어)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_open_button = Button.new()
	_open_button.text = "구성원"
	_open_button.custom_minimum_size = Vector2(120, 44)
	_open_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_open_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_open_button.pressed.connect(func() -> void: open_requested.emit())
	root.add_child(_open_button)

	# 오버레이 = 공용 Modal + 콘텐츠(명단 + 상세)
	_modal = ModalScript.new()
	_modal.title = "구성원"
	_modal.closed.connect(_on_modal_closed)
	add_child(_modal)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)

	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 6)
	content.add_child(list_col)

	_count_label = Label.new()
	list_col.add_child(_count_label)

	_list = MemberListScript.new()
	_list.custom_minimum_size = Vector2(780, 440)
	_list.member_selected.connect(_on_member_selected)
	list_col.add_child(_list)

	var detail_panel := PanelContainer.new()
	content.add_child(detail_panel)
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(220, 0)
	_detail.add_theme_constant_override("separation", 4)
	detail_panel.add_child(_detail)

	_modal.set_content(content)
	_show_detail(null)

func _on_modal_closed() -> void:
	_open_button.show()

func _on_member_selected(human) -> void:
	_show_detail(human)

## 상세 패널을 갱신한다. human이 null이면 안내 문구만 표시.
func _show_detail(human) -> void:
	for c in _detail.get_children():
		c.free()   # 즉시 제거(낡은 줄이 남지 않도록)
	if human == null:
		_add_line("군인을 선택하세요")
		return
	_add_line(human.human_name, 18)
	_add_line("힘 %d" % human.strength)
	_add_line("지혜 %d" % human.wisdom)
	_add_line("민첩 %d" % human.agility)
	_add_line("매력 %d" % human.charm)
	_add_line("행운 %d" % human.luck)
	_add_line("이동력 %d" % human.movement)
	_add_line("시야 %d" % human.vision)
	_add_line("지휘력 %d" % human.leadership)
	_add_line("화술 %d" % human.eloquence)
	_add_line("성실함 %d" % human.diligence)
	_add_line("예민함 %d" % human.sensitivity)
	_add_line("레벨 %d" % human.level)
	_add_line("HP %d/%d" % [human.hit_points, human.max_hp()])
	_add_line("스태미나 %d/%d" % [human.stamina, human.max_stamina])
	_add_line("사기 %d" % human.morale)

func _add_line(text: String, font_size := 14) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	_detail.add_child(l)

## 상세 패널의 현재 텍스트(테스트·디버그용).
func _detail_text() -> String:
	var parts: Array = []
	for c in _detail.get_children():
		if c is Label:
			parts.append(c.text)
	return "\n".join(parts)
