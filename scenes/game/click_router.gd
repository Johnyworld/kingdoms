class_name ClickRouter
extends RefCounted
## 맵 좌클릭이 어떤 동작을 해야 하는지 우선순위에 따라 결정하는 순수 함수.
## 노드에 의존하지 않아 테스트하기 쉽다(HexGrid·BuildPlanner와 같은 헬퍼 패턴).
## game.gd(_handle_click)는 셀 정보를 넘겨 받은 동작을 실행만 한다.

const MOVE := "move"                # 이동 범위 칸으로 부대를 이동
const CAMP_MENU := "camp_menu"      # 캠프 메뉴 열기
const BUILDING_INFO := "building_info"  # 캠프 아닌 건물 정보 패널 열기
const FOCUS_PARTY := "focus_party"  # 부대 정보 패널 열기(이동 가능하면 선택)
const DESELECT := "deselect"        # 선택 해제 + 정보 패널 닫기

## 우선순위(위에서부터):
##  1. 부대 칸 → 부대 우선(FOCUS_PARTY). 단 캠프 위에 서 있고 정보가 이미 열려 있으면
##     (= 같은 칸 두 번째 클릭) CAMP_MENU로 전환.
##  2. 선택 중 + 이동 범위 칸 → MOVE. 건물 칸이어도 이동이 우선(건물은 이동을 막지 않음 → 통행 가능).
##  3. 캠프 칸 → CAMP_MENU (부대가 없거나 범위 밖).
##  4. 그 외 건물 칸(농장 등) → BUILDING_INFO.
##  5. 그 외 → DESELECT.
static func resolve(on_party: bool, on_camp: bool, on_building: bool, selected: bool, reachable: bool, info_open: bool) -> String:
	if on_party:
		if on_camp and info_open:
			return CAMP_MENU
		return FOCUS_PARTY
	if selected and reachable:
		return MOVE
	if on_camp:
		return CAMP_MENU
	if on_building:
		return BUILDING_INFO
	return DESELECT
