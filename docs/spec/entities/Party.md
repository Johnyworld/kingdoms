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

거점에서 자원을 싣고 다른 거점으로 옮긴다([캠프 메뉴 보급](../features/camp-menu.md#보급-화물-적재하역)). 부대와 함께 이동하고, 전멸(부대 제거)하면 남은 화물은 소실되지만, **전투로 전멸당하면 승자가 노획한다**([약탈](../features/raid.md)). **병합** 시 화물은 합쳐진다(`merge_from`, 소실 방지). **분할**([부대 편성](../features/party-composition.md)) 시 화물은 **원래 부대에 남고 새 부대는 빈 화물로 시작**한다(화물 분배 UI는 **미구현**).

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 화물 | `cargo` | `Dictionary` | `{}` | 운반 중인 자원(자원명→수량). `인구`는 운반하지 않는다(노동력) |
| 적재 상한 | `CARGO_CAPACITY` | `int`(const) | `50` | 모든 자원 수량 합의 상한 |

### 노획 장비 (Loot Items)

전투로 전멸시킨 패자 전사자의 장비를 [약탈](../features/raid.md)해 보관한다. 장착되지 않은 채 목록으로만 들고 있으며, **활용(장착·판매·전용 표시 UI)은 `미구현`**.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 노획 장비 | `loot_items` | `Array` | `[]` | 노획한 장비 아이템 id 목록(무기·방어구·방패, [ItemTypes](../data/items.md)). **중복 허용**(같은 id 여러 개), 용량 제한 없음 |

### 유도 능력치 (Derived)

멤버들의 능력치에서 계산한다.

| 속성 | 메서드 | 규칙 | 설명 |
| --- | --- | --- | --- |
| 이동력 | `movement()` | 멤버 `movement`의 **최소값** | 가장 느린 멤버를 따라간다. 멤버 없으면 `0` |
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

한 턴에 **이동 1회 + 공격 1회**가 가능하다. 이동해도 공격은 아직 할 수 있지만, 공격하면 이동·공격 모두 끝난다. 어느 하나라도 했으면 토큰을 흐리게 표시한다.

## 동작

- `add_member(human) -> void` — 멤버를 `members`에 추가한다. 이미 포함된 멤버는 중복 추가하지 않는다. **지휘관이 없으면**(빈 부대의 첫 멤버) 그 멤버를 지휘관으로 삼는다. 다시 그린다.
- `remove_member(human) -> void` — 멤버를 `members`에서 뺀다. 그 멤버가 지휘관이면 남은 첫 멤버로 재지정하고(없으면 `null`), 다시 그린다. 없는 멤버면 no-op. [수비대 편성](../features/garrison.md)에서 부대→캠프 이동에 쓴다. 멤버가 0이 되면 토큰을 그리지 않는다(`_draw`가 빈 부대는 생략).
- `commander_name() -> String` — 지휘관의 `human_name`. 지휘관이 없으면(`null`) `"—"`. 부대 일람([Party Roster](../features/party-roster.md)) 표시에 사용.
- `cargo_total() -> int` — 화물 총량(모든 자원 수량 합).
- `cargo_space() -> int` — 화물 여유 공간(`CARGO_CAPACITY - cargo_total()`).
- `add_cargo(res_name, n) -> int` — 화물에 자원을 싣는다. 여유 공간까지만(`min(n, space)`), 음수 n은 0. **실제 실은 양**을 반환.
- `remove_cargo(res_name, n) -> int` — 화물에서 자원을 내린다. 보유분까지만(`min(n, 보유)`), 0이 되면 키 삭제. **실제 내린 양**을 반환.
- `take_loot(source, res_name, n) -> int` — 다른 부대(`source`)의 화물에서 자원을 약탈해 이 부대로 옮긴다([약탈](../features/raid.md)). `min(n, source 보유)`까지, 승자 용량은 무시(**초과 허용**). 음수 n은 0. **실제 옮긴 양**을 반환하고, `source` 보유가 0이 되면 키를 삭제한다.
- `take_all_loot(source) -> void` — `source`의 모든 화물을 전량 이 부대로 옮긴다(NPC/자동 약탈). `source` 화물은 빈 Dictionary가 된다.
- `equipment_ids() -> Array` — 이 부대 **전 멤버가 장착한 장비 id** 평탄 목록(각 멤버 `weapons` + `armor` + `shield`). 빈 방패(`""`)는 제외, **중복 유지**. [약탈](../features/raid.md) 시 패자 전사자 장비 스냅샷으로 쓴다. 멤버·장비 자체는 바꾸지 않는다(읽기 전용).
- `take_all_equipment(source) -> void` — `source.equipment_ids()`를 이 부대 `loot_items`에 전부 더한다(NPC/자동 장비 약탈). `source`는 바뀌지 않는다.
- `movement() -> int` — 멤버 `movement`의 최소값(멤버 없으면 0). 이동/공격 범위 계산에 사용.
- `vision() -> int` — 멤버 `vision`의 최대값(멤버 없으면 0). 전장의 안개 계산에 사용.
- `attack_range() -> int` — 멤버별 `ItemTypes.max_range(멤버.weapons)`의 최대값(멤버 없으면 0). 월드맵 공격 개시 범위([Selection & Movement](../features/selection-and-movement.md)).
- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `can_move() -> bool` — 이번 턴에 이동 가능한지(`not moved_this_turn and not attacked_this_turn` — 공격했으면 이동 불가).
- `can_attack() -> bool` — 이번 턴에 공격 가능한지(`not attacked_this_turn` — 이동만 했으면 아직 가능).
- `mark_moved() -> void` — 이동 완료 표시(`moved_this_turn = true`). 흐리게 다시 그린다.
- `mark_attacked() -> void` — 공격 완료 표시(`attacked_this_turn = true`). 흐리게 다시 그린다.
- `mark_rested() -> void` — 휴식/대기 표시. `rested_this_turn = true` + `attacked_this_turn = true`(행동 종료). `moved_this_turn`은 유지. 흐리게 다시 그린다.
- `undo_move() -> void` — 이동 되돌리기. `moved_this_turn = false`(다시 이동 가능)로 되돌리고 불투명하게 다시 그린다. 위치 복원·시야 갱신은 `game.gd`([행동 메뉴](../features/party-action-menu.md) `[취소]`).
- `can_rest() -> bool` — 휴식 가능 여부(`not attacked_this_turn` — 아직 행동을 끝내지 않았으면 가능).
- `reset_turn() -> void` — 턴 종료 시 호출. `moved_this_turn`·`attacked_this_turn`·`rested_this_turn`를 모두 `false`로 되돌리고 불투명하게 다시 그린다.
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
- [정상] `reset_turn()` 후 다시 `can_move()`·`can_attack()`·`can_rest()` 참, `rested_this_turn` 거짓
- [정상] `TurnManager.end_turn`에 넘긴 부대의 `moved_this_turn`이 참이면 호출 후 거짓으로 리셋

## 관련

- 부대 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용. 부대는 서로의 칸을 통과·점유할 수 없다([유닛 점유](../features/selection-and-movement.md)).
- 턴당 1회 이동 제한(`moved_this_turn`/`can_move`/`mark_moved`/`reset_turn`)은 [Turn](../features/turn.md)에서 사용.
- 멤버 개별 능력치는 [Human](Human.md), 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
