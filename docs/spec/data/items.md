# Data: Items (아이템 — 무기·방어구)

> 스크립트: `scenes/item/item_types.gd` (`class_name ItemTypes`)

전투에 쓰이는 **무기·방어구 카탈로그**와 **상성표**. `BuildingTypes`·`Terrain`·`UnitTypes`와 같은 "GDScript 카탈로그" 패턴이다.
기획 원본 `docs/table/아이템/무기.md`·`방어구.md`에서 **전투에 쓰는 필드만** 옮긴 **부분집합**이다(무게·공격거리·근접거리·생산비용·가치·부위 등은 미수록 — 관련 기능이 생길 때 추가).

## 무기 (`ItemTypes.WEAPONS`)

`{id: {name, attack, damage_type}}`. `damage_type` = `참격|자돌|타격|원거리|마법`([방어구 상성](#상성표)에 사용).

| id | 이름 | 공격력 | 데미지 타입 |
| --- | --- | --- | --- |
| `sword` | 검 | 14 | 참격 |
| `longsword` | 장검 | 18 | 참격 |
| `scimitar` | 곡도 | 15 | 참격 |
| `battleaxe` | 전투도끼 | 16 | 참격 |
| `spear` | 장창 | 15 | 자돌 |
| `mace` | 모닝스타 | 19 | 타격 |
| `bow` | 단궁 | 12 | 원거리 |
| `wand` | 완드 | 8 | 마법 |

## 방어구 (`ItemTypes.ARMORS`)

`{id: {name, defense, armor_class}}`. `armor_class` = `천|가죽|사슬|판금`. 부위(머리·몸통·팔·다리)는 미수록 — 유닛은 방어구 id 목록을 들고 DF는 그 합, 상성 분류는 방어력이 가장 큰 조각의 분류로 대표한다.

| id | 이름 | 방어력 | 분류 |
| --- | --- | --- | --- |
| `cloth_hood` | 두건 | 2 | 천 |
| `robe` | 로브 | 4 | 천 |
| `leather_helm` | 가죽 투구 | 4 | 가죽 |
| `leather_armor` | 가죽 갑옷 | 8 | 가죽 |
| `leather_gloves` | 가죽 장갑 | 2 | 가죽 |
| `leather_greaves` | 가죽 각반 | 3 | 가죽 |
| `chain_coif` | 사슬 코이프 | 6 | 사슬 |
| `chain_mail` | 사슬 갑옷 | 14 | 사슬 |

## 상성표 (`ItemTypes.AFFINITY`)

받는 피해에 곱하는 배율 `AFFINITY[방어구 분류][데미지 타입]`(1.0 = 기본). 기획 원본과 동일.

| 분류 | 참격 | 자돌 | 타격 | 원거리 | 마법 |
| --- | --- | --- | --- | --- | --- |
| 천 | 1.2 | 1.2 | 1.0 | 1.2 | 0.6 |
| 가죽 | 0.9 | 1.0 | 1.1 | 0.9 | 1.0 |
| 사슬 | 0.7 | 0.8 | 1.1 | 0.8 | 1.1 |
| 판금 | 0.5 | 0.6 | 0.9 | 0.6 | 1.3 |

## 헬퍼

- `weapon_attack(id) -> int` / `weapon_damage_type(id) -> String` / `weapon_name(id) -> String` — 없는(빈) id면 `0` / `""` / `""`.
- `armor_defense(id) -> int` / `armor_class(id) -> String` — 없는 id면 `0` / `""`.
- `total_defense(ids: Array) -> int` — 방어구 id 목록의 방어력 합.
- `armor_class_of(ids: Array) -> String` — 방어력이 가장 큰 조각의 분류(비면 `""`). 상성 판정의 대표 분류.
- `affinity(armor_class, damage_type) -> float` — 상성 배율. 분류/타입이 표에 없으면 `1.0`.

## 미수록 / 미구현

- 방패·무게·공격거리·근접거리·생산비용·가치·부위·직업 — 관련 기능(방패 막기, 무게 회피보정, 원거리, 생산) 도입 시 추가.
- 수치는 기획 초안값(밸런스 조정 대상).

## 테스트 시나리오

`test/unit/test_item_types.gd`.

- [정상] `weapon_attack("sword") == 14`, `weapon_damage_type("wand") == "마법"`, `weapon_name("sword") == "검"`
- [예외] 빈/없는 무기 id → `weapon_attack` `0`, `weapon_damage_type` `""`
- [정상] `armor_defense("chain_mail") == 14`, `armor_class("robe") == "천"`
- [정상] `total_defense`는 방어구 id 목록의 방어력 합
- [정상] `armor_class_of`는 방어력이 가장 큰 조각의 분류(예: 가죽 세트 → `가죽`)
- [경계] `armor_class_of([])` → `""`
- [정상] `affinity("판금", "마법") == 1.3`, `affinity("사슬", "참격") == 0.7`
- [예외] 없는 분류/타입 → `affinity` `1.0`

## 관련

- 전투 계산에서의 사용은 [Combat](../features/combat.md), 착용은 [Human](../entities/Human.md).
- 기획 원본: `docs/table/아이템/무기.md`·`방어구.md`.
