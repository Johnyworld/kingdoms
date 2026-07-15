# Feature: Camp Capture (캠프 점령 — 흡수/파괴)

> 스크립트: `scenes/game/game.gd` (`_compute_capture_targets`, `_camp_stand`, `_open_capture_popup`, `_capture_camp`, `_do_capture`, `_transfer_camp`, `_destroy_camp`, `_capturable_camp_for`, `_faction_named`) · `scenes/party/party_action_menu.gd` (`capture_actions`) · `scenes/faction/faction.gd` (`remove_territory`) · `scenes/territory/territory.gd` (`remove_building`)

선택한 플레이어 [부대](../entities/Party.md)로 발견된 적 [거점](npc-bases.md)(캠프)을 **점령**한다.
점령 시 **흡수**(영지 획득)와 **파괴**(제거) 중 하나를 고른다. 지난 슬라이스에서 유예했던 거점 상호작용의 핵심.

## 거점 방어 (창발 — 중심 점거)

거점을 지키는 **수비대는 별도 개념이 아니라 그냥 [부대](../entities/Party.md)**다. 방어는 특별한 상태(예전 `stationed`/주둔)가 아니라, **거점 중심 타일 위에 그 거점 세력의 부대가 있음**(`_camp_defender`)으로 창발한다.

- **방어됨** = 중심 타일을 그 거점 세력 부대가 점거 → 점령 전에 먼저 그 부대를 [공격](battle.md)해 격파해야 한다(중심에 진입할 수 없으므로).
- **무방비** = 중심 타일에 그 거점 세력 부대가 없음 → 바로 [흡수/파괴] 대상.
- 다른 세력 부대(격파 후 진입한 공격자 포함)가 중심에 서 있어도 그 거점 세력이 아니면 방어로 치지 않는다.
- **초기 배치**: 게임 시작 시 각 거점 중심 타일에 경보병 일반부대 1개를 세운다([시작 편제](parties.md)) — 별도 상태 없이 그 자리를 점거해 방어자가 된다. 플레이어·NPC 모두 병력을 안에 두어야 거점이 지켜진다.

**정보 표시** — 완성 **거점**이고 중심 타일에 그 거점 세력 부대가 있으면 중심 아래에 `"수비 N"` 배지(N = 그 부대 인원, `Building.defender_count`, `_refresh_garrison_badges`가 갱신)를 그린다. [거점 정보 패널](building-info.md)에도 `"수비대 N명"`을 표시한다. 성벽 안 중심 방어 부대의 [사다리 밀기](wall.md#사다리-밀기-방어)는 성벽 방어 참조.

세력 소멸·정복 승리는 [승패](victory.md) 참조(캠프 0 → 10턴 유예 → 소멸).

## 점령 대상 판정 (`game.gd` `_compute_capture_targets`)

[부대](../entities/Party.md) 선택 시([공격] 대상 계산과 함께) 매번 갱신한다.

- **발견된**(`camp.visible`) NPC 거점만 대상. 미발견(안개) 거점은 제외.
- 부대가 그 캠프에 **인접 가능**하면 점령 대상 — `_camp_stand(camp, start)`가 설 자리(현재 칸 또는 이동범위 내 인접 칸)를 돌려주면 점령 가능, 없으면(`Vector2i(-1,-1)`) 제외.
  - 판정: 캠프 7칸 중 하나라도 이웃 칸이 (현재 칸 ∪ 이동 도달 칸 `_reachable`)에 있으면 인접 가능. 이미 인접이면 현재 칸을 설 자리로.
- **[성벽](wall.md) 있는 적 거점은 점령 대상이 아니다** — 적 부대가 footprint에 진입할 수 없어 중심에 도달할 수 없다(사다리·공성병기 = 후속 슬라이스). `_compute_camp_targets`가 walled 적 거점을 건너뛴다.
- 성벽 없는 거점은 `game.gd`의 `_compute_camp_targets`가 인접 가능한 대상을 기록한다. **그 거점 세력의 부대가 중심을 지키는지(`_camp_defender`)로 갈린다**([거점 방어](#거점-방어-창발--중심-점거)) — 지키면 그 부대를 [공격](일반 부대 전투), **수비 부대가 없는(무방비) 거점만 `_capture_targets`(점령 대상)**. 점령은 **중심 타일 진입**으로 성립하므로, 수비 부대가 있으면 먼저 격파해야 진입·점령할 수 있다(격파 후 중심에 선 공격자는 그 거점 세력이 아니라 방어로 치지 않는다).
- 표시: 두 경우 모두 캠프 칸을 [공격 가능 적]과 같은 **빨강 오버레이**로 그린다(MOVE 모드). → [Selection & Movement](selection-and-movement.md).

## 점령 흐름 (클릭 → 팝업 → 실행)

1. MOVE 모드에서 **무방비 거점 클릭** → 그 거점 근처에 **[흡수][파괴] 팝업**을 연다(`_open_capture_popup`, [공격] 팝업과 같은 `PartyActionMenu`). (중심에 그 거점 세력 부대가 있으면 대신 그 부대 [공격] 팝업 → [거점 방어](#거점-방어-창발--중심-점거).)
   - 인접 **불가**하거나 **미선택** 상태의 캠프 클릭 → 기존 [거점 정보 패널](building-info.md)([NPC Bases](npc-bases.md) `NPC_BASE_INFO`).
2. **[흡수]/[파괴] 선택**(`_capture_camp`):
   - 이미 인접(설 자리 == 현재 칸)이면 즉시 실행.
   - 아니면 설 자리로 **이동 애니메이션** 후 실행(`_move_player_to`의 이동 후 처리 `_after_move`가 점령을 이어받는다 — 근접 공격과 같은 방식).
   - 점령은 부대 **행동을 끝낸다**(`mark_attacked`) — 되돌리기(undo)도 소멸.
3. **실행**:
   - **흡수**(`_transfer_camp(camp, _player_faction)`) — 영지를 점령한 세력으로 이전(플레이어·NPC 공용, 아래 [소유권 이전](#소유권-이전-_transfer_camp) 참고).
   - **파괴**(`_destroy_camp`) — 캠프를 제거:
     - 영지에서 건물 제거(`Territory.remove_building`), `_npc_buildings`에서 제거, 노드 `queue_free`.
     - 영지·세력은 남지만 캠프 0개가 된다(→ [세력 소멸](victory.md)).
   - 실행 후 안개·부대 일람 갱신, 선택 해제.

## 소유권 이전 (`_transfer_camp`)

캠프 점령의 소유권 이전을 플레이어·NPC가 공유하는 `_transfer_camp(camp, new_faction)`으로 처리한다.

- **영지 이전**: 이전 세력에서 제거(`Faction.remove_territory`) → `new_faction`에 편입(`Faction.add_territory`).
- **건물 리스트 재배치**(소유주에 따라):
  - `new_faction`이 **플레이어**면 캠프를 `_buildings`로 옮기고(플레이어 시야를 밝히고 건축 점유·[캠프 메뉴](camp-menu.md) 대상), 영지를 `_territories`에 넣어 턴 수입을 받게 한다.
  - `new_faction`이 **NPC**면 캠프를 `_npc_buildings`로 옮기고, 영지를 `_territories`에서 뺀다(수입 제외). 이후 표시는 탐험 기준([NPC Bases](npc-bases.md) `_update_npc_building_visibility`).
- 라벨색이 새 세력색으로 바뀐다(`map_label_lines`는 `territory.faction.color` 사용). 이전 직후 `visible = true`, `_update_fog`가 최종 표시를 정한다.

## NPC 점령 (`game.gd` `_npc_unit_act`)

NPC도 이동 뒤 **공격 페이즈**에서 적 캠프를 점령한다 → [NPC Movement](npc-movement.md).

- **우선순위**: 인접한 적 부대가 있으면 먼저 전투(현행). 공격할 적 부대가 없고 **인접(또는 그 위)한 적 캠프**가 있으면 그 캠프를 **흡수**한다(`_transfer_camp(camp, 그 NPC의 세력)`).
- 점령은 그 NPC의 행동을 끝낸다(`mark_attacked`). 중심에 수비 부대가 없는(무방비) 거점만 점령 대상이다(있으면 먼저 전투).
- NPC가 **플레이어 캠프**를 흡수하면 플레이어 캠프 수가 줄어 → 다음 턴부터 [세력 소멸 유예](victory.md)가 시작된다(플레이어 패배가 실제로 도달 가능). 플레이어는 재점령으로 되찾을 수 있다.
- `_capturable_camp_for(attacker)`가 소유 세력이 다른(적) 캠프 중 인접/위의 것을 찾고, `_faction_named`이 세력 이름으로 `Faction` 객체를 찾는다.

## 새 동작 (엔티티)

점령의 소속 이전·제거를 위해 [세력](../entities/Faction.md)·[영지](../entities/Territory.md)에 제거 메서드를 둔다(기존 `add_*`의 짝).

- `Faction.remove_territory(territory) -> void` — `territories`에서 제거하고, `territory.faction`이 이 세력이면 `null`로 되돌린다. 없으면 no-op.
- `Territory.remove_building(building) -> void` — `buildings`에서 제거하고, `building.territory`가 이 영지면 `null`로 되돌린다. 없으면 no-op.

## 관련 후속

- 캠프 흡수/파괴로 세력이 캠프 0이 되면 **세력 소멸(10턴 유예) → 정복 승리 / 플레이어 패배** 판정이 이어진다. → [승패](victory.md).

## 점령/함락 알림 (`Toast`)

캠프 소유권이 바뀌면 화면 상단 중앙에 짧은 메시지를 띄운다(`scenes/game/toast.gd`, 코드 UI CanvasLayer — 잠깐 표시 후 페이드 아웃). `game.gd`가 `_transfer_camp`/`_destroy_camp`에서 호출한다.

- **점령**(`_transfer_camp`에서 새 소유주가 플레이어) → `"<영지명> 점령!"`.
- **함락**(이전 소유주가 플레이어였는데 넘어감) → `"<영지명> 함락!"`. NPC가 플레이어 캠프를 빼앗을 때 확실히 인지시킨다.
- **파괴**(`_destroy_camp` — 플레이어만 파괴) → `"<영지명> 파괴!"`.
- NPC↔NPC 소유권 이전은 알림을 띄우지 않는다(노이즈 방지).

## 관련 후속

- 거점 중심에 **그 거점 세력 부대**가 있으면 점령 전에 먼저 격파해야 한다 → [거점 방어](#거점-방어-창발--중심-점거). 무방비(중심 타일 부대 없음) 거점만 [흡수/파괴] 대상.

## 미구현

- NPC의 점령은 **흡수만**(파괴는 안 함).

## 테스트 시나리오

**점령 팝업 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `capture_actions()` → `["absorb", "destroy"]`, 둘 다 활성

**세력 소속 이전** — `test/unit/test_faction.gd`:
- [정상] `remove_territory(t)` 후 `territories`에서 빠지고 `t.faction == null`
- [정상] 이전: `old.remove_territory(t)` → `new.add_territory(t)` 후 `t.faction == new`, `new.territories`에 포함, `old.territories`에서 제외
- [경계] 보유하지 않은 영지를 `remove_territory` → no-op(크래시 없음)

**영지 건물 제거** — `test/unit/test_territory.gd`:
- [정상] `remove_building(b)` 후 `buildings`에서 빠지고 `b.territory == null`
- [경계] 보유하지 않은 건물을 `remove_building` → no-op

`game.gd`의 점령 리치 판정·이동·팝업·흡수/파괴 배선, **소유권 이전(`_transfer_camp`)과 NPC 점령**(씬 트리·터레인 의존)은 실제 실행으로 확인한다. 소속 이전은 `remove_territory`+`add_territory`(단위 테스트됨)를 쓴다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [NPC Bases (NPC 거점)](npc-bases.md) — 점령 대상(발견·클릭 정보). [Party Action Menu](party-action-menu.md) — [흡수][파괴] 팝업. [승패](victory.md) — 세력 소멸/정복 승리/플레이어 패배.
- [Faction](../entities/Faction.md) · [Territory](../entities/Territory.md) — 소속 이전 메서드. [Camp Menu](camp-menu.md) — 흡수한 캠프의 건축.
- 기획: [승리조건](../../table/시스템/승리조건.md) · [영지](../../table/세력/영지.md)
