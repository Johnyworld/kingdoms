# Entity: Party (부대)

> 스크립트: `scenes/party/party.gd` (`extends Node2D`)
> 씬: `scenes/party/party.tscn`

맵 위에서 **실제로 움직이는 유닛**. **순수 "클래스 + 병력수" 모델**(랑그릿사식) — 부대는 아키타입과 병력수(`soldiers`)만 가지며, 개별 병사(Human) 객체·스탯은 없다(M4-C에서 제거).
우리가 선택·이동시키는 대상은 이 **부대**다.
부대는 [유닛 카탈로그](../data/factions.md)에서 생성되며, 플레이어 부대 외에 NPC 부대들도 맵에 존재한다([Parties](../features/parties.md)).
외형은 병종별 **idle 애니메이션 스프라이트**(`AnimatedSprite2D`)로 그린다(→ [맵 토큰 외형](#맵-토큰-외형-sprite)). 선택 링·인원 배지 등 오버레이는 여전히 `_draw()`에서 캔버스로 얹는다.

## Properties

### 정체 (Identity)

| 속성 | export 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 이름 | `party_name` | `""` | 부대의 이름. 엔진 내장 `name`(노드 이름)과 충돌하므로 별도 변수로 둔다 |
| 소속 세력 | `faction_name` | `""` | 부대가 속한 [세력](Faction.md) 이름. 정보 패널에 표시해 아군/적을 구분한다. 카탈로그 생성 시 설정 |
| 토큰 색 | `token_color` | `Color(0.92, 0.78, 0.35)` (금색) | 맵 토큰 몸통 색. 플레이어는 기본 금색, NPC 부대는 소속 세력 색으로 설정한다 |
| 종류 | `kind` | `"troop"` | 부대 종류(랑그릿사식 이분화). `KIND_HERO`(`"hero"`, 영웅부대 — 지휘관 1명 단독) / `KIND_TROOP`(`"troop"`, 일반부대 — 병사 다수, 기본 [10명](../data/factions.md)). **병력수로 파생하지 않고 명시 저장**(전투 사상으로 병력이 줄어도 종류는 유지). 카탈로그 생성 시 설정. → [Units](../data/factions.md) |
| 병종 | `troop_type` | `""` | 이 부대의 **병종**(아키타입) id. 값은 [병종 카탈로그](../data/unit-types.md)의 archetype id(`"light_infantry"` 경보병 / `"light_archer"` 경궁병 …). 일반부대 생성 시 설정하며, 한 부대는 **하나의 병종으로 동질**하다(병합은 같은 병종끼리만 → 혼합 안 됨). **[병합 가능 판정](../features/party-composition.md)의 기준**. 영웅부대는 설정하지 않아 `""`(병합 없음). `archetype()`(영웅=`"hero"`, 그 외=`troop_type`)이 [맵 토큰 스프라이트 세트](#맵-토큰-외형-sprite)·클래스 스탯 조회 키다 |

### 소속 (Lord)

**일반부대**([Units](../data/factions.md) `kind==KIND_TROOP`)는 하나의 **영웅부대**에 소속될 수 있다(랑그릿사식). 소속돼도 부대는 **독립 토큰으로 자유 이동**하며, 소속은 지금은 **메타데이터**다(향후 영웅 근처 소속 부대에 세력·영웅별 버프를 줄 근거 — `미구현`). 설정/해제는 [소속 UI](../features/party-lord.md)([소속] 버튼 → 모달).

| 속성 | 변수/메서드 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 소속 영웅 | `lord` | `Object`(Party) | `null` | 이 일반부대가 소속된 **영웅부대**([Party](Party.md)) 참조. 독립 부대·영웅부대 자신은 `null`. [시작 편제](../features/parties.md)에서 부하부대의 `lord`를 소속 영웅부대로 설정하고, 이후 [소속 UI](../features/party-lord.md)로 변경한다 |
| 소속 보유 | `has_lord()` | `bool` | — | `lord != null` |
| 소속 영웅 이름 | `lord_name()` | `String` | — | `lord`의 `commander_name`. `lord`가 없으면 `"—"` |
| 영웅부대 여부 | `is_hero()` | `bool` | — | `kind == KIND_HERO` |
| 인원수 배지 표시 여부 | `shows_member_count()` | `bool` | — | 토큰 우하단에 남은 병력수 배지를 그릴지. **일반부대(`KIND_TROOP`)이고 병력(`soldiers > 0`)이 있으면** 참. 영웅부대는 단독이라 생략(거짓) |
| 소속 지정 | `set_lord(hero)` | — | — | `lord = hero`. [소속 UI](../features/party-lord.md)의 소속(합류) 확정에 쓰는 단일 출처 |
| 소속 해제 | `clear_lord()` | — | — | `lord = null`(독립). [소속 UI](../features/party-lord.md)의 [독립] |
| 지휘 반경 | `command_range()` | `int` | — | 영웅부대의 [지휘 범위](../features/command-range.md) = lang 클래스 `cmd_range`(영웅 4·경보병 3, 아키타입 없으면 0). 소속 하위부대 버프 판정에 쓴다 |
| 지휘 버프 중 | `command_buffed` | `bool` | `false` | 이 부대가 영웅 지휘 범위 안인지(맵 배지 전용). **전투 미반영**([지휘 범위](../features/command-range.md)) |
| 하이라이트 | `highlight` | `Color` | `Color(0,0,0,0)` | 토큰 테두리 강조색(알파 0이면 없음). NPC 공격 연출에서 공격자·대상을 잠깐 표시([NPC 공격](../features/npc-movement.md#npc-공격-그룹-이동-직후)). `set_highlight(color)`로 변경, `_draw`가 알파>0이면 링을 그린다 |

### 병력 (Soldiers)

순수 "클래스 + 병력수" 모델. 개별 병사(Human) 객체는 없다.

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 병력수 | `soldiers` | `int` | `0` | 병력수 = HP 풀. 일반부대는 병사 수(기본 [10](../data/factions.md)), 영웅부대는 클래스 HP(`UnitTypes.max_hp("hero")`). **`0`이면 전멸**(토큰 미표시). 전투 결과(`final_soldiers`)로 갱신되며, 배지·전투 파워·lang 유닛 병력의 단일 출처 |
| 지휘관 이름 | `commander_name` | `String` | `""` | 부대 지휘관 이름(표시용). 영웅부대=영웅 이름, 일반부대=병종 이름. 카탈로그 생성 시 설정 |

### 유도 능력치 (Derived)

아키타입(lang 클래스)에서 계산한다. 병력 구성과 무관(부대는 단일 병종).

| 속성 | 메서드 | 규칙 | 설명 |
| --- | --- | --- | --- |
| 이동력 | `movement()` | **클래스 `mv`** | 아키타입 lang 클래스 `mv`([UnitTypes](../data/unit-types.md), 경보병·영웅 6). |
| 시야 | `vision()` | **클래스 시야** | 아키타입 카탈로그 시야([UnitTypes](../data/unit-types.md), 경보병 5·영웅 6) |
| 공격거리 | `attack_range()` | **클래스 공격거리** | 근접 0·원거리(경궁병) 3([UnitTypes](../data/unit-types.md)). 월드맵 공격 개시 거리 |
| 전투 파워 | `power()` | **= `soldiers`** | 교전/후퇴 판단([NPC 이동](../features/npc-movement.md))용 전력. 부상하면 낮아진다 |

### 상태 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 위치 | `position` | Node2D 위치. 맵 토큰으로서 부대가 선 칸 |
| 선택됨 | `selected` | 선택 상태. `set_selected(value)`로 변경 시 강조 링을 다시 그린다 |
| 이번 턴 이동함 | `moved_this_turn` | 이번 [턴](../features/turn.md)에 이미 이동했는지 |
| 이번 턴 공격함 | `attacked_this_turn` | 이번 턴에 이미 공격했는지. 공격은 그 부대의 행동을 끝낸다([전투](../features/lang-battle.md)) |

한 턴에 **이동 1회 + 공격 1회**가 가능하다. 이동해도 공격은 아직 할 수 있지만, 공격하면 이동·공격 모두 끝난다. 어느 하나라도 했으면 토큰을 흐리게 표시한다.

## 맵 토큰 외형 (Sprite)

> 스프라이트 세트·프레임 캐시: `scenes/party/unit_sprites.gd` (`UnitSprites`, 정적 헬퍼)

부대 토큰은 병종별 **idle 애니메이션 스프라이트**(`AnimatedSprite2D`)로 그린다. 전투 화면([Lang Battle](../features/lang-battle.md))과 **같은 에셋**(`res://assets/units/*_idle.png`, 100×100 프레임 6장)을 쓴다.

- **세트 매핑**(`UnitSprites.set_key(archetype)`) — `hero → "sword"`, `light_infantry → "soldier"`, `light_archer → "archer_a"`. 미지원/빈 아키타입은 `"soldier"`로 대체. 부대는 `archetype()`(영웅=`"hero"`, 그 외=`troop_type`)로 세트를 고른다.
- **프레임 캐시**(`UnitSprites.idle_frames`) — 세트별 idle `SpriteFrames`(6프레임 루프)를 **정적 캐시**로 1개만 만들어 64부대가 공유한다(부대마다 새로 만들지 않음). `AnimatedSprite2D`는 기본 `"default"` 애니메이션에 idle 프레임을 담아 재생한다.
- **크기·정렬** — 스프라이트를 `SPRITE_SCALE`(≈0.55)로 축소해 **16px 헥스**(`tile_size` 16×16, `tile_shape` 육각)에 맞춘다. `centered = true` + 세로 `offset`(`_SPRITE_OFFSET_Y`)으로 정렬하되, **머리를 기준으로 크기를 키워** 발은 칸 중심(부대 `position`)보다 살짝 아래에 온다(크기 조정 시 머리 위치 유지·아래로 성장). 그림자(`_SHADOW_Y`)도 발에 맞춰 함께 내린다.
- **필터** — 스프라이트·부대 노드 모두 `texture_filter = TEXTURE_FILTER_NEAREST`([전투 화면](../features/lang-battle.md)과 동일). 스프라이트 픽셀·`draw_string`(인원 배지 숫자) 글리프가 축소·줌 확대에도 **선명**하게 유지된다(Linear면 흐릿).
- **그림자** — 발밑에 **납작한 타원 3겹**(`_draw_ellipse`, 바깥 옅음→안쪽 진함)으로 그린다([전투 화면](../features/lang-battle.md)과 동일 방식 — 수치는 맵 규모로 축소). 정원이 아니라 지면에 앉은 타원.
- **레이어** — 스프라이트는 `show_behind_parent = true`로 두어, 부대 `_draw`의 오버레이(선택 링·지휘 배지·인원 배지)가 **스프라이트 위**에 그려지게 한다(가림 방지).
- **세력 틴트** — `modulate = token_color`를 가독성 위해 흰색으로 섞은 색(`token_color.lerp(Color.WHITE, TINT_MIX)`)으로 둔다. 플레이어(금색)·NPC(세력색) 구분을 스프라이트 위에 얹는다. 이동/공격 페이드는 `modulate.a`에 곱한다.
- **전멸**(`soldiers <= 0`) 시 스프라이트를 숨긴다. NPC 안개 처리는 부대 노드 `visible`로 되어 자식 스프라이트도 함께 숨는다([Fog of War](../features/fog-of-war.md)).

## 동작

- `power() -> int` — 전투 파워(교전/후퇴 판단). = `soldiers`(병력수/HP 풀). 부상하면 낮아진다. [NPC 이동](../features/npc-movement.md)이 전력 비교에 쓴다.
- `merge_from(other) -> void` — `other`의 병력을 이 부대로 흡수한다: `soldiers += other.soldiers; other.soldiers = 0`(other는 병력 0이 됨 → 호출부가 제거). 이 부대 지휘관 이름은 유지. 양쪽 다시 그린다. *(병종 검사는 호출부가 `can_merge_with`로 이미 거른다 — 이 함수는 병력 합산만 수행)*
- `is_hero() -> bool` — 영웅부대인지(`kind == KIND_HERO`). 일반부대는 거짓.
- `shows_member_count() -> bool` — 토큰에 남은 병력수 배지를 그릴지(`kind == KIND_TROOP` 그리고 `soldiers > 0`). 영웅부대·전멸 부대는 거짓. `_draw`가 이 판정으로 배지를 그린다.
- `can_merge_with(other) -> bool` — `other` 부대를 이 부대에 [병합](../features/party-composition.md)할 수 있는지. **병합 가능 판정의 단일 출처**. 참 조건: `other`가 `null`이 아니고, **양쪽 모두 일반부대**(`kind == KIND_TROOP` 그리고 `other.kind == KIND_TROOP` — 영웅부대는 어느 쪽이든 병합 불가), **같은 병종**(`troop_type == other.troop_type`), 그리고 **합쳐도 병력 상한을 넘지 않을 것**(`soldiers + other.soldiers <= FactionCatalog.TROOP_SIZE`(10) — 예: 4+6·5+5 가능, 6+5 불가). `game.gd`의 병합 대상 판정([Party Composition](../features/party-composition.md))이 이 메서드로 인접 아군을 거른다.
- `is_ranged() -> bool` — 이 부대 병종이 원거리인지: **아키타입이 원거리(경궁병)** 면 참([UnitTypes](../data/unit-types.md)). 아키타입 없으면 거짓(근접 기본). 근접/원거리 구분은 이제 **토큰 스프라이트 자체**(`soldier`/`archer_a`/`sword`)로 드러나므로 별도 아이콘은 그리지 않는다(코드 도형 병종 아이콘 제거). 이 판정은 전투·NPC AI 파워 계산 등에서 계속 쓰인다.
- `has_lord() -> bool` — 소속 영웅부대가 있는지(`lord != null`).
- `lord_name() -> String` — `lord`의 `commander_name`. `lord`가 `null`이면 `"—"`.
- `set_lord(hero) -> void` — 소속 영웅부대를 지정한다(`lord = hero`). [소속 UI](../features/party-lord.md)가 소속(합류) 확정에 쓴다.
- `clear_lord() -> void` — 소속을 해제한다(`lord = null`, 독립). [소속 UI](../features/party-lord.md)의 [독립].
- `base_movement() -> int` — 아키타입 lang 클래스 `mv`([UnitTypes](../data/unit-types.md)). `movement()`가 공유한다.
- `movement() -> int` — 아키타입 클래스 `mv`([UnitTypes](../data/unit-types.md)). 이동 범위·NPC 경로에 반영.
- `vision() -> int` — 아키타입 카탈로그 시야([UnitTypes](../data/unit-types.md)). 전장의 안개 계산에 사용(병력수 무관).
- `attack_range() -> int` — 아키타입 클래스 공격거리(근접 0·원거리 3, [UnitTypes](../data/unit-types.md)). 월드맵 공격 개시 범위([Selection & Movement](../features/selection-and-movement.md)).
- `melee_power() -> int` / `ranged_power() -> int` — 교전 선호 판정([NPC 이동](../features/npc-movement.md))용 파워. 병종이 근접이면 `melee_power = 클래스 AT × soldiers`·`ranged_power = 0`, 원거리(경궁병)면 반대. [UnitTypes](../data/unit-types.md) 기반.
- `archetype() -> String` — 이 부대의 아키타입 id(UnitTypes 카탈로그 키). 영웅부대는 `"hero"`, 그 외는 `troop_type`. 위 클래스 기반 스탯의 조회 키.
- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `can_move() -> bool` — 이번 턴에 이동 가능한지(`not moved_this_turn and not attacked_this_turn` — 공격했으면 이동 불가).
- `can_attack() -> bool` — 이번 턴에 공격 가능한지(`not attacked_this_turn` — 이동만 했으면 아직 가능).
- `mark_moved() -> void` — 이동 완료 표시(`moved_this_turn = true`). 흐리게 다시 그린다.
- `mark_attacked() -> void` — 공격 완료 표시(`attacked_this_turn = true`, 행동 종료). 흐리게 다시 그린다. [대기]도 이걸 쓴다.
- `undo_move() -> void` — 이동 되돌리기. `moved_this_turn = false`(다시 이동 가능)로 되돌리고 불투명하게 다시 그린다. 위치 복원·시야 갱신은 `game.gd`([행동 메뉴](../features/party-action-menu.md) `[취소]`).
- `can_rest() -> bool` — 아직 행동(대기 등)이 가능한지(`not attacked_this_turn`). 선택 가능 판정에 쓴다.
- `reset_turn() -> void` — 턴 종료 시 호출. `moved_this_turn`·`attacked_this_turn`를 `false`로 되돌리고 불투명하게 다시 그린다.
- `_draw()` — `soldiers <= 0`(전멸)이면 스프라이트를 숨기고 아무것도 그리지 않는다("사라짐"). 그 외엔 자식 [스프라이트](#맵-토큰-외형-sprite)의 프레임·틴트·재생을 현재 상태에 맞추고, 캔버스로 오버레이를 얹는다: 선택 시 발밑 강조 링(노란색), NPC 공격 [하이라이트](../features/npc-movement.md) 링, [지휘 버프](../features/command-range.md) 중이면 캐릭터 **머리 위**에 아주 작은 금색 갈매기(▲) 배지, `shows_member_count()`면 **발=중심 기준 아래-우측**에 남은 병력수(`soldiers`, 1~10) 배지(어두운 배경 원 + 흰 숫자, 폰트 **갈무리14**(`_BADGE_FONT`, 픽셀 폰트 — fallback 벡터 폰트는 흐릿해 교체)). **배지·삼각형은 16px 헥스 규모**의 작은 상수로 잡는다(`_CMD_BADGE_*`: 반폭 2.5·머리 위 y −10.5; `_COUNT_BADGE_*`: 중심 (4,4)·반지름 3·폰트 4). **숫자는 `MapText` 공용 헬퍼**(`scenes/game/map_text.gd`)로 그린다 — 갈무리14(픽셀)+합성 볼드(`variation_embolden` 0.4, regular만 있어 합성)를 **슈퍼샘플**(3배 래스터 후 1/3 축소)해 작아도 기본 3배 줌에서 48px 헥스급으로 또렷하다. 부대 노드는 `texture_filter = NEAREST`. (거점/세력 라벨도 같은 헬퍼를 쓴다 → [건물 렌더](../features/building.md).) 캐릭터 스프라이트는 헥스 위로 조금 솟을 수 있다. `moved_this_turn`/`attacked_this_turn`이면 스프라이트·오버레이를 반투명하게(`_MOVED_ALPHA`). 인원 배지는 플레이어·보이는 NPC 일반부대 모두 표시(사상자로 줄어든 병력 확인). 몸통 원·외곽선·코드 병종 아이콘은 스프라이트로 대체되어 그리지 않는다.

## 테스트 시나리오

### 맵 토큰 스프라이트 세트 (`test/unit/test_unit_sprites.gd`)

`UnitSprites.set_key(archetype)` — 순수 매핑(파일시스템 무관):

- [정상] `"hero"` → `"sword"`
- [정상] `"light_infantry"` → `"soldier"`
- [정상] `"light_archer"` → `"archer_a"`
- [예외] 빈 문자열 `""` → `"soldier"`(근접 기본 대체)
- [예외] 미지원 아키타입(`"dragon"` 등) → `"soldier"`(대체)

`UnitSprites.idle_frames(archetype)` — idle `SpriteFrames` 캐시(에셋 경로 회귀 방지):

- [정상] 각 세트(hero/light_infantry/light_archer) → `"default"` 애니에 `IDLE_COUNT`(6)프레임·루프
- [정상] 같은 세트를 두 번 부르면 **동일 캐시 인스턴스**(64부대 공유)

*(`AnimatedSprite2D` 생성·틴트·스케일·발 정렬은 씬 트리 의존이라 실제 실행으로 확인한다 — game.gd 배치와 동일 관례.)*

### 지도 텍스트 헬퍼 (`test/unit/test_map_text.gd`)

`MapText`(부대 인원 배지·거점/세력 라벨 공용). `draw_centered`는 렌더 결과라 실제 실행으로 확인하고, 폰트 계약만 검증:

- [정상] `MapText.font()`는 `FontVariation`이고 `variation_embolden == EMBOLDEN`(합성 볼드), `base_font == 갈무리14`
- [정상] `font()`는 전역 공유(두 번 불러도 같은 인스턴스)

### Party (`test/unit/test_party.gd`)

- [정상] 트리에 추가된 부대의 자식 스프라이트 `texture_filter == TEXTURE_FILTER_NEAREST`(픽셀 선명 — 흐릿함 방지, 전투 화면과 동일)
- [정상] `party_name` 기본값은 빈 문자열, 설정 가능
- [정상] `faction_name` 기본값은 빈 문자열, 설정 가능
- [정상] `token_color` 기본값은 금색 `Color(0.92, 0.78, 0.35)`, 설정 가능
- [정상] 생성 직후 `soldiers == 0`; 설정 가능
- [정상] `merge_from`: `a.soldiers += b.soldiers`, `b.soldiers == 0`, `a.commander_name` 유지
- [경계] 빈 부대(`soldiers == 0`) 병합은 변화 없음
- [정상] 생성 직후 `commander_name == ""`, 설정 가능
- [정상] `power() == soldiers`(전투 파워 = 병력수)
- [정상] 생성 직후 `kind == "troop"`(=`KIND_TROOP`), `is_hero() == false`; `kind = KIND_HERO`로 두면 `is_hero() == true`
- [정상] `shows_member_count()`: 병력 있는 일반부대(`KIND_TROOP`) → 참; 영웅부대(`KIND_HERO`) → 거짓; 병력 0인 일반부대 → 거짓
- [정상] `is_ranged()`: 경궁병 아키타입 → 참(활 아이콘); 경보병 → 거짓(검 아이콘); 아키타입 없음 → 거짓(근접 기본)
- [정상] 생성 직후 `troop_type == ""`, 설정 가능
- [정상] `can_merge_with`: 둘 다 `KIND_TROOP`이고 `troop_type`이 같으면(`"light_infantry"`끼리) → 참
- [예외] `can_merge_with`: `troop_type`이 다르면(`"light_infantry"` vs `"light_archer"`) → 거짓(다른 병종)
- [예외] `can_merge_with`: 어느 한쪽이라도 영웅부대(`KIND_HERO`)면 → 거짓(영웅은 병합 없음, `troop_type`이 같아도)
- [경계] `can_merge_with`: 병력 합계가 상한(10) 이하면(5+5, 4+6) → 참; 상한을 넘으면(6+5=11) → 거짓
- [예외] `can_merge_with(null)` → 거짓
- [정상] 생성 직후 `highlight`의 알파 0(없음); `set_highlight(Color.RED)` 후 `highlight == Color.RED`([NPC 공격 연출](../features/npc-movement.md#npc-공격-그룹-이동-직후))
- [정상] 생성 직후 `lord == null`, `has_lord() == false`, `lord_name() == "—"`
- [정상] `lord`에 `commander_name` 있는 영웅부대를 지정하면 `has_lord() == true`, `lord_name()`이 그 영웅 이름
- [정상] `set_lord(hero)` 후 `lord == hero`, `has_lord()` 참; `clear_lord()` 후 `lord == null`, `has_lord()` 거짓
- [정상] 경보병 부대 → `movement() ==` 클래스 mv(6); 아키타입 없으면 0
- [정상] 경보병 부대 → `vision() ==` 클래스 카탈로그 시야
- [정상] 경궁병 → `attack_range() == 3`(원거리); 경보병 → 0(근접)
- [정상] 생성 직후 `moved_this_turn`·`attacked_this_turn` 거짓, `can_move()`·`can_attack()` 참
- [정상] `mark_moved()` 후 `moved_this_turn` 참, `can_move()` 거짓, `can_attack()`는 **여전히 참**(이동 후 공격 가능)
- [정상] `mark_attacked()` 후 `can_attack()` 거짓, `can_move()`도 거짓(공격이 이동도 끝냄)
- [정상] `mark_moved()` 후 `undo_move()` → `moved_this_turn` 거짓, `can_move()` 다시 참
- [정상] `can_rest()`는 행동 전 참, `mark_attacked()` 후 거짓
- [정상] `reset_turn()` 후 다시 `can_move()`·`can_attack()`·`can_rest()` 참
- [정상] `TurnManager.end_turn`에 넘긴 부대의 `moved_this_turn`이 참이면 호출 후 거짓으로 리셋

## 관련

- 부대 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용. 부대는 서로의 칸을 통과·점유할 수 없다([유닛 점유](../features/selection-and-movement.md)).
- 턴당 1회 이동 제한(`moved_this_turn`/`can_move`/`mark_moved`/`reset_turn`)은 [Turn](../features/turn.md)에서 사용.
- 병력·전투 파워는 클래스 기반([유닛 카탈로그](../data/factions.md)·[UnitTypes](../features/lang-battle.md)). 개별 병사 스탯은 없다.
