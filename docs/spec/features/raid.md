# Feature: Raid (약탈 — 전멸한 적 부대 전사자 장비 노획)

> 스크립트: `scenes/party/party.gd`(`equipment_ids`/`take_all_equipment`) · `scenes/loot/loot_menu.gd`(약탈 패널) · `scenes/game/game.gd`(전투 결과 연동)

전투에서 **적 부대가 전멸**(전원 사망 → 부대 제거)하면, 생존한 **승자 부대**가 패자 **전사자 장비**([노획 장비](../entities/Party.md#노획-장비-loot-items))를 노획한다.
플레이어가 이기면 무엇을 가져올지 직접 고르고, NPC가 이기면 전량 자동 획득한다.

노획 대상은 **전사자 장비**(무기·방어구·방패 id)다. 장비는 승자 `loot_items`로 들어간다. **노획 장비의 활용**(장착·판매·전용 표시 UI)은 `미구현`. (화물 자원 노획은 [화물 제거](../entities/Party.md)로 폐지 — 이제 부대가 자원을 나르지 않는다.)

## 발동 조건

- 전투 종료 시 **정확히 한 부대만 전멸**했을 때(승자=생존, 패자=전멸). 양쪽 생존(후퇴)·양쪽 전멸(상호 전멸)이면 약탈 없음.
- 패자에게 노획할 장비(`equipment_ids()`가 비어있지 않음)가 하나도 없으면 아무 일도 일어나지 않는다(패널도 안 뜸).
- 장비 `loot_items`는 용량 제한 없음.
- 약탈은 패자 부대가 맵에서 제거(`_apply_survivors`의 `queue_free`)되기 **전에** 처리한다. 패자 멤버 장비를 읽어야 하므로(전멸 시점 `loser.members`는 아직 전사자 전원을 담고 있다).
- 승자·패자 모두 지속 부대(거점 방어 부대 포함)라, 노획물은 **승자 부대 자신이 보유**한다.

## 승자가 플레이어 부대 (관전 전투 · `_run_battle`)

- 오버레이 종료 후 승자가 **플레이어 세력 부대**이면 **약탈 패널**(`loot_menu`)을 띄우고 `await`한다. 패널은 노획 장비가 있으면 뜬다.
- 패널은 제목 "약탈" 아래 **좌우 2열** —
  - **왼쪽 「노획」(패자)**: **장비** 섹션 — 아이템별 행 `"<이름>"`([`ItemTypes.item_name`](../data/items.md)) + **[가져오기]**(그 아이템 → 승자 `loot_items`).
  - **오른쪽 「내 인벤토리」(승자)**: **읽기 전용**. 승자의 노획 장비(`loot_items`를 이름별로 묶어 `"<이름> ×<개수>"`). 비면 `"(없음)"`. 가져올 때마다 갱신돼 쌓이는 게 보인다.
  - 하단 **[모두 가져오기]**(남은 장비 전부) · **[닫기]**.
- 왼쪽에서 **[가져오기]** 하면 그 행이 사라지고 오른쪽 내 인벤토리에 반영된다. 노획 대상 장비가 모두 비거나 **[닫기]**면 패널을 닫는다.
- **닫을 때 안 가져간 장비는 소실**된다(패자 부대가 곧 `_apply_survivors`로 제거되므로).

## 승자가 NPC (또는 NPC↔NPC · `_resolve_battle_headless`)

- 패널 없이 `winner.take_all_equipment(loser)`(장비 전량)로 **자동 획득**한다. NPC가 플레이어를 이긴 경우(`_run_battle`)·NPC끼리(`_resolve_battle_headless`) 모두 동일.

## 수비대 방어 노획

거점을 지키는 [방어 부대](camp-capture.md#거점-방어-창발--중심-점거)는 그냥 **지속 부대**다. **방어 승리**(공격자 전멸) 시 노획 장비를 (플레이어면 [약탈 패널](#승자가-플레이어-부대-관전-전투--_run_battle), NPC면 전량 자동) **그 부대 자신이 보유**한다 — 일반 부대 승리와 완전히 동일.

## Party 노획 API (`party.gd`)

- `equipment_ids() -> Array` — 이 부대 전 멤버의 장비 id 평탄 목록(각 멤버 `weapons` + `armor` + `shield`). 빈 방패(`""`) 제외, 중복 유지. 읽기 전용(멤버·장비 불변). 약탈 시 패자 장비 스냅샷.
- `take_all_equipment(source) -> void` — `source.equipment_ids()`를 이 부대 `loot_items`에 전부 더한다(자동 장비 약탈). `source` 불변.
- 플레이어 패널에서 장비 한 점 노획 = `winner.loot_items.append(id)`(패널이 남은 스냅샷에서 그 id를 제거).

## 테스트 시나리오

### Party 노획 API — `test/unit/test_party.gd`

- [정상] `equipment_ids`: 멤버 무기 `["sword","bow"]`·방어구 `["leather_armor"]`·방패 `"buckler"` → `["sword","bow","leather_armor","buckler"]`(평탄·순서 유지)
- [경계] `equipment_ids`는 빈 방패 제외, 중복 id 유지(두 멤버 `sword` → 두 개); 멤버 없으면 `[]`
- [정상] `take_all_equipment`: source 멤버 장비 전부가 self `loot_items`에 더해짐(중복 유지), `source` 불변
- [경계] `take_all_equipment` 장비 없는 source → `loot_items` 변화 없음

### ItemTypes 통합 이름 — `test/unit/test_item_types.gd`

- [정상] `item_name("sword") == "검"`, `item_name("chain_mail") == "사슬 갑옷"`, `item_name("buckler") == "버클러"`; [예외] `item_name("") == ""`, 없는 id → `""`

### 내 인벤토리 묶음 표시 — `test/unit/test_loot_menu.gd`

- [정상] `_grouped_lines(["sword","sword","bow"]) == ["검 ×2", "단궁 ×1"]`(이름별로 묶고 첫 등장 순서 유지)
- [경계] `_grouped_lines([]) == []`

### 약탈 연동 (실행 확인)

- 승자 판정(한쪽만 전멸)·플레이어 승자 패널(좌 노획 2섹션 / 우 내 인벤토리 읽기 전용)·NPC 자동 전량은 `game.gd` 배선이라 실제 실행으로 확인한다. 거점 방어 부대의 방어 승리 노획도 지속 부대와 같은 경로라 별도 배선이 없다.

## 미구현

- **노획 장비 활용** — 노획한 장비를 승자 멤버에게 장착하거나 판매·전용 목록 표시. 지금은 `loot_items`에 수집만 한다.
- 상호 전멸 시 분배, 약탈 애니메이션.

## 관련

- 노획 장비 모델은 [Party](../entities/Party.md#노획-장비-loot-items). 아이템 이름은 [Items](../data/items.md). 전투 개시·결과 반영 흐름은 [Battle](battle.md).
