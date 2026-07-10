# Feature: Party Composition (부대 편성 — 다중 부대)

> 스크립트: `scenes/game/game.gd` (`_units`, `party`(활성 부대), `_player_party_at`, `_raise_party`) · `scenes/camp/camp_menu.gd` (`raise_party` 시그널)

플레이어가 **여러 부대**를 거느리고, 각각을 선택해 조작한다. 지금까지는 단일 부대(`party`) 전제였으나,
이 기능으로 **다중 부대 + 선택** 토대를 놓고, 첫 생성 수단으로 **캠프 수비대에서 새 부대를 편성**한다.

## 다중 부대 모델 (토대 리팩터)

`game.gd`가 단일 `party`를 전제하던 것을 다음으로 일반화한다(동작은 부대 1개일 때 이전과 동일).

- `_units: Array` — **모든 플레이어 부대**. 시작 시 아젤 부대 1개(`$Party` 노드). 안개 시야·턴 리셋·부대 일람·점유·NPC 타깃 판정은 이 목록 전체를 순회한다.
- `party` — **현재 활성(선택된) 플레이어 부대**. 시작은 `$Party`, 다른 플레이어 부대를 클릭하면 그 부대로 **재할당**된다(선택 대상 전환). 이동·공격·사격·점령·휴식·경계·범위 표시·행동 메뉴는 모두 활성 `party`에 대해 동작한다.
- `_selected: bool` — 활성 부대가 선택(범위·메뉴 표시) 상태인지. `party`는 선택 해제해도 마지막 활성 부대를 계속 가리킨다(fog/점유는 `party`가 아니라 `_units`를 쓰므로 안전).
- **선택**: 플레이어 부대 칸 클릭 → 그 부대를 활성(`party`)으로 바꾸고 선택. 같은 부대 재클릭은 기존 동작(메뉴 복귀). 빈 곳/해제 클릭 → 선택 해제(`party`는 유지).
- **클릭 판정**: `_player_party_at(cell)` — 그 칸에 선 플레이어 부대(멤버 있는 것)를 찾는다. `ClickRouter`의 `on_party`는 "클릭 칸에 플레이어 부대가 있는가"로 일반화된다.
- **안개**: `_update_fog`가 모든 `_units`의 시야원을 합친다(+ 완성 건물). → [Fog of War](fog-of-war.md).
- **점유·타깃**: 이동 장애물·NPC 접근 타깃은 `_units + _npc_parties`.
- **전투**: 플레이어가 방어하는 전투 판정은 `공격 대상 in _units`(단일 `== party` 대신).
- **빈 부대**: 멤버 0명 부대는 토큰 미표시·일람 제외([Party](../entities/Party.md) `_draw`·[Party Roster](party-roster.md)). `_units`에는 남되 선택·이동은 무의미(멤버 0 → 이동력 0).

## 부대 생성 — 캠프 수비대에서 편성 (`_raise_party`)

자기 [캠프](garrison.md)에서 **새 부대**를 일으켜 수비대 병력으로 채운다.

- [캠프 메뉴](camp-menu.md)에 **[새 부대 편성]** 버튼(자기 캠프). 누르면 `raise_party` 시그널 → `game.gd` `_raise_party(camp)`:
  1. 캠프에 **인접한 빈 칸**(부대 없는 칸)을 하나 찾는다. 없으면 아무 일도 안 함.
  2. 새 [부대](../entities/Party.md)를 생성(플레이어 세력·금색, 이름 "새 부대")해 그 칸에 두고 `_units`에 추가한다. 처음엔 멤버 0명(빈 부대 → 토큰 안 보임).
  3. 캠프 메뉴를 그 **새 부대를 편성 대상으로** 다시 연다(`camp_menu.open(camp, 새 부대)`).
- 이후 기존 [수비대 편성](garrison.md#수비대-편성-camp_menu)으로 수비대 병사를 새 부대로 옮기면 부대가 나타난다.
- 생성된 부대는 완전한 플레이어 부대다 — 선택·이동·전투·점령·수비대 편성 모두 가능.

## 이번 슬라이스 제외 (미구현)

- **부대 분할**(선택 부대의 멤버 일부 → 인접 칸 새 부대) — 다음 슬라이스.
- **부대 병합**(인접 두 아군 부대 합치기) — 다음 슬라이스.
- 부대 수 상한·유지비.

## 테스트 시나리오

다중 부대 토대·생성은 대부분 `game.gd`(씬 트리·터레인 의존) 오케스트레이션이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)* 단위 테스트 가능한 표면:

**캠프 메뉴 [새 부대 편성] 버튼** — `test/unit/test_camp_menu.gd`:
- [정상] 자기 캠프 `open` → "새 부대 편성" 버튼 존재
- [정상] 버튼 클릭 → `raise_party(building)` 시그널 방출

**빈 부대 처리**(기존, 재확인) — `test/unit/test_party_roster.gd`·`test/unit/test_party.gd`:
- 멤버 0명 부대는 일람 제외, `_draw` 생략.

`game.gd`의 활성 `party` 전환·`_player_party_at`·`_raise_party`·다중 시야 합산은 하네스로 검증한다(선택·이동·공격·점령·안개가 부대 1개일 때 이전과 동일, 2개 이상에서 각각 독립 동작).

## 관련

- [Parties (부대 배치)](parties.md) — 초기 부대 생성. [Garrison (수비대)](garrison.md) — 새 부대를 채우는 병력원. [Camp Menu](camp-menu.md) — [새 부대 편성] 버튼.
- [Selection & Movement](selection-and-movement.md) — 선택·이동(이제 활성 `party` 기준). [Party Roster](party-roster.md) · [Fog of War](fog-of-war.md).
