# Feature: Raid (약탈 — 전멸한 적 부대 화물 노획)

> 스크립트: `scenes/party/party.gd`(`take_loot`/`take_all_loot`) · `scenes/loot/loot_menu.gd`(약탈 패널) · `scenes/game/game.gd`(전투 결과 연동)

전투에서 **적 부대가 전멸**(전원 사망 → 부대 제거)하면, 생존한 **승자 부대**가 패자의 [화물](../entities/Party.md#화물-cargo--캐러반)을 노획한다.
플레이어가 이기면 무엇을 가져올지 직접 고르고, NPC가 이기면 전량 자동 획득한다.

이 문서는 **화물(자원) 약탈**만 다룬다. 전사자 장비(무기·방어구) 약탈은 노획 인벤토리 개념이 없어 `미구현`(별도 기능).

## 발동 조건

- 전투 종료 시 **정확히 한 부대만 전멸**했을 때(승자=생존, 패자=전멸). 양쪽 생존(후퇴)·양쪽 전멸(상호 전멸)이면 약탈 없음.
- 패자 화물이 비어 있으면(`cargo_total() == 0`) 아무 일도 일어나지 않는다(패널도 안 뜸).
- 승자 화물에 담을 때 **`CARGO_CAPACITY`(50) 초과 허용**(병합과 동일 — 다음 적재만 막힌다).
- 약탈은 패자 부대가 맵에서 제거(`_apply_survivors`의 `queue_free`)되기 **전에** 처리한다. 패자 화물을 읽어야 하므로.
- **승자가 임시 수비대 부대**(`_make_garrison_party` — `_units`·`_npc_parties`에 없는 방어 부대)면 노획하지 않는다. 전투 후 곧 제거돼 화물이 소실되므로(수비대 노획은 `미구현`). 지속 부대(플레이어·NPC)가 승자일 때만 노획한다.

## 승자가 플레이어 부대 (관전 전투 · `_run_battle`)

- 오버레이 종료 후 승자가 **플레이어 세력 부대**이면 **약탈 패널**(`loot_menu`)을 띄우고 `await`한다.
- 패널: 제목 "약탈" + 패자 화물을 자원별 행 `"<자원> ×<수량>"` + 각 행 **[가져오기]**(그 자원 전량 → 승자 화물) · 하단 **[모두 가져오기]** · **[닫기]**.
- **[가져오기]** = `winner.take_loot(loser, 자원, 전량)`으로 옮기고 그 행을 지운다. **[모두 가져오기]** = 남은 전부. 전량 이동 완료 또는 **[닫기]**면 패널을 닫는다.
- **닫을 때 안 가져간 화물은 소실**된다(패자 부대가 곧 `_apply_survivors`로 제거되므로).

## 승자가 NPC (또는 NPC↔NPC · `_resolve_battle_headless`)

- 패널 없이 `winner.take_all_loot(loser)`로 **전량 자동 획득**한다. NPC가 플레이어를 이긴 경우(`_run_battle`)·NPC끼리(`_resolve_battle_headless`) 모두 동일.

## Party 노획 API (`party.gd`)

- `take_loot(source, res_name, n) -> int` — `source` 화물에서 자원을 `min(n, source 보유)`만큼 이 부대로 옮긴다. 승자 용량은 무시(**초과 허용**). 실제 옮긴 양을 반환. `source` 보유가 0이 되면 키를 삭제한다. 음수 `n`은 0.
- `take_all_loot(source) -> void` — `source`의 모든 화물을 전량 이 부대로 옮긴다(자동 약탈). `source` 화물은 빈 Dictionary가 된다.

## 테스트 시나리오

### Party 노획 API — `test/unit/test_party.gd`

- [정상] `take_loot`: source 목재 20에서 `take_loot(source, "목재", 5)` → 5 반환, self `["목재"]==5` / source `["목재"]==15`
- [경계] `take_loot`는 source 보유분까지만 — 목재 3에서 10 요청 → 3만 옮기고 반환 3, source `"목재"` 키 삭제
- [경계] `take_loot` 용량 초과 허용 — self 화물 48 실린 상태서 `take_loot`로 10 → 전량 실림, `cargo_total() == 58`(>50)
- [경계] `take_loot` 음수/0 → 0(양쪽 변화 없음); source에 없는 자원 요청 → 0
- [정상] `take_all_loot`: source 목재10·식량5 → self로 전량 이전, `source.cargo`는 빈 Dictionary
- [경계] `take_all_loot` 빈 source → self 변화 없음

### 약탈 연동 (실행 확인)

- 승자 판정(한쪽만 전멸)·플레이어 승자 패널·NPC 자동 전량은 `game.gd` 배선이라 실제 실행으로 확인한다.

## 미구현

- **장비 약탈** — 전사자의 무기·방어구 노획. 노획 아이템 인벤토리 개념이 없어 `미구현`(별도 기능).
- **수비대 노획** — 임시 수비대 부대가 방어 승리 시 노획. 수비대 화물이 캠프/영지로 귀속되는 경로가 없어 `미구현`.
- 상호 전멸 시 화물 분배, 약탈 애니메이션.

## 관련

- 화물 모델·용량·병합은 [Party](../entities/Party.md#화물-cargo--캐러반). 전투 개시·결과 반영 흐름은 [Battle](battle.md).
