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
| 종류 | `kind` | `"troop"` | 부대 종류(랑그릿사식 이분화). `KIND_HERO`(`"hero"`, 영웅부대 — 지휘관 1명 단독) / `KIND_TROOP`(`"troop"`, 일반부대 — 동일 능력치 병사 다수, 기본 [10명](../data/units.md)). **멤버 수로 파생하지 않고 명시 저장**(전투 사상으로 인원이 줄어도 종류는 유지). 카탈로그 생성 시 설정. → [Units](../data/units.md) |
| 병종 | `troop_type` | `""` | 이 부대의 **병종**(아키타입) id. 값은 [병종 카탈로그](../data/units.md)의 archetype id(`"light_infantry"` 경보병 / `"light_archer"` 경궁병 …). 일반부대 생성·[분할](../features/party-composition.md) 시 설정하며(분할된 새 부대는 원 부대 병종을 물려받음), 한 부대는 **하나의 병종으로 동질**하다(병합은 같은 병종끼리만 → 혼합 안 됨). **[병합 가능 판정](../features/party-composition.md)의 기준**. 영웅부대는 설정하지 않아 `""`(병합 없음). `is_ranged()`(아키타입 기반 근접/원거리 아이콘 판별)는 이 `troop_type`을 [GameUnits](../data/units.md) 카탈로그로 조회한다 |

### 소속 (Lord)

**일반부대**([Units](../data/units.md) `kind==KIND_TROOP`)는 하나의 **영웅부대**에 소속될 수 있다(랑그릿사식). 소속돼도 부대는 **독립 토큰으로 자유 이동**하며, 소속은 지금은 **메타데이터**다(향후 영웅 근처 소속 부대에 세력·영웅별 버프를 줄 근거 — `미구현`). 설정/해제는 [소속 UI](../features/party-lord.md)([소속] 버튼 → 모달).

| 속성 | 변수/메서드 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 소속 영웅 | `lord` | `Object`(Party) | `null` | 이 일반부대가 소속된 **영웅부대**([Party](Party.md)) 참조. 독립 부대·영웅부대 자신은 `null`. [시작 편제](../features/parties.md)에서 부하부대의 `lord`를 소속 영웅부대로 설정하고, 이후 [소속 UI](../features/party-lord.md)로 변경한다 |
| 소속 보유 | `has_lord()` | `bool` | — | `lord != null` |
| 소속 영웅 이름 | `lord_name()` | `String` | — | `lord`의 [`commander_name()`](#동작). `lord`가 없거나 지휘관이 없으면 `"—"` |
| 영웅부대 여부 | `is_hero()` | `bool` | — | `kind == KIND_HERO` |
| 인원수 배지 표시 여부 | `shows_member_count()` | `bool` | — | 토큰 우하단에 남은 인원수 배지를 그릴지. **일반부대(`KIND_TROOP`)이고 멤버가 있으면** 참. 영웅부대는 항상 1명이라 생략(거짓) |
| 소속 지정 | `set_lord(hero)` | — | — | `lord = hero`. [소속 UI](../features/party-lord.md)의 소속(합류) 확정에 쓰는 단일 출처 |
| 소속 해제 | `clear_lord()` | — | — | `lord = null`(독립). [소속 UI](../features/party-lord.md)의 [독립] |
| 지휘 반경 | `command_range()` | `int` | — | 영웅부대의 [지휘 범위](../features/command-range.md) = lang 클래스 `cmd_range`(영웅 4·경보병 3, 아키타입 없으면 0). 소속 하위부대 버프 판정에 쓴다 |
| 지휘 버프 중 | `command_buffed` | `bool` | `false` | 이 부대가 영웅 지휘 범위 안이라 버프 중인지. 맵 배지·전투 배율의 출처([지휘 범위](../features/command-range.md)) |
| 하이라이트 | `highlight` | `Color` | `Color(0,0,0,0)` | 토큰 테두리 강조색(알파 0이면 없음). NPC 공격 연출에서 공격자·대상을 잠깐 표시([NPC 공격](../features/npc-movement.md#npc-공격-그룹-이동-직후)). `set_highlight(color)`로 변경, `_draw`가 알파>0이면 링을 그린다 |

### 멤버 (Members)

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 멤버 | `members` | `Array` | `[]` | 이 부대에 속한 [Human](Human.md) 목록 |
| 지휘관 | `commander` | `Object` (Human) | `null` | 부대를 이끄는 [Human](Human.md). 멤버 중 하나를 가리킨다. 아직 편성 UI가 없어 생성 시 코드로 지정한다 |

### 유도 능력치 (Derived)

멤버들의 능력치에서 계산한다.

| 속성 | 메서드 | 규칙 | 설명 |
| --- | --- | --- | --- |
| 이동력 | `movement()` | **클래스 `mv`** | 아키타입 lang 클래스 `mv`([GameUnits](../data/units.md), 경보병·영웅 6). 멤버 구성과 무관(같은 병종). |
| 시야 | `vision()` | **클래스 시야** | 아키타입 카탈로그 시야([GameUnits](../data/units.md), 경보병 5·영웅 6). 멤버 수와 무관 |
| 공격거리 | `attack_range()` | **클래스 공격거리** | 근접 0·원거리(경궁병) 3([GameUnits](../data/units.md)). 월드맵 공격 개시 거리 |

### 상태 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 위치 | `position` | Node2D 위치. 맵 토큰으로서 부대가 선 칸 |
| 선택됨 | `selected` | 선택 상태. `set_selected(value)`로 변경 시 강조 링을 다시 그린다 |
| 이번 턴 이동함 | `moved_this_turn` | 이번 [턴](../features/turn.md)에 이미 이동했는지 |
| 이번 턴 공격함 | `attacked_this_turn` | 이번 턴에 이미 공격했는지. 공격은 그 부대의 행동을 끝낸다([전투](../features/lang-battle.md)) |
| 이번 턴 휴식함 | `rested_this_turn` | 이번 턴 `[휴식]`/`[대기]`을 선택했는지([행동 메뉴](../features/party-action-menu.md)). 회복 연동은 `미구현` |

한 턴에 **이동 1회 + 공격 1회**가 가능하다. 이동해도 공격은 아직 할 수 있지만, 공격하면 이동·공격 모두 끝난다. 어느 하나라도 했으면 토큰을 흐리게 표시한다.

## 동작

- `add_member(human) -> void` — 멤버를 `members`에 추가한다. 이미 포함된 멤버는 중복 추가하지 않는다. **지휘관이 없으면**(빈 부대의 첫 멤버) 그 멤버를 지휘관으로 삼는다. 다시 그린다.
- `remove_member(human) -> void` — 멤버를 `members`에서 뺀다. 그 멤버가 지휘관이면 남은 첫 멤버로 재지정하고(없으면 `null`), 다시 그린다. 없는 멤버면 no-op. [부대 분할](../features/party-composition.md)·전투 사상자 반영에 쓴다. 멤버가 0이 되면 토큰을 그리지 않는다(`_draw`가 빈 부대는 생략).
- `commander_name() -> String` — 지휘관의 `human_name`. 지휘관이 없으면(`null`) `"—"`. 부대 일람([Party Roster](../features/party-roster.md)) 표시에 사용.
- `is_hero() -> bool` — 영웅부대인지(`kind == KIND_HERO`). 일반부대는 거짓.
- `shows_member_count() -> bool` — 토큰에 남은 인원수 배지를 그릴지(`kind == KIND_TROOP` 그리고 멤버 있음). 영웅부대·빈 부대는 거짓. `_draw`가 이 판정으로 배지를 그린다.
- `can_merge_with(other) -> bool` — `other` 부대를 이 부대에 [병합](../features/party-composition.md)할 수 있는지. **병합 가능 판정의 단일 출처**. 참 조건: `other`가 `null`이 아니고, **양쪽 모두 일반부대**(`kind == KIND_TROOP` 그리고 `other.kind == KIND_TROOP` — 영웅부대는 어느 쪽이든 병합 불가), **같은 병종**(`troop_type == other.troop_type`), 그리고 **합쳐도 인원 상한을 넘지 않을 것**(`members.size() + other.members.size() <= UnitTypes.TROOP_SIZE`(10) — 예: 4+6·5+5 가능, 6+5 불가). `game.gd`의 병합 대상 판정([Party Composition](../features/party-composition.md))이 이 메서드로 인접 아군을 거른다.
- `is_ranged() -> bool` — 이 부대 병종이 원거리인지: **아키타입이 원거리(경궁병)** 면 참([GameUnits](../data/units.md)). 월드맵 토큰 **좌하단 병종 아이콘**(원거리=활 / 근접=검) 판별에 쓴다(`_draw` → `_draw_class_icon`). 아키타입 없으면 거짓(근접 기본). 아이콘은 에셋 없이 **코드 도형 플레이스홀더**(검=날+가드+손잡이 그립+폼멜, 활=휜 활대+시위+화살).
- `has_lord() -> bool` — 소속 영웅부대가 있는지(`lord != null`).
- `lord_name() -> String` — `lord`의 `commander_name()`. `lord`가 `null`이거나 그 지휘관이 없으면 `"—"`.
- `set_lord(hero) -> void` — 소속 영웅부대를 지정한다(`lord = hero`). [소속 UI](../features/party-lord.md)가 소속(합류) 확정에 쓴다.
- `clear_lord() -> void` — 소속을 해제한다(`lord = null`, 독립). [소속 UI](../features/party-lord.md)의 [독립].
- `base_movement() -> int` — 아키타입 lang 클래스 `mv`([GameUnits](../data/units.md)). `movement()`가 공유한다.
- `movement() -> int` — 아키타입 클래스 `mv`([GameUnits](../data/units.md)). 이동 범위·NPC 경로에 반영.
- `vision() -> int` — 아키타입 카탈로그 시야([GameUnits](../data/units.md)). 전장의 안개 계산에 사용(멤버 수 무관).
- `attack_range() -> int` — 아키타입 클래스 공격거리(근접 0·원거리 3, [GameUnits](../data/units.md)). 월드맵 공격 개시 범위([Selection & Movement](../features/selection-and-movement.md)).
- `melee_power() -> int` / `ranged_power() -> int` — 교전 선호 판정([NPC 이동](../features/npc-movement.md))용 파워. 병종이 근접이면 `melee_power = 클래스 AT × members.size()`·`ranged_power = 0`, 원거리(경궁병)면 반대. [GameUnits](../data/units.md) 기반.
- `archetype() -> String` — 이 부대의 아키타입 id(GameUnits 카탈로그 키). 영웅부대는 `"hero"`, 그 외는 `troop_type`. 위 클래스 기반 스탯의 조회 키.
- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `can_move() -> bool` — 이번 턴에 이동 가능한지(`not moved_this_turn and not attacked_this_turn` — 공격했으면 이동 불가).
- `can_attack() -> bool` — 이번 턴에 공격 가능한지(`not attacked_this_turn` — 이동만 했으면 아직 가능).
- `mark_moved() -> void` — 이동 완료 표시(`moved_this_turn = true`). 흐리게 다시 그린다.
- `mark_attacked() -> void` — 공격 완료 표시(`attacked_this_turn = true`). 흐리게 다시 그린다.
- `mark_rested() -> void` — 휴식/대기 표시. `rested_this_turn = true` + `attacked_this_turn = true`(행동 종료). `moved_this_turn`은 유지. 흐리게 다시 그린다.
- `undo_move() -> void` — 이동 되돌리기. `moved_this_turn = false`(다시 이동 가능)로 되돌리고 불투명하게 다시 그린다. 위치 복원·시야 갱신은 `game.gd`([행동 메뉴](../features/party-action-menu.md) `[취소]`).
- `can_rest() -> bool` — 휴식 가능 여부(`not attacked_this_turn` — 아직 행동을 끝내지 않았으면 가능).
- `reset_turn() -> void` — 턴 종료 시 호출. `moved_this_turn`·`attacked_this_turn`·`rested_this_turn`를 모두 `false`로 되돌리고 불투명하게 다시 그린다.
- `_draw()` — 선택 시 발밑 강조 링(노란색) + 그림자 + 몸통 원(`token_color`) + 외곽선을 그린다. `moved_this_turn` 또는 `attacked_this_turn`이면 전체를 반투명하게 그린다. [지휘 버프](../features/command-range.md) 중이면 토큰 **위**에 금색 갈매기 배지, `shows_member_count()`면 토큰 **우하단**에 남은 인원수(`members.size()`, 1~10) 배지(어두운 배경 원 + 흰 숫자)를 그린다. 플레이어·보이는 NPC 일반부대 모두에 표시(사상자로 줄어든 병력 확인). 그리고 토큰 **좌하단**에 **병종 아이콘**(`_draw_class_icon` — `is_ranged()`(아키타입 기반)면 활, 아니면 검)을 그린다(멤버 있는 모든 부대, 영웅 포함).

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
- [정상] 생성 직후 `kind == "troop"`(=`KIND_TROOP`), `is_hero() == false`; `kind = KIND_HERO`로 두면 `is_hero() == true`
- [정상] `shows_member_count()`: 멤버 있는 일반부대(`KIND_TROOP`) → 참; 멤버 있는 영웅부대(`KIND_HERO`) → 거짓; 멤버 없는 일반부대 → 거짓
- [정상] `is_ranged()`: 경궁병 아키타입 → 참(활 아이콘); 경보병 → 거짓(검 아이콘); 아키타입 없음 → 거짓(근접 기본)
- [정상] 생성 직후 `troop_type == ""`, 설정 가능
- [정상] `can_merge_with`: 둘 다 `KIND_TROOP`이고 `troop_type`이 같으면(`"light_infantry"`끼리) → 참
- [예외] `can_merge_with`: `troop_type`이 다르면(`"light_infantry"` vs `"light_archer"`) → 거짓(다른 병종)
- [예외] `can_merge_with`: 어느 한쪽이라도 영웅부대(`KIND_HERO`)면 → 거짓(영웅은 병합 없음, `troop_type`이 같아도)
- [경계] `can_merge_with`: 인원 합계가 상한(10) 이하면(5+5, 4+6) → 참; 상한을 넘으면(6+5=11) → 거짓
- [예외] `can_merge_with(null)` → 거짓
- [정상] 생성 직후 `highlight`의 알파 0(없음); `set_highlight(Color.RED)` 후 `highlight == Color.RED`([NPC 공격 연출](../features/npc-movement.md#npc-공격-그룹-이동-직후))
- [정상] 생성 직후 `lord == null`, `has_lord() == false`, `lord_name() == "—"`
- [정상] `lord`에 지휘관 있는 영웅부대를 지정하면 `has_lord() == true`, `lord_name()`이 그 영웅 이름
- [경계] `lord`에 지휘관 없는(빈) 부대를 지정하면 `has_lord() == true`이나 `lord_name() == "—"`
- [정상] `set_lord(hero)` 후 `lord == hero`, `has_lord()` 참; `clear_lord()` 후 `lord == null`, `has_lord()` 거짓
- [정상] 경보병 부대 → `movement() ==` 클래스 mv(6); 아키타입 없으면 0
- [경계] 멤버 없으면 `movement() == 0`
- [정상] 경보병 부대 → `vision() ==` 클래스 카탈로그 시야
- [정상] 경궁병 → `attack_range() == 3`(원거리); 경보병 → 0(근접)
- [정상] 생성 직후 `moved_this_turn`·`attacked_this_turn` 거짓, `can_move()`·`can_attack()` 참
- [정상] `mark_moved()` 후 `moved_this_turn` 참, `can_move()` 거짓, `can_attack()`는 **여전히 참**(이동 후 공격 가능)
- [정상] `mark_attacked()` 후 `can_attack()` 거짓, `can_move()`도 거짓(공격이 이동도 끝냄)
- [정상] `mark_rested()` 후 `rested_this_turn` 참, `attacked_this_turn` 참(행동 종료), `can_rest()` 거짓
- [정상] `mark_moved()` 후 `undo_move()` → `moved_this_turn` 거짓, `can_move()` 다시 참
- [정상] `can_rest()`는 행동 전 참, `mark_attacked()`/`mark_rested()` 후 거짓
- [정상] `reset_turn()` 후 다시 `can_move()`·`can_attack()`·`can_rest()` 참, `rested_this_turn` 거짓
- [정상] `TurnManager.end_turn`에 넘긴 부대의 `moved_this_turn`이 참이면 호출 후 거짓으로 리셋

## 관련

- 부대 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용. 부대는 서로의 칸을 통과·점유할 수 없다([유닛 점유](../features/selection-and-movement.md)).
- 턴당 1회 이동 제한(`moved_this_turn`/`can_move`/`mark_moved`/`reset_turn`)은 [Turn](../features/turn.md)에서 사용.
- 멤버 개별 능력치는 [Human](Human.md), 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
