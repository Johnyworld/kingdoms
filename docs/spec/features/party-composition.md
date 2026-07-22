# Feature: Party Composition (부대 편성 — 다중 부대)

> 스크립트: `scenes/game/game.gd` (`PartyManager.units`, `party`(활성 부대), `_player_party_at`, `_merge_targets`) · `scenes/party/party.gd` (`merge_from`)

플레이어가 **여러 부대**를 거느리고, 각각을 선택해 조작한다. 지금까지는 단일 부대(`party`) 전제였으나,
이 기능으로 **다중 부대 + 선택** 토대를 놓고, **병합**으로 부대를 재조직한다. (부대 **분할**은 순수 랑그릿사화(M4-C)로 제거 — 개별 병사가 없어 나눌 대상이 없다.)

## 다중 부대 모델 (토대 리팩터)

`game.gd`가 단일 `party`를 전제하던 것을 다음으로 일반화한다(동작은 부대 1개일 때 이전과 동일).

- `PartyManager.units: Array` — **모든 플레이어 부대**(목록 단일 출처 — 부대 생명주기는 `scenes/party/party_manager.gd`). 시작 시 아젤 부대 1개(`$Party` 노드). 안개 시야·턴 리셋·부대 일람·점유·NPC 타깃 판정은 이 목록 전체를 순회한다.
- `party` — **현재 활성(선택된) 플레이어 부대**. 시작은 `$Party`, 다른 플레이어 부대를 클릭하면 그 부대로 **재할당**된다(선택 대상 전환). 이동·공격·사격·점령·범위 표시·행동 메뉴는 모두 활성 `party`에 대해 동작한다.
- `_selected: bool` — 활성 부대가 선택(범위·메뉴 표시) 상태인지. `party`는 선택 해제해도 마지막 활성 부대를 계속 가리킨다(fog/점유는 `party`가 아니라 `PartyManager.units`를 쓰므로 안전).
- **선택**: 플레이어 부대 칸 클릭 → 그 부대를 활성(`party`)으로 바꾸고 선택. 같은 부대 재클릭은 기존 동작(메뉴 복귀). 빈 곳/해제 클릭 → 선택 해제(`party`는 유지).
- **클릭 판정**: `_player_party_at(cell)` — 그 칸에 선 플레이어 부대(병력 있는 것)를 찾는다. `ClickRouter`의 `on_party`는 "클릭 칸에 플레이어 부대가 있는가"로 일반화된다.
- **안개**: `_update_fog`가 모든 `PartyManager.units`의 시야원을 합친다(+ 완성 건물). → [Fog of War](fog-of-war.md).
- **점유·타깃**: 이동 장애물·NPC 접근 타깃은 `PartyManager.units + PartyManager.npc_parties`.
- **전투**: 플레이어가 방어하는 전투 판정은 `공격 대상 in PartyManager.units`(단일 `== party` 대신).
- **빈 부대**: 병력 0(`soldiers <= 0`) 부대는 토큰 미표시·일람 제외([Party](../entities/Party.md) `_draw`·[Party Roster](party-roster.md)). `PartyManager.units`에는 남되 조회·선택 대상에서 빠진다.

## 부대 병합 (`_merge_targets` + `Party.merge_from`)

선택한 부대에 **인접한 같은 병종의 아군 일반부대**를 합친다(재조직 — 턴 소비 없음).

- **병합 제약**: **같은 병종([`troop_type`](../entities/Party.md#정체-identity))끼리만**, **일반부대(`KIND_TROOP`)끼리만**, 그리고 **합쳐도 병력 상한([`TROOP_SIZE`](../data/factions.md#상수), 10)을 넘지 않을 때만** 병합할 수 있다(예: 4+6·5+5 가능, 6+5 불가). 영웅부대는 지휘관 1인 단독이라 **병합 자체가 없다**(대상도, 개시도 불가). 판정은 [`Party.can_merge_with(other)`](../entities/Party.md#동작)이 단일 출처.
- **대상 판정**(`_update_ranges` → `_compute_merge_targets`): 활성 부대 칸에 **인접**하고 병력이 있는 **다른 플레이어 부대** 중 [`party.can_merge_with(p)`](../entities/Party.md#동작)이 참인 것만. cell → party. (병합 불가한 부대는 대상에서 빠져 **[병합] 팝업이 뜨지 않는다**.)
- **클릭**: 활성 부대 선택 상태에서 인접 아군 부대 칸을 클릭 → **[병합] 팝업**([공격] 팝업과 같은 `PartyActionMenu`). (선택 중 인접 아군 클릭은 전환 대신 병합 팝업 — 전환하려면 먼저 선택 해제.)
- **[병합]**: `Party.merge_from(other)` — 그 아군 부대(other)의 **병력을 활성 부대로 흡수**하고(`soldiers += other.soldiers`), other는 `PartyManager.units`에서 빼고 free한다. 활성 부대는 자리를 지키고 병력이 합쳐진다. 병합 후 활성 부대는 **이번 턴 행동을 끝낸다**(`mark_attacked`). 대상이 같은 병종으로 걸러졌으므로 병합 후에도 부대는 **하나의 병종으로 동질**하게 유지된다.

## 새 동작 (엔티티)

- `Party.can_merge_with(other) -> bool` — `other`를 자신에게 병합할 수 있는지(같은 병종·둘 다 일반부대). **병합 가능 판정의 단일 출처**. ([Party](../entities/Party.md#동작))
- `Party.merge_from(other) -> void` — `other`의 병력을 자신에게 흡수한다(`soldiers += other.soldiers; other.soldiers = 0` → other는 병력 0이 됨 → 호출부가 제거). 자신의 `commander_name`은 유지. *(병종 검사는 호출부가 `can_merge_with`로 이미 거른다 — 이 함수는 병력 합산만 수행)*

## 이번 슬라이스 제외 (미구현)

- 부대 수 상한·유지비.

## 테스트 시나리오

다중 부대 토대·생성은 대부분 `game.gd`(씬 트리·터레인 의존) 오케스트레이션이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)* 단위 테스트 가능한 표면:

**빈 부대 처리**(기존, 재확인) — `test/unit/test_party_roster.gd`·`test/unit/test_party.gd`:
- 병력 0(`soldiers <= 0`) 부대는 일람 제외, `_draw` 생략.

**부대 병합** — `test/unit/test_party.gd`:
- [정상] `a.merge_from(b)` 후 `a.soldiers += b.soldiers`, `b.soldiers == 0`, `a.commander_name` 유지
- [경계] 빈 부대(`soldiers == 0`)를 `merge_from` → a 변화 없음
- [정상] `can_merge_with`: 같은 병종 일반부대끼리(병력 합계 ≤ 10) → 참 ([Party 시나리오](../entities/Party.md#테스트-시나리오) 참조)
- [예외] `can_merge_with`: 다른 병종 / 영웅부대 포함 / 병력 합계 > 10 / `null` → 거짓 ([Party 시나리오](../entities/Party.md#테스트-시나리오) 참조)

`game.gd`의 활성 `party` 전환·`_player_party_at`·다중 시야 합산은 하네스로 검증한다(선택·이동·공격·점령·안개가 부대 1개일 때 이전과 동일, 2개 이상에서 각각 독립 동작).

## 관련

- [Parties (부대 배치)](parties.md) — 초기 부대 생성. [Camp Capture](camp-capture.md#거점-방어-창발--중심-점거) — 거점 방어 부대(중심 점거로 창발).
- [Selection & Movement](selection-and-movement.md) — 선택·이동(이제 활성 `party` 기준). [Party Roster](party-roster.md) · [Fog of War](fog-of-war.md).
