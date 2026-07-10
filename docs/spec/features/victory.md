# Feature: Victory & Defeat (승패)

> 스크립트: `scenes/game/game_result.gd` (`GameResult` — 순수 판정) · `scenes/result/result_overlay.gd` (`ResultOverlay` — 결과 화면) · `scenes/game/game.gd` (`_check_game_over`, `_trigger_game_over`, `_on_result_dismissed`)

한 판의 종료(승패)를 판정하고 결과 화면을 띄운다. 기획 [승리조건](../../table/시스템/승리조건.md)의 첫 조각으로,
**지금 도달 가능한 패배 조건 하나(플레이어 부대 전멸)**만 구현한다.

## 판정 (`GameResult`)

노드 비의존 순수 로직(`HexGrid`·`ClickRouter`와 같은 헬퍼 패턴).

- `GameResult.evaluate(player_member_count: int) -> String`
  - `player_member_count <= 0` → `DEFEAT` (플레이어 부대 전멸)
  - 그 외 → `ONGOING`
- 결과 상수: `ONGOING` · `DEFEAT`.
- **미구현**: `VICTORY`(정복 승리 = 모든 NPC 세력 소멸)·그 외 패배(플레이어 세력 소멸)·거점 점령·기간 우위.
  캠프 파괴/점령이 없어 아직 트리거할 수 없다 → [NPC Bases](npc-bases.md)에서 유예. *(다음 단계)*

## 트리거 (`game.gd` `_check_game_over`)

- 플레이어가 낀 **모든 전투 종료 직후**(`_run_battle`에서 사상자 반영 뒤) 판정한다.
  - 플레이어 부대는 전멸해도 맵 노드를 유지한다(`_apply_survivors`) — 멤버만 빈 배열이 된다.
  - `GameResult.evaluate(party.members.size())`가 `DEFEAT`면 게임 오버.
- 플레이어는 항상 오버레이 전투(`_run_battle`)로 싸우므로(NPC끼리는 헤드리스) 이 지점 하나로 충분하다.
- 게임 오버 상태(`_game_over`)에서는 월드맵 좌클릭·턴 종료를 잠근다(`_in_battle`과 같은 방식). 진행 중이던 NPC 공격 페이즈(`_npc_attack_phase`)도 남은 결산을 중단한다.

## 결과 화면 (`ResultOverlay`)

[부대 행동 메뉴](party-action-menu.md)처럼 UI를 코드로 구성하는 `CanvasLayer`(별도 `.tscn` 없음, `game.gd`가 `.new()`로 생성). 화면 최상단 레이어.

- `show_result(title: String, subtitle: String)` — 반투명 배경 + 중앙 패널(큰 제목 · 부제 · "클릭하면 타이틀로" 안내)을 띄운다.
- 배경/패널 아무 곳이나 클릭하면 `dismissed` 시그널을 방출한다.
- `game.gd` `_trigger_game_over`가 패배 시 `show_result("패배", "아젤 하르윈 부대가 전멸했다")`를 호출한다.
- `dismissed` → `game.gd` `_on_result_dismissed`가 `SceneManager.change_scene("res://scenes/title/title.tscn")`로 타이틀 복귀(페이드 전환).
- 승리 화면은 위 `show_result(title, subtitle)`를 그대로 재사용한다(정복 승리 구현 시 제목만 바꿔 호출). *(미구현)*

## 이번 슬라이스 제외 (미구현)

- **정복 승리**·**플레이어 세력 소멸 패배**(캠프 점령/파괴 필요).
- **영웅(지휘관) 개별 사망** 패배 — 이번엔 부대 전멸 기준(지휘관만 죽어도 다른 멤버가 남으면 진행).
- 점수·기간 모드·거점 점령 시나리오.

## 테스트 시나리오

**판정** — `test/unit/test_game_result.gd`:
- [정상] `evaluate(0)` → `DEFEAT` (전멸)
- [정상] `evaluate(1)`·`evaluate(5)` → `ONGOING` (생존자 있음)
- [경계] `evaluate(-1)` → `DEFEAT` (0 이하 방어적 처리)

**결과 화면** — `test/unit/test_result_overlay.gd`:
- [정상] `show_result("패배", "...")` → 제목 라벨 "패배", 부제 라벨 채워짐, `visible == true`
- [정상] 생성 직후 `visible == false`(숨김)
- [정상] `dismiss()` 호출 시 `dismissed` 시그널 방출

`game.gd`의 트리거·타이틀 전환은 씬 트리·SceneManager 의존이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- 기획: [승리조건](../../table/시스템/승리조건.md)
- [Battle (전투)](battle.md) — 사상자 반영 지점(`_run_battle`)이 판정 트리거. [Parties (부대 배치)](parties.md) — 플레이어 부대.
- [NPC Bases (NPC 거점)](npc-bases.md) — 정복 승리·세력 소멸의 전제(캠프 점령, 미구현). [Scene Transition](scene-transition.md) — 타이틀 복귀.
