# Feature: Raid (약탈 — 전멸한 적 부대 화물·장비 노획)

> 스크립트: `scenes/party/party.gd`(`take_loot`/`take_all_loot`/`equipment_ids`/`take_all_equipment`) · `scenes/loot/loot_menu.gd`(약탈 패널) · `scenes/game/game.gd`(전투 결과 연동)

전투에서 **적 부대가 전멸**(전원 사망 → 부대 제거)하면, 생존한 **승자 부대**가 패자의 [화물](../entities/Party.md#화물-cargo--캐러반)과 **전사자 장비**([노획 장비](../entities/Party.md#노획-장비-loot-items))를 노획한다.
플레이어가 이기면 무엇을 가져올지 직접 고르고, NPC가 이기면 전량 자동 획득한다.

노획 대상은 **① 화물**(자원)과 **② 전사자 장비**(무기·방어구·방패 id) 두 가지다. 화물은 승자 `cargo`로, 장비는 승자 `loot_items`로 들어간다. **노획 장비의 활용**(장착·판매·전용 표시 UI)은 `미구현`.

## 발동 조건

- 전투 종료 시 **정확히 한 부대만 전멸**했을 때(승자=생존, 패자=전멸). 양쪽 생존(후퇴)·양쪽 전멸(상호 전멸)이면 약탈 없음.
- 패자에게 노획할 것(화물 `cargo_total() > 0` **또는** 장비 `equipment_ids()` 비어있지 않음)이 하나도 없으면 아무 일도 일어나지 않는다(패널도 안 뜸).
- 승자 화물에 담을 때 **`CARGO_CAPACITY`(50) 초과 허용**(병합과 동일 — 다음 적재만 막힌다). 장비 `loot_items`는 용량 제한 없음.
- 약탈은 패자 부대가 맵에서 제거(`_apply_survivors`의 `queue_free`)되기 **전에** 처리한다. 패자 화물·멤버 장비를 읽어야 하므로(전멸 시점 `loser.members`는 아직 전사자 전원을 담고 있다).
- **승자가 임시 수비대 부대**(`_make_garrison_party` — `_units`·`_npc_parties`에 없는 방어 부대)면 노획하지 않는다(화물·장비 모두). 전투 후 곧 제거돼 소실되므로(수비대 노획은 `미구현`). 지속 부대(플레이어·NPC)가 승자일 때만 노획한다.

## 승자가 플레이어 부대 (관전 전투 · `_run_battle`)

- 오버레이 종료 후 승자가 **플레이어 세력 부대**이면 **약탈 패널**(`loot_menu`)을 띄우고 `await`한다. 패널은 화물·장비 중 하나라도 있으면 뜬다.
- 패널은 제목 "약탈" 아래 **좌우 2열** —
  - **왼쪽 「노획」(패자)**: 가져올 수 있는 두 섹션.
    - **화물**: 자원별 행 `"<자원> ×<수량>"` + **[가져오기]**(그 자원 전량 → 승자 `cargo`).
    - **장비**: 아이템별 행 `"<이름>"`([`ItemTypes.item_name`](../data/items.md)) + **[가져오기]**(그 아이템 → 승자 `loot_items`).
  - **오른쪽 「내 인벤토리」(승자)**: **읽기 전용**. 승자의 현재 화물(`"<자원> ×<수량>"`)과 노획 장비(`loot_items`를 이름별로 묶어 `"<이름> ×<개수>"`). 비면 `"(없음)"`. 가져올 때마다 갱신돼 쌓이는 게 보인다.
  - 하단 **[모두 가져오기]**(남은 화물+장비 전부) · **[닫기]**.
- 왼쪽에서 **[가져오기]** 하면 그 행이 사라지고 오른쪽 내 인벤토리에 반영된다. 노획 대상 화물·장비가 모두 비거나 **[닫기]**면 패널을 닫는다.
- **닫을 때 안 가져간 화물·장비는 소실**된다(패자 부대가 곧 `_apply_survivors`로 제거되므로).

## 승자가 NPC (또는 NPC↔NPC · `_resolve_battle_headless`)

- 패널 없이 `winner.take_all_loot(loser)`(화물 전량) + `winner.take_all_equipment(loser)`(장비 전량)로 **자동 획득**한다. NPC가 플레이어를 이긴 경우(`_run_battle`)·NPC끼리(`_resolve_battle_headless`) 모두 동일.

## Party 노획 API (`party.gd`)

- `take_loot(source, res_name, n) -> int` — `source` 화물에서 자원을 `min(n, source 보유)`만큼 이 부대로 옮긴다. 승자 용량은 무시(**초과 허용**). 실제 옮긴 양을 반환. `source` 보유가 0이 되면 키를 삭제한다. 음수 `n`은 0.
- `take_all_loot(source) -> void` — `source`의 모든 화물을 전량 이 부대로 옮긴다(자동 약탈). `source` 화물은 빈 Dictionary가 된다.
- `equipment_ids() -> Array` — 이 부대 전 멤버의 장비 id 평탄 목록(각 멤버 `weapons` + `armor` + `shield`). 빈 방패(`""`) 제외, 중복 유지. 읽기 전용(멤버·장비 불변). 약탈 시 패자 장비 스냅샷.
- `take_all_equipment(source) -> void` — `source.equipment_ids()`를 이 부대 `loot_items`에 전부 더한다(자동 장비 약탈). `source` 불변.
- 플레이어 패널에서 장비 한 점 노획 = `winner.loot_items.append(id)`(패널이 남은 스냅샷에서 그 id를 제거).

## 테스트 시나리오

### Party 노획 API — `test/unit/test_party.gd`

- [정상] `take_loot`: source 목재 20에서 `take_loot(source, "목재", 5)` → 5 반환, self `["목재"]==5` / source `["목재"]==15`
- [경계] `take_loot`는 source 보유분까지만 — 목재 3에서 10 요청 → 3만 옮기고 반환 3, source `"목재"` 키 삭제
- [경계] `take_loot` 용량 초과 허용 — self 화물 48 실린 상태서 `take_loot`로 10 → 전량 실림, `cargo_total() == 58`(>50)
- [경계] `take_loot` 음수/0 → 0(양쪽 변화 없음); source에 없는 자원 요청 → 0
- [정상] `take_all_loot`: source 목재10·식량5 → self로 전량 이전, `source.cargo`는 빈 Dictionary
- [경계] `take_all_loot` 빈 source → self 변화 없음
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

- 승자 판정(한쪽만 전멸)·플레이어 승자 패널(좌 노획 2섹션 / 우 내 인벤토리 읽기 전용)·NPC 자동 전량은 `game.gd` 배선이라 실제 실행으로 확인한다.

## 미구현

- **노획 장비 활용** — 노획한 장비를 승자 멤버에게 장착하거나 판매·전용 목록 표시. 지금은 `loot_items`에 수집만 한다.
- **수비대 노획** — 임시 수비대 부대가 방어 승리 시 노획. 수비대 화물·장비가 캠프/영지로 귀속되는 경로가 없어 `미구현`.
- 상호 전멸 시 분배, 약탈 애니메이션.

## 관련

- 화물·노획 장비 모델은 [Party](../entities/Party.md#화물-cargo--캐러반). 아이템 이름은 [Items](../data/items.md). 전투 개시·결과 반영 흐름은 [Battle](battle.md).
