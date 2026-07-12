# Entity: Territory (영지)

> 스크립트: `scenes/territory/territory.gd` (`class_name Territory extends RefCounted`)

세력이 보유하는 **영지**. 예: "파리". 하나의 [세력](Faction.md)은 여러 영지를 거느리고,
하나의 영지는 **중심 캠프 + 그 안의 건물들**을 가지며 **모든 자원(인구 포함)을 보유**한다.

구조: **[세력](Faction.md) → 영지(Territory) → [건물](Building.md)**.
캠프를 건설하면 새 영지가 생기고(**건설 로직은 Phase 2**), 영지의 초기 자원은 캠프 종류의
[카탈로그](../data/buildings.md) `resources`에서 복사된다.

시각 요소가 없는 **순수 데이터 엔티티**라 씬(`.tscn`) 없이 스크립트만 둔다.

## Properties

| 속성 | 변수 | 타입 | 초기값 | 설명 |
| --- | --- | --- | --- | --- |
| 이름 | `name` | `String` | `""` | 영지 이름 (예: "파리") |
| 보유 자원 | `resources` | `Dictionary` | `{}` | **모든 자원**(인구·밀·빵·나무·목재·철·철괴·금). 삽입 순서 = 메뉴 표시 순서. `금`은 [상거래](../features/trade.md)로 오가는 화폐(금고) |
| 소속 세력 | `faction` | `Faction` | `null` | 이 영지를 보유한 세력. `Faction.add_territory`로 연결 |
| 소속 건물 | `buildings` | `Array` | `[]` | 이 영지에 속한 [건물](Building.md) 목록(중심 캠프 + 그 안의 건물들) |
| 노획 장비 | `loot_items` | `Array` | `[]` | 영지가 소유한 노획 장비 아이템 id 목록([수비대 노획](../features/raid.md#수비대-노획)으로 귀속). 중복 허용. 활용(판매)은 `미구현`(다음) |

## 동작

- `_init(name := "", resources := {})` — 이름과 자원(복사본 권장)을 받아 생성. `buildings`는 빈 배열로 시작.
- `add_building(building) -> void` — 건물을 `buildings`에 추가하고 **동시에** `building.territory = self`로 설정한다(양방향). 이미 포함된 건물은 중복 추가하지 않는다.
- `remove_building(building) -> void` — 건물을 `buildings`에서 제거하고, `building.territory`가 이 영지면 `null`로 되돌린다(양방향 해제). 없으면 no-op. [캠프 점령](../features/camp-capture.md) 파괴 시 영지에서 캠프를 떼어낼 때 쓴다.
- `demolish(building) -> void` — [철거](../features/building-info.md#철거). 보유한 건물이면 `remove_building`으로 떼어낸 뒤 ① 그 건물의 `refund_on_demolish()`([Building](Building.md) — 완성은 salvage, **건설 중은 `build_cost` 진행도 비례**)를 자원에 더하고 ② **`required_pop()`만큼 `인구`를 되돌려준다**(고용 해제, 건설 중이어도 전액). `resources[자원] += 수량`, 없던 키는 새로 생성. 보유하지 않은 건물이면 no-op(환급·인구 반환 없음).
- `collect_income() -> void` — [턴](../features/turn.md) 종료 시 호출. 소속 건물들의 `production()`(자원명→수량)을 순회하며 `resources[자원] += 수량`. 영지에 없던 자원 키는 새로 만들어 더한다. 생산이 없는 건물(캠프 등)이나 **건설 중 건물**(생산 0)은 자원을 바꾸지 않는다.
- `can_afford(cost: Dictionary) -> bool` — `cost`의 모든 자원에 대해 `resources.get(자원, 0) >= 수량`이면 참. 빈 `cost`는 항상 참. 건설 비용([`build_cost`](../data/buildings.md)) 지불 가능 여부 확인용.
- `spend(cost: Dictionary) -> void` — `cost`의 각 자원을 `resources`에서 뺀다. 음수 방지는 하지 않으므로 호출 전 `can_afford`로 확인한다. [건축](../features/building.md) 시 자원 차감.
- `build_pay(type_id: String) -> void` — 그 종류를 지을 때의 비용을 한 번에 지불한다: `build_cost` 자재 차감(`spend`) + **[필요인원](../data/buildings.md#필요인원-required_pop)만큼 `인구` 차감**(고용). 호출 전 [`BuildPlanner.can_build`](../features/building.md#필요인원-게이트)로 지불 가능 여부를 확인한다(음수 방지 안 함).
- `advance_construction() -> void` — [턴](../features/turn.md) 종료 시 호출. 소속 건물들의 `advance_construction()`을 불러 건설 중 건물을 1턴씩 진행한다.
- `receive_loot(party) -> void` — 부대의 노획물을 이 영지로 흡수한다([수비대 노획](../features/raid.md#수비대-노획)). `party.cargo`(자원)를 `resources`에 더하고(없던 키 생성), `party.loot_items`(장비)를 이 영지 `loot_items`에 append한다. 옮긴 뒤 부대의 `cargo`·`loot_items`는 비운다(부대는 곧 제거되는 임시 수비대).

### 인구 상한(`population_cap`)

- `population_cap() -> int` — 소속 **완성** 건물들의 `pop_cap()`([Building](Building.md)) 합. 영지가 담을 수 있는 최대 인구. 캠프가 기본 10, 집이 +2씩 올린다. 건설 중 건물은 기여하지 않는다(`Building.pop_cap()`이 0).
- `grow_population() -> void` — [턴](../features/turn.md) 종료 시 호출. **현재 인구(`resources["인구"]`)가 상한 미만이면 +1**(상한에서 멈춤). 현재 인구가 상한 이상이면 아무 일도 하지 않는다(초과분을 강제로 줄이지는 않음 — 집을 철거해 상한이 내려간 경우 등).

## 테스트 시나리오

`test/unit/test_territory.gd`.

- [정상] `_init("파리", {인구:10, ...})` 후 `name == "파리"`, `resources`가 넘긴 값과 일치
- [정상] 생성 직후 `buildings`는 빈 배열, `faction`은 `null`
- [정상] `add_building(b)` 후 `buildings`에 `b`가 들어가고 `b.territory`가 이 영지를 가리킨다(양방향)
- [경계] 같은 건물을 두 번 `add_building` 해도 `buildings` 크기는 1 (중복 방지)
- [정상] `remove_building(b)` 후 `buildings`에서 빠지고 `b.territory == null`
- [경계] 보유하지 않은 건물을 `remove_building` → no-op
- [정상] 농장 건물을 편입한 영지의 `collect_income()` 후 `resources["밀"]`가 생산량(1)만큼 증가 (`test/unit/test_turn.gd`)
- [정상] 캠프만 가진 영지의 `collect_income()`은 자원 변화 없음 (`test/unit/test_turn.gd`)
- [정상] `can_afford({목재:5})` — 충분하면 참, 부족하면 거짓
- [경계] `can_afford({})`는 항상 참; 보유 없는 자원을 요구하면 거짓
- [정상] `spend({목재:5, 밀:5})` 후 해당 자원이 정확히 그만큼 감소
- [정상] 캠프만 가진 영지 `population_cap() == 10`; 완성 집 1채 편입 시 `12`, 2채면 `14`
- [경계] **건설 중** 집은 상한에 기여 안 함(캠프+건설중집 → `10`)
- [정상] `grow_population()` — 인구 10, 상한 12 → 11로 증가; 다시 호출 → 12; 상한 도달 후 재호출 → 12 유지(넘지 않음)
- [경계] 인구가 상한 이상(예: 상한 10, 인구 10)이면 `grow_population()`은 변화 없음
- [정상] 농장을 편입한 영지 `demolish(farm)` → `buildings`에서 빠지고 `farm.territory == null`; 자재 환급 `목재+1` + 노동력 반환 `인구+2`
- [정상] `demolish`는 없던 자원 키도 환급으로 새로 만든다
- [경계] 보유하지 않은 건물 `demolish` → no-op(자원 변화 없음)
- [정상] `build_pay("farm")` → `build_cost`(목재5·밀5) 차감 + `인구 -= 2`(고용)
- [정상] `build_pay("quarry")` → 목재10 차감 + `인구 -= 1`(벌목소·채석장의 신규 노동력)
- [정상] 생성 직후 `loot_items`는 빈 배열
- [정상] `receive_loot`: 부대 화물 목재10·장비 `["sword"]` → 영지 `resources["목재"] += 10`, `loot_items`에 `"sword"`; 부대 `cargo`·`loot_items` 비워짐
- [경계] `receive_loot` 빈 부대(화물·장비 없음) → 영지 변화 없음

## 관련

- 세력↔영지 연결은 [Faction 엔티티](Faction.md)의 `add_territory` 참고.
- 영지의 자원·이름·세력은 [Camp Menu](../features/camp-menu.md)에 표시된다.
- 영지 초기 자원의 출처(캠프 카탈로그)는 [buildings.md](../data/buildings.md) 참고.
