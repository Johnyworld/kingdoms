# Feature: Party Composition (부대 편성 — 다중 부대)

> 스크립트: `scenes/game/game.gd` (`_units`, `party`(활성 부대), `_player_party_at`, `_split_party`, `_merge_targets`) · `scenes/party/split_panel.gd` (`SplitPanel`) · `scenes/party/party.gd` (`merge_from`)

플레이어가 **여러 부대**를 거느리고, 각각을 선택해 조작한다. 지금까지는 단일 부대(`party`) 전제였으나,
이 기능으로 **다중 부대 + 선택** 토대를 놓고, **분할·병합**으로 부대를 재조직한다. (거점 [주둔 부대](garrison.md)도 하나의 부대라, 새 부대는 주둔 부대를 [주둔 종료] 후 **분할**해 만든다.)

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

## 부대 분할 (`_split_party` + `SplitPanel`)

선택한 부대의 멤버 일부를 인접 칸의 **새 부대**로 나눈다(재조직 — 턴 소비 없음).

- **[분할]** — 부대 [행동 메뉴](party-action-menu.md)의 버튼. 활성 부대의 **멤버가 2명 이상**이고 **인접 빈 칸**이 있을 때만 활성.
- `game.gd` `_split_party()`: 활성 부대 인접 빈 칸(`_empty_adjacent_cell` 재사용, 캠프가 아니라 부대 기준)에 **빈 새 부대**를 만들어 `_units`에 넣고, **분할 패널**(`SplitPanel`)을 연다.
- **분할 패널**(`scenes/party/split_panel.gd`, 코드 UI CanvasLayer — 두 목록 패턴): 왼쪽 **원 부대**·오른쪽 **새 부대**. 멤버 버튼 클릭으로 양쪽을 오간다(`Party.add_member`/`remove_member`). 변경 시 `changed` 시그널 → `game.gd`가 일람·안개 갱신.
- **화물·노획 장비 분배**: 멤버 목록 아래 두 섹션 —
  - **화물**: 자원별 행 `자원 · 원N [→][←] 새M`. `[→]`/`[←]`가 `CARGO_STEP`(5)씩 원↔새로 옮긴다(`Party.transfer_cargo_to`). **받는 부대 [화물 용량](../entities/Party.md#화물-cargo--캐러반)(50) 초과 허용**(병합·약탈과 동일) — 그 방향 **보유가 0일 때만** 비활성. `인구`·`금`은 제외(노동력·화폐 — 영지 전용). *(적재 초과 시 이동력 감소는 `미구현`(예정).)*
  - **노획 장비**: 아이템별(이름 묶음) 행 `이름 · 원N [→][←] 새M`. `[→]`/`[←]`가 **1개씩** 옮긴다(`Party.transfer_loot_to`). 용량 제한 없음.
  - 두 부대 화물·장비의 합집합으로 행을 만들고, 옮길 때마다 목록을 재구성한다.
- **닫을 때**: 새 부대가 **비어 있으면**(멤버 0명 — 분할 취소) 그 새 부대를 제거하되, **새 부대로 옮겨둔 화물·노획 장비는 원 부대로 회수**한다(소실 방지). `_units`에서 빼고 free, **소비 없음**. 멤버가 있으면 분할 확정 — **원 부대·새 부대 둘 다 이번 턴 행동을 끝낸다**(`mark_attacked`, 재조직 비용). 다음 턴 리셋.

## 부대 병합 (`_merge_targets` + `Party.merge_from`)

선택한 부대에 **인접한 아군 부대**를 합친다(재조직 — 턴 소비 없음).

- **대상 판정**(`_update_ranges` → `_merge_targets`): 활성 부대 칸에 **인접**하고 멤버가 있는 **다른 플레이어 부대**. cell → party.
- **클릭**: 활성 부대 선택 상태에서 인접 아군 부대 칸을 클릭 → **[병합] 팝업**([공격] 팝업과 같은 `PartyActionMenu`). (선택 중 인접 아군 클릭은 전환 대신 병합 팝업 — 전환하려면 먼저 선택 해제.)
- **[병합]**: `Party.merge_from(other)` — 그 아군 부대(other)의 멤버를 **활성 부대로 흡수**하고, other는 `_units`에서 빼고 free한다. 활성 부대는 자리를 지키고 병력이 합쳐진다. 병합 후 활성 부대는 **이번 턴 행동을 끝낸다**(`mark_attacked`).

## 새 동작 (엔티티)

- `Party.merge_from(other) -> void` — `other.members`를 모두 자신에게 `add_member`로 옮기고 `other.members`를 비운다(other는 빈 부대가 됨 → 호출부가 제거). 자신의 지휘관은 유지(없으면 첫 합류 멤버).
- `Party.transfer_cargo_to(other, res_name, n) -> int` — 화물 자원을 `other`로 옮긴다(분할 분배). 받는 부대 용량 존중, 옮긴 양 반환. ([Party](../entities/Party.md#동작))
- `Party.transfer_loot_to(other, id) -> bool` — 노획 장비 1개를 `other`로 옮긴다(분할 분배). 미보유면 `false`. ([Party](../entities/Party.md#동작))

## 이번 슬라이스 제외 (미구현)

- 부대 수 상한·유지비.

## 테스트 시나리오

다중 부대 토대·생성은 대부분 `game.gd`(씬 트리·터레인 의존) 오케스트레이션이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)* 단위 테스트 가능한 표면:

**빈 부대 처리**(기존, 재확인) — `test/unit/test_party_roster.gd`·`test/unit/test_party.gd`:
- 멤버 0명 부대는 일람 제외, `_draw` 생략.

**부대 병합** — `test/unit/test_party.gd`:
- [정상] `a.merge_from(b)` 후 a에 b 멤버가 합쳐지고 b는 빈 배열, a 지휘관 유지
- [경계] 빈 부대를 `merge_from` → a 변화 없음

**부대 분할 분배(transfer)** — `test/unit/test_party.gd`:
- [정상] `transfer_cargo_to`(이동·보유상한·용량상한·0), `transfer_loot_to`(이동·미보유) — [Party 시나리오](../entities/Party.md#테스트-시나리오) 참조.

**분할 패널** — `test/unit/test_split_panel.gd`:
- [정상] `open(orig, new)` → 두 목록이 각 인원수로 채워짐
- [정상] 원 부대원 클릭 → 원 −1, 새 부대 +1(반대도); 변경 시 `changed` 방출
- [정상] 버튼 pressed 경로로도 이동(리스트 재구성 안전 — locked 방지)
- [정상] 화물 분배: 원 부대 화물 있을 때 화물 행 표시, `[→]` 클릭 → 원 −5·새 +5, `changed` 방출
- [정상] 장비 분배: 원 부대 `loot_items` 있을 때 장비 행 표시, `[→]` 클릭 → 1개 이동
- [경계] 그 방향 보유가 0이면 `[→]`/`[←]` 비활성(용량 초과는 허용이라 여유와 무관)
- 취소 시 화물·장비 원 부대 회수·확정은 `game.gd` 배선이라 실행 확인

`game.gd`의 활성 `party` 전환·`_player_party_at`·다중 시야 합산은 하네스로 검증한다(선택·이동·공격·점령·안개가 부대 1개일 때 이전과 동일, 2개 이상에서 각각 독립 동작).

## 관련

- [Parties (부대 배치)](parties.md) — 초기 부대 생성. [Garrison / 주둔](garrison.md) — 거점 주둔 부대(분할로 병력을 나눠 새 부대 편성).
- [Selection & Movement](selection-and-movement.md) — 선택·이동(이제 활성 `party` 기준). [Party Roster](party-roster.md) · [Fog of War](fog-of-war.md).
