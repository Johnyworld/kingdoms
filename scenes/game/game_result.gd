class_name GameResult
extends RefCounted
## 한 판의 승패 판정(순수 로직). 노드 비의존이라 테스트하기 쉽다(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 지금은 도달 가능한 패배 조건 하나 — 플레이어 부대 전멸(생존 멤버 0 이하) → DEFEAT — 만 구현한다.
## 정복 승리(VICTORY)·그 외 패배는 캠프 점령/파괴가 생긴 뒤 구현한다(미구현).

const ONGOING := "ongoing"
const DEFEAT := "defeat"
# const VICTORY := "victory"  # 미구현: 정복 승리 = 모든 NPC 세력 소멸(캠프 0).

## 플레이어 부대의 생존 멤버 수로 판정한다. 0 이하면 패배(전멸), 아니면 진행 중.
static func evaluate(player_member_count: int) -> String:
	if player_member_count <= 0:
		return DEFEAT
	return ONGOING
