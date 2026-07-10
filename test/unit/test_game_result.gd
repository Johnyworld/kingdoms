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
