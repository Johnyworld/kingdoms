extends GutTest
## 승패 판정(GameResult) 테스트 — 노드 비의존 순수 로직.
## 승패는 세력 소멸(캠프 0 → 10턴 유예)로만 난다. 부대 전멸로는 게임 오버되지 않는다.

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

# --- 즉시 패배 (거점·부대 모두 상실) ---

func test_immediate_defeat_when_no_center_no_party() -> void:
	assert_true(GameResult.immediate_defeat(false, false), "거점·부대 모두 없음 → 즉시 패배")

func test_immediate_defeat_false_when_has_something() -> void:
	assert_false(GameResult.immediate_defeat(true, false), "거점 있으면 거짓")
	assert_false(GameResult.immediate_defeat(false, true), "부대 있으면 거짓(유예/수복)")
	assert_false(GameResult.immediate_defeat(true, true), "둘 다 있으면 거짓")
