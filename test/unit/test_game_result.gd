extends GutTest
## 승패 판정(GameResult) 테스트 — 노드 비의존 순수 로직.
## 현재는 플레이어 부대 전멸(생존 멤버 0 이하) → 패배(DEFEAT)만 구현.

func test_zero_members_is_defeat() -> void:
	assert_eq(GameResult.evaluate(0), GameResult.DEFEAT, "생존 0명 → 패배(전멸)")

func test_one_member_is_ongoing() -> void:
	assert_eq(GameResult.evaluate(1), GameResult.ONGOING, "1명 생존 → 진행 중")

func test_many_members_is_ongoing() -> void:
	assert_eq(GameResult.evaluate(5), GameResult.ONGOING, "여러 명 생존 → 진행 중")

func test_negative_is_defeat() -> void:
	# 경계: 음수(비정상 입력)도 0 이하로 보고 패배 처리.
	assert_eq(GameResult.evaluate(-1), GameResult.DEFEAT, "0 이하는 패배로 방어적 처리")

# --- 세력 소멸 유예 (advance_grace / grace_eliminated) ---

func test_grace_turns_constant() -> void:
	assert_eq(GameResult.GRACE_TURNS, 10, "유예는 10턴")

func test_advance_grace_reset_when_has_post() -> void:
	assert_eq(GameResult.advance_grace(true, 5), -1, "캠프 보유 → 위기 해제(-1)")

func test_advance_grace_starts_countdown() -> void:
	assert_eq(GameResult.advance_grace(false, -1), 10, "방금 캠프 0 → 카운트다운 시작(10)")

func test_advance_grace_counts_down() -> void:
	assert_eq(GameResult.advance_grace(false, 10), 9, "계속 캠프 0 → 감소")
	assert_eq(GameResult.advance_grace(false, 1), 0, "1 → 0(소멸)")

func test_advance_grace_floors_at_zero() -> void:
	assert_eq(GameResult.advance_grace(false, 0), 0, "0에서 멈춤")

func test_grace_eliminated() -> void:
	assert_true(GameResult.grace_eliminated(0), "0 → 소멸 확정")
	assert_false(GameResult.grace_eliminated(3), "3 → 아직 아님")
	assert_false(GameResult.grace_eliminated(-1), "-1(위기 아님) → 아님")

# --- 종합 판정 (endgame) ---

func test_endgame_ongoing() -> void:
	assert_eq(GameResult.endgame(false, false), GameResult.ONGOING, "아무도 소멸 안 함 → 진행")

func test_endgame_victory() -> void:
	assert_eq(GameResult.endgame(false, true), GameResult.VICTORY, "모든 NPC 소멸 → 정복 승리")

func test_endgame_defeat_when_player_eliminated() -> void:
	assert_eq(GameResult.endgame(true, false), GameResult.DEFEAT, "플레이어 세력 소멸 → 패배")

func test_endgame_player_defeat_takes_priority() -> void:
	assert_eq(GameResult.endgame(true, true), GameResult.DEFEAT, "동시면 패배 우선")
