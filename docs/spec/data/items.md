# Data: Items (아이템 — 무기·방어구)

> 스크립트: `scenes/item/item_types.gd` (`class_name ItemTypes`)

전투에 쓰이는 **무기·방어구 카탈로그**와 **상성표**. `BuildingTypes`·`Terrain`·`UnitTypes`와 같은 "GDScript 카탈로그" 패턴이다.
기획 원본 `docs/table/아이템/무기.md`·`방어구.md`에서 **전투에 쓰는 필드만** 옮긴 **부분집합**이다(무게·공격거리·근접거리·생산비용·가치·부위 등은 미수록 — 관련 기능이 생길 때 추가).

## 무기 (`ItemTypes.WEAPONS`)

`{id: {name, attack, damage_type, weight, range, reach, attack_speed, throw_range?}}`. `damage_type` = `참격|자돌|타격|원거리|마법`([방어구 상성](#상성표)에 사용). `weight`는 회피 페널티, `range`는 월드맵 공격거리(헥스 거리, [Selection & Movement](../features/selection-and-movement.md)). `reach`(근접거리)·`attack_speed`(공격속도)·`throw_range`는 전투씬([Battle](../features/battle.md))에서 쓴다:
- **`reach`(근접거리)** — 전투씬 근접 공격 개시 거리(원본 무기.md). **클수록 리치가 길어 먼저 사거리에 진입 = 선제 공격**. 맨손 1.0.
- **`attack_speed`(공격속도)** — 1회 공격에 걸리는 초(민첩 0 기준). 낮을수록 빠름. 최종 공격 간격은 민첩으로 단축([Combat](../features/combat.md) `attack_interval`).
- **`throw_range`**(선택, 기본 0) — **던지는 무기**의 전투씬 투척 사거리. 활과 달리 월드맵 `range`는 1이지만 접근 중 이 거리부터 투척한다.

| id | 이름 | 공격력 | 데미지 타입 | 무게 | 공격거리 | 근접거리 | 공격속도 | 투척 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `sword` | 검 | 14 | 참격 | 3 | 1 | 1.2 | 2.0 | — |
| `longsword` | 장검 | 18 | 참격 | 4 | 1 | 1.4 | 2.2 | — |
| `scimitar` | 곡도 | 15 | 참격 | 3 | 1 | 1.1 | 1.8 | — |
| `battleaxe` | 전투도끼 | 16 | 참격 | 4 | 1 | 1.1 | 2.6 | — |
| `spear` | 장창 | 15 | 자돌 | 3 | 1 | 2.0 | 2.4 | — |
| `mace` | 모닝스타 | 19 | 타격 | 5 | 1 | 1.1 | 2.8 | — |
| `javelin` | 투창 | 10 | 원거리 | 2 | 1 | 1.3 | 2.0 | 2 |
| `bow` | 단궁 | 12 | 원거리 | 2 | 3 | 0.7 | 3.3 | — |
| `wand` | 완드 | 8 | 마법 | 1 | 2 | 0.5 | 2.6 | — |

- **활·완드(쏘는 무기)**: 월드맵 `range` ≥ 2 → 원거리 개시. 전투씬에서 제자리 사격.
- **투창(던지는 무기)**: 월드맵 `range` 1(근접 개시) + `throw_range` 2 → 전투씬 접근 중 투척하다 접촉하면 근접무기로 교전. 활과 개념이 다르다. (공격력·데미지타입·근접거리는 원본 무기.md 값, 월드맵 거리만 1로 둠.)
- **공격속도는 원본 무기.md에 없어 신설**한 값이다(밸런스 조정 대상). `근접거리`는 원본 그대로.

## 방어구 (`ItemTypes.ARMORS`)

`{id: {name, defense, armor_class, weight}}`. `armor_class` = `천|가죽|사슬|판금`. 부위(머리·몸통·팔·다리)는 미수록 — 유닛은 방어구 id 목록을 들고 DF는 그 합, 상성 분류는 방어력이 가장 큰 조각의 분류로 대표한다.

| id | 이름 | 방어력 | 분류 | 무게 |
| --- | --- | --- | --- | --- |
| `cloth_hood` | 두건 | 2 | 천 | 1 |
| `robe` | 로브 | 4 | 천 | 2 |
| `leather_helm` | 가죽 투구 | 4 | 가죽 | 2 |
| `leather_armor` | 가죽 갑옷 | 8 | 가죽 | 4 |
| `leather_gloves` | 가죽 장갑 | 2 | 가죽 | 1 |
| `leather_greaves` | 가죽 각반 | 3 | 가죽 | 2 |
| `chain_coif` | 사슬 코이프 | 6 | 사슬 | 3 |
| `chain_mail` | 사슬 갑옷 | 14 | 사슬 | 8 |

## 방패 (`ItemTypes.SHIELDS`)

`{id: {name, defense, block, weight}}`. `defense`는 DF에 합산, `block`은 막기 확률(%), `weight`는 회피 페널티. 유닛은 방패 id 하나(`""`=없음)를 든다. 양손무기 제약은 미수록.

| id | 이름 | 방어력 | 막기(%) | 무게 |
| --- | --- | --- | --- | --- |
| `buckler` | 버클러 | 2 | 15 | 1 |
| `round_shield` | 라운드 실드 | 5 | 25 | 3 |
| `kite_shield` | 카이트 실드 | 8 | 30 | 5 |
| `tower_shield` | 타워 실드 | 12 | 40 | 8 |

## 상성표 (`ItemTypes.AFFINITY`)

받는 피해에 곱하는 배율 `AFFINITY[방어구 분류][데미지 타입]`(1.0 = 기본). 기획 원본과 동일.

| 분류 | 참격 | 자돌 | 타격 | 원거리 | 마법 |
| --- | --- | --- | --- | --- | --- |
| 천 | 1.2 | 1.2 | 1.0 | 1.2 | 0.6 |
| 가죽 | 0.9 | 1.0 | 1.1 | 0.9 | 1.0 |
| 사슬 | 0.7 | 0.8 | 1.1 | 0.8 | 1.1 |
| 판금 | 0.5 | 0.6 | 0.9 | 0.6 | 1.3 |

## 헬퍼

- `weapon_attack(id) -> int` / `weapon_damage_type(id) -> String` / `weapon_name(id) -> String` / `weapon_weight(id) -> int` — 없는(빈) id면 `0` / `""` / `""` / `0`.
- `weapon_range(id) -> int` — 무기 공격거리. **없는(빈) id는 1**(맨손 근접 기본).
- `weapon_throw_range(id) -> int` — 투척 사거리(던지는 무기). 없거나 투척 불가면 `0`.
- `weapon_reach(id) -> float` — 근접거리(리치). 없는(빈) id는 `1.0`(맨손).
- `weapon_attack_speed(id) -> float` — 기본 공격속도(초, 민첩 0). 없는(빈) id는 `2.0`(맨손 기본).

### 다중 무기 (유닛은 무기 2~3개 소지)

유닛([Human](../entities/Human.md))은 무기 id **목록**을 든다(첫 원소 = 주무기). 목록을 받아 상황별 무기를 고르는 헬퍼:

- `primary_weapon(weapons: Array) -> String` — 주무기(목록 첫 원소). 비면 `""`(맨손).
- `ranged_weapon(weapons: Array) -> String` — 목록 중 **공격거리 ≥ 2인 첫 무기**(활·완드 등). 없으면 `""`.
- `throwing_weapon(weapons: Array) -> String` — 목록 중 **`throw_range` > 0인 첫 무기**(투창 등). 없으면 `""`.
- `max_range(weapons: Array) -> int` — 목록 무기 공격거리의 **최대값**(월드맵 공격거리). 비면 `1`(맨손 근접). 투척 무기는 `range` 1이라 월드맵 사거리를 늘리지 않는다.
- `active_weapon(weapons: Array, ranged_mode: bool) -> String` — 전투에서 실제 쓸 무기. `ranged_mode`면 `ranged_weapon`(없으면 `""` → 공격 불가), 아니면 `primary_weapon`.
- `armor_defense(id) -> int` / `armor_class(id) -> String` / `armor_name(id) -> String` / `armor_weight(id) -> int` — 없는 id면 `0` / `""` / `""` / `0`.
- `shield_defense(id) -> int` / `shield_block(id) -> int` / `shield_name(id) -> String` / `shield_weight(id) -> int` — 없는(빈) id면 `0` / `0` / `""` / `0`.
- `total_defense(ids: Array) -> int` — 방어구 id 목록의 방어력 합.
- `armor_class_of(ids: Array) -> String` — 방어력이 가장 큰 조각의 분류(비면 `""`). 상성 판정의 대표 분류.
- `affinity(armor_class, damage_type) -> float` — 상성 배율. 분류/타입이 표에 없으면 `1.0`.

## 미수록 / 미구현

- 공격거리·근접거리·생산비용·가치·부위·직업 — 관련 기능(원거리, 생산) 도입 시 추가.
- 방패의 양손무기 배타 제약은 미구현.
- 수치는 기획 초안값(밸런스 조정 대상).

## 테스트 시나리오

`test/unit/test_item_types.gd`.

- [정상] `weapon_attack("sword") == 14`, `weapon_damage_type("wand") == "마법"`, `weapon_name("sword") == "검"`, `weapon_weight("sword") == 3`
- [정상] `weapon_range("bow") == 3`, `weapon_range("sword") == 1`; [경계] 빈 무기 → `weapon_range("") == 1`(맨손 근접)
- [정상] `weapon_range("javelin") == 1`(투창은 월드맵 근접), `weapon_throw_range("javelin") == 2`(투척 사거리); [경계] `weapon_throw_range("sword") == 0`(투척 불가)
- [정상] `weapon_reach("spear") == 2.0`(가장 김), `weapon_reach("sword") == 1.2`; [경계] `weapon_reach("") == 1.0`(맨손)
- [정상] `weapon_attack_speed("sword") == 2.0`, `weapon_attack_speed("bow") == 3.3`; [경계] `weapon_attack_speed("") == 2.0`(맨손 기본)
- [정상] `throwing_weapon(["scimitar","javelin"]) == "javelin"`; [경계] `throwing_weapon(["sword"]) == ""`
- [정상] `primary_weapon(["sword","bow"]) == "sword"`; [경계] `primary_weapon([]) == ""`
- [정상] `ranged_weapon(["sword","bow"]) == "bow"`(원거리 무기 선택); [경계] `ranged_weapon(["sword"]) == ""`(원거리 없음)
- [정상] `max_range(["sword","bow"]) == 3`(최대); [경계] `max_range([]) == 1`(맨손)
- [정상] `active_weapon(["sword","bow"], false) == "sword"`(근접→주무기), `active_weapon(["sword","bow"], true) == "bow"`(원거리→활); `active_weapon(["sword"], true) == ""`(원거리 무기 없음)
- [정상] `armor_weight("chain_mail") == 8`, `shield_weight("tower_shield") == 8`; 없는 id면 무게 0
- [예외] 빈/없는 무기 id → `weapon_attack` `0`, `weapon_damage_type` `""`
- [정상] `armor_defense("chain_mail") == 14`, `armor_class("robe") == "천"`, `armor_name("robe") == "로브"`
- [정상] `total_defense`는 방어구 id 목록의 방어력 합
- [정상] `shield_defense("tower_shield") == 12`, `shield_block("tower_shield") == 40`, `shield_name("buckler") == "버클러"`
- [예외] 빈/없는 방패 id → `shield_defense`·`shield_block` `0`, `shield_name` `""`
- [정상] `armor_class_of`는 방어력이 가장 큰 조각의 분류(예: 가죽 세트 → `가죽`)
- [경계] `armor_class_of([])` → `""`
- [정상] `affinity("판금", "마법") == 1.3`, `affinity("사슬", "참격") == 0.7`
- [예외] 없는 분류/타입 → `affinity` `1.0`

## 관련

- 전투 계산에서의 사용은 [Combat](../features/combat.md), 착용은 [Human](../entities/Human.md).
- 기획 원본: `docs/table/아이템/무기.md`·`방어구.md`.
