# Feature: Siege Engines / 공성병기 (부대 소속 공성 유닛)

> 스크립트: `scenes/siege/siege_types.gd` (`SiegeTypes` — 공성 유닛 카탈로그) · `scenes/siege/siege_unit.gd` (`SiegeUnit` — 부대에 실리는 공성 유닛 인스턴스) · `scenes/siege/siege.gd` (`Siege` — 성벽 내구도 상수·헬퍼) · `scenes/party/party.gd` (`siege_units`·`has_siege`·`siege_*`·견인 이동 규칙) · `scenes/building/building_types.gd` (`siege_workshop` 종류) · `scenes/territory/territory.gd` (`has_completed_building`) · `scenes/camp/camp_menu.gd` (`[투석기 생산]`·`siege_produced`) · `scenes/combat/battle.gd` (투석기·성벽 구조물 전투원) · `scenes/game/game.gd` (`_on_siege_produced`·`_bombard_targets`·`_bombard_wall`) · `scenes/party/party_info.gd` (공성 유닛 표시)

성벽을 두른 거점을 함락하기 위한 **공성 유닛**(투석기·충차·공성탑 …). 일반 병사([Human](../entities/Human.md))와 달리 **부대에 실리는 재사용 장비 유닛**이다. 인구를 차지하지 않고, 부대의 사람(인구)이 조작한다. 일반 전투에는 참여하지 않으며 「투석」 등 전용 명령으로만 공격한다.

**이 문서는 5a·5b·5d(전투 완전 통합)를 다룬다** — 유닛 모델·획득·투석(성벽/유닛)·거리 게이트·투석기 전투원화·투석기 피격·**성벽 구조물 전투원화(5d-3b)**까지. NPC 공성 AI(5c)만 후속 `미구현`(아래 [로드맵](#공성병기-로드맵)).

## 공성 유닛 모델 (`SiegeUnit` · `Party.siege_units`)

- 부대([Party](../entities/Party.md))는 `members`(사람)와 별개로 **`siege_units: Array`**(공성 유닛 인스턴스 목록)를 가진다.
- 공성 유닛은 **인구 비소모** — `members`에 들지 않으므로 부대 시야(`vision()`)·공격거리(`attack_range()`)·전투(사상자·[Battle](battle.md))에 **영향을 주지 않는다**. 부대의 사람이 조작한다는 설정만 있고, 별도 조작 인원 배정 로직은 없다.
- `SiegeUnit`(RefCounted)은 종류 id 하나를 들고 카탈로그([SiegeTypes](../data/siege-units.md))에서 스펙을 읽는다:
  - `type_id: String` — 기본 `"catapult"`.
  - `unit_name() -> String` — 카탈로그 이름(예: `"투석기"`).
  - `movement() -> int` — 견인 이동력(투석기 `2`).
  - `min_range() -> int` / `fire_range() -> int` — [투석](#투석-공성-성벽) 사거리 밴드(투석기 **4~5**). 이 거리 범위에서만 발사.
  - `attack() -> int` — 공격력(투석기 `50` — 무기보다 큰 공성 화력). 투석 피해의 기준값.
  - `max_hp() -> int` — 최대 내구도(투석기 `60`). `hit_points`(현재 내구도)는 생성 시 `max_hp()`로 채우고, [투석 피격](#투석기-피격파괴-방어-카운터플레이)으로 깎여 이월된다(0이면 파괴).
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

## 투석 (`[투석]` 선택 모드)

투석기를 실은 부대는 「투석」으로 **사거리 밴드 4~5**([min_range~fire_range](../data/siege-units.md)) 안 표적을 원거리 포격한다. 표적은 **성벽 있는 적 거점** 또는 **적 부대** 둘 다이며, **둘 다 `battle.gd` 통합 전투**로 처리한다(성벽은 [구조물 전투원](#battlegd-통합-전투--투석기구조물-전투원)으로 스폰). [사격](party-action-menu.md#상호작용-모드)처럼 **표적 선택 모드**로 동작한다.

### 행동·선택 모드 (`[투석]` · `MODE_BOMBARD`)

- 조건: 아군 부대가 **공성 유닛을 실었고**(`has_siege()`) **이번 턴 미행동**(`can_attack()`)이며 **사거리 밴드 안에 유효 표적**(아래)이 하나라도 있으면 [행동 메뉴](party-action-menu.md)에 **`[투석]`**(`can_bombard`, `{id="catapult"}`).
- 선택 → **투석 모드**(`MODE_BOMBARD`) 진입: 유효 표적을 빨강 강조. 클릭하면 발사, 그 외 클릭은 모드 취소([사격 SHOOT](party-action-menu.md#상호작용-모드) 패턴).
- **유효 표적**(`game.gd._bombard_targets`): 부대 셀에서 **거리가 `[Party.siege_min_range()` ~ `Party.siege_fire_range()]`(4~5) 밴드 안**(지형 무시 헥스 거리 `bfs_distances`)인 (a) **성벽 있는 적 세력 거점**, (b) **적 세력 부대**. 밴드보다 가까운(≤3) 표적은 제외(근거리 투석 불가). 아군 제외.
- 발사는 **부대 행동 종료**(`mark_attacked`) → 자연히 **1턴 1발**. 성벽/유닛 공통.

### battle.gd 통합 전투 — 투석기·구조물 전투원

성벽·유닛 대상 **모두 `battle.gd` 통합 전투**로 처리한다(별도 폭격 씬 없음 — `SiegeBombard` 제거). `[투석]`이 헥스 거리(4~5)로 전투를 개시하며 **양 부대의 `siege_units`를 전투원으로 스폰**(`include_siege`)하고, 성벽 대상이면 **성벽을 구조물 전투원**으로 방어 팀에 스폰한다. 거리 게이트([Battle](battle.md#전투-모드-교전-거리distance))로 사거리 닿는 유닛만 싸우므로 **양쪽 투석기가 있으면 자연히 상호 반격**한다.

- **투석기 전투원**: 사거리 밴드 4~5·공격 50·**전투당 1발**. 이동·근접 없이 `min_range ≤ distance ≤ fire_range`·미발사(`fired=false`)일 때만 발사.
- **발사 = 광역 최대 `Siege.MAX_BOMBARD_TARGETS`(5)**: `BattleField.bombard_targets(unit, units, n)`로 **적 투석기(siege) 우선 → 유닛·구조물, 거리순** 최대 5 표적. 표적별 개별 명중 — **성벽 구조물은 항상 명중**(거대·부동, 회피 없음), 유닛은 `Siege.hit_succeeds(rng, 0.4)`. 명중 시 `Siege.rolled_damage(attack 50, rng)`(30~70) **flat 피해**(방어구·회피·상성 무시, `resolve_hit` 안 탐). 발사 후 대기.

#### 성벽 구조물 전투원 (`game.gd._bombard_wall`)

- `[투석]` 성벽 클릭 → `_bombard_wall(building, distance)`: 공격 부대(+투석기) vs **성벽 구조물 전투원**(방어 팀, `hp = wall_hp`, `building` 참조). **수비대는 성벽 뒤라 미참여**(붕괴 전엔 안쪽을 못 침 — 기존 보호 규칙).
- 성벽 구조물은 **반격 없음·부동**, 투석 flat 피해만 받는다. `battle.gd`가 전투 종료 시 남은 hp를 `building.wall_hp`에 반영한다.
- 전투 후 `Siege.wall_broken(building.wall_hp)`면 붕괴: `wall_level=0`·`wall_hp=0`·[사다리 제거](wall.md#통로-돌파-breach)·재그리기·토스트 → `is_walled()==false`라 기존 점령/공격 자동 개방. 안 부서지면 `wall_hp`만 줄고 [성벽 링 색](wall.md#성벽-내구도-buildingwall_hp--siege) 갱신.

#### 투석기 피격·파괴 (방어 카운터플레이)

투석기 전투원은 **피격 대상**이 된다 — 사거리 4~5인 적 투석기만 닿으므로(궁수 3은 못 미침) 실질 **투석기 vs 투석기 대포병 결투**다.

- 투석기 전투원은 `hp`(= `SiegeUnit.hit_points`, 만 60)를 갖고, 적 투석 볼리에 맞으면 flat 피해로 깎인다. `hp ≤ 0`이면 **파괴**(전투불능·파괴 연출).
- **지속·제거**: 전투 종료 시 투석기 전투원 hp를 `SiegeUnit`에 반영 — 생존이면 **다음 전투로 이월(attrition)**, 파괴면 0. 전투 후 `game.gd`가 양 부대 `siege_units`에서 **hp ≤ 0 투석기를 제거**(`Party.prune_destroyed_siege()`)·[정보 패널](party-info.md) 갱신. 손상 투석기는 `"투석기 (HP 20/60)"`처럼 표시.

#### 표적 범위·승패·순수 로직

- **표적**: `BattleField.bombard_targets`(투석 볼리)만 투석기(siege)·성벽(structure)을 표적에 포함한다. `nearest_enemy`·`survivors`는 **siege·structure 제외**(일반 유닛은 사거리 부족으로 투석기·성벽을 못 침, 생존자는 Human만).
- **승패**: `team_wiped`는 **Human + 구조물**을 셈(siege 제외) — 성벽만 있는 방어 팀은 **성벽이 부서질 때** 전멸로 종료(안 부서지면 원거리 전투 시간까지). 부대 전멸로는 승패가 갈리지 않는다([Victory](victory.md) — 거점만). **노획은 없다**(후속).
- **순수 로직**: `BattleField.bombard_targets(unit, units, n) -> Array`(적 siege 우선·거리순·최대 n, siege·structure 포함) · `nearest_enemy`/`survivors`(siege·structure 제외) · `team_wiped`(structure 포함) + `Party.prune_destroyed_siege() -> int` + 기존 `Siege.hit_succeeds`·`MAX_BOMBARD_TARGETS`·`rolled_damage`·`wall_broken`.

## 이번 슬라이스 제외 (미구현)

- **NPC 공성 AI**(NPC의 작업장 건설·투석기 생산·투석 운용) — 5c.
- **투석 노획**(투석으로 전멸시킨 부대의 화물·장비 loot) — 후속.
- **맵 토큰의 공성 유닛 표시**(투석기 마커)·거점 상실 시 공성 유닛 소실 처리 — 후속. *(부대에 투석기가 여러 대면 battle.gd 통합 전투에서 각 투석기가 전투원으로 1발씩 쏜다 — 전투당 1발은 유닛 단위.)*
- 조작 인원 개별 배정 — 후속.

## 공성병기 로드맵

- **5a-1 유닛 모델** — 투석기 획득·부대 편입(인구 비소모)·견인 이동 규칙·정보 표시. ✅
- **5a-2 성벽 투석 + 내구도** — `[투석]` 성벽 공격 → `wall_hp` 감소 → 붕괴(→ 기존 [점령](camp-capture.md)). ✅ *(초기엔 전용 관전 씬 `SiegeBombard`였으나 5d-3b에서 battle.gd 구조물 전투원으로 흡수)*
- **5b 유닛 투석** — (이 문서) `[투석]` 선택 모드 + 적 부대 폭격(최대 5명·유닛별 명중 0.4·30~70 피해). ✅
- **5d 전투 통합**(공성은 게임 핵심 재미 → **완전 통합** 방향: 구조물도 전투원화해 battle.gd 흡수):
  - **5d-1 거리 게이트 일반화** — battle.gd·BattleSim `ranged_mode`(bool)→`distance`(int), 사거리 게이트 `range < distance`. ✅
  - **5d-2 투석기 전투원화 + 상호 반격** — (이 문서) `[투석]` 유닛 대상을 battle.gd 통합 전투로, 투석기를 전투원(사거리 4~5·1발·광역 최대 5)으로 스폰, 양쪽 투석기 상호 반격. 투석기는 아직 피격 안 됨. ✅
  - **5d-3a 투석기 피격·파괴** — (이 문서) 투석기가 표적이 되어(적 투석기 우선 대포병) 적 투석에 hp 소진 시 파괴·`siege_units`에서 제거. 방어 카운터플레이. ✅
  - **5d-3b 성벽 구조물 전투원화** — (이 문서) 성벽을 HP 구조물 전투원으로 battle.gd에 흡수(`_bombard_wall`이 통합 전투 개시·`siege_bombard.gd` 제거) → 충차·공성탑 등 구조물 공격 병기가 한 경로 공유. ✅ **5d 전투 완전 통합 완료.**
- **5c NPC 공성 AI**(NPC 작업장 건설·투석기 생산·운용).

## 테스트 시나리오

**공성 유닛 카탈로그(순수)** — `test/unit/test_siege_types.gd`:
- [정상] `SiegeTypes.CATAPULT == "catapult"`, `SiegeTypes.CREW_MIN == 4`
- [정상] `SiegeTypes.type_name("catapult") == "투석기"`, `movement("catapult") == 2`, `min_range("catapult") == 4`, `fire_range("catapult") == 5`, `attack("catapult") == 50`, `max_hp("catapult") == 60`
- [정상] `produce_gold("catapult") == 40`, `produce_cost("catapult") == {목재:30, 석재:20}`
- [경계] 없는 id → `type_name` `""`, `movement`·`min_range`·`fire_range`·`attack`·`max_hp` `0`, `produce_gold` `0`, `produce_cost` `{}`

**공성 유닛 인스턴스(순수)** — `test/unit/test_siege_unit.gd`:
- [정상] `SiegeUnit.new()` → `type_id == "catapult"`, `unit_name() == "투석기"`, `movement() == 2`, `min_range() == 4`, `fire_range() == 5`, `attack() == 50`, `max_hp() == 60`
- [정상] 생성 직후 `hit_points == max_hp()`(풀 내구도 60)
- [정상] `SiegeUnit.new("catapult")` 동일

**성벽 내구도·투석 데미지(순수)** — `test/unit/test_siege.gd`: → [Wall 성벽 내구도 시나리오](wall.md#테스트-시나리오)
- [정상] `Siege.WALL_MAX_HP == 180`, `Siege.DAMAGE_VARIANCE == 0.4`
- [정상] `rolled_damage(50, 0.0) == 30`, `rolled_damage(50, 1.0) == 70`, `rolled_damage(50, 0.5) == 50`
- [정상] `wall_after_hit(180, 50) == 130`; [경계] `wall_after_hit(30, 50) == 0`(하한 0)
- [정상] `wall_broken(0) == true`, `wall_broken(1) == false`

**유닛 투석 판정(순수)** — `test/unit/test_siege.gd`:
- [정상] `Siege.MAX_BOMBARD_TARGETS == 5`, `Siege.CATAPULT_HIT_CHANCE == 0.4`
- [정상] `hit_succeeds(0.2, 0.4) == true`(0.2 < 0.4), `hit_succeeds(0.5, 0.4) == false`; [경계] `hit_succeeds(0.4, 0.4) == false`(미만만 명중)

**투석 표적 선정(순수)** — `test/unit/test_battle_field.gd`:
- [정상] `bombard_targets(unit, units, 5)` — 적 투석기(siege) 우선 → 유닛·성벽 구조물(structure), 거리순 최대 5명
- [정상] 적 유닛보다 뒤에 있는 적 투석기라도 **먼저** 뽑힌다(대포병 우선); [정상] 성벽 구조물도 표적에 포함
- [경계] 적이 n보다 적으면 있는 만큼만; 적 없으면 빈 배열; 죽은 적·같은 팀 제외
- [정상] `nearest_enemy`·`survivors`는 siege·structure 제외; `team_wiped`는 structure 포함·siege 제외(구조물만 살아있으면 미전멸, 투석기만 살아있으면 전멸)

**부대 공성 유닛·견인 이동** — `test/unit/test_party.gd`:
- [정상] 생성 직후 `siege_units` 빈 배열, `has_siege() == false`
- [정상] `add_siege_unit(SiegeUnit.new())` → `siege_units` 크기 1, `has_siege() == true`
- [정상] 공성 유닛 없으면 이동력 규칙 불변(기존 테스트대로)
- [정상] 사람 4명(이동력 4) + 투석기 1대 → `movement() == 2`(견인 속도 상한)
- [경계] 사람 3명 + 투석기 → `movement() == 0`(견인 인력 부족)
- [경계] 사람 4명 + 투석기 + 과적으로 사람 기준 이동력 1 → `movement() == 1`(min)
- [정상] 투석기 추가는 `vision()`·`attack_range()`·`members`에 영향 없음(인구 비소모)
- [정상] `siege_fire_range()`/`siege_min_range()`/`siege_attack()` — 공성 유닛 없으면 0, 투석기 실으면 각각 5/4/50
- [정상] `prune_destroyed_siege()` — `hit_points ≤ 0`인 투석기를 `siege_units`에서 제거하고 제거 수 반환; hp > 0은 유지. [경계] 파괴 없으면 0 반환·불변

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

`game.gd`의 `_on_siege_produced`, 투석 선택 모드(`MODE_BOMBARD`)·`_bombard_targets`(밴드 4~5 내 성벽 거점+적 부대), **성벽/적 부대 모두** → `_bombard_wall`/`_begin_battle`(battle.gd 통합 전투, `include_siege`·성벽은 구조물 전투원), `battle.gd`의 투석기·성벽 구조물 전투원 스폰·발사(광역·flat 피해·적 투석기 우선·성벽 항상 명중)·**투석기 피격·파괴**(hp 소진 시 `_kill`)·hp/wall_hp 이월 반영·붕괴, 전투 후 `prune_destroyed_siege`·정보 갱신, `[투석]` 행동 노출, 성벽 링 내구도 색, 작업장 건축, 정보 패널 표시는 실제 실행으로 확인한다(`game.gd`·오버레이 통합 테스트는 기존 관례상 두지 않음).

## 관련

- [Party (부대)](../entities/Party.md) — `siege_units`·견인 이동. [SiegeUnits (공성 유닛 카탈로그)](../data/siege-units.md) — `SiegeTypes`·투석기 값(`fire_range`). [Buildings](../data/buildings.md) — 공성 작업장. [Camp Menu](../features/camp-menu.md)·[Trade](../features/trade.md) — 생산 버튼(구매 패턴). [Garrison](../features/garrison.md) — 주둔 부대에 편입·출격. [Wall / 성벽](../features/wall.md) — [성벽 내구도](../features/wall.md#성벽-내구도-buildingwall_hp--siege)(투석 대상)·사다리 공성. [Party Action Menu](../features/party-action-menu.md) — `[투석]` 행동. [Building](../entities/Building.md) — `wall_hp`.
- 기획: 공성 로드맵 슬라이스 5(공성병기).
