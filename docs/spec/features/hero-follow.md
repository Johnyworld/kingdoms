# Feature: Hero Follow (영웅부대 하위부대 자동 추종)

> 스크립트: `scenes/party/party.gd` (`auto_follow`) · `scenes/party/party_action_menu.gd` (`party_actions`의 `[자동]`) · `scenes/game/game.gd` (`_on_party_action("auto")`, `_subordinates_of`, `_follow_with_lord`, `_finish_pending_follow_moves`) · `scenes/game/hex_grid.gd` (`follow_destination`)

랑그릿사식 편제에서 **영웅부대**([Party](../entities/Party.md) `KIND_HERO`)는 **자동 추종**을 켤 수 있다. 켜진 영웅부대를 이동시키면, 그 영웅에 [소속](party-lord.md)된 **하위부대**(`lord == 영웅`)들이 **같은 턴에 즉시** 영웅의 목적지 주변으로 자동 이동한다. 소대를 일일이 클릭해 옮기지 않고 영웅만 움직이면 부대가 따라오게 하는 편의 기능이다.

## 토글 — `auto_follow` ([Party](../entities/Party.md))

- **영웅부대**만 갖는 의미 있는 상태. `auto_follow: bool`(기본 `false`). 일반부대에도 필드는 있으나 추종 트리거는 영웅부대에서만 본다.
- [행동 메뉴](party-action-menu.md)의 **[자동]** 버튼으로 켜고 끈다(턴 소비 없음). 상태에 따라 라벨이 `추종 켜기`(꺼짐) / `추종 끄기`(켜짐)로 바뀐다.
- 노출 조건(`game.gd` `_open_action_menu`): **영웅부대**(`party.is_hero()`)이고 주둔 중이 아닐 때. 하위부대 유무와 무관하게 미리 켜 둘 수 있다.

## 추종 발동 — 영웅 이동 직후 (`game.gd`)

플레이어가 **자동 추종이 켜진 영웅부대**를 [이동](selection-and-movement.md)시키면(맵 클릭으로 이동 확정), 이동 애니메이션을 시작한 직후 `_follow_with_lord(hero, hero_dest_cell)`가 하위부대들을 뒤따르게 한다.

- **대상 하위부대**(`_subordinates_of(hero)`): `lord == hero`이고 멤버가 있는 부대. (같은 세력 안에서만 `lord`가 설정되므로 세력은 자동으로 일치한다.)
- **가능한 부대만**(요구사항): 이번 턴 아직 행동 가능(`can_move()`)한 하위부대만 따라온다. 이미 이동/공격했거나 **주둔 중**인 부대는 건너뛴다(그 자리에 남음).
- **각 하위부대 목적지**: 영웅의 **목적지 칸에 인접한 빈 헥스** 중 그 부대가 이번 이동력으로 **도달 가능하고 자신에게 가장 가까운** 칸. 인접 칸에 못 닿으면 **이동력 내에서 영웅 쪽으로 최대한 접근**한 칸(부분 추종). 판정은 `HexGrid.follow_destination`(아래).
- **겹침 방지**: 하위부대를 하나씩 순차 처리하며, 배정된 목적지와 영웅 목적지 칸을 **예약**(차단 셀에 추가)한다. 그래서 여러 하위부대가 영웅 주변 서로 다른 칸으로 흩어진다.
- **턴 소비**: 따라 움직인 하위부대는 `mark_moved()`로 이번 턴 이동을 소모한다(재이동 불가). 이미 최선 위치(영웅에 인접)라 움직일 필요가 없으면 이동·소모 없이 남는다.
- **연출**: 하위부대는 순간이동하지 않고 [이동 애니메이션](selection-and-movement.md#이동-애니메이션-gamegd-_animate_path)(`_animate_path`, 칸당 `MOVE_STEP_TIME`)으로 걸어가며, 도착 칸마다 `_update_fog()`로 시야를 연다. 여러 부대는 `FOLLOW_STAGGER` 간격으로 순차 출발한다.
- **클릭 잠금**: 하위부대 추종 트윈(`_follow_tweens`)이 살아 있는 동안은 영웅 이동(`_player_moving`)과 마찬가지로 새 좌클릭(이동·선택·메뉴)을 무시한다 — 걷는 도중 점유 칸을 오독하거나 겹쳐 보이지 않게. 카메라 이동·줌은 계속 가능.
- **턴 종료 스냅**: 추종 이동 중 턴이 끝나면(`_on_turn_ended`) `_finish_pending_follow_moves()`가 진행 중 추종 트윈을 죽이고 각 부대를 목적지 칸으로 스냅한다(영웅 이동 스냅 `_finish_player_move`와 같은 자리).

### 적용 대상

- **모든 영웅부대**에 `auto_follow` 필드가 있고 추종 로직(`follow_destination`)은 세력 무관하게 동작한다. 다만 **토글 UI와 발동 배선은 현재 플레이어 이동 경로에만** 붙는다. NPC 영웅부대의 자동 추종 발동은 `미구현`(추후 AI가 켜고 NPC 이동에서 호출).

## 추종 목적지 판정 (`HexGrid.follow_destination`)

```
static func follow_destination(terrain, hero_cell, follower_cell, move_range, map_w, map_h, blocked_cells := {}) -> Vector2i
```

하위부대(`follower_cell`)가 영웅(`hero_cell`)을 따라갈 **목적지 칸**을 고른다. 노드 비의존 순수 함수(테스트 용이).

- **후보**: `follower_cell`(제자리) + `movement_ranges(...).move`(이번 이동력으로 도달 가능한 칸). 지형(산)·`blocked_cells`(점유·예약 칸)는 도달 계산에서 제외된다.
- **순위**: 각 후보를 **영웅으로부터의 지형 거리**(`bfs_distances(hero_cell, ...)`, 산만 제외·유닛 무관)가 **작은 순**으로 고른다. 동률이면 **하위부대로부터 가까운 순**(`movement_ranges`의 `dist`)으로 고른다.
- `hero_cell` 자체는 **절대 목적지로 고르지 않는다**(영웅이 설 칸). 영웅에 인접한 빈 칸이 도달 가능하면 그 칸(영웅 거리 1)이 뽑히고, 아니면 도달 가능한 칸 중 영웅에 가장 가까운 칸이 뽑힌다.
- 더 가까워질 수 없으면(이미 인접, 또는 완전히 갇힘) `follower_cell`(제자리)을 반환한다 → 호출부는 이동을 생략한다.

## API

`Party` (`party.gd`):

| 속성/메서드 | 설명 |
| --- | --- |
| `auto_follow` | `bool`, 기본 `false`. 영웅부대의 자동 추종 on/off 상태 |
| `set_auto_follow(v: bool) -> void` | `auto_follow`를 설정한다([자동] 버튼의 단일 출처) |
| `toggle_auto_follow() -> void` | `auto_follow`를 반전한다 |

`PartyActionMenu.party_actions(...)`: 맨 끝에 `can_auto_follow := false, auto_follow_on := false` 인자를 받는다. `can_auto_follow`면 `[장비]` **바로 앞**에 `{id="auto", label = auto_follow_on ? "추종 끄기" : "추종 켜기", enabled=true}`를 넣는다.

`game.gd`:
- `_subordinates_of(hero) -> Array` — `lord == hero`이고 멤버 있는 부대 목록.
- `_follow_with_lord(hero, hero_dest_cell) -> void` — 위 발동 로직(하위부대 순차 추종·예약·애니메이션).
- `_finish_pending_follow_moves() -> void` — 진행 중 추종 트윈을 죽이고 목적지로 스냅(턴 종료 시).
- `_on_party_action("auto")` — `party.toggle_auto_follow()` 후 메뉴 재표시(턴 소비 없음).

## 테스트 시나리오

### 추종 목적지 판정 — `test/unit/test_hex_grid.gd` (실제 헥스 TileMapLayer)

- [정상] 하위부대가 영웅에서 3칸 떨어짐, 이동력 넉넉 → 결과는 **영웅에 인접(거리 1)** 한 칸
- [정상] 결과 칸은 영웅 칸(`hero_cell`)이 아니다
- [경계] 하위부대가 이미 영웅에 인접 → 제자리(`follower_cell`) 반환(더 가까워질 수 없음)
- [경계] 이동력이 부족해 인접 칸에 못 닿음(예: 이동력 1, 영웅과 4칸) → 인접이 아니어도 **영웅에 더 가까워지는**(거리가 주는) 칸 반환
- [점유] 영웅의 인접 칸 일부가 `blocked_cells`로 막힘 → 막힌 칸은 안 고르고, 남은 인접 빈 칸(도달 가능) 중 하나를 고른다
- [점유] 영웅의 인접 칸이 전부 막힘 → 인접 밖이라도 도달 가능한 가장 가까운 칸으로 접근
- [경계] 완전히 갇혀 이동 불가(사방 점유/산) → 제자리(`follower_cell`) 반환

### [자동] 버튼 — `test/unit/test_party_action_menu.gd`

- [정상] `party_actions(false, true, false, ... , can_auto_follow=true, auto_follow_on=false)` → 목록에 `{id="auto", label="추종 켜기"}` 포함(`[장비]` 바로 앞)
- [정상] `auto_follow_on=true` → `{id="auto", label="추종 끄기"}`
- [경계] `can_auto_follow=false` → `[자동]` 없음
- [경계] 주둔 중(`stationed=true`)이면 `can_auto_follow`와 무관하게 `[자동]` 없음

### `auto_follow` 상태 — `test/unit/test_party.gd`

- [정상] 생성 직후 `auto_follow == false`
- [정상] `set_auto_follow(true)` 후 `auto_follow == true`
- [정상] `toggle_auto_follow()` 로 값이 반전(false→true→false)

### 발동·연출 (실행 확인)

`game.gd`의 하위부대 순회·예약·애니메이션·턴 종료 스냅은 씬 트리·터레인 의존이라 실제 실행으로 확인한다.

- 자동 추종 켠 영웅부대를 이동 → 소속 하위부대들이 영웅 주변 빈 칸으로 흩어져 따라오고 흐리게(이동 완료) 표시된다.
- 이미 행동한/주둔 중인 하위부대는 따라오지 않는다.
- 이동력이 부족한 하위부대는 영웅 쪽으로 최대한만 접근한다.
- 추종 도중 턴 종료 → 하위부대들이 목적지 칸으로 스냅된다.

## 관련

- [Party (부대)](../entities/Party.md) — `auto_follow`·`lord`. [Party Lord (소속 영웅)](party-lord.md) — 하위부대 소속 설정.
- [Party Action Menu](party-action-menu.md) — `[자동]` 버튼. [Selection & Movement](selection-and-movement.md) — 이동·경로·애니메이션·`follow_destination`이 쓰는 BFS.
