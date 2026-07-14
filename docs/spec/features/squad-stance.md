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
| `st_engage` | 교전 | 가까운 적에게 자동 접근·교전. | `미구현`(Slice 2) |
| `st_charge` | 돌격 | 공통 목표 1지점을 찍으면 그 방향으로 어택무브(경로 상 적 교전, 스타 "어택땅"). | `미구현`(Slice 2) |

이번 슬라이스(이동계열)는 **추종·대기**만 메뉴에 넣는다. 교전·돌격은 전투 개시를 수반해 별도 슬라이스에서 추가한다([스탠스 계획](#미구현) 메모).

## 발동 흐름 (`game.gd`)

플레이어가 **영웅부대**를 [이동](selection-and-movement.md)시켜 이동 애니메이션이 끝나면(`_after_move`, 전투가 아닌 순수 이동), 그 영웅에 **이번 턴 명령 가능한 하위부대**(멤버 있고 `can_move()`인 `lord == 영웅` 부대)가 하나라도 있으면 **작전 메뉴**를 연다.

1. `_after_move(null)`: `party.is_hero()`이고 명령 가능한 하위부대가 있으면 `_open_stance_menu(party)`(→ `_stance_hero = party`), 아니면 기존대로 `_select()`(영웅 행동 메뉴).
2. `_open_stance_menu(hero)`: `PartyActionMenu.stance_actions()` 버튼을 영웅 토큰 근처에 띄운다.
3. 플레이어가 스탠스를 고르면 `_on_party_action`이 `_stance_hero != null`을 먼저 보고 `_resolve_stance(id)`로 처리한다.
   - **추종(`st_follow`)** → `_follow_with_lord(hero, 영웅 현재 칸)`.
   - **대기(`st_hold`)** → 아무것도 안 한다(하위부대 제자리).
   - 처리 후 `_stance_hero = null`, 작전 메뉴를 닫고, 영웅이 아직 행동 가능하면(`can_rest()`) `_select()`로 **영웅 자신의 이동 후 메뉴**([사격]·[대기])로 복귀한다.
4. **클릭 잠금**: 작전 메뉴가 떠 있는 동안(`_stance_hero != null`)은 새 좌클릭(맵 이동·선택)을 무시한다 — 명령을 고르기 전 맵 조작으로 문맥이 깨지지 않게. 카메라·줌은 가능.
5. **작전 메뉴 대기 중 턴 종료**: 스탠스를 고르기 전에 턴을 넘기면(`_on_turn_ended`) 명령을 취소(대기 취급)하고 `_stance_hero`를 비우며 메뉴를 닫는다 — 다음 턴에 클릭이 잠긴 채 남지 않게. 게임 오버(`_trigger_game_over`)에도 같은 정리를 한다(순수 이동 직후엔 도달 불가지만, 전투 수반 스탠스(Slice 2) 대비 방어).

### 추종 (`st_follow`)

`_follow_with_lord(hero, hero_cell)` — 하위부대들을 영웅 칸(`hero_cell`) 주변 빈 칸으로 따라오게 한다.

- **대상**(`_subordinates_of(hero)`): `lord == hero`이고 멤버 있는 부대.
- **가능한 부대만**: `can_move()`인 부대만 이동(이미 이동/공격했거나 주둔 중이면 건너뜀).
- **목적지**: 영웅 칸에 인접한 도달 가능 빈 칸(자신에게 가장 가까운 칸). 못 닿으면 이동력 내 **최대한 접근**. 판정은 `HexGrid.follow_destination`(아래).
- **겹침 방지**: 하나씩 순차 배정하며 배정된 목적지·영웅 칸을 예약(차단)해 서로 다른 칸으로 흩어진다.
- **턴 소비**: 따라 움직인 부대는 `mark_moved()`. 이미 최선 위치(인접)면 이동·소모 없이 남는다.
- **연출**: [이동 애니메이션](selection-and-movement.md#이동-애니메이션-gamegd-_animate_path)(`_animate_path`, 칸당 `MOVE_STEP_TIME`)으로 걸어가며 도착 칸마다 `_update_fog()`. 여러 부대는 `FOLLOW_STAGGER` 간격 순차 출발. **추종 트윈(`_follow_tweens`)이 사는 동안 좌클릭 잠금**(영웅 이동 `_player_moving`과 동일).
- **턴 종료 스냅**: 추종 중 턴이 끝나면(`_on_turn_ended`) `_finish_pending_follow_moves()`가 트윈을 죽이고 각 부대를 목적지로 스냅.

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

## API

`PartyActionMenu.stance_actions() -> Array` — 작전 메뉴 버튼(순수, 노드 비의존). 이번 슬라이스는 `[{id="st_follow", label="추종", enabled=true}, {id="st_hold", label="대기", enabled=true}]`. 교전·돌격은 Slice 2에서 추가.

`game.gd`:
- `_subordinates_of(hero) -> Array` — `lord == hero`이고 멤버 있는 하위부대 목록.
- `_can_command_subordinates(hero) -> bool` — 위 목록 중 `can_move()`인 부대가 하나라도 있는지(작전 메뉴 노출 조건).
- `_open_stance_menu(hero) -> void` — `_stance_hero`를 세우고 작전 메뉴를 연다.
- `_resolve_stance(id) -> void` — 고른 스탠스를 처리하고 영웅 행동 메뉴로 복귀.
- `_follow_with_lord(hero, hero_cell) -> void` / `_start_follow_animation(f, path, delay)` / `_finish_pending_follow_moves()` — 추종 이동·애니메이션·턴 종료 스냅.

## 미구현

- **교전(`st_engage`)·돌격(`st_charge`)** — 전투 개시를 수반하는 스탠스(Slice 2). 돌격은 공통 목표 1지점 어택무브.
- **대기의 방어 버프** — 지금 대기는 제자리 유지만. 방어 자세 보정은 후속.
- **NPC 작전 발동** — 현재 플레이어 이동 경로 전용.
- **소속 부대 지휘 버프**(영웅 근처) — [Party Lord](party-lord.md)와 별개 후속. → [army-overhaul 메모]

## 테스트 시나리오

### 작전 메뉴 버튼 — `test/unit/test_party_action_menu.gd`

- [정상] `stance_actions()` → `[추종(st_follow), 대기(st_hold)]`(둘 다 활성)
- [경계] 교전·돌격은 이번 슬라이스 메뉴에 없다(id `st_engage`·`st_charge` 미포함)

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

- 하위부대 있는 영웅부대 이동 → 작전 메뉴 [추종][대기].
- [추종] → 하위부대들이 영웅 주변 빈 칸으로 흩어져 따라오고 흐리게(이동 완료) 표시. 이미 행동/주둔한 부대는 안 따라옴. 이동력 부족하면 최대 접근.
- [대기] → 하위부대 제자리, 영웅 행동 메뉴([사격]/[대기])로 복귀.
- 추종 도중 턴 종료 → 하위부대들이 목적지 칸으로 스냅.
- 하위부대 없는(또는 전부 행동 완료) 영웅부대 이동 → 작전 메뉴 없이 바로 영웅 행동 메뉴.

## 관련

- [Party (부대)](../entities/Party.md) — `lord`(소속). [Party Lord (소속 영웅)](party-lord.md) — 하위부대 소속 설정.
- [Party Action Menu](party-action-menu.md) — 작전 메뉴 버튼(`stance_actions`)·영웅 행동 메뉴. [Selection & Movement](selection-and-movement.md) — 이동·경로·애니메이션·`follow_destination`이 쓰는 BFS.
