extends GutTest
## 좌클릭 우선순위(ClickRouter.resolve) 테스트 — 노드 비의존 순수 로직.
## 우선순위: 부대 칸(부대 우선, 캠프 위 재클릭 시 메뉴) → 선택 중 이동(건물 위 통행)
##          → 캠프 메뉴 → 건물 정보 → 선택 해제.
## 인자 순서: resolve(on_party, on_camp, on_building, selected, reachable, info_open)

# --- 선택 중 이동 (건물 위 통행이 이 기능의 핵심) ---

func test_selected_reachable_empty_cell_moves() -> void:
	assert_eq(
		ClickRouter.resolve(false, false, false, true, true, false),
		ClickRouter.MOVE, "선택 중 + 이동 범위 빈 칸 → 이동")

func test_selected_reachable_camp_cell_moves() -> void:
	# 이동우선: 건물(캠프) 칸이어도 선택 중 + 범위면 이동한다 — 건물 위로 통행.
	assert_eq(
		ClickRouter.resolve(false, true, false, true, true, false),
		ClickRouter.MOVE, "선택 중 + 캠프 칸 + 범위 → 이동(건물 위 통행)")

func test_selected_reachable_building_cell_moves() -> void:
	# 농장 칸도 선택 중 + 범위면 이동이 정보 패널보다 우선.
	assert_eq(
		ClickRouter.resolve(false, false, true, true, true, false),
		ClickRouter.MOVE, "선택 중 + 농장 칸 + 범위 → 이동(건물 위 통행)")

func test_selected_camp_cell_out_of_range_opens_menu() -> void:
	# 범위 밖 캠프 칸은 이동 불가 → 캠프 메뉴.
	assert_eq(
		ClickRouter.resolve(false, true, false, true, false, false),
		ClickRouter.CAMP_MENU, "선택 중 + 캠프 칸 + 범위 밖 → 캠프 메뉴")

# --- 부대 칸 (부대 우선) ---

func test_party_cell_focuses_party() -> void:
	assert_eq(
		ClickRouter.resolve(true, false, false, false, false, false),
		ClickRouter.FOCUS_PARTY, "부대 칸 클릭 → 부대 우선")

func test_party_cell_focuses_even_when_selected_and_reachable() -> void:
	# 부대 칸은 선택+범위 상태에서도 이동(MOVE)보다 부대 우선(FOCUS_PARTY)이어야 한다.
	assert_eq(
		ClickRouter.resolve(true, false, false, true, true, false),
		ClickRouter.FOCUS_PARTY, "선택+범위여도 부대 칸은 부대 우선")

func test_party_on_camp_info_closed_focuses_party() -> void:
	# 첫 클릭: 부대가 캠프 위여도 정보가 닫혀 있으면 부대 우선.
	assert_eq(
		ClickRouter.resolve(true, true, false, false, false, false),
		ClickRouter.FOCUS_PARTY, "부대가 캠프 위 + 정보 닫힘(첫 클릭) → 부대")

func test_party_on_camp_info_open_opens_menu() -> void:
	# 두 번째 클릭: 정보가 이미 열려 있으면 캠프 메뉴로 전환.
	assert_eq(
		ClickRouter.resolve(true, true, false, false, false, true),
		ClickRouter.CAMP_MENU, "부대가 캠프 위 + 정보 열림(두 번째 클릭) → 캠프 메뉴")

func test_party_on_plain_info_open_still_focuses() -> void:
	# 캠프가 아니면 정보가 열려 있어도 재클릭 시 메뉴 없음(부대 유지).
	assert_eq(
		ClickRouter.resolve(true, false, false, false, false, true),
		ClickRouter.FOCUS_PARTY, "부대가 평지 위 + 정보 열림 → 부대 유지")

# --- 캠프 메뉴 / 건물 정보 / 선택 해제 ---

func test_camp_cell_opens_menu() -> void:
	assert_eq(
		ClickRouter.resolve(false, true, false, false, false, false),
		ClickRouter.CAMP_MENU, "캠프 칸(부대 아님·선택 아님) → 캠프 메뉴")

func test_building_cell_opens_building_info() -> void:
	# 캠프가 아닌 건물(농장) 칸 → 건물 정보 패널.
	assert_eq(
		ClickRouter.resolve(false, false, true, false, false, false),
		ClickRouter.BUILDING_INFO, "농장 칸(부대·선택 아님) → 건물 정보")

func test_camp_takes_priority_over_building() -> void:
	# 캠프는 건물 정보보다 우선(캠프 메뉴).
	assert_eq(
		ClickRouter.resolve(false, true, true, false, false, false),
		ClickRouter.CAMP_MENU, "캠프 칸이면 건물 정보보다 캠프 메뉴 우선")

func test_empty_cell_deselects() -> void:
	assert_eq(
		ClickRouter.resolve(false, false, false, false, false, false),
		ClickRouter.DESELECT, "빈 칸(부대·캠프·건물 아님) → 선택 해제")
