# Feature: Wall / 성벽 (거점 방어 구조물)

> 스크립트: `scenes/building/building.gd` (`wall_level`·`is_walled`·성벽 그리기) · `scenes/building/building_types.gd` (`WALL_COST`·`can_build_wall`) · `scenes/siege/siege.gd` (`Siege` — 사다리 상수·`push_succeeds`) · **`scenes/siege/siege_system.gd`** (`SiegeSystem` — 사다리 레코드 `ladders`·설치/밀기/카운트다운/통로·성벽 차단 `wall_blocked_cells`·돌파 `breached_by`·붕괴 `collapse_wall`) · `scenes/siege/siege_overlay.gd` (사다리 마커 표시) · `scenes/camp/camp_menu.gd` (`[성벽 건설]` 버튼·`wall_requested`) · `scenes/game/game.gd` (`_on_wall_requested`·행동 종료·오버레이 갱신·전투 연출)

**계층 분리**: `Siege`(순수 static — 상수·확률 판정) ← `SiegeSystem`(공성 도메인 — 사다리 상태·규칙. 월드는 game.gd의 `all_buildings`/`party_on_cell` 조회 인터페이스로만 읽어 테스트에서 스텁으로 대체 — `test_siege_system.gd`) ← `game.gd`(실행·연출 — `mark_attacked`·사다리 오버레이 갱신·토스트·전투 오버레이). game.gd의 `wall_blocked_cells`/`breached_by`는 SiegeSystem 위임(NpcPlanner 월드 조회 겸용).

**마을회관·성**([center](../data/buildings.md#동작) tier ≥ town_hall) 둘레에 세우는 방어 구조물. 성벽이 있으면 **적 부대가 그 거점에 접근(진입·통과)하지 못해**, 중심 [방어 부대](camp-capture.md#거점-방어-창발--중심-점거)를 공격하거나 [점령](camp-capture.md)할 수 없다. 성벽을 넘으려면 **[사다리](#사다리-공성-siege-game_gd)**(아래)를 설치해야 한다.

캠프(tier 0)는 성벽을 지을 수 없다(무방비로 남아 점령/공격 가능).

## 성벽 상태 (`Building.wall_level`)

- `Building.wall_level: int` — 기본 `0`(성벽 없음). ≥ 1이면 성벽 있음. *이번 슬라이스는 단일 단계(0/1)만* — 기획의 다단계 벽(통나무/나무/돌/성벽)·성문은 후속.
- `is_walled() -> bool` — `wall_level > 0`. 거점 방어·이동 차단 판정에 쓴다. (비거점 건물엔 성벽을 짓지 않으므로 항상 0.)
- 성벽은 **거점에 붙는 값**이다(별도 씬 노드 아님). 거점 footprint(중심+이웃 6 = 7칸)를 두르는 것으로 본다.

## 성벽 건설 (`camp_menu` `[성벽 건설]` · `game.gd` `_on_wall_requested`)

캠프 메뉴에 **[성벽 건설]** 버튼(`_wall_btn`)을 둔다. 거점 업그레이드 버튼과 같은 패턴(즉시 적용 — 배치 모드 없음).

- **표시 조건**: 연 건물이 거점이고 **tier ≥ town_hall**(마을회관·성)이며 **아직 성벽 없음**(`not is_walled()`). 캠프·이미 성벽 있음·비거점이면 숨김.
- **텍스트**: `"성벽 건설  <비용>"`(예: `"성벽 건설  목재 15 · 철 5"`). 비용 = `BuildingTypes.WALL_COST`.
- **활성**: 여는 영지가 비용을 감당하면([`can_build_wall`](../data/buildings.md) = tier·자재 확인) 활성, 부족하면 비활성.
- 누르면 `wall_requested(building)` 방출 → `game.gd` `_on_wall_requested`: 영지 자재 차감(`Territory.spend(WALL_COST)`) + `building.wall_level = 1` + 맵 다시 그리기. 갱신된 정보로 캠프 메뉴를 재오픈.

## 이동 차단 (`game.gd`)

- **적 세력 부대**는 성벽 있는 거점의 **footprint 7칸에 진입·통과할 수 없다**(산처럼 완전 장애물). **같은 세력 부대는 자유 통행**(수비대 출입).
- 세력 상대적 — 부대 P의 이동 범위·경로 계산 시, **P의 세력과 다른** walled 거점들의 footprint를 막는 칸(`blocked_cells`)에 더한다([Selection & Movement](selection-and-movement.md) 유닛 점유와 같은 `HexGrid` 인자 재사용). 플레이어·NPC 이동 모두 반영.

## 공격·점령 차단 (`game.gd`)

성벽으로 접근이 막히므로, 성벽 있는 **적 거점**은 이번 슬라이스에서 공격·점령 대상이 아니다.

- **점령 제외**: `_compute_camp_targets`가 walled 적 거점은 점령 대상에서 뺀다(무방비여도 성벽이 있으면 진입 불가).
- **표적 제외**: walled 적 거점 footprint 안에 있는 부대(중심 방어 부대)는 근접·사격 표적에서 제외한다(`_compute_attack_targets`·NPC `NpcPlanner.adjacent_enemy`) — 성벽이 안쪽을 보호한다.
- 결과: 성벽 있는 마을회관·성은 **[사다리](#사다리-공성-siege--gamegd) 통로 돌파** 또는 **[투석](siege-engines.md#투석-공성-성벽)으로 성벽을 부수기** 전에는 함락 불가.

## 성벽 내구도 (`Building.wall_hp` · `Siege`)

성벽은 [투석기](siege-engines.md)의 [투석](siege-engines.md#투석-공성-성벽)으로 부술 수 있다. 성벽에 내구도를 두고, 투석 피해가 쌓여 0이 되면 붕괴한다.

- `Building.wall_hp: int` — 기본 `0`. 성벽 건설 시(`wall_level = 1`) `Siege.WALL_MAX_HP`(180)로 채운다(`game.gd._on_wall_requested`). `is_walled()`는 `wall_level`만 본다 — **붕괴는 `wall_level`을 0으로 내려 처리**하므로 내구도와 무관하게 일관된다.
- **상수·헬퍼**(`Siege`): `WALL_MAX_HP = 180`, `DAMAGE_VARIANCE = 0.4`(±40% 랜덤). 투석 1발 피해는 투석기 공격력([`SiegeTypes.attack`](../data/siege-units.md) = 50)에 랜덤을 준 **`rolled_damage(base_attack, roll) -> int`**(roll 0~1 → `base × (1−0.4 .. 1+0.4)`, 즉 **30~70·평균 50**)로 계산한다 → 성벽 180은 **평균 3~6발에 붕괴**. `wall_after_hit(hp, dmg) -> int`(= `max(0, hp − dmg)`), `wall_broken(hp) -> bool`(= `hp <= 0`).
- 투석 피해는 **다른 공격처럼 랜덤성**을 가진다(고정값 아님). 유닛도 위협하도록 무기 기본 공격력(검 14~모닝스타 19)보다 크게 잡았다 — 유닛 대상 적용은 [유닛 투석 5b](siege-engines.md#공성병기-로드맵).
- **붕괴**: 투석으로 `wall_hp`가 0이 되면(`wall_broken`) 그 거점을 **성벽 없음**(`wall_level = 0`·`wall_hp = 0`)으로 되돌리고 그 거점의 [사다리를 모두 제거](#통로-돌파-breach)(`_clear_ladders`)한다. 이후 `is_walled() == false`라 [이동 차단](#이동-차단-gamegd)·[공격·점령 차단](#공격점령-차단-gamegd)이 자동으로 풀려 **기존 점령·공격 흐름이 열린다**(추가 배선 없음).
- **맵 표시**(`building.gd`): 성벽 링을 `wall_hp / WALL_MAX_HP` 비율로 색 보간해 그린다 — 온전(회색) → 손상(붉게). 붕괴하면 성벽 없음이라 링을 그리지 않는다.

## 성문 (Gate)

성벽에는 **성문**이 하나 있다 — 성벽의 지정된 약점/입구. 성벽 전체를 무너뜨리는 대신, 성문만 부수면 **그 면으로 진입**할 수 있다. [충차](siege-engines.md#충차-근접-성문-파쇄)가 성문 전담 파쇄 병기다.

- `Building.gate_cell() -> Vector2i` — 성문이 놓인 면. footprint 이웃 6칸(ring) 중 **결정론적으로 한 칸**(각도순 정렬 첫 칸). 위치 고정(성벽 유무·내구도와 무관하게 같은 칸).
- `Building.gate_hp: int` — 기본 `0`. 성벽 건설 시(`wall_level = 1`) `Siege.GATE_MAX_HP`(120)로 채운다(`wall_hp`와 함께). [충차·투석](siege-engines.md#충차-근접-성문-파쇄)으로 깎인다.
- `Building.gate_broken() -> bool` — `is_walled() and gate_hp <= 0`. 성문이 부서져 통로가 열렸는지.
- **상수**(`Siege`): `GATE_MAX_HP = 120`(성벽 180보다 약함 — 성문은 약점). 성문 피해는 성벽과 같은 `rolled_damage(attack, roll)` → 충차(90)로 **평균 2발**, 투석기(50)로 ~3발.
- **타격**: [BOMBARD](siege-engines.md#충차-근접-성문-파쇄)에서 `gate_cell`을 표적으로 친다. 충차는 **성문만**(근접·`targets=["gate"]`), 투석기는 **성벽·성문 둘 다**(`["unit","wall","gate"]`). 성문 타격은 성벽과 같은 [battle.gd 구조물 전투원](siege-engines.md#battlegd-통합-전투--투석기구조물-전투원) 전투를 쓰되 `gate_hp`를 깎는다(`target_gate`).
- **돌파**: `gate_hp`가 0이 되면(`gate_broken`) **성벽은 그대로 두고** `gate_cell` + 중심만 통로로 연다([통로 돌파](#통로-돌파-breach)). 진입·점령은 사다리 통로와 동일 흐름. 성벽 전체 붕괴(투석기 vs `wall_hp`)와 달리 성벽 링은 남는다.

## 맵 표시 (`building.gd` `_draw`)

- 성벽 있는 거점은 중심 둘레(footprint 경계)에 **성벽 링**을 그린다(간단한 선/색). 캠프·성벽 없는 거점은 그리지 않는다.
- **성문**: `gate_cell` 방향 링 구간을 다른 색(내구도 비율)으로 강조한다. `gate_broken`이면 열린 표시.

## 사다리 공성 (`Siege` · `game.gd`)

성벽을 넘는 공성 수단. 공격자가 성벽 면에 사다리를 세우고 **그 자리를 3턴 지키면** **통로**가 열려, 그 세력이 성벽 안으로 진입해 [기존 전투·점령](camp-capture.md)으로 함락한다. 자리를 떠나면 공성이 멈춘다([타이머](#타이머-공성-유지)). 방어자는 **[사다리 밀기]**로 저지한다.

- **사다리 레코드** (`SiegeSystem.ladders` 리스트): `{building, target_cell(대상 ring 셀), from_cell(공격자 셀), faction(공격 세력), countdown, hooked}`. 한 거점에 **여러 면(ring 셀)에 각각** 허용하되, **한 면(target_cell)엔 하나만**(같은 면 중복 적층 방지 — 밀기 회피 악용 차단). `hooked`=설치 시 [고리 사다리](../data/items.md#도구-itemtypestools) 소모로 세운 사다리(밀기 확률 감소).
- **상수** (`Siege`): `LADDER_TURNS = 3`(설치 후 준비까지), `LADDER_PUSH_CHANCE = 0.15`(밀기 파괴 확률), `HOOKED_PUSH_REDUCTION = 0.05`(고리 사다리 밀기 확률 감소분).

### 설치 (플레이어)

- 아군 부대가 **성벽 있는 적 거점 footprint에 인접**(바깥 셀에서 ring 셀에 붙음)하고 이번 턴 미행동이면 [행동 메뉴](party-action-menu.md)에 **[사다리 설치]**(`can_place_ladder`).
- 선택 → 붙은 ring 셀(사다리 없는 면) 하나를 `target_cell`로, 부대 칸을 `from_cell`로 사다리 생성(`countdown = LADDER_TURNS`). 설치는 그 부대 **행동 종료**(`mark_attacked`). 인접 면이 모두 사다리면 [사다리 설치]는 뜨지 않는다.
- **[고리 사다리](../data/items.md#도구-itemtypestools) 소모**: 설치 부대가 `grapple_ladder`를 `loot_items`에 가지고 있으면 설치 시 **1개 소모**하고 그 사다리를 `hooked = true`로 만든다(없으면 `hooked = false`). NPC는 고리 사다리를 사지 않아 항상 `false`.

### 설치 (NPC 공성 AI · `_npc_unit_act`)

- NPC 로빙 부대는 공격 페이즈에서 **① 인접 적 부대 전투 → ② 인접 무방비/돌파 거점 흡수 → ③ 인접 성벽 적 거점에 빈 면 있으면 사다리 설치** 순으로 행동한다(`_npc_place_ladder`). 설치는 그 NPC의 **행동 종료**.
- **전력 판단 없이** 인접 시 빈 면에 설치한다(실제 수비대 공격은 돌파 후 기존 `should_engage`가 게이트). 밀려 사라지면 다음 턴 인접 시 재설치.
- NPC 거점은 캠프(성벽 없음)라 실제로는 **NPC가 플레이어 성벽 거점을 공성**하는 흐름이다. 접근은 기존 [NPC 이동](npc-movement.md) 타깃(`camp_entries`)이 성벽 거점을 포함해 자연히 인접까지 온다.

### 타이머 (공성 유지)

- 매 [턴](turn.md) 종료(`_on_turn_ended` → `_advance_ladders`)마다, 사다리가 **유지(manned)되고 있을 때만** `countdown -= 1`(하한 0). `countdown == 0`이면 **준비 완료**(통로 열림). `Siege.advance_ladder_countdown(countdown, manned)`.
- **유지 판정**(`SiegeSystem.ladder_manned`): 사다리의 **`from_cell`(설치 위치)에 그 사다리 세력(`faction`)의 부대가 서 있으면** 유지 중. 부대가 그 자리를 지켜야 공성 단계가 진행된다.
- **이동하면 정지**: 부대가 `from_cell`을 떠나면 유지가 끊겨 카운트가 **줄지 않고 멈춘다**(리셋은 아님 — 다시 지키면 이어서 진행). 적 부대가 그 칸을 뺏어도(세력 불일치) 정지 — 성벽 밖 요격으로 공성을 늦추는 창발.
- **재사용**: 유지 판정은 특정 부대가 아니라 **세력·위치 기준**이라, 설치한 부대가 떠나고 **같은 세력 다른 부대가 `from_cell`에 도착**하면 그 사다리를 이어서 공성할 수 있다.
- 준비 완료(0) 이후에는 유지와 무관하게 통로가 열린 채 유지된다(`advance_ladder_countdown(0, ·) == 0`).

### 사다리 밀기 (방어)

- 성벽 안 **중심을 점거한 방어 부대**([거점 방어](camp-capture.md#거점-방어-창발--중심-점거))의 행동 메뉴에, 자기 거점을 겨눈 사다리가 있으면 **[사다리 밀기]**(`can_push_ladder`). *(예전엔 주둔 부대 전용이었으나, [주둔 제거](camp-capture.md)로 "자기 거점 중심 점거" 조건으로 바뀜.)*
- 발동 → 그 거점의 **각 사다리를 독립 판정**: `Siege.push_succeeds(rng.randf(), markup)`. `markup`은 그 사다리가 `hooked`면 `HOOKED_PUSH_REDUCTION`(0.05, 임계 0.10), 아니면 0(임계 0.15). roll < 임계면 그 사다리 제거. 밀기는 방어 부대 **행동 종료**. **NPC 방어자는 공격 페이즈에서 자동 밀기**(사다리 있을 때).

### 통로 돌파 (breach)

돌파 경로는 두 가지다: **사다리**(준비 완료된 면) 또는 **성문 파괴**(`gate_broken`). 둘 다 `wall_blocked_cells`가 해당 통로 칸의 차단을 풀고, `breached_by`가 참이 되어 [공격·점령](camp-capture.md)이 열린다.

- **성문 통로**: `gate_broken`이면 **모든 적 세력**에게 `gate_cell` + 중심의 차단을 해제한다(성문은 물리적으로 열린 것 — 세력 무관). `_breached_by(b, faction)`는 사다리 통로 **또는** `b.gate_broken()`이면 참.
- **준비 완료(`countdown == 0`)** 사다리는 그 `faction`에게 **`target_cell`(ring) + 거점 `center_cell()`**의 성벽 차단을 해제한다(`wall_blocked_cells`가 그 두 칸을 그 세력엔 막지 않음). 나머지 footprint는 여전히 차단 = **방향 제한**(사다리 통로로만 진입).
- 이후 그 세력은 통로로 진입해 중심 [방어 부대와 전투](battle.md)·[점령](camp-capture.md)한다 — **기존 이동·전투·점령 재사용**. 준비된 사다리가 있으면 walled 거점도 공격·점령 대상 판정에서 그 세력에겐 열린다:
  - 플레이어: `_compute_camp_targets`가 `breached_by`면 점령 대상에 포함.
  - NPC: `NpcPlanner.adjacent_enemy_camp`가 `breached_by`면 흡수 대상에 포함(그 전엔 성벽 거점 제외).
- 거점이 **점령·파괴**되면 그 거점의 사다리를 모두 제거한다.

## 이번 슬라이스 제외 (미구현)

- **오르기 애니메이션**·다단계 벽·NPC의 성벽 건설·NPC의 고리 사다리 사용.
- **NPC의 성문 공격 AI**(NPC가 충차로 플레이어 성문을 부수는 흐름) — 후속. NPC 수비대의 성문 방어(플레이어 충차 반격)는 [충차 반격](siege-engines.md#충차-근접-성문-파쇄)으로 처리됨.

## 테스트 시나리오

**성벽 상태** — `test/unit/test_building.gd`:
- [정상] 생성 직후 `wall_level == 0`, `is_walled() == false`, `wall_hp == 0`
- [정상] `wall_level = 1` → `is_walled() == true`; 설정 가능
- [정상] `wall_hp` 설정 가능(예: 180); [정상] `upgrade_to`(티어 교체) 후에도 `wall_level`·`wall_hp` 유지

**성문 상태** — `test/unit/test_building.gd`:
- [정상] `gate_cell()`은 footprint ring 6칸 중 하나(중심 아님), 반복 호출에 **동일**(결정론적)
- [정상] 생성 직후 `gate_hp == 0`, `gate_broken() == false`
- [정상] `wall_level = 1` + `gate_hp = 0` → `gate_broken() == true`(성벽 있고 성문 0)
- [경계] `wall_level = 0` + `gate_hp = 0` → `gate_broken() == false`(성벽 없으면 성문 무의미)
- [정상] `wall_level = 1` + `gate_hp = 120` → `gate_broken() == false`

**성벽 건설 가능 판정** — `test/unit/test_building_types.gd`:
- [정상] `WALL_COST == {목재15, 철5}`(자재 Dictionary)
- [정상] `can_build_wall(territory, building)` — 마을회관·성 + 자재 충분 → 참
- [경계] 캠프(tier 0) → 거짓(성벽 불가); 이미 성벽 있음 → 거짓; 자재 부족 → 거짓

**성벽 건설 버튼** — `test/unit/test_camp_menu.gd`:
- [정상] 마을회관 거점 + 자재 충분 → `[성벽 건설]` 표시·활성, 텍스트에 `"성벽 건설"`·비용 포함
- [경계] 캠프 거점 → `[성벽 건설]` 숨김; 이미 성벽 있는 거점 → 숨김
- [경계] 자재 부족 → 표시하되 비활성
- [정상] 버튼 누르면 `wall_requested(building)` 방출

**사다리 밀기 판정(순수)** — `test/unit/test_siege.gd`:
- [정상] `Siege.LADDER_TURNS == 3`, `Siege.LADDER_PUSH_CHANCE == 0.15`, `Siege.HOOKED_PUSH_REDUCTION == 0.05`
- [정상] `push_succeeds(0.10)` 참(0.10 < 0.15), `push_succeeds(0.20)` 거짓
- [경계] `push_succeeds(0.15)` 거짓(경계 미만만 성공); `push_succeeds(0.12, 0.05)` 거짓(markup 0.05 → 임계 0.10, 0.12 ≥ 0.10) — 고리 사다리 훅

**사다리 공성 유지 카운트(순수)** — `test/unit/test_siege.gd`:
- [정상] `advance_ladder_countdown(3, true) == 2`(유지 중 −1); `advance_ladder_countdown(1, true) == 0`
- [정상] `advance_ladder_countdown(3, false) == 3`(유지 끊기면 정지 — 리셋 아님)
- [경계] `advance_ladder_countdown(0, true) == 0`·`advance_ladder_countdown(0, false) == 0`(하한 0, 준비 완료 유지)

**성벽 내구도 판정(순수)** — `test/unit/test_siege.gd`:
- [정상] `Siege.WALL_MAX_HP == 180`, `Siege.GATE_MAX_HP == 120`, `Siege.DAMAGE_VARIANCE == 0.4`
- [정상] `rolled_damage(50, 0.0) == 30`, `rolled_damage(50, 1.0) == 70`, `rolled_damage(50, 0.5) == 50`(랜덤 데미지 하한·상한·중앙)
- [정상] `wall_after_hit(180, 50) == 130`; [경계] `wall_after_hit(30, 50) == 0`(하한 0)
- [정상] `wall_broken(0) == true`, `wall_broken(1) == false`; [경계] `wall_broken(-5) == true`
- [경계] 만피 180에 최소 데미지(30)면 6발, 최대 데미지(70)면 3발에 붕괴(평균 3~6발)

**고리 사다리 도구** — `test/unit/test_item_types.gd`:
- [정상] `item_name("grapple_ladder") == "고리 사다리"`, `item_value("grapple_ladder") == 12`, `item_slot("grapple_ladder") == ""`(장착 불가)

**공성 도메인(SiegeSystem, 월드 스텁 주입)** — `test/unit/test_siege_system.gd`:
- [정상] `place_ladder` — 성벽 적 거점 인접 부대가 설치 성공(레코드 {세력, countdown=LADDER_TURNS}), 면당 하나(중복 적층 없음)
- [경계] 아군 성벽엔 `ladder_target_for == {}`(설치 대상 없음)
- [정상] 고리 사다리 소지 설치 → `loot_items`에서 1개 소모 + `hooked` 사다리
- [정상] manned 상태로 `advance_ladders` × LADDER_TURNS → 통로 개방(대상 면+중심), `breached_by` 참(그 세력만)
- [경계] 설치 부대가 자리를 뜨면(unmanned) 카운트다운 정지
- [정상] `wall_blocked_cells` — 자기 세력 0칸 / 적 세력 footprint 전체, 준비된 사다리 통로 2칸 개방
- [정상] 부서진 성문(`gate_hp 0`) → 모든 세력에 돌파·성문 면+중심 개방
- [정상] `clear_ladders`·`push_ladders`는 대상 거점 사다리만 건드린다
- [정상] `collapse_wall` — 내구도 0이면 wall_level 0 + 사다리 정리 + true / 내구도 남으면 false·불변
- [정상] `bombard_wall_headless` — 내구도 감소, 소진 시 붕괴까지 처리
- [정상] `ram_counter` — 충차(min_range 1)만 반격 피해(투석기 무피해), 파괴 수 반환·prune, 충차 없으면 no-op

**도구 구매** — `test/unit/test_camp_menu.gd`:
- [정상] 부대 + 금 충분 → 구매 패널 「도구」 행에서 고리 사다리 [구매] → 부대 `loot_items`에 `grapple_ladder`

**사다리 메뉴 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `can_place_ladder=true` → 목록에 `{id="ladder"}` 포함([장비] 앞)
- [경계] `can_place_ladder=false` → `ladder` 없음
- [정상] `can_push_ladder=true` → 목록에 `{id="push_ladder"}` 포함
- [경계] `can_push_ladder=false` → `push_ladder` 없음

`game.gd`의 자재 차감·`wall_level` 설정과 **연출 배선(행동 종료·오버레이 갱신·NPC 공성 AI·돌파 후 흡수)**(씬 트리·터레인 의존)은 실제 실행으로 확인한다. *(공성 도메인 자체 — 설치·타이머(유지 판정 `ladder_manned`)·통로·차단·밀기 — 는 `test_siege_system.gd`가 월드 스텁으로, 순수 판정은 `test_siege.gd`가 커버.)*

## 관련

- [Camp Capture](camp-capture.md#거점-방어-창발--중심-점거) — 성벽 안 중심 방어 부대·[사다리 밀기], 성벽 있으면 점령 불가(사다리 통로로만). [Building](../entities/Building.md) — `wall_level`. [Camp Menu](camp-menu.md) — [성벽 건설] 버튼. [Party Action Menu](party-action-menu.md) — [사다리 설치]/[사다리 밀기]. [Selection & Movement](selection-and-movement.md) — 이동 차단(`blocked_cells`).
- 기획: [건물](../../table/세력/건물.md)(벽·성벽·성문 라인) · 공성 로드맵 슬라이스 3b(NPC 공세)·4(고리 사다리 아이템).
