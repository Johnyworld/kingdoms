# Feature: Squad Command (부대 지휘 — 따라옴 · 전투 스탠스)

> 스크립트: `scenes/party/command_menu.gd` (`CommandMenu`) · `scenes/party/party.gd` (`command_follow`·`command_engage`) · `scenes/game/game.gd` (`_command_follow`, `_settle_after_move`, `_subordinates_of`, `_can_command_subordinates`) · `scenes/game/hex_grid.gd` (`follow_destination`)

랑그릿사식 편제에서 **영웅부대**([Party](../entities/Party.md) `KIND_HERO`)는 자신에 [소속](party-lord.md)된 **하위부대**(`lord == 영웅`)의 **지휘 방식을 지속 설정**한다. 설정은 영웅부대에 저장되고 **턴이 바뀌어도 유지**된다. 플레이어는 [부대 정보 패널](party-info.md)의 **[지휘] 버튼**으로 연다.

(이전의 one-shot 작전 메뉴 — 이동 직후 뜨던 추종/대기/교전/돌격 — 은 **삭제**됐다. 다중 클릭 이동([Selection & Movement](selection-and-movement.md))과 양립하지 않아 지속 설정으로 대체했다.)

## 지휘 설정 (영웅부대 저장, 지속)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 추종 방식 | `command_follow` | `false`(직접명령) | `true`=**따라옴**(하위부대가 영웅 이동마다 자동 추종), `false`=**직접명령**(자동 이동 없음, 플레이어가 하위부대를 직접 조작) |
| 전투 스탠스 | `command_engage` | `false`(전투회피) | `true`=**전투우선**(따라오다 사거리 안에 적이 들면 그 자리에서 교전), `false`=**전투회피**(이동만). **따라옴일 때만** 의미 있다 |

- **기본값은 직접명령 + 전투회피** — 새 게임 시작 시 하위부대는 자동으로 움직이지 않는다. 플레이어가 [지휘]로 따라옴을 켜야 자동 추종이 시작된다.
- 두 값은 **`reset_turn()`에서 리셋되지 않는다**(지속 설정).

## [지휘] 메뉴 (`CommandMenu`)

[소속 모달](party-lord.md)과 같은 공용 [Modal](modal.md) 기반. 토글 2줄:

- **추종**: `[따라옴]` · `[직접명령]` — 현재 값인 쪽 버튼은 비활성(선택 표시). 누르면 `hero.command_follow` 설정 → `changed` 방출.
- **전투**: `[전투우선]` · `[전투회피]` — 현재 값인 쪽 비활성. 누르면 `hero.command_engage` 설정 → `changed` 방출.
- 턴 소비 없음(순수 설정). `game.gd`가 `changed`를 받아 정보 패널([지휘] 버튼 상태)을 갱신한다.

`CommandMenu` API:
| 함수/시그널 | 설명 |
| --- | --- |
| `open(hero) -> void` | 그 영웅의 현재 설정을 읽어 토글을 그리고 모달을 연다 |
| `changed` (signal) | 설정을 바꾼 뒤 방출 |

## 발동 흐름 (`game.gd`)

플레이어가 **영웅부대**를 [이동](selection-and-movement.md)시키면, 그 영웅이 **따라옴**(`command_follow`)이고 이번 턴 명령 가능한 하위부대(`can_move()`)가 있을 때 **영웅 토큰이 출발하는 그 시점에**(`_start_player_move` 안에서) 하위부대 트레일도 함께 출발한다(`_launch_follow`). 전투우선이면 영웅 도착 후 교전 시퀀스(`_settle_after_move`→`_engage_followers`)가 이어진다.

- **from_cell**: 영웅이 이번 이동에서 출발한 칸(`_move_from_cell`, 이동 시작 시 저장). 진행 방향(전방 링) 판정에 쓴다.
- **직접명령**이면 아무것도 하지 않는다(하위부대 자동 이동 없음).

### 영웅과 **동시 이동**(시차) — `_launch_follow` (+ 전투우선 `_engage_followers`)

**영웅과 하위부대가 함께 움직인다.** 영웅 이동을 클릭하면(`_start_player_move`) 영웅 토큰이 출발하는 **바로 그때** 하위부대 트레일도 함께 출발한다 — 영웅이 먼저(딜레이 0), 하위부대는 `FOLLOW_STAGGER` 간격으로 조금씩 늦게(시차) 출발해 한 무리로 이동한다. 하위부대는 영웅의 **목적지(`dest`) 주변 링**을 향한다(영웅이 아직 걸어가는 중이라 도착 칸 기준).

- **대상**: `_subordinates_of(hero)` 중 `can_move()`. 이동력 큰 순으로 처리해 빠른 부대가 진행 방향 **전방** 링을 먼저 차지하고, 배정 칸·영웅 도착 칸을 예약해 겹치지 않는다(`HexGrid.follow_destination`, `from_cell`=영웅 출발 칸).
- **이동력 소모**: 걸어간 경로의 **누적비용만큼 `spend_movement`**(영웅과 같은 풀). 다 쓰면 다음 영웅 이동엔 못 따라온다.
- **비차단 트레일**(두 스탠스 공통): `_start_follow_animation`(`FOLLOW_STAGGER` 간격)로 launch. 영웅 다중 클릭이 끊기지 않는다. 새 이동을 또 명령하면 이전 트레일을 스냅(`_finish_pending_follow_moves`)하고 다시 launch. 턴 종료 시에도 스냅.
- **전투우선(`command_engage`) 교전**: 영웅이 도착하면(`_settle_after_move`) `_engage_followers`가 `_command_busy`로 입력을 잠그고 **트레일이 다 끝나길 기다린 뒤**, 각 하위부대가 **사거리 안에 적**(`NpcPlanner.adjacent_enemy`)이 있고 전력이 신중 기준 이상(`NpcAi.should_engage`)이면 순차로 **교전**(근접=붙어서·승리 시 점령, 원거리=제자리 사격). 중단은 `_game_over`. 전투회피는 교전 없이 트레일만.
- **ESC 정지**: 영웅 이동 중 ESC로 멈추면 하위부대 트레일도 현재 위치에 멈춘다(`_stop_follow_trails`).

### API (`game.gd`)

- `_subordinates_of(hero) -> Array` — `lord == hero`·멤버 있는 하위부대.
- `_can_command_subordinates(hero) -> bool` — 위 중 `can_move()`가 하나라도 있는지([지휘] 버튼 노출·즉시 추종 발동 조건).
- `_launch_follow(hero, hero_dest, from_cell) -> void` — 영웅 목적지 링으로 비차단 스태거 트레일 출발(영웅과 동시). 이전 트레일은 스냅 후 재launch.
- `_engage_followers(hero) -> void`(async) — 전투우선: 트레일 완료 대기 후 사거리 적 순차 교전(입력 잠금).
- `_finish_pending_follow_moves()` / `_stop_follow_trails()` — 트레일 턴 종료 스냅 / ESC 현재 위치 정지.

## 추종 목적지 판정 (`HexGrid.follow_destination`)

```
static func follow_destination(terrain, hero_cell, from_cell, follower_cell, move_range, map_w, map_h, blocked_cells := {}, cell_costs := {}, blocked_edges := {}, no_stop_cells := {}) -> Vector2i
```

하위부대(`follower_cell`)가 영웅(`hero_cell`)을 따라갈 **목적지 칸**을 고른다. 노드 비의존 순수 함수. `from_cell`은 영웅의 이번 이동 출발 칸(진행 방향 기준).

- **아군 통과**: `_launch_follow`는 **적 부대만 `blocked_cells`(완전 차단)**, **다른 하위부대·영웅·예약 목적지는 `no_stop_cells`(통과 O·정지 X)** 로 넘긴다. 그래서 하위부대끼리 서로를 벽으로 막지 않고 뚫고 지나가 링에 도달한다(예전엔 서로를 완전 차단해 **가끔 갇혀 안 따라오던** 문제 — 해결). `no_stop_cells`는 `movement_ranges`에 그대로 전달돼 `move` 후보에서만 제외된다.
- **후보**: `follower_cell`(제자리) + `movement_ranges(...).move`(도달 가능 칸, no_stop 제외). 산·`blocked_cells`·`hero_cell` 제외.
- **링 우선**: 도달 가능한 영웅 인접 칸 중 **진행 방향(`hero_cell − from_cell`) 내적이 큰**(가장 앞선) 칸, 동률이면 하위부대에서 가까운 칸. `from_cell == hero_cell`(방향 없음)이면 가까운 링 칸.
- **접근 폴백**: 도달 가능한 링 칸이 없으면 영웅 지형 거리(`bfs_distances`) 최소 칸(동률 시 근접). 더 못 가까워지면 제자리.

이 판정은 **NPC 이동 계획**도 재사용한다([NPC 편제 — 하위부대 영웅 추종](npc-movement.md), 지휘 범위 내 적은 교전). NPC는 이 지휘 설정 UI와 무관하게 항상 영웅을 추종한다.

## 적용 대상

- **[지휘] 설정 UI는 플레이어 전용**이다. **NPC 하위부대는 자동으로 영웅을 추종**(항상 따라옴)하며 지휘 범위 내 적은 교전한다([NPC 편제](npc-movement.md)) — `follow_destination`을 NPC 이동 계획이 재사용한다.

## 미구현

- 대기(방어 자세) 스탠스 — 삭제됨(직접명령이 대체). 방어 버프는 후속.
- 돌격(어택무브 목표 지정) — 삭제됨. `HexGrid.attack_move_stop`도 제거.
- 소속 부대 지휘 버프(영웅 근처) — [Party Lord](party-lord.md)와 별개 후속.

## 테스트 시나리오

### 지휘 설정 지속 — `test/unit/test_party.gd`

- [정상] 생성 직후 `command_follow == false`(직접명령), `command_engage == false`(전투회피)
- [정상] `command_follow`/`command_engage`를 `true`로 두고 `reset_turn()` 해도 **유지**(리셋 대상 아님)

### [지휘] 메뉴 — `test/unit/test_command_menu.gd`

- [정상] `open(hero)` → 모달 열림(`is_open()`), 현재 설정에 맞는 토글 4버튼
- [정상] [따라옴] 누르면 `hero.command_follow == true`, `changed` 방출; [직접명령]이면 `false`
- [정상] [전투우선]/[전투회피] 누르면 `hero.command_engage` 토글, `changed` 방출
- [정상] 현재 값인 쪽 버튼은 비활성(선택 표시)

### 추종 목적지 판정 — `test/unit/test_hex_grid.gd` (실제 헥스 TileMapLayer)

- [정상] 하위부대가 영웅에서 3칸·이동력 넉넉(방향 없음) → **영웅 인접(거리 1)** 링 칸, 결과는 `hero_cell`이 아님
- [정상] **진행 방향(서→동)** 이고 링 전체 도달 → **전방(동쪽) 링 칸**(월드 x가 영웅보다 큼)
- [경계] 이동력 부족(이동력 1, 영웅과 4칸) → 링 못 닿음 → 영웅에 더 가까워지는 칸으로 접근
- [점유] 전방 링 칸이 `blocked_cells`로 막힘 → 다른 도달 가능 링 칸; 인접 전부 막히면 인접 밖 최근접
- [아군통과] 링 칸이 `no_stop_cells`(아군·예약)면 그 칸엔 못 멈추고 다른 도달 가능 링 칸(통과는 가능 — 하위부대끼리 안 막힘)
- [경계] 완전히 갇힘(사방 점유/산) → 제자리(`follower_cell`)

### 발동·연출 (실행 확인)

`_settle_after_move`의 따라옴 발동·비차단 트레일·전투우선 시퀀스·입력 잠금·턴 종료 스냅은 씬 트리·전투 오버레이 의존이라 실제 실행으로 확인한다.

- 영웅 [지휘]→[따라옴] 설정 후 영웅을 클릭 이동 → 하위부대가 **영웅과 동시에(시차 두고, 영웅부터)** 목적지 주변 링으로 이동(전방 우선). 이동력 다 쓴 하위는 뒤처짐. 1기씩 순차가 아니라 한 무리로 움직인다.
- [직접명령]이면 하위부대가 자동으로 안 움직인다(수동 조작).
- [전투우선]이면 따라오다 사거리 안 적을 만나면 자동 교전(입력 잠금), [전투회피]면 이동만.
- 비차단 트레일 도중 턴 종료 → 하위부대가 목적지로 스냅.

## 관련

- [Party (부대)](../entities/Party.md) — `command_follow`·`command_engage`·`lord`. [Party Lord (소속)](party-lord.md). [Party Info](party-info.md) — [지휘]·[소속] 버튼. [Selection & Movement](selection-and-movement.md) — 이동·`follow_destination`이 쓰는 BFS. [NPC Movement](npc-movement.md) — NPC 자동 추종.
