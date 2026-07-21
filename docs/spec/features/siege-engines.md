# Feature: Siege Engines / 공성병기 (부대 소속 공성 유닛)

> 스크립트: `scenes/siege/siege_types.gd` (`SiegeTypes` — 공성 유닛 카탈로그) · `scenes/siege/siege_unit.gd` (`SiegeUnit` — 부대에 실리는 공성 유닛 인스턴스) · `scenes/siege/siege.gd` (`Siege` — 성벽 내구도 상수·헬퍼) · `scenes/siege/siege_system.gd` (`SiegeSystem` — 헤드리스 성벽 투석 `bombard_wall_headless`·붕괴 `collapse_wall`·충차 반격 `ram_counter`; game.gd의 `_npc_bombard_wall_headless`/`_collapse_wall`/`_apply_ram_counter`는 이 위임 + 연출) · `scenes/party/party.gd` (`siege_units`·`has_siege`·`siege_*`·견인 이동 규칙) · `scenes/building/building_types.gd` (`siege_workshop` 종류) · `scenes/territory/territory.gd` (`has_completed_building`) · `scenes/combat/battle.gd` (투석기·성벽 구조물 전투원) · `scenes/game/game.gd` (`_bombard_targets`·`_bombard_wall`) · `scenes/party/party_info.gd` (공성 유닛 표시)
> **(생산 관련 스크립트 제거됨)** `camp_menu.gd`의 `[투석기/충차 생산]`·`siege_produced`, `game.gd`의 `_on_siege_produced`·`_npc_produce_siege`, `NpcAi.should_produce_siege` 는 [주둔 제거](camp-capture.md)와 함께 삭제됐다.

성벽을 두른 거점을 함락하기 위한 **공성 유닛**(투석기·충차·공성탑 …). 일반 병사([Human](../entities/Human.md))와 달리 **부대에 실리는 재사용 장비 유닛**이다. 인구를 차지하지 않고, 부대의 사람(인구)이 조작한다. 일반 전투에는 참여하지 않으며 「투석」 등 전용 명령으로만 공격한다.

> **⚠️ 생산 경로 제거됨 (휴면).** [주둔(garrison) 제거](camp-capture.md)와 함께 공성 병기 **생산 경로가 전부 제거**됐다 — 캠프 메뉴 `[투석기/충차 생산]` 버튼(`_siege_btn`·`_ram_btn`·`siege_produced`·`_on_siege_produced`), **NPC 주기 생산**(5c·5e — `_npc_produce_siege`·`NpcAi.should_produce_siege`) 모두 삭제. 시작 투석기 지급도 이미 폐지 상태라, **현재 게임 내에 공성 병기가 생성될 경로가 없다**. 아래 유닛 모델·투석·충차·전투·NPC 운용 로직(`SiegeUnit`·`_bombard_*`·battle.gd 통합 전투 등)은 **코드가 남아 있으나 발동하지 않는 휴면 상태**다(공성 시스템 재구축 시 되살린다).

**이 문서가 다루는 시스템(현재 휴면)** — 유닛 모델·투석(성벽/유닛)·거리 게이트·투석기 전투원화·투석기 피격·**성벽 구조물 전투원화**·**로빙 positioning 공격형 공성**·**NPC↔NPC 투석**·충차(근접 성문 파쇄). 생산·NPC 생산은 위처럼 제거됐다.

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

## 획득 — 생산 제거됨 (재구축 예정)

공성 병기 **생산 경로는 [주둔 제거](camp-capture.md)와 함께 전부 삭제**됐다(재구축 예정).

- 예전엔 **전용 건물 「공성 작업장」**([buildings](../data/buildings.md))을 지은 거점에서 캠프 메뉴 `[투석기/충차 생산]` 버튼(`_siege_btn`·`_ram_btn`)으로 부대에 편입했으나, 버튼·시그널(`siege_produced`)·핸들러(`_on_siege_produced`)를 **모두 제거**했다.
- **공성 작업장(`siege_workshop`) 건물 자체는 [건축](building.md) 카탈로그에 남아 있으나**, 이제 소비처가 없다(생산 게이트가 사라짐).
- 부대는 여전히 `siege_units`를 담을 수 있고(`add_siege_unit`) 실린 공성 유닛은 아래 견인·투석 규칙대로 동작하지만, **편입 경로가 없어 실전에서 생성되지 않는다**(휴면).

## 견인 이동 규칙 (`Party.movement`)

공성 유닛을 실은 부대는 느리고, 끌 인력이 있어야 움직인다.

- **견인 속도**: 부대가 공성 유닛을 실으면(`has_siege()`) 그 부대 이동력은 **공성 유닛 견인 이동력(가장 느린 것, 투석기 `2`)으로 상한**된다. 즉 `min(사람 기준 이동력, 견인 속도)`.
- **인력 게이트**: 공성 유닛을 실은 부대의 **사람(`members`) 수가 `SiegeTypes.CREW_MIN`(4) 미만이면 이동력 0**(끌 인력 부족 → 정지). 4명 이상이어야 견인 이동력을 얻는다.
- 공성 유닛이 없으면 규칙은 적용되지 않고 기존 이동력(사람 최소)을 그대로 쓴다.
- 사람 기준 이동력이 이미 견인 속도보다 낮으면 그 낮은 값이 유지된다(`min`).

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

성벽·유닛 대상 **모두 `battle.gd` 통합 전투**로 처리한다(별도 폭격 씬 없음 — `SiegeBombard` 제거). `[투석]`이 헥스 거리(투석기 4~5·충차 1)로 전투를 개시하며 **양 부대의 `siege_units`를 전투원으로 스폰**(`include_siege`)하고, 성벽/성문 대상이면 **성벽·성문을 구조물 전투원**으로 방어 팀에 스폰한다. 이 거리에서는 사람(`members`)이 사거리 게이트·표적 부재로 행동하지 않아 **공성 유닛·구조물만** 싸운다.

- **순차 연출(공격자 선공 → 방어자 반격)**: [투석] 통합 전투는 프레임 시뮬·전투 타이머 대신 **스크립트 시퀀스**로 진행한다([Battle 투석 순차 연출](battle.md#투석-오버레이-순차-연출)). **공격측(a) 밴드 공성 유닛이 먼저 일제 발사** → 착탄(타격 판정) → `SIEGE_COUNTER_GAP`(0.5초) 뒤 **살아남은 방어측(b) 밴드 공성 유닛이 반격** → 마지막 착탄 +1초 후 종료. 발사 대상은 `BattleField.firing_siege(_units, team, distance)`(밴드 안 살아있는 siege). 이 순차 때문에 **공격자가 선제 이점**을 가진다(선공 볼리로 방어측 투석기가 전멸하면 반격 없음). 성벽·성문(구조물)은 반격하지 않는다. *(양측 투석기가 남으면 여전히 상호 반격 — 순서만 공격자→방어자.)*
- **투석기 전투원**: 사거리 밴드 4~5·공격 50·**전투당 1발**. 이동·근접 없이 밴드 소속(`min_range ≤ distance ≤ fire_range`)일 때만 발사하며, 순차 연출이 각 진영을 정확히 1회 발사한다(발사 판정은 `_ranged_mode`가 아니라 밴드 소속 — 충차 밴드 1도 발사).
- **발사 = 광역 최대 `Siege.MAX_BOMBARD_TARGETS`(5)**: `BattleField.bombard_targets(unit, units, n)`로 **적 투석기(siege) 우선 → 유닛·구조물, 거리순** 최대 5 표적. 표적별 개별 명중 — **성벽 구조물은 항상 명중**(거대·부동, 회피 없음), 유닛은 `Siege.hit_succeeds(rng, CATAPULT_HIT_CHANCE)`(**0.1**, 낮음). 명중 시 `Siege.rolled_damage(attack 50, rng)`(30~70) **flat 피해**(방어구·회피·상성 무시, `resolve_hit` 안 탐). **피해는 투사체 착탄 시점에 적용**(투석 볼리 투사체는 화살의 1/3 속도 `SIEGE_PROJECTILE_TIME` 0.72초).

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
- **순수 로직**: `BattleField.bombard_targets(unit, units, n) -> Array`(적 siege 우선·거리순·최대 n, siege·structure 포함) · `BattleField.firing_siege(units, team, distance) -> Array`(밴드 안 살아있는 siege — 발사 대상·반격 가능 판정) · `nearest_enemy`/`survivors`(siege·structure 제외) · `team_wiped`(structure 포함) + `Party.prune_destroyed_siege() -> int` + 기존 `Siege.hit_succeeds`·`MAX_BOMBARD_TARGETS`·`rolled_damage`·`wall_broken`.

## NPC 공성 AI (5c·5e·5f · `_npc_unit_act`·`_on_turn_ended`·`NpcPlanner.targets_for`)

> **⚠️ NPC 공성 생산 제거됨 (5c·5e 휴면).** [주둔 제거](camp-capture.md)와 함께 **NPC 주기 생산(5e, `_npc_produce_siege`·`NpcAi.should_produce_siege`)이 삭제**됐다. 시작 투석기 지급도 이미 폐지 상태라 **NPC 부대도 공성 병기를 얻을 경로가 없다**. 아래 운용(`_npc_unit_act`)·타깃팅(5f·5g) 로직은 코드가 남아 있으나 투석기를 실은 NPC가 없어 발동하지 않는다(휴면).

- **~~주기 생산(5e)~~ (제거됨)**: 예전엔 매 턴 종료 시 각 NPC 수비대에 대해 `NpcAi.should_produce_siege`가 참이면 투석기 1대를 편입했으나, 함수·호출(`_npc_produce_siege`)을 모두 삭제했다.
- **운용**(`_npc_unit_act`, 휴면): 투석기를 실은 NPC 부대가 **사거리 밴드 4~5 안에 적 표적**이 있으면 **[투석]**한다(`NpcPlanner.siege_target_for` — 밴드 내 최근접). 성벽이면 성벽 구조물 전투, 부대면 `include_siege` 통합 전투. 로직은 남아 있으나 위처럼 투석기 편입 경로가 없어 실전 미발동.
- **표적 범위**(5c·5f 초기엔 플레이어만, **5g에서 NPC↔NPC 추가**): NPC 투석은 이제 **적 세력 성벽 거점·부대**면 플레이어·다른 NPC 불문 겨냥한다(아래 [5g](#npcnpc-투석-5g)). 성벽은 5g-A, 부대 투석 결투는 5g-B(헤드리스 [BattleSim 볼리](battle.md#헤드리스-전투-결산-battle_simgd-순수)).

### 로빙 positioning 공격형 공성 (5f · `NpcPlanner.targets_for` — 현재 휴면)

수비대(5c)는 고정 위치라, 접근한 플레이어를 반격만 한다. **5f는 로빙 NPC 부대가 투석기를 끌고 와 능동적으로 성벽을 공성**하게 한다 — 새 이동 모드 없이 기존 접근 AI(`NpcAi._approach`)의 **이동 타깃을 밴드 셀로 바꿔** 사거리 밴드(4~5)에 자리잡게 유도한다.

> **현재 휴면**: [주둔·생산 제거](camp-capture.md)로 NPC가 투석기를 얻을 경로(주기 생산)가 사라졌다. 아래 밴드 타깃팅 로직(`NpcPlanner.targets_for`·`has_siege()` 게이트)은 그대로 남아 있어 로빙 부대가 다시 투석기를 얻으면 즉시 발동한다.
- **밴드 유지 타깃팅(`NpcPlanner.targets_for`)**: 투석기를 실은(`has_siege()`) 로빙 NPC는 이동 타깃 우선순위에 **밴드 티어**를 끼운다 — `NpcAi.prioritize([undefended, weak, band, rest])`. 즉 **기존 우선순위(무방비 캠프 > 약한 부대)는 그대로** 두고, 그 위 티어가 비어 손쉬운 표적이 없을 때 `rest`(전체 적 셀) **대신 밴드 셀**을 탄다. 투석기 없는 NPC·밴드 없음이면 기존대로 `rest`.
  - **밴드 셀(`_siege_band_cells`)**: NPC에서 **가장 가까운 적 세력 성벽 거점**(플레이어·다른 NPC 불문, 자기 세력 제외 — 5g에서 NPC 거점까지 확장) 하나를 골라, 그 거점 셀에서 헥스 거리가 **`[siege_min_range` ~ `siege_fire_range]`(4~5) 밴드 안**(`Siege.in_fire_band`)인 도달 가능 셀 목록. 성벽 거점이 없으면 빈 배열(→ 밴드 티어 스킵). `_approach`가 그중 최근접 밴드 셀로 접근하고, 밴드 셀에 서면 거리 0이라 **그 자리를 유지**(오버슛·이탈 없음).
- **발동**: 밴드에 자리잡으면 이미 있는 로빙 NPC 투석 경로(`_npc_unit_act`의 `_npc_try_bombard`, 근접·사다리보다 우선)가 밴드 내 성벽을 [투석](#battlegd-통합-전투--투석기구조물-전투원)한다 → 성벽 붕괴 → `is_walled()==false`가 되면 기존 흡수/점령 AI가 무방비 거점을 점령(창발 흐름). **배선은 5c에서 이미 존재**, 밴드에 서게 하는 것만이 5f의 실질 변경이다.
- **전력 판단 없음**(후속): 밴드 접근은 전력 비교 없이 무조건 시도한다(성벽 없는 거점 시즈·전력 기반 시즈 결정은 후속).
- **순수 로직**: `Siege.in_fire_band(dist, min_r, fire_r) -> bool`(밴드 셀 필터, `min_r ≤ dist ≤ fire_r`). 표적 선정(`NpcPlanner.siege_target_for`)·밴드 셀 계산(`_siege_band_cells`)·타깃 배선(`NpcPlanner.targets_for`)·운용은 game.gd(실행 검증). *(생산 판정 `should_produce_siege`는 제거됨.)*

### NPC↔NPC 투석 (5g · `NpcPlanner.siege_target_for`·`_siege_band_cells`·`_npc_bombard_wall_headless`·`_resolve_battle_headless`)

5f는 로빙 NPC가 **플레이어** 표적만 공성했다. **5g는 표적을 적 세력 전체로 넓혀 NPC가 다른 NPC의 성벽 거점(5g-A)·부대(5g-B)도 공성**하게 한다 — NPC 왕국끼리 서로 무너뜨리고 점령하는 창발. 플레이어가 안 보는 전투이므로 **오버레이 없이 헤드리스**로 정산한다(기존 [헤드리스 결산](battle.md#헤드리스-전투-결산-battle_simgd-순수) 관례와 일관 — 토스트 없음, 성벽 링만 다시 그림).

- **표적 확장(성벽)**: `NpcPlanner.siege_target_for`·`_siege_band_cells`의 **성벽 거점 스캔**을 `BuildingManager.buildings`(플레이어) → `BuildingManager.buildings + BuildingManager.npc_buildings` 중 **자기 세력이 아닌** 거점 전체로 넓힌다(`_enemy_walled_centers`).
- **표적 확장(부대, 5g-B)**: `NpcPlanner.siege_target_for`의 **부대 스캔**도 `_units`(플레이어) → `_units + _npc_parties` 중 **자기 세력·자기 부대 제외** 전체로 넓힌다 — NPC가 다른 NPC 부대를 밴드에서 투석. 유닛 볼리는 헤드리스([BattleSim 투석 볼리](battle.md#헤드리스-전투-결산-battle_simgd-순수))로 정산.
- **헤드리스 성벽 투석(`_npc_bombard_wall_headless`)**: `_npc_try_bombard`에서 표적 성벽이 **플레이어 소유면 기존 오버레이**(`_bombard_wall_by`), **다른 NPC 소유면 헤드리스**로 분기. 헤드리스는 attacker의 **공성 유닛마다 1발**씩(전투당 1발 규칙과 동일) `Siege.rolled_damage`를 굴려 합산(`Siege.total_bombard_damage`)한 flat 피해를 `wall_hp`에서 뺀다(`Siege.wall_after_hit`). 성벽은 반격 없고(구조물·부동), 성벽 뒤 수비대는 미참여(붕괴 전 보호 규칙 — 오버레이 `defender=null`과 동일).
- **붕괴·점령**: 헤드리스 정산 후 `Siege.wall_broken(wall_hp)`면 붕괴 처리(오버레이와 공유 — `wall_level=0`·`wall_hp=0`·[사다리 정리](wall.md#통로-돌파-breach)·재그리기). `is_walled()==false`가 되면 기존 흡수 AI(`NpcPlanner.adjacent_enemy_camp`)가, 수비대가 있으면 먼저 부대 전투(헤드리스 BattleSim) 후 점령한다(창발 흐름).
- **헤드리스 부대 투석 결투(5g-B, `_resolve_battle_headless`)**: `_npc_try_bombard`에서 표적 부대가 **플레이어면 기존 오버레이**(`_run_battle(..., include_siege=true)`), **다른 NPC면 헤드리스**(`_resolve_battle_headless`)로 분기. 헤드리스는 양측 `siege_units`를 [BattleSim 투석 볼리](battle.md#헤드리스-전투-결산-battle_simgd-순수)에 넘겨 밴드(4~5)면 전투당 1발씩 상호 포격(적 투석기 우선·명중 0.1·flat 피해)·투석기 hp 이월. 전투 후 양 부대 `prune_destroyed_siege()`.
- **순수 로직(신규)**: `Siege.total_bombard_damage(attacks, rolls) -> int`(성벽 피해 총량, 5g-A) + `BattleSim.bombard_pick(enemy_siege, enemy_members, n) -> Array`(볼리 표적: 적 투석기 우선 → 멤버, 최대 n, 비공간, 5g-B). 표적/분기/붕괴/라우팅 배선은 game.gd(실행 검증), 볼리 통합은 BattleSim 시드 테스트.

## 충차 (근접 성문 파쇄)

충차(`battering_ram`)는 [투석기와 같은 공성 유닛 모델](#공성-유닛-모델-siegeunit--partysiege_units)(획득·견인·구조물 전투)을 재사용하되, **성문([Gate](wall.md#성문-gate))을 부수는 전담 병기**다. **이번 슬라이스는 플레이어 충차만** 다룬다(NPC 충차 생산·운용 AI는 후속). 카탈로그 수치는 [Siege Units](../data/siege-units.md).

1. **근접(밴드 1)** — 성문에 **인접(거리 1)**해야 타격한다(투석기 4~5와 반대). `min_range = fire_range = 1`.
2. **성문 전용** — `targets = ["gate"]`. 성문만 친다 — 성벽도 적 부대(유닛)도 노리지 않는다. (투석기는 `["unit","wall","gate"]`로 셋 다 가능.)
3. **취약·노출** — 성문에 붙어야 해서 수비 사거리에 들어가고, 내구도가 낮다(40). 아래 반격 참조.

### 획득·생산

- **~~생산~~ (제거됨)**: 예전엔 공성 작업장 거점에서 `[충차 <비용>]` 버튼으로 생산했으나, [투석기 생산과 함께 제거](#획득--생산-제거됨-재구축-예정)됐다. 카탈로그(`SiegeTypes.BATTERING_RAM`)·전투·성문 파쇄 로직은 남아 있으나 편입 경로가 없어 휴면.

### 타격 표적 — 종류별 (`_compute_bombard_targets`)

- `[투석]`(BOMBARD) 모드 표적은 유닛의 `targets` 리스트로 거른다 — `Party.siege_can_bombard(kind) -> bool`(= 실은 공성 유닛 중 하나라도 그 `kind`를 `targets`에 가지면 참).
  - **충차**: `gate`만 참 → **성문 셀(`gate_cell`)만** 표적. 성벽 셀·적 부대 제외.
  - **투석기**: `unit`·`wall`·`gate` 모두 참 → 적 부대 + 성벽 셀 + 성문 셀 전부 표적.
- 성문 표적은 `b.is_walled()` + `b.gate_hp > 0`일 때만(이미 부서졌으면 없음). 성벽 셀은 `gate_cell`을 제외한 footprint(성문 셀은 `gate` 종류로 별도).
- 사거리 밴드는 유닛 집계(`siege_min_range`~`siege_fire_range`)를 그대로 쓴다 → 충차만이면 밴드 1~1(인접).

### 성문 타격·돌파 (`_bombard_gate`)

- 성문 표적(`kind == "gate"`) 클릭 → 기존 [성벽 battle.gd 통합 전투](#battlegd-통합-전투--투석기구조물-전투원)를 **`target_gate`로** 연다(구조물 전투원의 HP가 `gate_hp`, 종료 시 `gate_hp` 되씀). 충차 공격력 90 → [`rolled_damage`](wall.md#성벽-내구도-buildingwall_hp--siege) 54~126 → 성문 120을 **평균 2발**에 파괴.
- `gate_hp`가 0이 되면 **성문 면 통로 개방**([Wall 통로 돌파](wall.md#통로-돌파-breach)) — `gate_cell` + 중심이 열려 진입·점령. **성벽(`wall_level`)은 유지**(성벽 전체 붕괴와 다름). 별도 상태 플립 없이 `gate_broken()`(=`gate_hp<=0`)을 `breached_by`·`wall_blocked_cells`가 읽어 반영.

### 반격 — 근접 노출 (`Siege.ram_counter_damage`)

- 충차가 **방어된 성벽 거점**(중심 타일에 그 세력 수비 부대가 있는 거점)의 성문을 타격하면, 수비대가 **즉시 반격**해 충차 내구도를 깎는다(결정론적). 무방비(수비 부대 없음) 거점이면 반격 없음.
- **반격 피해**: `Siege.ram_counter_damage(roll) = rolled_damage(RAM_COUNTER_BASE, roll)`. 상수 `Siege.RAM_COUNTER_BASE = 15`(→ ±40%로 9~21). 타격 1회당 부대의 충차 유닛(들)에 적용(`_apply_ram_counter`).
- 타격 후 반격 → 충차 HP 차감 → 0 이하면 [`prune_destroyed_siege`](#공성-유닛-모델-siegeunit--partysiege_units)로 파괴(토스트 "충차 파괴"). 충차가 다 파괴되면 그 부대는 더는 성문을 못 부순다.
- **긴장 구조**: 충차 HP 40, 반격 평균 15 → 성문을 부수는 평균 2발 동안 대략 30 피해로 **아슬아슬하게 버티거나** 불리한 롤에서 파괴된다(리스크·리워드). 투석기(원거리 4~5)가 성문을 칠 때는 반격 없음(안전하지만 느림). 수치는 밸런스 조정 대상.

### 이번 슬라이스 범위

- **플레이어 충차만**: 생산·견인·성문 타격·반격 피해 수신. **NPC가 충차를 생산/운용하는 AI는 후속**(단, NPC 수비대가 플레이어 충차를 반격하는 방어는 위 규칙으로 자동).
- **혼합 부대**(투석기+충차 동시 탑재)는 특수 처리하지 않는다 — 밴드·표적 집계가 섞이므로 **단일 종류 운용 권장**. (혼합 시 `siege_can_bombard`가 유닛/성벽/성문 모두 참, 밴드는 1~5로 늘어남.)

## 이번 슬라이스 제외 (미구현)

- **NPC 충차·성문 공격 AI**: NPC의 충차 생산·근접 공성, NPC의 성문 타격 — 후속(현재 NPC는 투석기만). NPC 투석 표적 선정(`NpcPlanner.siege_target_for`)은 **성문 셀을 제외**하고 성벽 footprint만 겨눈다(NPC는 성벽만 공격, 성문은 안 침).
- **NPC 건설 AI**: NPC의 작업장 건설(추상 생산은 5e에서 구현) — 후속.
- **전력 기반 시즈 결정·성벽 없는 거점 시즈**: 밴드 접근은 전력 비교 없이 무조건 시도, 대상은 성벽 있는 거점만 — 후속.
- **투석 노획**(투석으로 전멸시킨 부대의 장비 loot) — 후속.
- **맵 토큰의 공성 유닛 표시**(투석기 마커)·거점 상실 시 공성 유닛 소실 처리 — 후속. *(부대에 투석기가 여러 대면 battle.gd 통합 전투에서 각 투석기가 전투원으로 1발씩 쏜다 — 전투당 1발은 유닛 단위.)*
- 조작 인원 개별 배정 — 후속.

## 공성병기 로드맵

- **5a-1 유닛 모델** — 투석기 획득·부대 편입(인구 비소모)·견인 이동 규칙·정보 표시. ✅
- **5a-2 성벽 투석 + 내구도** — `[투석]` 성벽 공격 → `wall_hp` 감소 → 붕괴(→ 기존 [점령](camp-capture.md)). ✅ *(초기엔 전용 관전 씬 `SiegeBombard`였으나 5d-3b에서 battle.gd 구조물 전투원으로 흡수)*
- **5b 유닛 투석** — (이 문서) `[투석]` 선택 모드 + 적 부대 폭격(최대 5명·유닛별 명중 0.1·30~70 피해). ✅
- **5d 전투 통합**(공성은 게임 핵심 재미 → **완전 통합** 방향: 구조물도 전투원화해 battle.gd 흡수):
  - **5d-1 거리 게이트 일반화** — battle.gd·BattleSim `ranged_mode`(bool)→`distance`(int), 사거리 게이트 `range < distance`. ✅
  - **5d-2 투석기 전투원화 + 상호 반격** — (이 문서) `[투석]` 유닛 대상을 battle.gd 통합 전투로, 투석기를 전투원(사거리 4~5·1발·광역 최대 5)으로 스폰, 양쪽 투석기 상호 반격. 투석기는 아직 피격 안 됨. ✅
  - **5d-3a 투석기 피격·파괴** — (이 문서) 투석기가 표적이 되어(적 투석기 우선 대포병) 적 투석에 hp 소진 시 파괴·`siege_units`에서 제거. 방어 카운터플레이. ✅
  - **5d-3b 성벽 구조물 전투원화** — (이 문서) 성벽을 HP 구조물 전투원으로 battle.gd에 흡수(`_bombard_wall`이 통합 전투 개시·`siege_bombard.gd` 제거) → 충차·공성탑 등 구조물 공격 병기가 한 경로 공유. ✅ **5d 전투 완전 통합 완료.**
- **5c NPC 공성 AI** — (이 문서) NPC 투석기 방어 포격(밴드 4~5). 운용 로직 잔존하나 ❌ **생산 제거로 휴면** — 투석기를 얻을 NPC 부대가 없음([주둔 제거](camp-capture.md)).
- **5e NPC 투석기 생산** — ❌ **제거됨**([주둔 제거](camp-capture.md)) — `_npc_produce_siege`·`NpcAi.should_produce_siege` 삭제(재구축 예정).
- **5f 로빙 positioning 공격형 공성** — (이 문서) `NpcPlanner.targets_for`에 밴드 티어(`prioritize([undefended, weak, band, rest])`)를 끼워 가장 가까운 적 성벽 거점의 사거리 밴드(4~5)에 자리잡고 능동 포격. ⏸️ **현재 휴면** — NPC가 투석기를 얻을 경로가 없음(로직은 잔존, 후속 공성 재구축 시 재활성).
- **5g-A NPC↔NPC 성벽 공성** — (이 문서) 투석 성벽 표적을 적 세력 전체(`_enemy_walled_centers`)로 확장 + NPC 소유 성벽은 헤드리스 정산(`_npc_bombard_wall_headless`·`Siege.total_bombard_damage`)으로 `wall_hp` 감소·붕괴. ✅
- **5g-B NPC↔NPC 부대 투석 결투** — (이 문서) 투석 부대 표적을 적 세력 전체(`_units + _npc_parties`, 자기 세력·자기 부대 제외)로 확장 + NPC 부대는 헤드리스([BattleSim 투석 볼리](battle.md#헤드리스-전투-결산-battle_simgd-순수)·`bombard_pick`)로 상호 포격·투석기 피격·파괴 이월. ✅
- **5h 충차(근접 성문 파쇄)** — (이 문서 [충차](#충차-근접-성문-파쇄)) 성문 전용·근접(밴드 1)·고화력(90)·저내구(40) 공성 유닛. 초기엔 성벽을 직접 쳤으나 **성문 시스템 도입으로 성문 타격으로 재타깃**(역할 정리: 충차→성문, 투석기→성벽·성문·유닛). 표적 리스트(`targets`·`siege_can_bombard`), [성문](wall.md#성문-gate) 파괴 시 그 면 통로 개방(성벽 유지), 방어 거점 타격 시 수비 반격(`Siege.ram_counter_damage`)으로 취약. 플레이어만. ✅
- **후속**: NPC 충차/성문 공격 AI, NPC 작업장 건설 AI, 전력 기반 시즈 결정, 공성탑.

## 테스트 시나리오

**공성 유닛 카탈로그(순수)** — `test/unit/test_siege_types.gd`:
- [정상] `SiegeTypes.CATAPULT == "catapult"`, `SiegeTypes.CREW_MIN == 4`
- [정상] `SiegeTypes.type_name("catapult") == "투석기"`, `movement("catapult") == 2`, `min_range("catapult") == 4`, `fire_range("catapult") == 5`, `attack("catapult") == 50`, `max_hp("catapult") == 60`
- [정상] `produce_gold("catapult") == 40`, `produce_cost("catapult") == {목재:30, 철:20}`
- [정상] 충차: `BATTERING_RAM == "battering_ram"`, `type_name == "충차"`, `movement == 1`, `min_range == 1`, `fire_range == 1`, `attack == 90`, `max_hp == 40`, `produce_full_cost == {금:50, 목재:40, 철:10}`
- [정상] `targets("battering_ram") == ["gate"]`, `targets("catapult") == ["unit","wall","gate"]`; `can_target("battering_ram","gate")`만 참(wall·unit 거짓)
- [경계] 없는 id → `type_name` `""`, `movement`·`min_range`·`fire_range`·`attack`·`max_hp` `0`, `produce_gold` `0`, `produce_cost` `{}`

**공성 유닛 인스턴스(순수)** — `test/unit/test_siege_unit.gd`:
- [정상] `SiegeUnit.new()` → `type_id == "catapult"`, `unit_name() == "투석기"`, `movement() == 2`, `min_range() == 4`, `fire_range() == 5`, `attack() == 50`, `max_hp() == 60`
- [정상] 생성 직후 `hit_points == max_hp()`(풀 내구도 60)
- [정상] `SiegeUnit.new("catapult")` 동일
- [정상] `SiegeUnit.new("battering_ram")` → `unit_name() == "충차"`, `movement() == 1`, `min_range() == 1`, `fire_range() == 1`, `attack() == 90`, `max_hp() == 40`, 생성 직후 `hit_points == 40`

**성벽 내구도·투석 데미지(순수)** — `test/unit/test_siege.gd`: → [Wall 성벽 내구도 시나리오](wall.md#테스트-시나리오)
- [정상] `Siege.WALL_MAX_HP == 180`, `Siege.DAMAGE_VARIANCE == 0.4`
- [정상] `rolled_damage(50, 0.0) == 30`, `rolled_damage(50, 1.0) == 70`, `rolled_damage(50, 0.5) == 50`
- [정상] `wall_after_hit(180, 50) == 130`; [경계] `wall_after_hit(30, 50) == 0`(하한 0)
- [정상] `wall_broken(0) == true`, `wall_broken(1) == false`

**유닛 투석 판정(순수)** — `test/unit/test_siege.gd`:
- [정상] `Siege.MAX_BOMBARD_TARGETS == 5`, `Siege.CATAPULT_HIT_CHANCE == 0.1`
- [정상] `hit_succeeds(0.05, 0.1) == true`(0.05 < 0.1), `hit_succeeds(0.2, 0.1) == false`; [경계] `hit_succeeds(0.1, 0.1) == false`(미만만 명중)

**충차 반격 피해(순수)** — `test/unit/test_siege.gd`:
- [정상] `Siege.RAM_COUNTER_BASE == 15`
- [정상] `ram_counter_damage(0.0) == 9`(15×0.6), `ram_counter_damage(1.0) == 21`(15×1.4), `ram_counter_damage(0.5) == 15`

**사거리 밴드 판정(순수, 5f)** — `test/unit/test_siege.gd`:
- [정상] `in_fire_band(4, 4, 5) == true`, `in_fire_band(5, 4, 5) == true`(밴드 안 4~5)
- [경계] `in_fire_band(3, 4, 5) == false`(밴드보다 가까움 — 근거리 투석 불가), `in_fire_band(6, 4, 5) == false`(밴드보다 멀음)
- [경계] `in_fire_band(4, 4, 4) == true`(min==fire 단일 셀 밴드), `in_fire_band(0, 4, 5) == false`(거점 위)

**헤드리스 성벽 투석 피해 총량(순수, 5g)** — `test/unit/test_siege.gd`:
- [정상] `total_bombard_damage([50, 50], [0.0, 1.0]) == 100`(30 + 70 — 유닛별 rolled_damage 합)
- [정상] `total_bombard_damage([50], [0.5]) == 50`(1대 = rolled_damage 그대로)
- [경계] `total_bombard_damage([], []) == 0`(공성 유닛 없음), `total_bombard_damage([50, 50], [1.0]) == 70`(둘 중 짧은 길이만큼 — 1발)

**투석 표적 선정(순수)** — `test/unit/test_battle_field.gd`:
- [정상] `bombard_targets(unit, units, 5)` — 적 투석기(siege) 우선 → 유닛·성벽 구조물(structure), 거리순 최대 5명
- [정상] 적 유닛보다 뒤에 있는 적 투석기라도 **먼저** 뽑힌다(대포병 우선); [정상] 성벽 구조물도 표적에 포함
- [경계] 적이 n보다 적으면 있는 만큼만; 적 없으면 빈 배열; 죽은 적·같은 팀 제외
- [정상] `nearest_enemy`·`survivors`는 siege·structure 제외; `team_wiped`는 structure 포함·siege 제외(구조물만 살아있으면 미전멸, 투석기만 살아있으면 전멸)
- [정상] `firing_siege(units, "a", 4)`는 팀 a의 살아있는 밴드 안(min 4·fire 5) 투석기만; [경계] 죽은 siege·다른 팀·밴드 밖(거리 3/6)·구조물·일반 human 제외; [정상] 충차(밴드 1~1)는 distance 1이면 포함·distance 4면 제외

**부대 공성 유닛·견인 이동** — `test/unit/test_party.gd`:
- [정상] 생성 직후 `siege_units` 빈 배열, `has_siege() == false`
- [정상] `add_siege_unit(SiegeUnit.new())` → `siege_units` 크기 1, `has_siege() == true`
- [정상] 공성 유닛 없으면 이동력 규칙 불변(기존 테스트대로)
- [정상] 사람 4명(이동력 4) + 투석기 1대 → `movement() == 2`(견인 속도 상한)
- [경계] 사람 3명 + 투석기 → `movement() == 0`(견인 인력 부족)
- [경계] 사람 4명(이동력 1) + 투석기 → `movement() == 1`(사람이 더 느리면 min)
- [정상] 투석기 추가는 `vision()`·`attack_range()`·`members`에 영향 없음(인구 비소모)
- [정상] `siege_fire_range()`/`siege_min_range()`/`siege_attack()` — 공성 유닛 없으면 0, 투석기 실으면 각각 5/4/50
- [정상] 충차 실으면 `siege_fire_range()==1`, `siege_min_range()==1`, `siege_attack()==90`
- [정상] 사람 4명 + 충차 1대 → `movement() == 1`(충차 견인 속도); [경계] 사람 3명 + 충차 → `movement() == 0`
- [정상] `siege_can_bombard(kind)` — 공성 유닛 없으면 전부 false; 투석기만 → unit·wall·gate 참; 충차만 → gate만 참(unit·wall 거짓); 혼합 → 셋 다 참
- [정상] `prune_destroyed_siege()` — `hit_points ≤ 0`인 투석기를 `siege_units`에서 제거하고 제거 수 반환; hp > 0은 유지. [경계] 파괴 없으면 0 반환·불변

**영지 완성 건물 판정(순수)** — `test/unit/test_territory.gd`:
- [정상] 완성된 `siege_workshop`이 있으면 `has_completed_building("siege_workshop") == true`
- [경계] 건설 중 작업장만 있으면 `false`; 작업장 없으면 `false`

**공성 작업장 종류** — `test/unit/test_building_types.gd`:
- [정상] `CATALOG`에 `siege_workshop` 존재(label "공성 작업장", footprint 1, prerequisite "town_hall")
- [정상] `BUILDABLE_IDS`에 `"siege_workshop"` 포함

*(공성 유닛 생산 버튼 테스트는 [생산 제거](#획득--생산-제거됨-재구축-예정)와 함께 삭제됨.)*

**투석 메뉴 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `party_actions(..., can_bombard=true)` → 목록에 `{id="catapult"}` 포함([장비] 앞)
- [경계] `can_bombard=false` → `catapult` 없음

**성벽 내구도 상태** — `test/unit/test_building.gd`: → [Wall 테스트 시나리오](wall.md#테스트-시나리오)
- [정상] 생성 직후 `wall_hp == 0`; 설정 가능; `upgrade_to` 후 `wall_hp` 유지

투석 선택 모드(`MODE_BOMBARD`)·`_bombard_targets`(밴드 4~5 내 성벽 거점+적 부대), **성벽/적 부대 모두** → `_bombard_wall`/`_begin_battle`(battle.gd 통합 전투, `include_siege`·성벽은 구조물 전투원), `battle.gd`의 투석기·성벽 구조물 전투원 스폰·발사(광역·flat 피해·적 투석기 우선·성벽 항상 명중)·**투석기 피격·파괴**(hp 소진 시 `_kill`)·hp/wall_hp 이월 반영·붕괴, 전투 후 `prune_destroyed_siege`·정보 갱신, `[투석]` 행동 노출, 성벽 링 내구도 색, 작업장 건축, 정보 패널 표시, **충차·성문(성문 표적 클릭→`_bombard_gate`가 battle.gd `target_gate` 전투로 `gate_hp` 차감·0이면 통로 개방, 방어 거점 타격 시 `_apply_ram_counter`로 충차 반격·`prune_destroyed_siege`, `breached_by`/`wall_blocked_cells`가 `gate_broken()` 통로 반영, 성벽 건설 시 `gate_hp=GATE_MAX_HP`)**, **NPC 투석 운용 AI(`_npc_unit_act`·`NpcPlanner.siege_target_for`)·밴드 유지 타깃팅(`NpcPlanner.targets_for`의 band 티어·`_siege_band_cells`)·NPC↔NPC 투석(`NpcPlanner.siege_target_for`·`_siege_band_cells`의 적 세력 성벽·부대 확장, NPC 성벽은 `_npc_bombard_wall_headless`로 헤드리스 정산·붕괴, NPC 부대는 `_resolve_battle_headless`가 양측 `siege_units`를 BattleSim 볼리에 넘겨 상호 포격·`prune_destroyed_siege`)**은 실제 실행으로 확인한다. **단 공성 병기 생성 경로가 제거돼 위 운용·NPC 로직은 현재 휴면**(코드만 잔존). *(순수 판정은 `in_fire_band`·`total_bombard_damage`·`bombard_pick` + BattleSim 볼리 시드 테스트로 커버.)*

## 관련

- [Party (부대)](../entities/Party.md) — `siege_units`·견인 이동. [SiegeUnits (공성 유닛 카탈로그)](../data/siege-units.md) — `SiegeTypes`·투석기 값(`fire_range`). [Buildings](../data/buildings.md) — 공성 작업장(소비처 없음). [Camp Capture](../features/camp-capture.md) — 주둔·생산 제거. [Wall / 성벽](../features/wall.md) — [성벽 내구도](../features/wall.md#성벽-내구도-buildingwall_hp--siege)(투석 대상)·사다리 공성. [Party Action Menu](../features/party-action-menu.md) — `[투석]` 행동. [Building](../entities/Building.md) — `wall_hp`.
- 기획: 공성 로드맵 슬라이스 5(공성병기).
