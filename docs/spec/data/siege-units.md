# Data: Siege Units (공성 유닛 카탈로그)

> 스크립트: `scenes/siege/siege_types.gd` (`class_name SiegeTypes`)

부대([Party](../entities/Party.md))에 실리는 **공성 유닛**(투석기·충차·공성탑 …)의 카탈로그. [BuildingTypes](buildings.md)·[UnitTypes](units.md)·[ItemTypes](items.md)와 같은 "GDScript 카탈로그" 패턴이다. 일반 병사([Human](../entities/Human.md))와 달리 인구를 차지하지 않는 재사용 장비 유닛이며, 동작 정의는 [Siege Engines](../features/siege-engines.md)에 있다.

유닛 모델·획득·이동(5a-1) 필드에 더해, **「투석」 사거리(`fire_range`)·공격력(`attack`)·내구도(`hit_points`)**를 수록한다. 성벽·유닛 투석 피해는 `attack`에 ±40% 랜덤을 준 [`Siege.rolled_damage`](../features/wall.md#성벽-내구도-buildingwall_hp--siege)(30~70), 유닛 투석의 명중률·최대 표적 수는 [`Siege` 상수](../features/siege-engines.md#유닛-투석-적-부대-폭격).

## 상수

| 상수 | 값 | 설명 |
| --- | --- | --- |
| `CATAPULT` | `"catapult"` | 투석기 종류 id |
| `BATTERING_RAM` | `"battering_ram"` | 충차 종류 id |
| `CREW_MIN` | `4` | 공성 유닛을 실은 부대가 **이동**하는 데 필요한 최소 사람(멤버) 수. 미만이면 이동력 0(견인 불가) → [Party 견인 이동](../entities/Party.md) |

## 카탈로그 (`CATALOG`)

종류 id → 스펙. 수록 필드: `name`(이름), `movement`(견인 이동력), `min_range`·`fire_range`(투석/타격 사거리 밴드), `attack`(공격력), `hit_points`(내구도), `produce_gold`(생산 금), `produce_cost`(생산 자재), `targets`(타격 가능 표적 종류 리스트).

| id | 이름(`name`) | 견인 이동력(`movement`) | 최소 사거리(`min_range`) | 최대 사거리(`fire_range`) | 공격력(`attack`) | 내구도(`hit_points`) | 생산 금(`produce_gold`) | 생산 자재(`produce_cost`) | 표적(`targets`) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `catapult` | 투석기 | 2 | 4 | 5 | 50 | 60 | 40 | 목재 30 · 석재 20 | `["unit","wall","gate"]` |
| `battering_ram` | 충차 | 1 | 1 | 1 | 90 | 40 | 50 | 목재 40 · 석재 10 | `["gate"]` |

- **견인 이동력** — 이 유닛을 실은 부대의 이동력 상한(느림). 부대 이동력 = `min(사람 기준 이동력, 견인 이동력)`, 단 사람이 `CREW_MIN` 미만이면 0. → [Party](../entities/Party.md)
- **투석 사거리 밴드(`min_range`~`fire_range`)** — [투석](../features/siege-engines.md#투석-공성-성벽) 가능한 헥스 거리 범위(투석기 **4~5**). 너무 가까우면(< `min_range`) 못 쏜다(포물선 공성이라 근거리 불가). 부대 셀에서 표적까지 거리가 이 밴드 안이어야 투석 가능.
- **공격력** — 투석 1발의 기준 피해. **무기 기본 공격력(검 14~모닝스타 19)보다 크다** — 성벽뿐 아니라 일반 유닛도 위협하는 공성 화력. 실제 피해는 여기에 ±40% 랜덤을 준다([`Siege.rolled_damage`](../features/wall.md#성벽-내구도-buildingwall_hp--siege) → 30~70·평균 50). 성벽·[유닛 투석](../features/siege-engines.md#유닛-투석-적-부대-폭격) 모두 이 피해를 쓴다.
- **내구도(`hit_points`)** — 공성 유닛 자체의 HP. [SiegeUnit](../features/siege-engines.md#공성-유닛-모델-siegeunit--partysiege_units)은 생성 시 이 값을 현재 HP·최대 HP로 삼는다. 투석기(60)는 원거리라 잘 안 맞지만, **충차(40)는 근접이라 수비 [반격](../features/siege-engines.md#충차-근접-대성벽-공성)에 노출**돼 쉽게 깎인다.
- **표적(`targets`)** — 타격할 수 있는 대상 종류. `"unit"`(적 부대)·`"wall"`(성벽)·`"gate"`([성문](../features/wall.md#성문-gate))의 부분집합. **투석기** = `["unit","wall","gate"]`(전부), **충차** = `["gate"]`(성문 전용 — 성벽·유닛 못 침). [BOMBARD 표적 선정](../features/siege-engines.md#충차-근접-성문-파쇄)이 이 리스트로 표적을 거른다.
- **생산 금·자재** — [공성 작업장](../features/siege-engines.md#획득--공성-작업장에서-생산)에서 생산 시 영지가 지불하는 비용. **인구는 소비하지 않는다.**
- **충차 vs 투석기** — 충차는 **근접(밴드 1)·성문 전용·고화력(90)·저내구(40)**. 성문에 붙어야 해서 수비 사거리에 노출되는 대신 [성문](../features/wall.md#성문-gate)을 빠르게(≈2발) 부순다. 투석기는 원거리(4~5)에서 안전하게 성벽·성문·유닛을 겸해 때린다.
- 값은 기획 초안값(밸런스 조정 대상).

## 헬퍼

- `get_type(id) -> Dictionary` — 종류 스펙(없는 id면 빈 Dictionary).
- `type_name(id) -> String` — 이름(없는 id면 `""`).
- `movement(id) -> int` — 견인 이동력(없는 id면 `0`).
- `min_range(id) -> int` — 최소 투석 사거리(없는 id면 `0`).
- `fire_range(id) -> int` — 최대 투석 사거리(없는 id면 `0`).
- `attack(id) -> int` — 공격력(없는 id면 `0`).
- `max_hp(id) -> int` — 내구도(카탈로그 `hit_points`, 없는 id면 `0`).
- `targets(id) -> Array` — 타격 가능 표적 종류 리스트(카탈로그 `targets`, 없는 id면 `[]`).
- `can_target(id, kind) -> bool` — 그 종류(`"unit"`/`"wall"`/`"gate"`)를 타격할 수 있는지(`targets`에 포함 여부).
- `produce_gold(id) -> int` — 생산 금(없는 id면 `0`).
- `produce_cost(id) -> Dictionary` — 생산 자재(없는 id면 `{}`).
- `produce_full_cost(id) -> Dictionary` — 생산 총비용(금 + 자재)을 한 Dictionary로(금이 앞). 없는 id면 `{}`. [투석기 생산] 버튼 표시·활성 판정과 지불이 공유하는 단일 출처.

## 미수록 / 미구현

- 발사 수(1턴 1발)는 투석이 부대 행동을 종료해 자연 보장(스탯 아님). 유닛 투석 명중률·최대 표적 수는 [`Siege` 상수](../features/siege-engines.md#유닛-투석-적-부대-폭격)(카탈로그 스탯 아님).
- 조작 인원 개별 배정은 후속(현재 `CREW_MIN` 인원수 게이트만).
- **공성탑** — 종류만 후속 추가 예정(같은 모델, 성벽 월담 메커니즘 필요).

## 테스트 시나리오

`test/unit/test_siege_types.gd`. → [Siege Engines 테스트 시나리오](../features/siege-engines.md#테스트-시나리오)

- [정상] `CATAPULT == "catapult"`, `BATTERING_RAM == "battering_ram"`, `CREW_MIN == 4`
- [정상] `type_name("catapult") == "투석기"`, `movement("catapult") == 2`, `min_range("catapult") == 4`, `fire_range("catapult") == 5`, `attack("catapult") == 50`, `max_hp("catapult") == 60`, `produce_gold("catapult") == 40`, `produce_cost("catapult") == {"목재":30, "석재":20}`
- [정상] `produce_full_cost("catapult") == {"금":40, "목재":30, "석재":20}`(금+자재 통합)
- [정상] 충차: `type_name("battering_ram") == "충차"`, `movement == 1`, `min_range == 1`, `fire_range == 1`, `attack == 90`, `max_hp == 40`, `produce_gold == 50`, `produce_cost == {"목재":40, "석재":10}`, `produce_full_cost == {"금":50, "목재":40, "석재":10}`
- [정상] `targets("catapult") == ["unit","wall","gate"]`, `targets("battering_ram") == ["gate"]`
- [정상] `can_target("battering_ram","gate") == true`, `can_target("battering_ram","wall") == false`, `can_target("battering_ram","unit") == false`; `can_target("catapult","wall") == true`
- [경계] 없는 id → `type_name` `""`, `movement`·`min_range`·`fire_range`·`attack`·`max_hp` `0`, `produce_gold` `0`, `produce_cost` `{}`, `produce_full_cost` `{}`, `targets` `[]`, `can_target` `false`

## 관련

- [Siege Engines (공성병기)](../features/siege-engines.md) — 동작 정의. [Party](../entities/Party.md) — `siege_units`·견인 이동. [Buildings](buildings.md) — 공성 작업장.
