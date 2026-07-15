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

`_follow_with_lord(hero, hero_cell, from_cell)` — 하위부대들을 영웅 칸(`hero_cell`) **주변 링(인접 6칸)** 으로 대형 지어 따라오게 한다. 지휘관을 한 줄로 뒤쫓지 않고 **둘러싸며**, 빠른 부대는 진행 방향 **앞**에 선다.

- **대상**(`_subordinates_of(hero)`): `lord == hero`이고 멤버 있는 부대.
- **가능한 부대만**: `can_move()`인 부대만 이동(이미 이동/공격했으면 건너뜀).
- **처리 순서**: 하위부대를 **이동력 큰 순**으로 정렬해 처리한다 → 빠른 부대가 **진행 방향 전방** 링 타일을 먼저 차지하고, 느린 부대가 측면·후방을 채운다("앞설 수 있으면 앞서도록"). 순차 배정하며 배정 칸·영웅 칸을 예약(차단)해 겹치지 않는다.
- **목적지**: 영웅 칸에 인접한 도달 가능 빈 칸(**링**) 중, **진행 방향(from_cell→hero_cell)** 으로 가장 앞선 칸. 링에 못 닿으면 이동력 내 **최대한 접근**(기존 동작). 판정은 `HexGrid.follow_destination`(아래).
- **진행 방향(`from_cell`)**: 영웅이 이번 턴 이동한 출발 칸. 이동 확정 시 `_stance_from_cell`에 저장해 넘긴다. 방향이 없으면(제자리 발동 등) 링 중 자신에게 가까운 칸(무방향 분산).
- **앞서는 거리**: 링(인접 1칸)까지만 — 전방 인접 타일이 최대(2칸+ 과도 전진 없음).
- **턴 소비**: 따라 움직인 부대는 `mark_moved()`. 이미 최선(가장 앞선 링) 위치면 이동·소모 없이 남는다.
- **연출**: [이동 애니메이션](selection-and-movement.md#이동-애니메이션-gamegd-_animate_path)(`_animate_path`, 칸당 `MOVE_STEP_TIME`)으로 걸어가며 도착 칸마다 `_update_fog()`. 여러 부대는 `FOLLOW_STAGGER` 간격 순차 출발. **추종 트윈(`_follow_tweens`)이 사는 동안 좌클릭 잠금**(영웅 이동 `_player_moving`과 동일).
- **턴 종료 스냅**: 추종 중 턴이 끝나면(`_on_turn_ended`) `_finish_pending_follow_moves()`가 트윈을 죽이고 각 부대를 목적지로 스냅.

### 교전 (`st_engage`)

`_engage_with_lord(hero)`(async) — 하위부대들을 **하나씩 순차로** 가까운 적에게 접근시키고, 사거리 안이면 전투를 벌인다. 전투 오버레이가 모달(`_run_battle`의 `_in_battle`)이라 한 부대씩 `await`한다. 기존 NPC 공격 페이즈(`_npc_unit_act`)와 같은 원리·같은 전투 경로를 재사용한다.

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

- 추종 로직(`follow_destination`)은 세력 무관하게 동작한다. **작전 메뉴(플레이어가 스탠스를 고르는 UI)는 플레이어 전용**이지만, **NPC 하위부대는 자동으로 영웅을 추종**한다([NPC 편제](npc-movement.md#npc-편제--하위부대-영웅-추종-_move_npcs-이동-계획), 영웅 추종 우선·지휘 범위 내 적은 교전) — `follow_destination`을 NPC 이동 계획이 재사용한다.

## 추종 목적지 판정 (`HexGrid.follow_destination`)

```
static func follow_destination(terrain, hero_cell, from_cell, follower_cell, move_range, map_w, map_h, blocked_cells := {}) -> Vector2i
```

하위부대(`follower_cell`)가 영웅(`hero_cell`)을 따라갈 **목적지 칸**을 고른다. 노드 비의존 순수 함수(테스트 용이). `from_cell`은 영웅의 이번 턴 출발 칸(진행 방향 기준).

- **후보**: `follower_cell`(제자리) + `movement_ranges(...).move`(도달 가능 칸). 지형(산)·`blocked_cells`(점유·예약 칸) 제외. `hero_cell`은 절대 목적지 아님.
- **링 우선**: 도달 가능한 후보 중 **영웅에 인접한 칸(`get_surrounding_cells(hero_cell)`)** 이 있으면 그중에서 고른다.
  - **전방 점수**: 각 링 타일의 월드 위치가 진행 방향(`map_to_local(hero_cell) − map_to_local(from_cell)`)과 이루는 **내적(dot)** 이 **큰 순**(가장 앞선 칸). 동률이면 **하위부대에서 가까운 순**(`movement_ranges`의 `dist`).
  - `from_cell == hero_cell`(방향 없음)이면 전방 점수가 모두 0 → 하위부대에서 가까운 링 타일(무방향, 예약과 함께 분산).
- **접근 폴백**: 도달 가능한 링 타일이 하나도 없으면(멀거나 갇힘) 후보 중 **영웅 지형 거리(`bfs_distances`)가 최소**인 칸(동률 시 하위부대 근접). 더 가까워질 수 없으면 `follower_cell`(제자리).

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
- `_follow_with_lord(hero, hero_cell, from_cell) -> void` — 추종(이동력 큰 순 정렬 → 전방 링 우선 배정). `from_cell`은 영웅 이동 출발 칸(`_stance_from_cell`, 이동 확정 시 저장). / `_start_follow_animation(f, path, delay)` / `_finish_pending_follow_moves()` — 애니메이션·턴 종료 스냅.
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

- [정상] 하위부대가 영웅에서 3칸, 이동력 넉넉(방향 없음) → **영웅에 인접(거리 1)** 한 링 칸
- [정상] 결과 칸은 영웅 칸(`hero_cell`)이 아니다
- [정상] **진행 방향(예: 서→동)** 이고 링 전체 도달 가능 → **전방(동쪽) 링 칸**을 고른다(월드 x가 영웅보다 큼)
- [정상] 이미 최전방 링 칸에 있으면 제자리(`follower_cell`)
- [경계] 방향 없음(`from_cell == hero_cell`)이고 이미 인접 → 제자리
- [경계] 이동력 부족(예: 이동력 1, 영웅과 4칸) → 링 못 닿음 → **영웅에 더 가까워지는** 칸으로 접근
- [점유] 전방 링 칸이 `blocked_cells`로 막힘 → 막힌 칸 회피, 도달 가능한 다른 링 칸
- [점유] 영웅 인접 칸 전부 막힘 → 인접 밖이라도 도달 가능한 가장 가까운 칸으로 접근
- [경계] 완전히 갇힘(사방 점유/산) → 제자리(`follower_cell`)

### 발동·연출 (실행 확인)

작전 메뉴 노출·`_resolve_stance`·하위부대 순회·예약·애니메이션·턴 종료 스냅·클릭 잠금은 씬 트리·터레인 의존이라 실제 실행으로 확인한다.

- 하위부대 있는 영웅부대 이동 → 작전 메뉴 [추종][대기][교전][돌격].
- [추종] → 하위부대들이 영웅 **주변 링으로 대형** 지어 따라오고(한 줄 아님), 빠른 부대가 진행 방향 앞에 선다. 이미 행동한 부대는 안 따라옴. 링에 못 닿으면 최대 접근.
- [대기] → 하위부대 제자리, 영웅 행동 메뉴([사격]/[대기])로 복귀.
- [교전] → 하위부대들이 하나씩 가까운 적으로 접근, 사거리 안이면 근접/사격 전투(불리하면 접근만). 시퀀스 동안 맵 클릭·턴 종료 잠김, 끝나면 영웅 메뉴로 복귀.
- [돌격] → 하위부대 도달 범위(파랑) 표시 + 목표 지정 대기. 맵 한 지점 클릭 → 하위부대들이 그 방향으로 전진하다 사거리 내 적을 만나면 정지·무조건 교전. 영웅 칸 클릭 시 취소.
- 추종 도중 턴 종료 → 하위부대들이 목적지 칸으로 스냅.
- 하위부대 없는(또는 전부 행동 완료) 영웅부대 이동 → 작전 메뉴 없이 바로 영웅 행동 메뉴.
- 교전·돌격 시퀀스는 씬·전투 오버레이·NPC AI 의존이라 순수 단위 테스트가 아닌 실행으로 확인한다(재사용하는 `NpcAi.should_engage`·`choose_destination`·`HexGrid.attack_move_stop`는 단위 테스트가 커버).

## 관련

- [Party (부대)](../entities/Party.md) — `lord`(소속). [Party Lord (소속 영웅)](party-lord.md) — 하위부대 소속 설정.
- [Party Action Menu](party-action-menu.md) — 작전 메뉴 버튼(`stance_actions`)·영웅 행동 메뉴. [Selection & Movement](selection-and-movement.md) — 이동·경로·애니메이션·`follow_destination`이 쓰는 BFS.
