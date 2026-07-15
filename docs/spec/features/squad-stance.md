# Feature: Squad Stance (부대 작전 — 이동 후 하위부대 명령)

> 스크립트: `scenes/party/party_action_menu.gd` (`stance_actions`) · `scenes/game/game.gd` (`_open_stance_menu`, `_resolve_stance`, `_stance_hero`, `_follow_with_lord`, `_subordinates_of`, `_finish_pending_follow_moves`) · `scenes/game/hex_grid.gd` (`follow_destination`)

랑그릿사식 편제에서 **영웅부대**([Party](../entities/Party.md) `KIND_HERO`)를 이동시키면, 그 영웅에 [소속](party-lord.md)된 **하위부대**(`lord == 영웅`)에게 이번 턴 **작전(스탠스)** 을 지정한다. 지휘관만 움직이고 예하 부대는 명령 한 번으로 일괄 통솔하는 편의 기능이다.

- **이동 직후 매번 선택**(one-shot): 영웅 이동이 끝나면 **작전 메뉴**가 떠서 그 턴의 하위부대 행동을 고른다. 스탠스는 부대에 저장하지 않는다(지속 설정 아님).
- **영웅 하위 전체 일괄**: 고른 작전은 그 영웅의 **모든 소속 하위부대**에 함께 적용된다.
- 이 기능이 이전의 `auto_follow` 토글(단일 on/off)을 **대체**한다.

## 스탠스 종류

| id | 라벨 | 동작 | 상태 |
| --- | --- | --- | --- |
| `st_follow` | 추종 | 하위부대가 영웅 목적지 인접 빈 칸으로 따라온다(아래 [추종](#추종-st_follow)). | **구현** |
| `st_hold` | 대기 | 하위부대는 제자리에 머문다(이동·턴 소비 없음). 방어 버프는 `미구현`. | **구현** |
| `st_engage` | 교전 | 보이는 적 중 최근접으로 접근해, 사거리 안이면 교전(근접은 붙어서, 원거리는 제자리 사격). 불리하면(`should_engage`) 접근만. | **구현**(Slice 2a) |
| `st_charge` | 돌격 | 공통 목표 1지점을 찍으면 그 방향으로 어택무브 — 경로 상에서 사거리 안에 적이 들어오는 첫 지점에 멈춰 **무조건 교전**(공격적, `should_engage` 없음). 스타 "어택땅". | **구현**(Slice 2b) |

메뉴 순서: `[추종][대기][교전][돌격]`.

## 발동 흐름 (`game.gd`)

플레이어가 **영웅부대**를 [이동](selection-and-movement.md)시켜 이동 애니메이션이 끝나면(`_after_move`, 전투가 아닌 순수 이동), 그 영웅에 **이번 턴 명령 가능한 하위부대**(멤버 있고 `can_move()`인 `lord == 영웅` 부대)가 하나라도 있으면 **작전 메뉴**를 연다.

1. `_after_move(null)`: `party.is_hero()`이고 명령 가능한 하위부대가 있으면 `_open_stance_menu(party)`(→ `_stance_hero = party`), 아니면 기존대로 `_select()`(영웅 행동 메뉴).
2. `_open_stance_menu(hero)`: `PartyActionMenu.stance_actions()` 버튼을 영웅 토큰 근처에 띄운다.
3. 플레이어가 스탠스를 고르면 `_on_party_action`이 `_stance_hero != null`을 먼저 보고 `_resolve_stance(id)`로 처리한다.
   - **추종(`st_follow`)** → `_follow_with_lord(hero, 영웅 현재 칸)`.
   - **대기(`st_hold`)** → 아무것도 안 한다(하위부대 제자리).
   - **교전(`st_engage`)** → `await _engage_with_lord(hero)`(아래 [교전](#교전-st_engage)). 여러 부대가 순차로 접근·전투하는 비동기 시퀀스.
   - **돌격(`st_charge`)** → `_charge_hero = hero`로 두고 **목표 지정 모드**에 들어간다(아래 [돌격](#돌격-st_charge)). 메뉴를 닫고 다음 맵 클릭을 기다린다(즉시 복귀하지 않음).
   - 처리 후(추종·대기·교전) `_stance_hero = null`, 작전 메뉴를 닫고, 영웅이 아직 행동 가능하면(`can_rest()`) `_select()`로 **영웅 자신의 이동 후 메뉴**([사격]·[대기])로 복귀한다(교전은 시퀀스가 끝난 뒤). 돌격은 목표를 찍고 시퀀스가 끝난 뒤 복귀한다.
4. **클릭 잠금**: 작전 메뉴가 떠 있는 동안(`_stance_hero != null`)·교전 시퀀스 중(`_stance_busy`)은 새 좌클릭(맵 이동·선택)을 무시한다. **단 돌격 목표 지정 중(`_charge_hero != null`)은 좌클릭이 목표 선택으로 라우팅**된다(`_pick_charge_target`). 카메라·줌은 항상 가능.
5. **대기 중 턴 종료·게임 오버**: 스탠스를 고르기 전(`_stance_hero`)이나 돌격 목표 지정 중(`_charge_hero`)에 턴을 넘기거나(`_on_turn_ended`) 게임 오버(`_trigger_game_over`)가 나면, 두 상태를 모두 비우고 메뉴를 닫아 취소한다 — 다음 턴에 클릭이 잠기거나 목표 지정 모드가 남지 않게.

### 추종 (`st_follow`)

`_follow_with_lord(hero, hero_cell)` — 하위부대들을 영웅 칸(`hero_cell`) 주변 빈 칸으로 따라오게 한다.

- **대상**(`_subordinates_of(hero)`): `lord == hero`이고 멤버 있는 부대.
- **가능한 부대만**: `can_move()`인 부대만 이동(이미 이동/공격했거나 주둔 중이면 건너뜀).
- **목적지**: 영웅 칸에 인접한 도달 가능 빈 칸(자신에게 가장 가까운 칸). 못 닿으면 이동력 내 **최대한 접근**. 판정은 `HexGrid.follow_destination`(아래).
- **겹침 방지**: 하나씩 순차 배정하며 배정된 목적지·영웅 칸을 예약(차단)해 서로 다른 칸으로 흩어진다.
- **턴 소비**: 따라 움직인 부대는 `mark_moved()`. 이미 최선 위치(인접)면 이동·소모 없이 남는다.
- **연출**: [이동 애니메이션](selection-and-movement.md#이동-애니메이션-gamegd-_animate_path)(`_animate_path`, 칸당 `MOVE_STEP_TIME`)으로 걸어가며 도착 칸마다 `_update_fog()`. 여러 부대는 `FOLLOW_STAGGER` 간격 순차 출발. **추종 트윈(`_follow_tweens`)이 사는 동안 좌클릭 잠금**(영웅 이동 `_player_moving`과 동일).
- **턴 종료 스냅**: 추종 중 턴이 끝나면(`_on_turn_ended`) `_finish_pending_follow_moves()`가 트윈을 죽이고 각 부대를 목적지로 스냅.

### 교전 (`st_engage`)

`_engage_with_lord(hero)`(async) — 하위부대들을 **하나씩 순차로** 가까운 적에게 접근시키고, 사거리 안이면 전투를 벌인다. 전투 오버레이가 모달(`_run_battle`의 `_in_battle`)이라 한 부대씩 `await`한다. 기존 NPC 공격 페이즈(`_npc_attack_phase`)와 같은 원리·같은 전투 경로를 재사용한다.

각 하위부대(`can_move()`)에 대해:
1. **대상**: 보이는 적 부대 칸(`_visible_enemy_cells(hero.faction_name)` — 세력 다르고 멤버 있고 `visible`, 적 세력 성벽 안 수비대 제외).
2. **접근**: `NpcAi.choose_destination(...)`로 가장 가까운 적 방향의 도달 칸을 골라 이동(더 가까워질 수 없으면 제자리). 이동하면 `mark_moved()` + `await _move_party_await(f, path)`(칸당 애니메이션 + 시야 개방).
3. **교전 판정**: 이동/제자리 후 `_adjacent_enemy(f)`(사거리 `max(attack_range,1)` 내 적)가 있고 `NpcAi.should_engage(내 전력, 적 전력)`(전력 ≥ 0.7배)이면 전투. 불리하면 접근만(전투 없음).
4. **전투**: `f.mark_attacked()` 후 `await _run_battle(f, target, dist, occupy)`. `dist = _engagement_distance(f, target)` — **1(근접)이면 승리 시 적 칸 점령(`occupy = 적 칸`), 2+(원거리 사격)이면 점령 없음(`(-1,-1)`)**. 원거리 무기 부대는 사거리 안이면 붙지 않고 제자리 사격이 된다.

- **입력 잠금**: 교전 시퀀스 동안 `_stance_busy = true` — 턴 종료(`_on_turn_ended`)와 맵 좌클릭을 막는다(전투 사이 이동 구간 포함). 전투 중은 `_in_battle`이 함께 막는다. 시퀀스가 끝나면 `false`. 카메라·줌은 가능.
- **중단**: 시퀀스 도중 `_game_over`가 되면 루프를 멈춘다.
- **턴 소비**: 접근한 부대는 `mark_moved`, 전투한 부대는 `mark_attacked`. 접근도 전투도 없던 부대(더 못 가까워지고 인접 적도 없음)는 턴을 그대로 둔다(수동 조작 가능).

### 돌격 (`st_charge`)

**어택무브**("어택땅"): 하위부대들이 플레이어가 찍은 **공통 목표 1지점** 방향으로 전진하다가, 경로 상에서 사거리 안에 적이 들어오는 **첫 지점에서 멈춰 무조건 교전**한다. 교전과 달리 `should_engage`(신중) 판정이 없다 — 돌격은 확실한 공격 명령이다.

**목표 지정 모드**:
- `[돌격]` 선택 → `_charge_hero = hero`, 작전 메뉴 닫힘. 힌트로 **하위부대 도달 범위(파랑 오버레이)** 를 표시한다(`overlay.show_ranges(하위부대 이동범위 합집합, [])`).
- 목표 지정 대기 중에는 **다음 맵 좌클릭이 목표 선택**으로 라우팅된다(`_pick_charge_target`). 카메라·줌은 가능.
- **영웅 칸을 클릭하면 취소**(돌격 안 함, 영웅 메뉴로 복귀). 목표 지정 중 **턴 종료·게임 오버**도 `_charge_hero`를 비우고 취소한다.

**`_charge_with_lord(hero, target_cell)`(async)** — 하위부대(`can_move()`)마다 순차로:
1. **접근 경로**: 목표 방향 도달 칸(`NpcAi.choose_destination(..., [target_cell])`) → `reconstruct_path`로 경로.
2. **정지 지점**: `HexGrid.attack_move_stop(terrain, path, 보이는 적 칸, reach, ...)` — 경로에서 사거리(`reach = max(attack_range,1)`) 안에 적이 들어오는 첫 칸 인덱스. `stop >= 1`이면 거기까지만 이동(`path[0..stop]`, `mark_moved` + `await _move_party_await`). `stop == 0`(이미 사거리 내)이면 이동 없음.
3. **교전**: `_adjacent_enemy(f)`가 있으면 **무조건** `mark_attacked` + `await _run_battle(f, target, dist, occ)`(근접=점령, 원거리=제자리 사격). 경로에 적이 없었으면 목표 근처까지 이동만 하고 끝.
- 입력 잠금(`_stance_busy`)·중단(`_game_over`)·턴 소비 규칙은 교전과 동일.

### 적용 대상

- 추종 로직(`follow_destination`)은 세력 무관하게 동작하지만, **작전 메뉴·발동 배선은 현재 플레이어 이동 경로에만** 붙는다. NPC 영웅부대의 작전 발동은 `미구현`.

## 추종 목적지 판정 (`HexGrid.follow_destination`)

```
static func follow_destination(terrain, hero_cell, follower_cell, move_range, map_w, map_h, blocked_cells := {}) -> Vector2i
```

하위부대(`follower_cell`)가 영웅(`hero_cell`)을 따라갈 **목적지 칸**을 고른다. 노드 비의존 순수 함수(테스트 용이).

- **후보**: `follower_cell`(제자리) + `movement_ranges(...).move`(이번 이동력으로 도달 가능한 칸). 지형(산)·`blocked_cells`(점유·예약 칸)는 도달 계산에서 제외.
- **순위**: 각 후보를 **영웅으로부터의 지형 거리**(`bfs_distances(hero_cell, ...)`, 산만 제외·유닛 무관)가 **작은 순**으로. 동률이면 **하위부대로부터 가까운 순**(`movement_ranges`의 `dist`).
- `hero_cell` 자체는 **절대 고르지 않는다**(영웅이 설 칸). 인접 빈 칸이 도달 가능하면 그 칸(거리 1), 아니면 도달 가능한 칸 중 영웅에 가장 가까운 칸.
- 더 가까워질 수 없으면(이미 인접·완전히 갇힘) `follower_cell`(제자리)을 반환한다 → 호출부는 이동을 생략한다.

## 어택무브 정지 판정 (`HexGrid.attack_move_stop`)

```
static func attack_move_stop(terrain, path, enemy_cells, reach, map_w, map_h) -> int
```

돌격 어택무브의 **정지 지점**을 고른다. 노드 비의존 순수 함수(테스트 용이).

- `path`를 순서대로 훑어, 그 칸에서 **`reach` 헥스 이내**(`cells_within`)에 `enemy_cells`의 적이 있는 **첫 인덱스**를 반환한다 → 거기서 멈춰 교전.
- 시작 칸(index 0)에서 이미 사거리 안이면 `0`(이동 없이 교전).
- 경로 내내 사거리 안에 적이 없으면 `path.size() - 1`(끝까지 이동). 빈 경로면 `0`.
- `reach`는 부대 사거리(`max(attack_range, 1)`) — 근접(1)은 적에 인접해지는 칸, 원거리(≥2)는 적이 사거리 안에 **처음 들어오는 경로 칸**에서 멈춘다(정확한 최대 사거리 유지가 아니라 "경로를 따라가다 사거리에 든 첫 지점"이다). 지형/시야 차단은 보지 않는다(순수 헥스 거리, 기존 `_adjacent_enemy`와 동일 한계).

## API

`PartyActionMenu.stance_actions() -> Array` — 작전 메뉴 버튼(순수, 노드 비의존). `[추종(st_follow), 대기(st_hold), 교전(st_engage), 돌격(st_charge)]`(모두 활성).

`game.gd`:
- `_subordinates_of(hero) -> Array` — `lord == hero`이고 멤버 있는 하위부대 목록.
- `_can_command_subordinates(hero) -> bool` — 위 목록 중 `can_move()`인 부대가 하나라도 있는지(작전 메뉴 노출 조건).
- `_open_stance_menu(hero) -> void` — `_stance_hero`를 세우고 작전 메뉴를 연다.
- `_resolve_stance(id) -> void`(async) — 고른 스탠스를 처리하고(교전은 시퀀스 await, 돌격은 목표 지정 모드 진입) 영웅 행동 메뉴로 복귀.
- `_follow_with_lord(hero, hero_cell) -> void` / `_start_follow_animation(f, path, delay)` / `_finish_pending_follow_moves()` — 추종 이동·애니메이션·턴 종료 스냅.
- `_engage_with_lord(hero) -> void`(async) — 교전 시퀀스(접근→사거리 내 전투, 부대별 순차 await).
- `_charge_with_lord(hero, target_cell) -> void`(async) — 돌격 어택무브 시퀀스(목표 방향 접근→정지 지점 교전).
- `_pick_charge_target(world_pos) -> void`(async) — 목표 지정 모드에서 맵 클릭을 목표로 잡아 `_charge_with_lord` 실행(영웅 칸 클릭은 취소).
- `_visible_enemy_cells(faction) -> Array` — 보이는 적 부대 칸 목록(성벽 안 수비대 제외). 교전·돌격 대상.
- `_move_party_await(p, path) -> void`(async) — 한 부대를 경로 따라 이동하고 완료까지 await.

## 미구현

- **대기의 방어 버프** — 지금 대기는 제자리 유지만. 방어 자세 보정은 후속.
- **NPC 작전 발동** — 현재 플레이어 이동 경로 전용.
- **소속 부대 지휘 버프**(영웅 근처) — [Party Lord](party-lord.md)와 별개 후속. → [army-overhaul 메모]

## 테스트 시나리오

### 작전 메뉴 버튼 — `test/unit/test_party_action_menu.gd`

- [정상] `stance_actions()` → `[추종(st_follow), 대기(st_hold), 교전(st_engage), 돌격(st_charge)]`(모두 활성)

### 어택무브 정지 판정 — `test/unit/test_hex_grid.gd` (실제 헥스 TileMapLayer)

- [정상] 경로 중간 칸에 인접한 적(reach 1) → 그 칸 인덱스에서 정지
- [정상] 경로 어디에도 사거리 내 적 없음 → 마지막 인덱스(끝까지)
- [경계] 시작 칸이 이미 사거리 내 → `0`(이동 없이 교전)
- [정상] 원거리 reach 2 → 근접(1)보다 한 칸 일찍 정지

### 추종 목적지 판정 — `test/unit/test_hex_grid.gd` (실제 헥스 TileMapLayer)

- [정상] 하위부대가 영웅에서 3칸, 이동력 넉넉 → **영웅에 인접(거리 1)** 한 칸
- [정상] 결과 칸은 영웅 칸(`hero_cell`)이 아니다
- [경계] 이미 영웅에 인접 → 제자리(`follower_cell`)
- [경계] 이동력 부족(예: 이동력 1, 영웅과 4칸) → 인접 아니어도 **영웅에 더 가까워지는** 칸
- [점유] 영웅 인접 칸 일부가 `blocked_cells`로 막힘 → 막힌 칸 회피, 남은 인접 빈 칸
- [점유] 영웅 인접 칸 전부 막힘 → 인접 밖이라도 도달 가능한 가장 가까운 칸으로 접근
- [경계] 완전히 갇힘(사방 점유/산) → 제자리(`follower_cell`)

### 발동·연출 (실행 확인)

작전 메뉴 노출·`_resolve_stance`·하위부대 순회·예약·애니메이션·턴 종료 스냅·클릭 잠금은 씬 트리·터레인 의존이라 실제 실행으로 확인한다.

- 하위부대 있는 영웅부대 이동 → 작전 메뉴 [추종][대기][교전][돌격].
- [추종] → 하위부대들이 영웅 주변 빈 칸으로 흩어져 따라오고 흐리게(이동 완료) 표시. 이미 행동/주둔한 부대는 안 따라옴. 이동력 부족하면 최대 접근.
- [대기] → 하위부대 제자리, 영웅 행동 메뉴([사격]/[대기])로 복귀.
- [교전] → 하위부대들이 하나씩 가까운 적으로 접근, 사거리 안이면 근접/사격 전투(불리하면 접근만). 시퀀스 동안 맵 클릭·턴 종료 잠김, 끝나면 영웅 메뉴로 복귀.
- [돌격] → 하위부대 도달 범위(파랑) 표시 + 목표 지정 대기. 맵 한 지점 클릭 → 하위부대들이 그 방향으로 전진하다 사거리 내 적을 만나면 정지·무조건 교전. 영웅 칸 클릭 시 취소.
- 추종 도중 턴 종료 → 하위부대들이 목적지 칸으로 스냅.
- 하위부대 없는(또는 전부 행동 완료) 영웅부대 이동 → 작전 메뉴 없이 바로 영웅 행동 메뉴.
- 교전·돌격 시퀀스는 씬·전투 오버레이·NPC AI 의존이라 순수 단위 테스트가 아닌 실행으로 확인한다(재사용하는 `NpcAi.should_engage`·`choose_destination`·`HexGrid.attack_move_stop`는 단위 테스트가 커버).

## 관련

- [Party (부대)](../entities/Party.md) — `lord`(소속). [Party Lord (소속 영웅)](party-lord.md) — 하위부대 소속 설정.
- [Party Action Menu](party-action-menu.md) — 작전 메뉴 버튼(`stance_actions`)·영웅 행동 메뉴. [Selection & Movement](selection-and-movement.md) — 이동·경로·애니메이션·`follow_destination`이 쓰는 BFS.
