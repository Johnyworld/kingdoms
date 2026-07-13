# Data: Siege Units (공성 유닛 카탈로그)

> 스크립트: `scenes/siege/siege_types.gd` (`class_name SiegeTypes`)

부대([Party](../entities/Party.md))에 실리는 **공성 유닛**(투석기·충차·공성탑 …)의 카탈로그. [BuildingTypes](buildings.md)·[UnitTypes](units.md)·[ItemTypes](items.md)와 같은 "GDScript 카탈로그" 패턴이다. 일반 병사([Human](../entities/Human.md))와 달리 인구를 차지하지 않는 재사용 장비 유닛이며, 동작 정의는 [Siege Engines](../features/siege-engines.md)에 있다.

**이 슬라이스(5a-1)는 유닛 모델·획득·이동에 쓰는 필드만 수록**한다. 「투석」 사거리·데미지·명중률 등 공격 관련 필드는 후속 슬라이스(5a-2·5b)에서 추가한다.

## 상수

| 상수 | 값 | 설명 |
| --- | --- | --- |
| `CATAPULT` | `"catapult"` | 투석기 종류 id |
| `CREW_MIN` | `4` | 공성 유닛을 실은 부대가 **이동**하는 데 필요한 최소 사람(멤버) 수. 미만이면 이동력 0(견인 불가) → [Party 견인 이동](../entities/Party.md) |

## 카탈로그 (`CATALOG`)

종류 id → 스펙. 슬라이스 5a-1 수록 필드: `name`(이름), `movement`(견인 이동력), `produce_gold`(생산 금), `produce_cost`(생산 자재).

| id | 이름(`name`) | 견인 이동력(`movement`) | 생산 금(`produce_gold`) | 생산 자재(`produce_cost`) |
| --- | --- | --- | --- | --- |
| `catapult` | 투석기 | 2 | 40 | 목재 30 · 석재 20 |

- **견인 이동력** — 이 유닛을 실은 부대의 이동력 상한(느림). 부대 이동력 = `min(사람 기준 이동력, 견인 이동력)`, 단 사람이 `CREW_MIN` 미만이면 0. → [Party](../entities/Party.md)
- **생산 금·자재** — [공성 작업장](../features/siege-engines.md#획득--공성-작업장에서-생산)에서 [투석기 생산] 시 영지가 지불하는 비용. **인구는 소비하지 않는다.**
- 값은 기획 초안값(밸런스 조정 대상).

## 헬퍼

- `get_type(id) -> Dictionary` — 종류 스펙(없는 id면 빈 Dictionary).
- `type_name(id) -> String` — 이름(없는 id면 `""`).
- `movement(id) -> int` — 견인 이동력(없는 id면 `0`).
- `produce_gold(id) -> int` — 생산 금(없는 id면 `0`).
- `produce_cost(id) -> Dictionary` — 생산 자재(없는 id면 `{}`).
- `produce_full_cost(id) -> Dictionary` — 생산 총비용(금 + 자재)을 한 Dictionary로(금이 앞). 없는 id면 `{}`. [투석기 생산] 버튼 표시·활성 판정과 지불이 공유하는 단일 출처.

## 미수록 / 미구현

- 「투석」 사거리(5)·발사 수(1턴 1발)·성벽/유닛 데미지·유닛 명중률·최대 표적 수(5) — 5a-2·5b에서 추가.
- 공성 유닛 내구도·조작 인원 개별 배정 — 후속.
- 충차·공성탑 — 종류만 후속 추가 예정(같은 모델).

## 테스트 시나리오

`test/unit/test_siege_types.gd`. → [Siege Engines 테스트 시나리오](../features/siege-engines.md#테스트-시나리오)

- [정상] `CATAPULT == "catapult"`, `CREW_MIN == 4`
- [정상] `type_name("catapult") == "투석기"`, `movement("catapult") == 2`, `produce_gold("catapult") == 40`, `produce_cost("catapult") == {"목재":30, "석재":20}`
- [정상] `produce_full_cost("catapult") == {"금":40, "목재":30, "석재":20}`(금+자재 통합)
- [경계] 없는 id → `type_name` `""`, `movement` `0`, `produce_gold` `0`, `produce_cost` `{}`, `produce_full_cost` `{}`

## 관련

- [Siege Engines (공성병기)](../features/siege-engines.md) — 동작 정의. [Party](../entities/Party.md) — `siege_units`·견인 이동. [Buildings](buildings.md) — 공성 작업장.
