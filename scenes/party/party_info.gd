extends CanvasLayer
## 부대 정보 패널. 부대를 클릭하면 화면 우측 상단에 이름·이동력·시야·멤버를 표시한다.
## 캠프 메뉴(camp_menu.gd)·턴 HUD(turn_hud.gd)처럼 UI를 코드로 구성한다(별도 .tscn 없음).

const MARGIN := 16

var _title: Label          # 제목 = 부대 이름
var _faction: Label        # 소속 세력 이름(비면 숨김)
var _summary: Label        # 요약 = "이동력 N · 시야 M"
var _member_list: VBoxContainer  # 멤버 한 명당 라벨 한 줄

func _ready() -> void:
	layer = 48
	_build()
	hide()

## UI 트리를 코드로 구성한다. 우측 상단 패널.
func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(200, 0)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_title)

	_faction = Label.new()
	vbox.add_child(_faction)

	_summary = Label.new()
	vbox.add_child(_summary)

	vbox.add_child(HSeparator.new())

	_member_list = VBoxContainer.new()
	_member_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_member_list)

## 부대 정보를 채우고 패널을 보인다. 멤버 리스트는 비우고 다시 채운다(재오픈 대비).
func open(party) -> void:
	_title.text = party.party_name
	_faction.text = party.faction_name
	_faction.visible = not party.faction_name.is_empty()   # 세력명이 없으면 줄을 숨긴다.
	_summary.text = "이동력 %d · 시야 %d · 사거리 %s" % [party.movement(), party.vision(), _range_label(party.attack_range())]

	for child in _member_list.get_children():
		child.free()   # 즉시 제거(다음 프레임까지 낡은 행이 남지 않도록)
	# 순수 class+count — 개별 병사 없음. 지휘관 이름 + 병력수만 표시(영웅부대는 병력=클래스 HP).
	var label := Label.new()
	label.text = "지휘관 %s · 병력 %d" % [party.commander_name, party.soldiers]
	_member_list.add_child(label)

	show()

## 사거리 표기. 0 이하 → "근접", 그 외 "사거리 N".
func _range_label(r: int) -> String:
	return "근접" if r <= 0 else "사거리 %d" % r

## 패널을 숨긴다.
func close() -> void:
	hide()
