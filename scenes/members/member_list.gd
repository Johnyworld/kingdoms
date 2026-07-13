class_name MemberList
extends Tree
## 구성원 리스트 위젯. Human 배열을 정렬·스크롤·키보드 이동되는 표로 그린다.
## Human만 안다(게임/세력 무관) — 나중에 유닛 선택 UI 등에서 그대로 재사용한다.
## 스크롤(세로·가로)·키보드 이동(↑/↓/PageUp/Down)·행 하이라이트는 Tree 기본 동작을 쓰고,
## 컬럼 정렬만 직접 구현한다. → docs/spec/features/member-list.md

## 선택 행이 바뀔 때(클릭·키보드 이동) 그 Human을 실어 방출한다. 후속 동작은 사용하는 쪽이 정한다.
signal member_selected(human)

## 컬럼 정의. 컬럼 추가/변경은 이 배열만 고친다. 첫 컬럼(이름)만 문자열, 나머지는 숫자 스탯.
const COLUMNS := [
	{ "key": "human_name", "label": "이름" },
	{ "key": "strength", "label": "힘" },
	{ "key": "wisdom", "label": "지혜" },
	{ "key": "agility", "label": "민첩" },
	{ "key": "charm", "label": "매력" },
	{ "key": "luck", "label": "행운" },
	{ "key": "movement", "label": "이동력" },
	{ "key": "vision", "label": "시야" },
	{ "key": "leadership", "label": "지휘력" },
	{ "key": "eloquence", "label": "화술" },
	{ "key": "diligence", "label": "성실함" },
	{ "key": "sensitivity", "label": "예민함" },
	{ "key": "level", "label": "레벨" },
	{ "key": "hit_points", "label": "HP" },
	{ "key": "stamina", "label": "스태미나" },
	{ "key": "morale", "label": "사기" },
]

const NAME_COL_WIDTH := 120
const STAT_COL_WIDTH := 56

var _members: Array = []       # 현재 멤버(입력 순서 보존)
var _sort_key := ""            # ""이면 정렬 없이 입력 순서 유지(헤더 클릭 전 기본 상태)
var _sort_asc := true
var _rows: Array = []          # 표시 순서의 TreeItem 목록
var _selected_index := -1
var _selecting := false        # 프로그램적 선택 중 플래그(item_selected 재진입으로 인한 중복 방출 방지)

func _ready() -> void:
	columns = COLUMNS.size()
	hide_root = true
	select_mode = Tree.SELECT_ROW
	column_titles_visible = true
	for i in COLUMNS.size():
		set_column_title(i, COLUMNS[i]["label"])
		set_column_expand(i, false)
		set_column_custom_minimum_width(i, NAME_COL_WIDTH if i == 0 else STAT_COL_WIDTH)
	column_title_clicked.connect(_on_title_clicked)
	item_selected.connect(_on_item_selected)
	_rebuild()

## 멤버 목록을 교체하고 현재 정렬 상태로 표를 다시 그린다.
func set_members(humans: Array) -> void:
	_members = humans.duplicate()
	_rebuild()

## 현재 멤버를 key 기준으로 정렬한 새 배열을 반환한다(원본 불변, 안정 정렬). key가 ""이면 입력 순서 그대로.
func sorted_members(key: String, ascending: bool) -> Array:
	if key == "":
		return _members.duplicate()
	# 원래 인덱스를 첨부해 동률 시 입력 순서를 유지한다(안정 정렬).
	var indexed: Array = []
	for i in _members.size():
		indexed.append({ "i": i, "h": _members[i] })
	indexed.sort_custom(func(a, b) -> bool:
		var va = a["h"].get(key)
		var vb = b["h"].get(key)
		if va == vb:
			return a["i"] < b["i"]
		return va < vb if ascending else va > vb
	)
	var out: Array = []
	for e in indexed:
		out.append(e["h"])
	return out

## 그 key로 정렬해 다시 그린다. 같은 key를 다시 지정하면 오름/내림을 토글, 다른 key면 오름차순부터.
func sort_by(key: String) -> void:
	if key == _sort_key:
		_sort_asc = not _sort_asc
	else:
		_sort_key = key
		_sort_asc = true
	_rebuild()

## 선택 행을 delta만큼 이동(0~마지막으로 클램프)하고 보이도록 스크롤한다. 선택이 없으면 첫 행 기준.
func move_selection(delta: int) -> void:
	if _rows.is_empty():
		return
	var base := _selected_index if _selected_index >= 0 else 0
	_select_index(clampi(base + delta, 0, _rows.size() - 1))

## 현재 선택된 Human(없으면 null).
func selected_member():
	if _selected_index < 0 or _selected_index >= _rows.size():
		return null
	return _rows[_selected_index].get_metadata(0)

func _rebuild() -> void:
	clear()
	_rows.clear()
	_selected_index = -1
	var root := create_item()   # 숨김 루트
	for h in sorted_members(_sort_key, _sort_asc):
		var item := create_item(root)
		for i in COLUMNS.size():
			item.set_text(i, str(h.get(COLUMNS[i]["key"])))
		item.set_metadata(0, h)
		_rows.append(item)

func _select_index(idx: int) -> void:
	_selected_index = idx
	var item: TreeItem = _rows[idx]
	_selecting = true
	item.select(0)
	scroll_to_item(item)
	_selecting = false
	member_selected.emit(item.get_metadata(0))

func _on_title_clicked(column: int, _mouse_button: int) -> void:
	sort_by(COLUMNS[column]["key"])

func _on_item_selected() -> void:
	if _selecting:
		return   # 프로그램적 선택은 _select_index가 이미 방출한다
	var item := get_selected()
	if item == null:
		return
	_selected_index = _rows.find(item)
	member_selected.emit(item.get_metadata(0))
