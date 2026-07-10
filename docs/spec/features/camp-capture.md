# Feature: Camp Capture (캠프 점령 — 흡수/파괴)

> 스크립트: `scenes/game/game.gd` (`_compute_capture_targets`, `_camp_stand`, `_open_capture_popup`, `_capture_camp`, `_do_capture`, `_absorb_camp`, `_destroy_camp`) · `scenes/party/party_action_menu.gd` (`capture_actions`) · `scenes/faction/faction.gd` (`remove_territory`) · `scenes/territory/territory.gd` (`remove_building`)

선택한 플레이어 [부대](../entities/Party.md)로 발견된 적 [거점](npc-bases.md)(캠프)을 **점령**한다.
점령 시 **흡수**(영지 획득)와 **파괴**(제거) 중 하나를 고른다. 지난 슬라이스에서 유예했던 거점 상호작용의 핵심.

현재 캠프에는 수비대가 없어 인접만 하면 즉시 점령된다. 세력 소멸·정복 승리는 **다음 슬라이스**(캠프 0 → 10턴 유예 → 소멸). → [승패](victory.md).

## 점령 대상 판정 (`game.gd` `_compute_capture_targets`)

[부대](../entities/Party.md) 선택 시([공격] 대상 계산과 함께) 매번 갱신한다.

- **발견된**(`camp.visible`) NPC 거점만 대상. 미발견(안개) 거점은 제외.
- 부대가 그 캠프에 **인접 가능**하면 점령 대상 — `_camp_stand(camp, start)`가 설 자리(현재 칸 또는 이동범위 내 인접 칸)를 돌려주면 점령 가능, 없으면(`Vector2i(-1,-1)`) 제외.
  - 판정: 캠프 7칸 중 하나라도 이웃 칸이 (현재 칸 ∪ 이동 도달 칸 `_reachable`)에 있으면 인접 가능. 이미 인접이면 현재 칸을 설 자리로.
- 점령 가능한 캠프의 **모든 칸**을 `_capture_targets[cell] = {camp, stand}`에 넣는다(어느 칸을 클릭해도 점령).
- 표시: 점령 가능 캠프 칸은 [공격 가능 적]과 같은 **빨강 오버레이**로 그린다(MOVE 모드). → [Selection & Movement](selection-and-movement.md).

## 점령 흐름 (클릭 → 팝업 → 실행)

1. MOVE 모드에서 **점령 가능한 캠프 칸 클릭** → 그 캠프 근처에 **[흡수][파괴] 팝업**을 연다(`_open_capture_popup`, [공격] 팝업과 같은 `PartyActionMenu`).
   - 점령 **불가**(인접 못 함)하거나 **미선택** 상태의 캠프 클릭 → 기존 [거점 정보 패널](building-info.md)([NPC Bases](npc-bases.md) `NPC_BASE_INFO`).
2. **[흡수]/[파괴] 선택**(`_capture_camp`):
   - 이미 인접(설 자리 == 현재 칸)이면 즉시 실행.
   - 아니면 설 자리로 **이동 애니메이션** 후 실행(`_move_player_to`의 이동 후 처리 `_after_move`가 점령을 이어받는다 — 근접 공격과 같은 방식).
   - 점령은 부대 **행동을 끝낸다**(`mark_attacked`) — 되돌리기(undo)도 소멸.
3. **실행**:
   - **흡수**(`_absorb_camp`) — 영지를 플레이어 세력으로 이전:
     - 이전 세력에서 영지 제거(`Faction.remove_territory`) → 플레이어 세력에 편입(`Faction.add_territory`).
     - 캠프를 `_npc_buildings` → `_buildings`로 옮긴다(이제 플레이어 시야를 밝히고 건축 점유·[캠프 메뉴](camp-menu.md) 대상이 된다).
     - 영지를 `_territories`에 넣어 턴 수입을 받게 한다. → [Turn](turn.md).
     - 캠프 라벨색이 플레이어 세력색으로 바뀐다(`map_label_lines`는 `territory.faction.color` 사용). 항상 보이게 `visible = true`.
   - **파괴**(`_destroy_camp`) — 캠프를 제거:
     - 영지에서 건물 제거(`Territory.remove_building`), `_npc_buildings`에서 제거, 노드 `queue_free`.
     - 영지·세력은 남지만 캠프 0개가 된다(소멸 판정은 다음 슬라이스).
   - 실행 후 안개·부대 일람 갱신, 선택 해제.

## 새 동작 (엔티티)

점령의 소속 이전·제거를 위해 [세력](../entities/Faction.md)·[영지](../entities/Territory.md)에 제거 메서드를 추가한다(기존 `add_*`의 짝).

- `Faction.remove_territory(territory) -> void` — `territories`에서 제거하고, `territory.faction`이 이 세력이면 `null`로 되돌린다. 없으면 no-op.
- `Territory.remove_building(building) -> void` — `buildings`에서 제거하고, `building.territory`가 이 영지면 `null`로 되돌린다. 없으면 no-op.

## 관련 후속

- 캠프 흡수/파괴로 세력이 캠프 0이 되면 **세력 소멸(10턴 유예) → 정복 승리** 판정이 이어진다. → [승패](victory.md).

## 미구현

- 캠프 **수비대**(거점 방어 부대) — 현재 인접만 하면 즉시 점령.
- NPC가 플레이어 캠프를 점령하는 AI(적 점령).

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

`game.gd`의 점령 리치 판정·이동·팝업·흡수/파괴 배선(씬 트리·터레인 의존)은 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [NPC Bases (NPC 거점)](npc-bases.md) — 점령 대상(발견·클릭 정보). [Party Action Menu](party-action-menu.md) — [흡수][파괴] 팝업. [승패](victory.md) — 세력 소멸/정복 승리(미구현).
- [Faction](../entities/Faction.md) · [Territory](../entities/Territory.md) — 소속 이전 메서드. [Camp Menu](camp-menu.md) — 흡수한 캠프의 건축.
- 기획: [승리조건](../../table/시스템/승리조건.md) · [영지](../../table/세력/영지.md)
