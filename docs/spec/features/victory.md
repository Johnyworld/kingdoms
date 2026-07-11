# Feature: Victory & Defeat (승패)

> 스크립트: `scenes/game/game_result.gd` (`GameResult` — 순수 판정) · `scenes/result/result_overlay.gd` (`ResultOverlay` — 결과 화면) · `scenes/game/game.gd` (`_update_endgame`, `_check_endgame`, `_eliminate_faction`, `_trigger_game_over`, `_on_result_dismissed`) · `scenes/faction/faction.gd` (`grace_turns`, `eliminated`) · `scenes/turn/turn_hud.gd` (`set_grace`)

한 판의 종료(승패)를 판정하고 결과 화면을 띄운다. 기획 [승리조건](../../table/시스템/승리조건.md)의 구현.

승패는 **세력 소멸(유예)** 로만 난다 — 어떤 세력이 **거점**([center](../data/buildings.md#동작) = 캠프·마을회관·성 중 하나)을 하나도 안 가지면 **10턴 유예** 뒤 소멸(턴 종료마다 판정). 세 티어 중 무엇이든 하나라도 있으면 유지된다.

- 모든 NPC 세력이 소멸하면 **정복 승리**, 플레이어 세력이 소멸하면 **패배**.
- **부대 전멸로는 게임 오버되지 않는다** — 플레이어 부대가 전멸해도(거점은 남으므로) 판이 끝나지 않는다.

## 판정 (`GameResult` — 순수)

노드 비의존 순수 로직(`HexGrid`·`ClickRouter`와 같은 헬퍼 패턴). 결과 상수: `ONGOING` · `DEFEAT` · `VICTORY`.

### 세력 소멸 유예 (grace countdown)

- `const GRACE_TURNS := 10` — 캠프를 모두 잃은 세력이 소멸까지 버티는 턴 수(수복 기회).
- `advance_grace(has_command_post: bool, grace: int) -> int` — 턴마다 유예 카운트를 갱신한다. `grace` 규약: **-1 = 위기 아님**(캠프 보유), **≥1 = 남은 유예 턴**, **0 = 이번 턴 소멸 확정**.
  - `has_command_post` 참 → `-1` (캠프 보유/수복 → 위기 해제·리셋).
  - 캠프 0 + `grace < 0`(방금 잃음) → `GRACE_TURNS`(카운트다운 시작).
  - 캠프 0 + `grace >= 0` → `max(0, grace - 1)`(계속 감소, 0에서 멈춤).
- `grace_eliminated(grace: int) -> bool` — `grace == 0`이면 소멸 확정.

### 종합 판정

- `endgame(player_eliminated: bool, all_npc_eliminated: bool) -> String`
  - `player_eliminated` → `DEFEAT` (플레이어 세력 소멸이 승리보다 우선).
  - 아니고 `all_npc_eliminated` → `VICTORY`.
  - 그 외 → `ONGOING`.

## 세력 상태 (`Faction`)

[세력](../entities/Faction.md)에 소멸 유예 상태를 둔다(순수 데이터).

- `grace_turns: int = -1` — 유예 남은 턴. `-1`이면 위기 아님. `advance_grace`가 갱신한다.
- `eliminated: bool = false` — 소멸 확정. true면 이후 판정에서 제외.

## 트리거

### 세력 소멸 (`game.gd` `_update_endgame` — 턴 종료마다)

- `game.gd`는 모든 세력을 `_factions`(플레이어 + NPC 3)로 추적한다. 세력별 거점 수 = `_faction_center_count` (소속 영지의 건물 중 `BuildingTypes.is_center` = 캠프·마을회관·성 개수).
- 각 세력(소멸 안 된 것)에 대해 `faction.grace_turns = GameResult.advance_grace(거점 수 > 0, faction.grace_turns)`.
  - `GameResult.grace_eliminated(faction.grace_turns)`면 `eliminated = true` + `_eliminate_faction`(그 세력 소속 NPC 부대를 맵에서 제거).
- 이어서 `_check_endgame`: `GameResult.endgame(플레이어 세력 소멸, 모든 NPC 세력 소멸)` → `VICTORY`면 `_trigger_game_over("정복 승리", "모든 적 세력을 물리쳤다")`, `DEFEAT`면 `_trigger_game_over("패배", "세력이 소멸했다")`.
- **거점 소멸→유예 진입 경로**: 어떤 세력이 거점을 모두 잃으면(플레이어가 [흡수/파괴](camp-capture.md), 또는 NPC가 [흡수](camp-capture.md#npc-점령-gamegd-_npc_attack_phase)) 그 세력의 거점 수가 0이 된다 → 다음 턴 종료부터 카운트다운.
- **양방향 도달**: 플레이어는 NPC 거점을 점령해 **정복 승리**, NPC는 플레이어 거점을 점령해 **플레이어 세력 소멸(패배)** 을 만들 수 있다. 거점을 잃어도 10턴 안에 재점령하면 소멸을 면한다. (현재 NPC 거점은 캠프뿐 — 마을회관/성 거점은 인플레이스 업그레이드 도입 시 등장.)

### 유예 표시 (`turn_hud.set_grace`)

- 턴 HUD(우측 아래)에 소멸 위기 세력 목록을 표시한다 — `grace_turns >= 0`이고 소멸 안 된 세력마다 `"<세력명> 소멸까지 N턴"`(세력색). 위기 세력이 없으면 숨긴다.
- `game.gd` `_refresh_grace_hud`가 `_update_endgame` 뒤 목록을 만들어 넘긴다.

## 결과 화면 (`ResultOverlay`)

[부대 행동 메뉴](party-action-menu.md)처럼 UI를 코드로 구성하는 `CanvasLayer`(별도 `.tscn` 없음, `game.gd`가 `.new()`로 생성). 화면 최상단 레이어.

- `show_result(title: String, subtitle: String)` — 반투명 배경 + 중앙 패널(큰 제목 · 부제 · "클릭하면 타이틀로" 안내)을 띄운다. 승리·패배가 제목만 바꿔 재사용한다.
- 배경/패널 아무 곳이나 클릭하면 `dismissed` 시그널을 방출한다.
- `game.gd` `_trigger_game_over(title, subtitle)`가 `_game_over`를 세우고(중복 방지) 진행 중 선택·메뉴를 정리한 뒤 `show_result`를 호출한다.
- `dismissed` → `game.gd` `_on_result_dismissed`가 `SceneManager.change_scene("res://scenes/title/title.tscn")`로 타이틀 복귀(페이드 전환).
- 게임 오버 상태(`_game_over`)에서는 월드맵 좌클릭·턴 종료를 잠근다(`_in_battle`과 같은 방식). 진행 중이던 NPC 공격 페이즈(`_npc_attack_phase`)도 남은 결산을 중단한다.

## 미구현

- **부대 전멸 패배** — 의도적으로 없앰(플레이어 부대가 전멸해도 게임 오버 아님). 승패는 세력 소멸로만.
- 점수·기간 모드·거점 점령 시나리오.

## 테스트 시나리오

**세력 소멸 유예 판정** — `test/unit/test_game_result.gd`:
- [정상] `GRACE_TURNS == 10`
- [정상] `advance_grace(true, 5)` → `-1` (캠프 보유 → 위기 해제)
- [정상] `advance_grace(false, -1)` → `10` (방금 캠프 0 → 카운트다운 시작)
- [정상] `advance_grace(false, 10)` → `9`; `advance_grace(false, 1)` → `0` (계속 감소)
- [경계] `advance_grace(false, 0)` → `0` (0에서 멈춤)
- [정상] `grace_eliminated(0)` 참; `grace_eliminated(3)`·`grace_eliminated(-1)` 거짓
- [정상] `endgame(false, false)` → `ONGOING`; `endgame(false, true)` → `VICTORY`; `endgame(true, false)`·`endgame(true, true)` → `DEFEAT`

**세력 상태 필드** — `test/unit/test_faction.gd`:
- [정상] 생성 직후 `grace_turns == -1`, `eliminated == false`

**결과 화면** — `test/unit/test_result_overlay.gd`:
- [정상] `show_result("정복 승리", "...")` → 제목 "정복 승리", 부제 채워짐, `visible == true`
- (기존) 생성 직후 숨김 · `dismiss()` → `dismissed`

`game.gd`의 세력 추적·거점 수 계산(`_faction_center_count`, `is_center`)·유예 갱신·부대 제거·HUD·타이틀 전환(씬 트리·터레인 의존)은 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

거점 판정 자체(`BuildingTypes.is_center`)는 `test/unit/test_building_types.gd`에서 검증한다.

## 관련

- 기획: [승리조건](../../table/시스템/승리조건.md)
- [Camp Capture (캠프 점령)](camp-capture.md) — 세력 소멸의 진입 경로(캠프 흡수/파괴). [NPC Bases](npc-bases.md) — NPC 세력·거점.
- [Turn (턴)](turn.md) — 세력 소멸 판정 지점(턴 종료). [Faction](../entities/Faction.md) — 소멸 유예 상태.
- [Scene Transition](scene-transition.md) — 타이틀 복귀.
