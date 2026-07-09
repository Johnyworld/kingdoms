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

### 유도 능력치 (Derived)

멤버들의 능력치에서 계산한다.

| 속성 | 메서드 | 규칙 | 설명 |
| --- | --- | --- | --- |
| 이동력 | `movement()` | 멤버 `movement`의 **최소값** | 가장 느린 멤버를 따라간다. 멤버 없으면 `0` |
| 시야 | `vision()` | 멤버 `vision`의 **최대값** | 가장 멀리 보는 멤버를 따라간다. 멤버 없으면 `0` |

### 상태 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 위치 | `position` | Node2D 위치. 맵 토큰으로서 부대가 선 칸 |
| 선택됨 | `selected` | 선택 상태. `set_selected(value)`로 변경 시 강조 링을 다시 그린다 |
| 이번 턴 이동함 | `moved_this_turn` | 이번 [턴](../features/turn.md)에 이미 이동했는지 |
| 이번 턴 공격함 | `attacked_this_turn` | 이번 턴에 이미 공격했는지. 공격은 그 부대의 행동을 끝낸다([전투](../features/battle.md)) |

한 턴에 **이동 1회 + 공격 1회**가 가능하다. 이동해도 공격은 아직 할 수 있지만, 공격하면 이동·공격 모두 끝난다. 어느 하나라도 했으면 토큰을 흐리게 표시한다.

## 동작

- `add_member(human) -> void` — 멤버를 `members`에 추가한다. 이미 포함된 멤버는 중복 추가하지 않는다.
- `commander_name() -> String` — 지휘관의 `human_name`. 지휘관이 없으면(`null`) `"—"`. 부대 일람([Party Roster](../features/party-roster.md)) 표시에 사용.
- `movement() -> int` — 멤버 `movement`의 최소값(멤버 없으면 0). 이동/공격 범위 계산에 사용.
- `vision() -> int` — 멤버 `vision`의 최대값(멤버 없으면 0). 전장의 안개 계산에 사용.
- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `can_move() -> bool` — 이번 턴에 이동 가능한지(`not moved_this_turn and not attacked_this_turn` — 공격했으면 이동 불가).
- `can_attack() -> bool` — 이번 턴에 공격 가능한지(`not attacked_this_turn` — 이동만 했으면 아직 가능).
- `mark_moved() -> void` — 이동 완료 표시(`moved_this_turn = true`). 흐리게 다시 그린다.
- `mark_attacked() -> void` — 공격 완료 표시(`attacked_this_turn = true`). 흐리게 다시 그린다.
- `reset_turn() -> void` — 턴 종료 시 호출. `moved_this_turn`·`attacked_this_turn`를 모두 `false`로 되돌리고 불투명하게 다시 그린다.
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
- [정상] 생성 직후 `moved_this_turn`·`attacked_this_turn` 거짓, `can_move()`·`can_attack()` 참
- [정상] `mark_moved()` 후 `moved_this_turn` 참, `can_move()` 거짓, `can_attack()`는 **여전히 참**(이동 후 공격 가능)
- [정상] `mark_attacked()` 후 `can_attack()` 거짓, `can_move()`도 거짓(공격이 이동도 끝냄)
- [정상] `reset_turn()` 후 다시 `can_move()`·`can_attack()` 참
- [정상] `TurnManager.end_turn`에 넘긴 부대의 `moved_this_turn`이 참이면 호출 후 거짓으로 리셋

## 관련

- 부대 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용. 부대는 서로의 칸을 통과·점유할 수 없다([유닛 점유](../features/selection-and-movement.md)).
- 턴당 1회 이동 제한(`moved_this_turn`/`can_move`/`mark_moved`/`reset_turn`)은 [Turn](../features/turn.md)에서 사용.
- 멤버 개별 능력치는 [Human](Human.md), 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
