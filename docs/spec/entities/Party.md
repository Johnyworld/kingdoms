# Entity: Party (부대)

> 스크립트: `scenes/party/party.gd` (`extends Node2D`)
> 씬: `scenes/party/party.tscn`

맵 위에서 **실제로 움직이는 유닛**. 여러 [Human](Human.md)을 멤버로 거느린다.
**주인공은 이 부대의 멤버**(`human_name = "아젤 하르윈"`)이고, 우리가 선택·이동시키는 대상은 개별 Human이 아니라 이 **부대**다.
부대는 [유닛 카탈로그](../data/units.md)에서 생성되며, 플레이어 부대 외에 NPC 부대들도 맵에 존재한다([Parties](../features/parties.md)).
현재 외형은 임시 플레이스홀더(원형 마커, 반지름 12px)로 `_draw()`에서 직접 그려진다(예전에 Human이 하던 역할을 이관).

## Properties

### 정체 (Identity)

| 속성 | export 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 이름 | `party_name` | `""` | 부대의 이름. 엔진 내장 `name`(노드 이름)과 충돌하므로 별도 변수로 둔다 |
| 소속 세력 | `faction_name` | `""` | 부대가 속한 [세력](Faction.md) 이름. 정보 패널에 표시해 아군/적을 구분한다. 카탈로그 생성 시 설정 |
| 토큰 색 | `token_color` | `Color(0.92, 0.78, 0.35)` (금색) | 맵 토큰 몸통 색. 플레이어는 기본 금색, NPC 부대는 소속 세력 색으로 설정한다 |

### 멤버 (Members)

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 멤버 | `members` | `Array` | `[]` | 이 부대에 속한 [Human](Human.md) 목록 |
| 지휘관 | `commander` | `Object` (Human) | `null` | 부대를 이끄는 [Human](Human.md). 멤버 중 하나를 가리킨다. 아직 편성 UI가 없어 생성 시 코드로 지정한다 |

### 화물 (Cargo — 캐러반)

거점에서 자원을 싣고 다른 거점으로 옮긴다([캠프 메뉴 보급](../features/camp-menu.md#보급-화물-적재하역)). 부대와 함께 이동하고, 전멸(부대 제거)하면 남은 화물은 소실되지만, **전투로 전멸당하면 승자가 노획한다**([약탈](../features/raid.md)). **병합** 시 화물은 합쳐진다(`merge_from`, 소실 방지). **분할**([부대 편성](../features/party-composition.md)) 시 화물·[노획 장비](#노획-장비-loot-items)를 **분할 패널에서 원 부대 ↔ 새 부대로 나눠 실을 수 있다**(`transfer_cargo_to`/`transfer_loot_to`). 기본값은 원 부대에 남는다.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 화물 | `cargo` | `Dictionary` | `{}` | 운반 중인 자원(자원명→수량). `인구`는 운반하지 않는다(노동력) |
| 적재 상한 | `CARGO_CAPACITY` | `int`(const) | `50` | 모든 자원 수량 합의 상한 |

### 노획 장비 (Loot Items)

전투로 전멸시킨 패자 전사자의 장비를 [약탈](../features/raid.md)해 보관한다. 장착되지 않은 채 목록으로만 들고 있으며, **활용(장착·판매·전용 표시 UI)은 `미구현`**.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 노획 장비 | `loot_items` | `Array` | `[]` | 노획한 장비 아이템 id 목록(무기·방어구·방패, [ItemTypes](../data/items.md)). **중복 허용**(같은 id 여러 개), 용량 제한 없음 |

### 공성 유닛 (Siege Units)

멤버(사람)와 별개로 **공성 유닛**(투석기 등)을 실을 수 있다([Siege Engines](../features/siege-engines.md)). 인구를 차지하지 않는 재사용 장비 유닛이라 시야·공격거리·전투에 영향을 주지 않는다. 실으면 부대가 느려지고(견인 이동), 끌 인력(사람 4명)이 있어야 움직인다.

| 속성 | 변수/메서드 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 공성 유닛 | `siege_units` | `Array` | `[]` | 실은 [SiegeUnit](../features/siege-engines.md) 목록(투석기 등). `members`와 별개, **인구 비소모** |
| 공성 유닛 보유 | `has_siege()` | `bool` | — | `siege_units`가 비지 않았는지. 견인 이동 규칙 적용 여부 |

- `add_siege_unit(unit) -> void` — 공성 유닛을 `siege_units`에 추가한다([공성 작업장 생산](../features/siege-engines.md#획득--공성-작업장에서-생산)).

### 유도 능력치 (Derived)

멤버들의 능력치에서 계산한다.

| 속성 | 메서드 | 규칙 | 설명 |
| --- | --- | --- | --- |
| 이동력 | `movement()` | `max(0, 기본 − overload_penalty())`, **공성 유닛 실으면** 견인 규칙 적용 | 기본 = 멤버 `movement`의 **최소값**(가장 느린 멤버). **과적 페널티**를 뺀 값(아래). 멤버 없으면 `0`. **공성 유닛 보유 시**([Siege Engines](../features/siege-engines.md)): 사람 `< SiegeTypes.CREW_MIN`(4)이면 `0`(견인 불가), 아니면 `min(위 값, 견인 이동력 2)` |
| 과적 페널티 | `overload_penalty()` | `floor(초과량 ÷ (CARGO_CAPACITY ÷ 기본))` | 화물이 [용량](#화물-cargo--캐러반)(50)을 넘으면 감소. 초과량=`cargo_total()−50`. step=`50÷기본이동력`(예 50÷3≈16.7)마다 −1. **2배 용량(100)에서 이동력 0**. 화물 용량 이하·멤버 없으면 `0` |
| 시야 | `vision()` | 멤버 `vision`의 **최대값** | 가장 멀리 보는 멤버를 따라간다. 멤버 없으면 `0` |
| 공격거리 | `attack_range()` | 멤버별 무기 공격거리([ItemTypes](../data/items.md) `max_range(멤버.weapons)`)의 **최대값** | 가장 사거리 긴 멤버·무기 기준. 검+활 소지자는 활(3)로 계산. 월드맵 공격 개시 거리. 멤버 없으면 `0` |

### 상태 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 위치 | `position` | Node2D 위치. 맵 토큰으로서 부대가 선 칸 |
| 선택됨 | `selected` | 선택 상태. `set_selected(value)`로 변경 시 강조 링을 다시 그린다 |
| 이번 턴 이동함 | `moved_this_turn` | 이번 [턴](../features/turn.md)에 이미 이동했는지 |
| 이번 턴 공격함 | `attacked_this_turn` | 이번 턴에 이미 공격했는지. 공격은 그 부대의 행동을 끝낸다([전투](../features/battle.md)) |
| 이번 턴 휴식함 | `rested_this_turn` | 이번 턴 `[휴식]`/`[대기]`을 선택했는지([행동 메뉴](../features/party-action-menu.md)). 회복 연동은 `미구현` |
| 주둔 중 | `stationed` | `bool`, 기본 `false`. 부대가 거점에서 **주둔(대기)** 중인지([Garrison](../features/garrison.md)). 참이면 명령([주둔 종료]) 전까지 대기하며, `can_move()`·`can_attack()`이 거짓이 된다(이동·근접 개시 불가). 단 **원거리 무기가 있으면 주둔을 유지한 채 제자리 사격**은 가능(턴당 1회). `reset_turn()`에도 **유지**(턴을 넘겨 지속) |
| 소속 영지 | `home_territory` | **거점 주둔 부대**([Garrison](../features/garrison.md))가 설정하는 방어 영지 참조(그 외 부대는 `null`). 현재 소비처 없음(수비대 노획 폐지) — 향후 공성 확장 대비 메타데이터 |

한 턴에 **이동 1회 + 공격 1회**가 가능하다. 이동해도 공격은 아직 할 수 있지만, 공격하면 이동·공격 모두 끝난다. 어느 하나라도 했으면 토큰을 흐리게 표시한다. **주둔 중**이면 이동·공격을 모두 막는다(대기).

## 동작

- `add_member(human) -> void` — 멤버를 `members`에 추가한다. 이미 포함된 멤버는 중복 추가하지 않는다. **지휘관이 없으면**(빈 부대의 첫 멤버) 그 멤버를 지휘관으로 삼는다. 다시 그린다.
- `remove_member(human) -> void` — 멤버를 `members`에서 뺀다. 그 멤버가 지휘관이면 남은 첫 멤버로 재지정하고(없으면 `null`), 다시 그린다. 없는 멤버면 no-op. [부대 분할](../features/party-composition.md)·전투 사상자 반영에 쓴다. 멤버가 0이 되면 토큰을 그리지 않는다(`_draw`가 빈 부대는 생략).
- `commander_name() -> String` — 지휘관의 `human_name`. 지휘관이 없으면(`null`) `"—"`. 부대 일람([Party Roster](../features/party-roster.md)) 표시에 사용.
- `cargo_total() -> int` — 화물 총량(모든 자원 수량 합).
- `cargo_space() -> int` — 화물 여유 공간(`CARGO_CAPACITY - cargo_total()`).
- `add_cargo(res_name, n) -> int` — 화물에 자원을 싣는다. 여유 공간까지만(`min(n, space)`), 음수 n은 0. **실제 실은 양**을 반환.
- `remove_cargo(res_name, n) -> int` — 화물에서 자원을 내린다. 보유분까지만(`min(n, 보유)`), 0이 되면 키 삭제. **실제 내린 양**을 반환.
- `take_loot(source, res_name, n) -> int` — 다른 부대(`source`)의 화물에서 자원을 약탈해 이 부대로 옮긴다([약탈](../features/raid.md)). `min(n, source 보유)`까지, 승자 용량은 무시(**초과 허용**). 음수 n은 0. **실제 옮긴 양**을 반환하고, `source` 보유가 0이 되면 키를 삭제한다.
- `take_all_loot(source) -> void` — `source`의 모든 화물을 전량 이 부대로 옮긴다(NPC/자동 약탈). `source` 화물은 빈 Dictionary가 된다.
- `equipment_ids() -> Array` — 이 부대 **전 멤버가 장착한 장비 id** 평탄 목록(각 멤버 `weapons` + `armor` + `shield`). 빈 방패(`""`)는 제외, **중복 유지**. [약탈](../features/raid.md) 시 패자 전사자 장비 스냅샷으로 쓴다. 멤버·장비 자체는 바꾸지 않는다(읽기 전용).
- `take_all_equipment(source) -> void` — `source.equipment_ids()`를 이 부대 `loot_items`에 전부 더한다(NPC/자동 장비 약탈). `source`는 바뀌지 않는다.
- `transfer_cargo_to(other, res_name, n) -> int` — 이 부대 화물의 자원을 `other` 부대로 옮긴다([부대 분할 분배](../features/party-composition.md)). `min(n, 이 부대 보유)`만큼 — **받는 부대 `CARGO_CAPACITY` 초과 허용**(병합·약탈과 동일). 음수 n은 0. 옮긴 만큼 이 부대에서 빼고 `other`에 싣는다. **실제 옮긴 양** 반환. *(적재량이 용량을 넘으면 [이동력이 감소](#유도-능력치-derived)한다 — `overload_penalty`.)*
- `transfer_loot_to(other, id) -> bool` — 이 부대 `loot_items`의 장비 `id` 하나를 `other.loot_items`로 옮긴다. 이 부대가 그 id를 안 가졌으면 `false`(no-op). 성공 시 이 부대에서 그 id 하나 빼고 `other`에 더해 `true`.
- `can_equip_from_loot(member, id) -> bool` — `member`가 `id`를 장착할 수 있는지 판정(dry-run, 변경 없음). id가 `loot_items`에 있고 슬롯 종류가 명확하며 그 슬롯에 여유가 있으면 `true`. **장착 성공 조건의 단일 출처** — `equip_from_loot`와 [장비 관리 UI](../features/equipment.md)의 `[장착]` 버튼 활성이 모두 이 함수를 쓴다.
- `equip_from_loot(member, id) -> bool` — 인벤토리(`loot_items`)의 장비 `id`를 `member`에게 장착한다([장비 관리](../features/equipment.md)). `can_equip_from_loot`이 `false`면 no-op으로 `false`. 슬롯은 [`ItemTypes.item_slot`](../data/items.md)로 판별: 무기는 `weapons`(상한 [`MAX_WEAPONS`](Human.md)), 방어구는 `armor`(상한 [`MAX_ARMOR`](Human.md)), 방패는 `shield`(비어 있을 때만). **id가 인벤토리에 없거나 / 슬롯 종류 불명 / 슬롯이 꽉 차면 `false`**(no-op). 성공 시 멤버 슬롯에 넣고 `loot_items`에서 그 id 하나를 빼고 `true`.
- `unequip_to_loot(member, id) -> bool` — `member`가 장착한 장비 `id`를 빼서 인벤토리(`loot_items`)로 되돌린다. 무기·방어구는 목록에서 그 id 하나 제거(주무기[0]를 빼면 다음 무기가 주무기), 방패는 일치할 때 `""`로. **멤버가 그 장비를 안 갖고 있으면 `false`**(no-op). 성공 시 `loot_items`에 더하고 `true`.
- `base_movement() -> int` — 멤버 `movement`의 최소값(가장 느린 멤버, 멤버 없으면 0). 과적 반영 전 기본 이동력. `movement()`·`overload_penalty()`가 공유한다.
- `movement() -> int` — **`base_movement()` − `overload_penalty()`**, `max(0, …)`으로 하한 0(멤버 없으면 0). **공성 유닛을 실었으면**([Siege Engines](../features/siege-engines.md)) 견인 규칙을 마저 적용: 사람(`members`) 수가 `SiegeTypes.CREW_MIN`(4) 미만이면 `0`(견인 인력 부족), 아니면 공성 유닛 견인 이동력(가장 느린 것, 투석기 2)으로 `min` 상한. 이동 범위 계산에 사용 — 과적이면 감소된 값이 그대로 [이동 범위](../features/selection-and-movement.md)·NPC 경로에 반영.
- `has_siege() -> bool` — `siege_units`가 비지 않았는지. 견인 이동 규칙(`movement`)·[정보 패널](../features/party-info.md) 표시에 쓴다.
- `add_siege_unit(unit) -> void` — 공성 유닛([SiegeUnit](../features/siege-engines.md))을 `siege_units`에 추가한다([공성 작업장 생산](../features/siege-engines.md)). 인구·멤버에는 영향 없다.
- `siege_fire_range() -> int` — 실은 공성 유닛의 **최대 투석 사거리**(없으면 0). [투석](../features/siege-engines.md#투석-공성-성벽) 대상·사거리 판정에 쓴다.
- `siege_attack() -> int` — 실은 공성 유닛의 **최대 공격력**(없으면 0). 투석 데미지 기준값([`Siege.rolled_damage`](../features/wall.md#성벽-내구도-buildingwall_hp--siege)).
- `overload_penalty() -> int` — 화물 과적으로 인한 이동력 감소량. 화물 `cargo_total()`이 `CARGO_CAPACITY`(50) 이하이거나 기본 이동력이 0이면 `0`. 초과 시 개념상 `floor(초과량 ÷ (50 ÷ 기본))` — step `50÷기본`(예 16.7)마다 −1. **구현은 정수식 `(초과량 × 기본) ÷ CARGO_CAPACITY`**(정수 나눗셈, 부동소수점 오차 없음, 동일 결과). 화물이 용량의 2배면 페널티 = 기본 이동력(→ movement 0, 정지).
- `vision() -> int` — 멤버 `vision`의 최대값(멤버 없으면 0). 전장의 안개 계산에 사용.
- `attack_range() -> int` — 멤버별 `ItemTypes.max_range(멤버.weapons)`의 최대값(멤버 없으면 0). 월드맵 공격 개시 범위([Selection & Movement](../features/selection-and-movement.md)).
- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `can_move() -> bool` — 이번 턴에 이동 가능한지(`not moved_this_turn and not attacked_this_turn and not stationed` — 공격했거나 주둔 중이면 이동 불가).
- `can_attack() -> bool` — 이번 턴에 공격 가능한지(`not attacked_this_turn and not stationed` — 이동만 했으면 아직 가능, 주둔 중이면 불가).
- `mark_moved() -> void` — 이동 완료 표시(`moved_this_turn = true`). 흐리게 다시 그린다.
- `mark_attacked() -> void` — 공격 완료 표시(`attacked_this_turn = true`). 흐리게 다시 그린다.
- `mark_rested() -> void` — 휴식/대기 표시. `rested_this_turn = true` + `attacked_this_turn = true`(행동 종료). `moved_this_turn`은 유지. 흐리게 다시 그린다.
- `undo_move() -> void` — 이동 되돌리기. `moved_this_turn = false`(다시 이동 가능)로 되돌리고 불투명하게 다시 그린다. 위치 복원·시야 갱신은 `game.gd`([행동 메뉴](../features/party-action-menu.md) `[취소]`).
- `can_rest() -> bool` — 휴식 가능 여부(`not attacked_this_turn` — 아직 행동을 끝내지 않았으면 가능).
- `reset_turn() -> void` — 턴 종료 시 호출. `moved_this_turn`·`attacked_this_turn`·`rested_this_turn`를 모두 `false`로 되돌리고 불투명하게 다시 그린다. **`stationed`는 유지**(주둔은 턴을 넘겨 지속). 단 주둔 부대는 `can_move()`/`can_attack()`이 거짓이라 리셋 후에도 대기 상태를 이어간다.
- `_draw()` — 선택 시 발밑 강조 링(노란색) + 그림자 + 몸통 원(`token_color`) + 외곽선을 그린다. `moved_this_turn` 또는 `attacked_this_turn`이면 전체를 반투명하게 그린다.

## 테스트 시나리오

`test/unit/test_party.gd`.

- [정상] `party_name` 기본값은 빈 문자열, 설정 가능
- [정상] `faction_name` 기본값은 빈 문자열, 설정 가능
- [정상] `token_color` 기본값은 금색 `Color(0.92, 0.78, 0.35)`, 설정 가능
- [정상] 생성 직후 `members`는 빈 배열, `movement() == 0`, `vision() == 0`
- [정상] `add_member`로 멤버 추가 후 `members`에 들어감
- [경계] 같은 멤버를 두 번 `add_member` 해도 크기는 1 (중복 방지)
- [정상] 생성 직후 `commander`는 `null`, `commander_name() == "—"`
- [정상] `commander`를 멤버로 지정하면 `commander_name()`이 그 멤버의 `human_name`
- [정상] 이동력 3·2 멤버 → `movement() == 2` (최소값, 가장 느린 멤버)
- [정상] 화물이 용량(50) 이하면 `overload_penalty() == 0`, `movement()`는 기본과 같음
- [정상] 과적: 기본 이동력 3·화물 67(초과 17, step 16.7) → `overload_penalty() == 1`, `movement() == 2`
- [경계] 과적: 기본 3·화물 100(용량 2배, 초과 50) → `overload_penalty() == 3`, `movement() == 0`(정지)
- [정상] 빠른 부대는 초과에 더 오래 버틴다 — 기본 5·화물 60(초과 10, step 10) → 페널티 1, `movement() == 4`
- [경계] 멤버 없으면 `overload_penalty() == 0`, `movement() == 0`
- [정상] 시야 5·2 멤버 → `vision() == 5` (최대값)
- [정상] 무기 공격거리 1·3 멤버 → `attack_range() == 3` (최대값), 멤버 없으면 0
- [정상] 생성 직후 `moved_this_turn`·`attacked_this_turn` 거짓, `can_move()`·`can_attack()` 참
- [정상] `mark_moved()` 후 `moved_this_turn` 참, `can_move()` 거짓, `can_attack()`는 **여전히 참**(이동 후 공격 가능)
- [정상] `mark_attacked()` 후 `can_attack()` 거짓, `can_move()`도 거짓(공격이 이동도 끝냄)
- [정상] `mark_rested()` 후 `rested_this_turn` 참, `attacked_this_turn` 참(행동 종료), `can_rest()` 거짓
- [정상] `mark_moved()` 후 `undo_move()` → `moved_this_turn` 거짓, `can_move()` 다시 참
- [정상] `can_rest()`는 행동 전 참, `mark_attacked()`/`mark_rested()` 후 거짓
- [정상] 생성 직후 `cargo` 빈 Dictionary, `cargo_total() == 0`, `cargo_space() == 50`
- [정상] `add_cargo("목재", 10)` → 10 반환, `cargo["목재"] == 10`, `cargo_total() == 10`
- [경계] `add_cargo`는 여유 공간까지만 — 화물 45 실린 상태서 `add_cargo("밀", 10)` → 5만 실림(반환 5, 상한 50)
- [경계] `add_cargo` 음수 n → 0(변화 없음)
- [정상] `remove_cargo("목재", 4)` → 4 반환, 남은 6; 보유보다 크게 요청하면 보유분만 내리고 0이 되면 키 삭제
- [정상] `take_loot`: source 목재 20에서 `take_loot(source, "목재", 5)` → 5 반환, self `["목재"]==5` / source `["목재"]==15`
- [경계] `take_loot`는 source 보유분까지만 — 목재 3에서 10 요청 → 3만 옮기고 반환 3, source `"목재"` 키 삭제
- [경계] `take_loot` 용량 초과 허용 — self 화물 48 실린 상태서 `take_loot`로 10 → 전량 실림, `cargo_total() == 58`(>50)
- [경계] `take_loot` 음수/0 → 0(양쪽 변화 없음); source에 없는 자원 요청 → 0
- [정상] `take_all_loot`: source 목재10·식량5 → self로 전량 이전, `source.cargo`는 빈 Dictionary
- [경계] `take_all_loot` 빈 source → self 변화 없음
- [정상] `equipment_ids`: 멤버(무기 `["sword","bow"]`·방어구 `["leather_armor"]`·방패 `"buckler"`) → `["sword","bow","leather_armor","buckler"]`(평탄, 순서 유지)
- [경계] `equipment_ids`는 빈 방패(`shield==""`)를 제외하고, 같은 id 중복은 유지(두 멤버가 `sword`면 두 개); 멤버 없으면 `[]`
- [정상] `take_all_equipment`: source 멤버 장비 전부가 self `loot_items`에 더해짐(중복 유지), `source`는 불변
- [경계] `take_all_equipment` 장비 없는 source → `loot_items` 변화 없음
- [정상] `can_equip_from_loot`: `loot_items`에 `"sword"`·빈 무기 슬롯 → `true`; 무기 3개면 `false`; `loot_items`에 없는 id → `false`(변경 없음)
- [정상] `equip_from_loot`: `loot_items`에 `"sword"`, 멤버 무기 비었을 때 장착 → `true`, 멤버 `weapons==["sword"]`, `loot_items`에서 제거
- [정상] `equip_from_loot` 방어구/방패: `"chain_mail"`→멤버 `armor`, `"buckler"`→멤버 `shield`(빈 슬롯)
- [경계] `equip_from_loot` 슬롯 꽉 참 — 무기 3개(`MAX_WEAPONS`)면 4번째 장착 `false`(no-op); 방패 이미 있으면 `false`; 방어구 4개면 `false`
- [경계] `equip_from_loot` id가 `loot_items`에 없거나 슬롯 불명(카탈로그 없는 id) → `false`, 변화 없음
- [정상] `unequip_to_loot`: 멤버 무기 `["sword","bow"]`에서 `"sword"` 탈착 → `true`, 멤버 `["bow"]`, `loot_items`에 `"sword"`
- [정상] `unequip_to_loot` 방패: 멤버 방패 `"buckler"` 탈착 → `member.shield==""`, `loot_items`에 `"buckler"`
- [경계] `unequip_to_loot` 멤버가 안 가진 장비 → `false`, 변화 없음
- [정상] `transfer_cargo_to`: A 목재 20 → `transfer_cargo_to(B, "목재", 5)` = 5, A `["목재"]==15` / B `["목재"]==5`
- [경계] `transfer_cargo_to`는 보유분까지만 — A 목재 3에서 10 요청 → 3만 이동
- [경계] `transfer_cargo_to` 용량 초과 허용 — B가 이미 48이어도 5 더 받아 `cargo_total()==53`(>50)
- [경계] `transfer_cargo_to` 음수/0/미보유 → 0, 변화 없음
- [정상] `transfer_loot_to`: A `loot_items`에 `"sword"` → `transfer_loot_to(B, "sword")` = `true`, A에서 빠지고 B에 `"sword"`
- [경계] `transfer_loot_to` A가 안 가진 id → `false`, 양쪽 변화 없음(중복이면 첫 개만 이동)
- [정상] 생성 직후 `stationed == false`; 설정 가능
- [정상] `stationed = true`면 `can_move()`·`can_attack()` 거짓(주둔은 대기 — 이동·공격 불가)
- [정상] `stationed = true`로 두고 `reset_turn()` → `stationed` 여전히 참(주둔은 턴을 넘겨 유지), `can_move()` 거짓
- [정상] `reset_turn()` 후 다시 `can_move()`·`can_attack()`·`can_rest()` 참, `rested_this_turn` 거짓(주둔 아님 기준)
- [정상] `TurnManager.end_turn`에 넘긴 부대의 `moved_this_turn`이 참이면 호출 후 거짓으로 리셋
- [정상] 생성 직후 `siege_units` 빈 배열, `has_siege() == false`
- [정상] `add_siege_unit(SiegeUnit.new())` 후 `siege_units` 크기 1, `has_siege() == true`
- [정상] 사람 4명(이동력 4) + 투석기 1대 → `movement() == 2`(견인 속도 상한)
- [경계] 사람 3명 + 투석기 → `movement() == 0`(견인 인력 부족)
- [경계] 사람 4명 + 투석기 + 과적으로 사람 기준 이동력 1 → `movement() == 1`(min)
- [정상] 투석기 추가는 `vision()`·`attack_range()`·`members`에 영향 없음(인구 비소모)

## 관련

- 부대 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용. 부대는 서로의 칸을 통과·점유할 수 없다([유닛 점유](../features/selection-and-movement.md)).
- 턴당 1회 이동 제한(`moved_this_turn`/`can_move`/`mark_moved`/`reset_turn`)은 [Turn](../features/turn.md)에서 사용.
- 멤버 개별 능력치는 [Human](Human.md), 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
