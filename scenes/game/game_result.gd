class_name GameResult
extends RefCounted
## 한 판의 승패 판정(순수 로직). 노드 비의존이라 테스트하기 쉽다(HexGrid·ClickRouter와 같은 헬퍼 패턴).
## 승패는 세력 소멸(캠프 0 → 10턴 유예)로만 난다 — 모든 NPC 세력 소멸 = 정복 승리, 플레이어 세력 소멸 = 패배.
## (부대 전멸로는 게임 오버되지 않는다.)

const ONGOING := "ongoing"
const DEFEAT := "defeat"
const VICTORY := "victory"

# 지휘소(캠프)를 모두 잃은 세력이 소멸까지 버티는 턴 수(수복 기회).
const GRACE_TURNS := 10

## 세력 소멸 유예 카운트를 한 턴 갱신한다.
## grace 규약: -1 = 위기 아님(캠프 보유) · ≥1 = 남은 유예 턴 · 0 = 이번 턴 소멸 확정.
## - 캠프 보유(has_command_post) → -1 (위기 해제·수복 리셋)
## - 캠프 0 + grace<0(방금 잃음) → GRACE_TURNS (카운트다운 시작)
## - 캠프 0 + grace>=0 → max(0, grace-1) (계속 감소, 0에서 멈춤)
static func advance_grace(has_command_post: bool, grace: int) -> int:
	if has_command_post:
		return -1
	if grace < 0:
		return GRACE_TURNS
	return maxi(0, grace - 1)

## 유예 카운트가 소멸 확정(0)인지.
static func grace_eliminated(grace: int) -> bool:
	return grace == 0

## 세력 소멸 종합 판정. 플레이어 세력 소멸이 정복 승리보다 우선(동시면 패배).
static func endgame(player_eliminated: bool, all_npc_eliminated: bool) -> String:
	if player_eliminated:
		return DEFEAT
	if all_npc_eliminated:
		return VICTORY
	return ONGOING
