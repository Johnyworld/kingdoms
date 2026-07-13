# Feature: Siege Engines / 공성병기 (부대 소속 공성 유닛)

> 스크립트: `scenes/siege/siege_types.gd` (`SiegeTypes` — 공성 유닛 카탈로그) · `scenes/siege/siege_unit.gd` (`SiegeUnit` — 부대에 실리는 공성 유닛 인스턴스) · `scenes/siege/siege.gd` (`Siege` — 성벽 내구도 상수·헬퍼) · `scenes/party/party.gd` (`siege_units`·`has_siege`·견인 이동 규칙) · `scenes/building/building_types.gd` (`siege_workshop` 종류) · `scenes/territory/territory.gd` (`has_completed_building`) · `scenes/camp/camp_menu.gd` (`[투석기 생산]`·`siege_produced`) · `scenes/combat/siege_bombard.gd` (`SiegeBombard` — 성벽 투석 관전 씬) · `scenes/game/game.gd` (`_on_siege_produced`·`_catapult_target_for`·`_bombard_wall`) · `scenes/party/party_info.gd` (공성 유닛 표시)

성벽을 두른 거점을 함락하기 위한 **공성 유닛**(투석기·충차·공성탑 …). 일반 병사([Human](../entities/Human.md))와 달리 **부대에 실리는 재사용 장비 유닛**이다. 인구를 차지하지 않고, 부대의 사람(인구)이 조작한다. 일반 전투에는 참여하지 않으며 「투석」 등 전용 명령으로만 공격한다.

**이 문서는 슬라이스 5a-1(유닛 모델·획득·이동·표시)과 5a-2(성벽 투석·내구도)를 다룬다.** 유닛 대상 폭격(5b)·NPC 공성 AI(5c)는 후속 슬라이스로 `미구현`이다(아래 [로드맵](#공성병기-로드맵)).

## 공성 유닛 모델 (`SiegeUnit` · `Party.siege_units`)

- 부대([Party](../entities/Party.md))는 `members`(사람)와 별개로 **`siege_units: Array`**(공성 유닛 인스턴스 목록)를 가진다.
- 공성 유닛은 **인구 비소모** — `members`에 들지 않으므로 부대 시야(`vision()`)·공격거리(`attack_range()`)·전투(사상자·[Battle](battle.md))에 **영향을 주지 않는다**. 부대의 사람이 조작한다는 설정만 있고, 별도 조작 인원 배정 로직은 없다.
- `SiegeUnit`(RefCounted)은 종류 id 하나를 들고 카탈로그([SiegeTypes](../data/siege-units.md))에서 스펙을 읽는다:
  - `type_id: String` — 기본 `"catapult"`.
  - `unit_name() -> String` — 카탈로그 이름(예: `"투석기"`).
  - `movement() -> int` — 견인 이동력(투석기 `2`).
  - `fire_range() -> int` — [투석](#투석-공성-성벽) 사거리(투석기 `5`).
  - `attack() -> int` — 공격력(투석기 `50` — 무기보다 큰 공성 화력). 투석 피해의 기준값.
  - `max_hp() -> int` — 최대 내구도(투석기 `60`). `hit_points`(현재 내구도)는 생성 시 `max_hp()`로 채운다. **깎는 공격원은 아직 없다**(방어 요격 5d·`미구현`).
- **재사용** — 소모품이 아니다. 생성 후 부대에 계속 남는다(전투 사상·거점 상실 시의 소실 처리는 후속 슬라이스에서 다룬다).
- 충차·공성탑도 같은 모델을 쓸 예정이다(카탈로그에 종류만 추가).

## 획득 — 공성 작업장에서 생산 (`siege_workshop` · `[투석기 생산]`)

투석기는 **전용 건물 「공성 작업장」**([buildings](../data/buildings.md))을 지은 영지에서만 생산한다.

- **공성 작업장(`siege_workshop`)**: 소형(footprint 1) 생산 건물. 선행 `town_hall`. 기존 [건축](building.md) 흐름으로 짓는다(`BUILDABLE_IDS`에 포함). 턴당 생산(`production`)은 없다 — 투석기 생산은 아래 수동 행동으로 한다.
- **[투석기 생산] 버튼** (`camp_menu._siege_btn` — [성벽 건설](wall.md) 버튼과 같은 전용 버튼 패턴):
  - **표시 조건**: 연 건물이 **거점**이고 그 **주둔 부대(`_party`)가 있으며**, 그 거점의 **영지에 완성된 공성 작업장이 있을 때**(`Territory.has_completed_building("siege_workshop")`). 아니면 숨김.
  - **텍스트**: `"투석기  <비용>"`(예: `"투석기  금 40 · 목재 30 · 석재 20"`, `_format_cost`가 `"금 40"`처럼 단위-값 순으로 낸다). 비용 = `SiegeTypes.produce_full_cost`(생산 금 + 생산 자재).
  - **활성**: 영지가 금·자재를 감당하면 활성, 부족하면 비활성. **인구는 소비하지 않는다**(비소모 유닛).
  - 누르면 `siege_produced(building)` 방출 → `game.gd._on_siege_produced`: 영지 금·자재 차감 + 그 **주둔 부대 `siege_units`에 투석기 1대 추가** + 부대 일람·정보 갱신. 갱신된 정보로 캠프 메뉴 재오픈([병사 구매](trade.md)와 같은 패턴).
- 투석기는 주둔 부대에 실린다. 출격하려면 [주둔 종료](garrison.md) 후 이동하는데, **견인 인력(4명) 규칙**(아래)을 만족해야 움직인다.

## 견인 이동 규칙 (`Party.movement`)

공성 유닛을 실은 부대는 느리고, 끌 인력이 있어야 움직인다.

- **견인 속도**: 부대가 공성 유닛을 실으면(`has_siege()`) 그 부대 이동력은 **공성 유닛 견인 이동력(가장 느린 것, 투석기 `2`)으로 상한**된다. 즉 `min(사람 기준 이동력, 견인 속도)`.
- **인력 게이트**: 공성 유닛을 실은 부대의 **사람(`members`) 수가 `SiegeTypes.CREW_MIN`(4) 미만이면 이동력 0**(끌 인력 부족 → 정지). 4명 이상이어야 견인 이동력을 얻는다.
- 공성 유닛이 없으면 규칙은 적용되지 않고 기존 이동력(사람 최소 − 과적)을 그대로 쓴다.
- 과적([overload](../entities/Party.md))으로 이미 이동력이 견인 속도보다 낮으면 그 낮은 값이 유지된다(`min`).

정리(공성 유닛 있는 부대):

| 사람 수 | 이동력 |
| --- | --- |
| ≤ 3 | `0` (견인 불가) |
| ≥ 4 | `min(사람 기준 이동력, 견인 속도 2)` |

## 정보 표시 (`party_info`)

- [부대 정보 패널](party-info.md)은 멤버 목록 아래에 **「공성 유닛」 줄**을 추가한다 — 실은 공성 유닛 이름·내구도를 나열(예: `"공성 유닛: 투석기 (HP 60/60)"`). 공성 유닛이 없으면 그 줄은 없다.
- 견인 인력이 부족(사람 ≤ 3 + 공성 유닛 보유)해 이동력이 0이면 그 사실을 덧붙여(예: `"(견인 인력 부족 — 이동 불가)"`) 이동력 0의 이유를 알린다.
- 요약 줄의 `이동력`은 이미 견인 규칙이 반영된 `movement()` 값이라 별도 처리는 없다.

## 투석 공성 (성벽) — `[투석]` · `SiegeBombard`

투석기를 실은 부대는 **성벽 있는 적 거점**을 원거리에서 「투석」해 [성벽 내구도](wall.md#성벽-내구도-buildingwall_hp--siege)를 깎고, 0이 되면 성벽을 붕괴시켜 함락 경로를 연다. (유닛 대상 투석은 5b, `미구현`.)

### 대상·사거리 (`game.gd._catapult_target_for`)

- 부대 셀에서 [투석 사거리](../data/siege-units.md)(투석기 `fire_range` = 5) 안(`HexGrid.cells_within` 반경 디스크)에 footprint가 걸치는 **성벽 있는 적 세력 거점**이 대상이다.
- 사거리 안에 그런 거점이 여럿이면 **가장 가까운 것**(중심까지 헥스 거리 최소)을 자동 대상으로 삼는다. 별도 표적 선택 UI는 없다(후속).
- 없으면 `null` — `[투석]` 행동은 뜨지 않는다.

### 행동 (`[투석]` · `party_action_menu`)

- 조건: 아군 부대가 **공성 유닛을 실었고**(`has_siege()`) **이번 턴 미행동**(`can_attack()`)이며 위 [대상](#대상사거리-gamegd_catapult_target_for)이 있으면 [행동 메뉴](party-action-menu.md)에 **`[투석]`**(`can_bombard`, `{id="catapult"}`).
- 선택 → `game.gd._bombard_wall(party)`: 대상 거점에 [투석 관전 씬](#관전-씬-siegebombard)을 띄우고(await), 성벽에 **`Siege.rolled_damage(투석기 attack 50, rng)`**(40~60·평균 50, [랜덤](wall.md#성벽-내구도-buildingwall_hp--siege)) 피해. **투석은 그 부대 행동 종료**(`mark_attacked`) → 자연히 **1턴 1발**.
- **붕괴 처리**: `Siege.wall_broken(building.wall_hp)`면 성벽을 무너뜨린다(`wall_level = 0`·`wall_hp = 0`, 그 거점 [사다리 제거](wall.md#통로-돌파-breach), 재그리기, 토스트). 이후 `is_walled() == false`라 [기존 이동/점령/공격](wall.md#성벽-내구도-buildingwall_hp--siege)이 열린다. 안 부서졌으면 `wall_hp`만 줄고 [맵 표시](wall.md#성벽-내구도-buildingwall_hp--siege)(성벽 링 색)가 갱신된다.

### 관전 씬 (`SiegeBombard`)

`battle.gd`(두 부대 교전)와 별개인 **성벽 전용 경량 관전 오버레이**(신규, `scenes/combat/siege_bombard.gd`). 방어 멤버가 없는 성벽을 대상으로 하므로 기존 전투 씬을 개조하지 않는다.

- `start(party, building, from_hp, damage)` — 화면을 어둡게 덮고, 좌측에 투석기 토큰(부대 색), 우측에 **성벽 표적 + 내구도 바**(`from_hp` → `from_hp − damage`)를 둔다. 투사체가 포물선으로 날아가 착탄하면 바가 줄고, 짧은 흔들림 뒤 `finished`를 방출한다(관전 전용, 입력 잠금).
- 판정은 씬이 하지 않는다 — 실제 `wall_hp` 반영·붕괴는 `game.gd`가 씬 종료 후 처리한다(씬은 연출만).

## 이번 슬라이스 제외 (미구현)

- **유닛 대상 투석**(적 부대, 최대 5명·유닛별 명중) — 5b(이때 두 부대 전투 씬 재사용).
- **NPC 공성 AI**(NPC의 작업장 건설·투석기 생산·투석 운용) — 5c.
- **다중 표적 선택 UI**(사거리 안 여러 성벽 중 선택) — 자동 최근접으로 대체, 후속.
- **투석기 여러 대 스택**(부대에 2대 이상이어도 1턴 1발·`siege_attack()`의 가장 센 투석기 1발만) — 후속.
- **맵 토큰의 공성 유닛 표시**(투석기 마커)·공성 유닛 내구도·전투 사상/거점 상실 시 공성 유닛 소실 처리 — 후속.
- 조작 인원 개별 배정·방어자 요격/투석기 파괴(5d) — 후속.

## 공성병기 로드맵

- **5a-1 유닛 모델** — (이 문서) 투석기 획득·부대 편입(인구 비소모)·견인 이동 규칙·정보 표시. ✅
- **5a-2 성벽 투석 + 내구도** — (이 문서) `[투석]` 성벽 공격(사거리 5·1턴 1발) → `wall_hp` 감소 → 붕괴(→ 기존 [점령](camp-capture.md)). 성벽 전용 관전 씬. ✅
- **5b 유닛 투석** — [투석] 적 부대 공격(최대 5명, 유닛별 명중 판정).
- **5c NPC 공성 AI** / **5d 방어 카운터플레이**.

## 테스트 시나리오

**공성 유닛 카탈로그(순수)** — `test/unit/test_siege_types.gd`:
- [정상] `SiegeTypes.CATAPULT == "catapult"`, `SiegeTypes.CREW_MIN == 4`
- [정상] `SiegeTypes.type_name("catapult") == "투석기"`, `movement("catapult") == 2`, `fire_range("catapult") == 5`, `attack("catapult") == 50`, `max_hp("catapult") == 60`
- [정상] `produce_gold("catapult") == 40`, `produce_cost("catapult") == {목재:30, 석재:20}`
- [경계] 없는 id → `type_name` `""`, `movement`·`fire_range`·`attack`·`max_hp` `0`, `produce_gold` `0`, `produce_cost` `{}`

**공성 유닛 인스턴스(순수)** — `test/unit/test_siege_unit.gd`:
- [정상] `SiegeUnit.new()` → `type_id == "catapult"`, `unit_name() == "투석기"`, `movement() == 2`, `fire_range() == 5`, `attack() == 50`, `max_hp() == 60`
- [정상] 생성 직후 `hit_points == max_hp()`(풀 내구도 60)
- [정상] `SiegeUnit.new("catapult")` 동일

**성벽 내구도·투석 데미지(순수)** — `test/unit/test_siege.gd`: → [Wall 성벽 내구도 시나리오](wall.md#테스트-시나리오)
- [정상] `Siege.WALL_MAX_HP == 180`, `Siege.DAMAGE_VARIANCE == 0.2`
- [정상] `rolled_damage(50, 0.0) == 40`, `rolled_damage(50, 1.0) == 60`, `rolled_damage(50, 0.5) == 50`
- [정상] `wall_after_hit(180, 50) == 130`; [경계] `wall_after_hit(30, 50) == 0`(하한 0)
- [정상] `wall_broken(0) == true`, `wall_broken(1) == false`

**부대 공성 유닛·견인 이동** — `test/unit/test_party.gd`:
- [정상] 생성 직후 `siege_units` 빈 배열, `has_siege() == false`
- [정상] `add_siege_unit(SiegeUnit.new())` → `siege_units` 크기 1, `has_siege() == true`
- [정상] 공성 유닛 없으면 이동력 규칙 불변(기존 테스트대로)
- [정상] 사람 4명(이동력 4) + 투석기 1대 → `movement() == 2`(견인 속도 상한)
- [경계] 사람 3명 + 투석기 → `movement() == 0`(견인 인력 부족)
- [경계] 사람 4명 + 투석기 + 과적으로 사람 기준 이동력 1 → `movement() == 1`(min)
- [정상] 투석기 추가는 `vision()`·`attack_range()`·`members`에 영향 없음(인구 비소모)
- [정상] `siege_fire_range()`/`siege_attack()` — 공성 유닛 없으면 0, 투석기 실으면 각각 5/50(최대 집계)

**영지 완성 건물 판정(순수)** — `test/unit/test_territory.gd`:
- [정상] 완성된 `siege_workshop`이 있으면 `has_completed_building("siege_workshop") == true`
- [경계] 건설 중 작업장만 있으면 `false`; 작업장 없으면 `false`

**공성 작업장 종류** — `test/unit/test_building_types.gd`:
- [정상] `CATALOG`에 `siege_workshop` 존재(label "공성 작업장", footprint 1, prerequisite "town_hall")
- [정상] `BUILDABLE_IDS`에 `"siege_workshop"` 포함

**투석기 생산 버튼(`_siege_btn`)** — `test/unit/test_camp_menu.gd`:
- [정상] 거점 + 주둔 부대 + 영지에 완성 작업장 + 금·자재 충분 → `_siege_btn` 표시·활성, 텍스트에 `"투석기"`·비용 포함
- [경계] 작업장 없음 / 주둔 부대 없음 → 숨김; 금·자재 부족 → 표시하되 비활성
- [정상] `_siege_btn.pressed` → `siege_produced(building)` 방출

**투석 메뉴 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `party_actions(..., can_bombard=true)`(비주둔) → 목록에 `{id="catapult"}` 포함([장비] 앞)
- [경계] `can_bombard=false` → `catapult` 없음

**성벽 내구도 상태** — `test/unit/test_building.gd`: → [Wall 테스트 시나리오](wall.md#테스트-시나리오)
- [정상] 생성 직후 `wall_hp == 0`; 설정 가능; `upgrade_to` 후 `wall_hp` 유지

`game.gd`의 `_on_siege_produced`, `_catapult_target_for`(사거리 내 최근접 성벽 거점), `_bombard_wall`(관전 씬 → `wall_hp` 감소·붕괴·사다리 제거·재그리기), `[투석]` 행동 노출, 성벽 관전 씬(`SiegeBombard`) 연출, 성벽 링 내구도 색, 작업장 건축, 정보 패널 표시는 실제 실행으로 확인한다(`game.gd`·관전 씬 통합 테스트는 기존 관례상 두지 않음).

## 관련

- [Party (부대)](../entities/Party.md) — `siege_units`·견인 이동. [SiegeUnits (공성 유닛 카탈로그)](../data/siege-units.md) — `SiegeTypes`·투석기 값(`fire_range`). [Buildings](../data/buildings.md) — 공성 작업장. [Camp Menu](../features/camp-menu.md)·[Trade](../features/trade.md) — 생산 버튼(구매 패턴). [Garrison](../features/garrison.md) — 주둔 부대에 편입·출격. [Wall / 성벽](../features/wall.md) — [성벽 내구도](../features/wall.md#성벽-내구도-buildingwall_hp--siege)(투석 대상)·사다리 공성. [Party Action Menu](../features/party-action-menu.md) — `[투석]` 행동. [Building](../entities/Building.md) — `wall_hp`.
- 기획: 공성 로드맵 슬라이스 5(공성병기).
