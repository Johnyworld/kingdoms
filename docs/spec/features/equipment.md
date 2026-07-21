# Feature: Equipment (장비 관리 — 노획 장비 장착·탈착)

> 스크립트: `scenes/party/party.gd`(`equip_from_loot`/`unequip_to_loot`) · `scenes/item/item_types.gd`(`item_slot`) · `scenes/equip/equip_menu.gd`(장비 관리 모달) · `scenes/party/party_action_menu.gd`([장비] 액션) · `scenes/game/game.gd`(배선)

부대가 [약탈](raid.md)로 모은 **노획 장비**([`loot_items`](../entities/Party.md#노획-장비-loot-items))를 플레이어가 **멤버에게 직접 장착**하거나 **탈착**해 되돌린다. 자동 장착이 아니라 유저가 골라 갈아끼운다.

## 슬롯과 장착 규칙

멤버([Human](../entities/Human.md)) 장비 슬롯:

| 슬롯 | 변수 | 상한 |
| --- | --- | --- |
| 무기 | `weapons`(Array, 첫 원소=주무기) | `MAX_WEAPONS` = 3 |
| 방어구 | `armor`(Array) | `MAX_ARMOR` = 4 |
| 방패 | `shield`(String) | 1 |

- **장착**(`Party.equip_from_loot(member, id)`): 인벤토리의 장비를 [`ItemTypes.item_slot`](../data/items.md)로 판별해 알맞은 슬롯에 넣는다. **슬롯 여유가 있을 때만** — 꽉 차 있으면 실패(스왑 없음). 성공하면 `loot_items`에서 그 id 하나가 빠진다.
- **탈착**(`Party.unequip_to_loot(member, id)`): 멤버가 낀 장비를 빼 `loot_items`로 되돌린다. 주무기(`weapons[0]`)를 빼면 다음 무기가 주무기가 된다.
- **스왑 없음**: 슬롯을 비우려면 먼저 [탈착]해야 한다(장착이 기존 장비를 밀어내지 않는다). 규칙을 단순·일관되게 유지한다.

## 장비 관리 모달 (`equip_menu`)

[부대 행동 메뉴](party-action-menu.md)의 **[장비]** 로 연다(플레이어 부대 선택 시). 오버레이 chrome은 공용 [Modal](modal.md)에 위임하고 콘텐츠(2열)만 주입한다. `EquipMenu`는 상시 UI가 없는 순수 컨트롤러(`extends Node`, `class_name EquipMenu`)로, 내부에 `Modal` 하나를 두어 `set_content`로 콘텐츠를 넣는다.

- 제목 "장비 — <부대명>"(Modal 제목, `open` 시 갱신).
- **왼쪽 「멤버」**: 부대 멤버 목록(버튼). 클릭해 **한 명 선택**. 선택 멤버 아래에 장착 장비를 슬롯별로 — `무기 <n>/3` · `방어구 <n>/4` · `방패` — 각 장비 행에 **[탈착]**.
- **오른쪽 「인벤토리」**: 부대 `loot_items`를 이름별로 묶어(`"<이름> ×<개수>"`) 나열, 각 행에 **[장착]**(선택 멤버에게). **선택 멤버의 그 슬롯이 꽉 찼으면 [장착] 비활성**. 멤버 미선택이면 전부 비활성.
- 장착/탈착할 때마다 양쪽 목록을 갱신한다(선택 멤버 유지).
- **닫기**: Modal의 **우측 상단 X · 배경 좌클릭 · ESC**로 닫는다(별도 [닫기] 버튼 없음). 닫히면(`closed`) `_party`/선택 멤버를 비운다. 열려 있는 동안 [Modal](modal.md)의 `ModalStack.blocking()`으로 지도 입력도 차단된다.
- 장비는 부대 정보 표시·월드맵 사거리에 쓰인다. **전투 판정은 lang 클래스**([Lang Battle](lang-battle.md))라 장비 능력치는 전투 결과에 직접 반영되지 않는다(구 전투 수학 폐기).

## 데이터 API

- `ItemTypes.item_slot(id) -> String` — `"weapon"|"armor"|"shield"|""`([Items](../data/items.md)).
- `Party.can_equip_from_loot(member, id) -> bool` — 장착 가능 판정(dry-run). `[장착]` 버튼 활성·`equip_from_loot`의 단일 출처.
- `Party.equip_from_loot(member, id) -> bool` — 장착. 실패 시 `false`(no-op).
- `Party.unequip_to_loot(member, id) -> bool` — 탈착. 실패 시 `false`(no-op).
- (상세는 [Party](../entities/Party.md#동작)·[Items](../data/items.md) 참조.)

## 테스트 시나리오

### 데이터 API — `test/unit/test_party.gd` · `test/unit/test_item_types.gd`

- `item_slot`·`equip_from_loot`·`unequip_to_loot` 정상·경계 케이스는 [Party](../entities/Party.md#테스트-시나리오)·[Items](../data/items.md#테스트-시나리오) 시나리오 참조(슬롯 판별, 상한 초과 실패, 없는 장비 실패, 탈착 반환).

### 모달 — `test/unit/test_equip_menu.gd`

- [정상] `open(party)` → Modal 열림(`is_open()` true), 제목에 부대명 포함, 멤버 목록에 멤버 버튼 = 멤버 수
- [정상] 첫 멤버 자동 선택 → 그 멤버의 장착 슬롯 라벨(`무기 0/3` 등) 표시
- [정상] 다른 멤버 버튼 클릭 → 선택 이동(장착 목록이 그 멤버 기준으로 갱신)
- [정상] 인벤토리 장비 [장착] → 멤버 슬롯에 반영·`loot_items`에서 제거, 양쪽 목록 갱신
- [정상] 장착 장비 [탈착] → `loot_items`로 복귀, 목록 갱신
- [경계] 빈 `loot_items` → 인벤토리에 "(없음)" 표시
- [경계] 선택 멤버 슬롯이 꽉 참 → 그 장비 [장착] 버튼 비활성
- [경계] 멤버 없는 부대(선택 없음) → `_can_equip` false(장착 전부 비활성)
- [정상] `close()`(또는 Modal `closed`) → `is_open()` false, `_party` 비움

> 행동 메뉴 [장비] 열기 배선(`game.gd`)만 실제 실행으로 확인한다.

## 미구현

- **판매** — 노획 장비를 자원으로 환산해 팔기(자원 가치 카탈로그 없음).
- **주무기 재정렬** — 장착 순서만 반영(장착하면 목록 끝에 추가). 주무기 슬롯 직접 지정 UI 없음.
- **자동 장착**, 캠프 저장고 귀속, 장비 무게에 따른 스태미나 소모.

## 관련

- 노획 경로는 [Raid](raid.md), 장비 데이터는 [Items](../data/items.md), 멤버 슬롯은 [Human](../entities/Human.md). 전투 판정은 [Lang Battle](lang-battle.md)(lang 클래스).
