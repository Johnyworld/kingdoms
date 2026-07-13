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
	_summary.text = "이동력 %d · 시야 %d · 사거리 %s" % [party.movement(), party.vision(), ItemTypes.range_label(party.attack_range())]
	var overload: int = party.overload_penalty()
	if overload > 0:
		_summary.text += " · 과적 −%d" % overload   # 화물 과적으로 이동력 감소 중

	for child in _member_list.get_children():
		child.free()   # 즉시 제거(다음 프레임까지 낡은 멤버 행이 남지 않도록)
	for member in party.members:
		var label := Label.new()
		var weapon: String = ItemTypes.weapon_name(ItemTypes.primary_weapon(member.weapons))
		if weapon.is_empty():
			weapon = "맨손"
		# 무기를 여럿 들면 주무기 뒤에 보조무기 이름을 (+…)로 덧붙인다.
		if member.weapons.size() > 1:
			var extras: Array = []
			for i in range(1, member.weapons.size()):
				extras.append(ItemTypes.weapon_name(member.weapons[i]))
			weapon += " (+%s)" % ", ".join(extras)
		# 1줄: 이름·HP(현재/최대)·이동·시야, 2줄: 무기 · 공격(AT) · 방어(DF) · 회피(EV) [· 막기(방패 있을 때)].
		label.text = "%s   HP %d/%d   이동 %d / 시야 %d\n  %s · 공격 %d · 방어 %d · 회피 %d" % [
			member.human_name, member.hit_points, member.max_hp(), member.movement, member.vision,
			weapon, CombatResolver.attack_power(member), CombatResolver.defense(member),
			roundi(CombatResolver.evasion(member))]
		var block: int = CombatResolver.block_chance(member)
		if block > 0:
			label.text += " · 막기 %d%%" % block
		# 3줄: 착용 방어구 조각 이름(맨몸이면 줄 없음).
		if not member.armor.is_empty():
			var pieces: Array = []
			for a in member.armor:
				pieces.append(ItemTypes.armor_name(a))
			label.text += "\n  방어구: %s" % ", ".join(pieces)
		_member_list.add_child(label)

	# 공성 유닛(투석기 등)을 실었으면 멤버 아래에 한 줄 표시. 견인 인력 부족이면 이동 불가 사유를 덧붙인다. → siege-engines.md
	if party.has_siege():
		var names: Array = []
		for u in party.siege_units:
			names.append(u.unit_name())
		var siege_label := Label.new()
		siege_label.text = "공성 유닛: %s" % ", ".join(names)
		if party.members.size() < SiegeTypes.CREW_MIN:
			siege_label.text += "  (견인 인력 부족 — 이동 불가)"
		_member_list.add_child(siege_label)

	show()

## 패널을 숨긴다.
func close() -> void:
	hide()
