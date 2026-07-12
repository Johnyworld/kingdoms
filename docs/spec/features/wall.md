# Feature: Wall / 성벽 (거점 방어 구조물)

> 스크립트: `scenes/building/building.gd` (`wall_level`·`is_walled`·성벽 그리기) · `scenes/building/building_types.gd` (`WALL_COST`·`can_build_wall`) · `scenes/siege/siege.gd` (`Siege` — 사다리 상수·`push_succeeds`) · `scenes/siege/siege_overlay.gd` (사다리 마커 표시) · `scenes/camp/camp_menu.gd` (`[성벽 건설]` 버튼·`wall_requested`) · `scenes/game/game.gd` (`_on_wall_requested`·이동 차단·표적 제외·`_ladders`·사다리 설치/밀기/통로 돌파)

**마을회관·성**([center](../data/buildings.md#동작) tier ≥ town_hall) 둘레에 세우는 방어 구조물. 성벽이 있으면 **적 부대가 그 거점에 접근(진입·통과)하지 못해**, 중심 [주둔 부대](garrison.md)를 공격하거나 [점령](camp-capture.md)할 수 없다. 성벽을 넘으려면 **[사다리](#사다리-공성-siege-game_gd)**(아래)를 설치해야 한다.

캠프(tier 0)는 성벽을 지을 수 없다(무방비로 남아 점령/공격 가능).

## 성벽 상태 (`Building.wall_level`)

- `Building.wall_level: int` — 기본 `0`(성벽 없음). ≥ 1이면 성벽 있음. *이번 슬라이스는 단일 단계(0/1)만* — 기획의 다단계 벽(통나무/나무/돌/성벽)·성문은 후속.
- `is_walled() -> bool` — `wall_level > 0`. 거점 방어·이동 차단 판정에 쓴다. (비거점 건물엔 성벽을 짓지 않으므로 항상 0.)
- 성벽은 **거점에 붙는 값**이다(별도 씬 노드 아님). 거점 footprint(중심+이웃 6 = 7칸)를 두르는 것으로 본다.

## 성벽 건설 (`camp_menu` `[성벽 건설]` · `game.gd` `_on_wall_requested`)

캠프 메뉴에 **[성벽 건설]** 버튼(`_wall_btn`)을 둔다. 거점 업그레이드 버튼과 같은 패턴(즉시 적용 — 배치 모드 없음).

- **표시 조건**: 연 건물이 거점이고 **tier ≥ town_hall**(마을회관·성)이며 **아직 성벽 없음**(`not is_walled()`). 캠프·이미 성벽 있음·비거점이면 숨김.
- **텍스트**: `"성벽 건설  <비용>"`(예: `"성벽 건설  목재 15 · 석재 10"`). 비용 = `BuildingTypes.WALL_COST`.
- **활성**: 여는 영지가 비용을 감당하면([`can_build_wall`](../data/buildings.md) = tier·자재 확인) 활성, 부족하면 비활성.
- 누르면 `wall_requested(building)` 방출 → `game.gd` `_on_wall_requested`: 영지 자재 차감(`Territory.spend(WALL_COST)`) + `building.wall_level = 1` + 맵 다시 그리기. 갱신된 정보로 캠프 메뉴를 재오픈.

## 이동 차단 (`game.gd`)

- **적 세력 부대**는 성벽 있는 거점의 **footprint 7칸에 진입·통과할 수 없다**(산처럼 완전 장애물). **같은 세력 부대는 자유 통행**(수비대 주둔·출입).
- 세력 상대적 — 부대 P의 이동 범위·경로 계산 시, **P의 세력과 다른** walled 거점들의 footprint를 막는 칸(`blocked_cells`)에 더한다([Selection & Movement](selection-and-movement.md) 유닛 점유와 같은 `HexGrid` 인자 재사용). 플레이어·NPC 이동 모두 반영.

## 공격·점령 차단 (`game.gd`)

성벽으로 접근이 막히므로, 성벽 있는 **적 거점**은 이번 슬라이스에서 공격·점령 대상이 아니다.

- **점령 제외**: `_compute_camp_targets`가 walled 적 거점은 점령 대상에서 뺀다(무방비여도 성벽이 있으면 진입 불가).
- **표적 제외**: walled 적 거점 footprint 안에 있는 부대(중심 주둔 수비대)는 근접·사격 표적에서 제외한다(`_compute_attack_targets`·NPC `_adjacent_enemy`) — 성벽이 안쪽을 보호한다.
- 결과: 성벽 있는 마을회관·성은 **사다리·공성병기(후속 슬라이스)** 없이는 함락 불가.

## 맵 표시 (`building.gd` `_draw`)

- 성벽 있는 거점은 중심 둘레(footprint 경계)에 **성벽 링**을 그린다(간단한 선/색). 캠프·성벽 없는 거점은 그리지 않는다.

## 사다리 공성 (`Siege` · `game.gd`)

성벽을 넘는 공성 수단. 공격자가 성벽 면에 사다리를 세워 3턴 뒤 **통로**를 열면, 그 세력이 성벽 안으로 진입해 [기존 전투·점령](camp-capture.md)으로 함락한다. 방어자는 **[사다리 밀기]**로 저지한다.

- **사다리 레코드** (`game.gd._ladders` 리스트): `{building, target_cell(대상 ring 셀), from_cell(공격자 셀), faction(공격 세력), countdown}`. 한 거점에 **여러 면(ring 셀)에 각각** 허용하되, **한 면(target_cell)엔 하나만**(같은 면 중복 적층 방지 — 밀기 회피 악용 차단).
- **상수** (`Siege`): `LADDER_TURNS = 3`(설치 후 준비까지), `LADDER_PUSH_CHANCE = 0.15`(밀기 파괴 확률).

### 설치 (플레이어)

- 아군 부대가 **성벽 있는 적 거점 footprint에 인접**(바깥 셀에서 ring 셀에 붙음)하고 이번 턴 미행동이면 [행동 메뉴](party-action-menu.md)에 **[사다리 설치]**(`can_place_ladder`).
- 선택 → 붙은 ring 셀(사다리 없는 면) 하나를 `target_cell`로, 부대 칸을 `from_cell`로 사다리 생성(`countdown = LADDER_TURNS`). 설치는 그 부대 **행동 종료**(`mark_attacked`). 인접 면이 모두 사다리면 [사다리 설치]는 뜨지 않는다.

### 타이머

- 매 [턴](turn.md) 종료(`_on_turn_ended`)마다 모든 사다리 `countdown -= 1`(하한 0). `countdown == 0`이면 **준비 완료**(통로 열림).

### 사다리 밀기 (방어)

- 성벽 안 **주둔 방어 부대**([Garrison](garrison.md))의 행동 메뉴에, 자기 거점을 겨눈 사다리가 있으면 **[사다리 밀기]**(`can_push_ladder`).
- 발동 → 그 거점의 **각 사다리를 독립 판정**: `Siege.push_succeeds(rng.randf())`(roll < `LADDER_PUSH_CHANCE`)면 그 사다리 제거. 밀기는 방어 부대 **행동 종료**. **NPC 방어자는 공격 페이즈에서 자동 밀기**(사다리 있을 때).
- *(「고리 사다리」 아이템으로 밀기 확률 감소는 [슬라이스 4](#미구현))*

### 통로 돌파 (breach)

- **준비 완료(`countdown == 0`)** 사다리는 그 `faction`에게 **`target_cell`(ring) + 거점 `center_cell()`**의 성벽 차단을 해제한다(`_wall_blocked_cells`가 그 두 칸을 그 세력엔 막지 않음). 나머지 footprint는 여전히 차단 = **방향 제한**(사다리 통로로만 진입).
- 이후 그 세력은 통로로 진입해 중심 [주둔 수비대와 전투](battle.md)·[점령](camp-capture.md)한다 — **기존 이동·전투·점령 재사용**. 준비된 사다리가 있으면 walled 거점도 공격·점령 대상 판정(`_camp_defender`/표적 제외)에서 그 세력에겐 열린다.
- 거점이 **점령·파괴**되면 그 거점의 사다리를 모두 제거한다.

## 이번 슬라이스 제외 (미구현)

- **NPC 공세** — NPC가 플레이어 성벽에 사다리를 설치·돌파하는 AI는 `미구현`(슬라이스 3b). 이번엔 플레이어 공성 + NPC 방어(밀기)만.
- **「고리 사다리」 아이템** — 소지 시 방어자 밀기 성공 확률 −5%p는 `미구현`(슬라이스 4). `push_succeeds`의 `markup` 인자로 훅만 마련.
- **오르기 애니메이션**·다단계 벽·성문·성벽/사다리 내구도·NPC의 성벽 건설.

## 테스트 시나리오

**성벽 상태** — `test/unit/test_building.gd`:
- [정상] 생성 직후 `wall_level == 0`, `is_walled() == false`
- [정상] `wall_level = 1` → `is_walled() == true`; 설정 가능
- [정상] `upgrade_to`(티어 교체) 후에도 `wall_level` 유지

**성벽 건설 가능 판정** — `test/unit/test_building_types.gd`:
- [정상] `WALL_COST == {목재15, 석재10}`(자재 Dictionary)
- [정상] `can_build_wall(territory, building)` — 마을회관·성 + 자재 충분 → 참
- [경계] 캠프(tier 0) → 거짓(성벽 불가); 이미 성벽 있음 → 거짓; 자재 부족 → 거짓

**성벽 건설 버튼** — `test/unit/test_camp_menu.gd`:
- [정상] 마을회관 거점 + 자재 충분 → `[성벽 건설]` 표시·활성, 텍스트에 `"성벽 건설"`·비용 포함
- [경계] 캠프 거점 → `[성벽 건설]` 숨김; 이미 성벽 있는 거점 → 숨김
- [경계] 자재 부족 → 표시하되 비활성
- [정상] 버튼 누르면 `wall_requested(building)` 방출

**사다리 밀기 판정(순수)** — `test/unit/test_siege.gd`:
- [정상] `Siege.LADDER_TURNS == 3`, `Siege.LADDER_PUSH_CHANCE == 0.15`
- [정상] `push_succeeds(0.10)` 참(0.10 < 0.15), `push_succeeds(0.20)` 거짓
- [경계] `push_succeeds(0.15)` 거짓(경계 미만만 성공); `push_succeeds(0.12, 0.05)` 거짓(markup 0.05 → 임계 0.10, 0.12 ≥ 0.10) — 고리 사다리 훅

**사다리 메뉴 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `can_place_ladder=true`(비주둔) → 목록에 `{id="ladder"}` 포함([장비] 앞)
- [경계] `can_place_ladder=false` → `ladder` 없음
- [정상] 주둔 + `can_push_ladder=true` → 목록에 `{id="push_ladder"}` 포함
- [경계] 주둔 + `can_push_ladder=false` → `push_ladder` 없음

`game.gd`의 자재 차감·`wall_level` 설정·적 이동 차단·표적 제외, 그리고 **사다리 설치·타이머·통로 돌파·밀기 배선**(씬 트리·터레인 의존)은 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Garrison / 주둔](garrison.md) — 성벽 안 중심 주둔 부대·[사다리 밀기]. [Camp Capture](camp-capture.md) — 성벽 있으면 점령 불가(사다리 통로로만). [Building](../entities/Building.md) — `wall_level`. [Camp Menu](camp-menu.md) — [성벽 건설] 버튼. [Party Action Menu](party-action-menu.md) — [사다리 설치]/[사다리 밀기]. [Selection & Movement](selection-and-movement.md) — 이동 차단(`blocked_cells`).
- 기획: [건물](../../table/세력/건물.md)(벽·성벽·성문 라인) · 공성 로드맵 슬라이스 3b(NPC 공세)·4(고리 사다리 아이템).
