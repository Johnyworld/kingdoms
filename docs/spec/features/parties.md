# Feature: Parties (부대 배치)

> 스크립트: `scenes/game/game.gd` (`_setup_parties`, `_new_party`, `_nearby_free_cells`) · **`scenes/party/party_manager.gd`** (`PartyManager` — 부대 목록 `units`/`npc_parties` 단일 출처·노드 생성 `new_party`/`make_party`·전멸 반영 `apply_survivors`·세력 소멸 제거·칸 조회) · `scenes/party/unit_spawns.gd`([UnitSpawns]) · `scenes/party/faction_catalog.gd`

**계층 분리**: `PartyManager`(부대 생명주기 — 목록·생성·전멸/소멸 제거·칸 조회. 테스트는 `test_party_manager.gd`) ← `game.gd`(스폰 소비·배치·선택 상태·일람 갱신·패배 확인·연출). game.gd의 `all_parties`/`party_on_cell`은 PartyManager 위임(NpcPlanner·SiegeSystem 월드 조회 겸용). `apply_survivors`는 ALIVE/WIPED_NPC/WIPED_PLAYER를 반환하고, 활성 부대 재할당 등 WIPED_PLAYER 후처리는 game.gd가 한다.

게임 시작 시 [초기 배치 카탈로그](../data/unit-spawns.md)(unit_spawns.csv)대로 [부대](../entities/Party.md)를 생성해 맵에 배치한다. 이름·색·상수는 [FactionCatalog](../data/factions.md), 병종 스탯은 [UnitTypes](../data/unit-types.md)에서 온다.
**랑그릿사식 편제** — 현재 데이터는 각 세력이 **영웅부대 4 + 부하부대 12 = 16부대**로 시작한다(4세력 = 맵 64부대). 편제·좌표는 데이터라 코드 수정 없이 CSV로 조정한다.

## 데이터 기반 스폰 (`_setup_parties`)

[UnitSpawns.entries()](../data/unit-spawns.md)를 순회하며 스폰 entry마다 [부대](../entities/Party.md)를 생성한다:

- **영웅부대**(`type == "hero"` → `kind = KIND_HERO`) — `commander_name = ` [`hero_name`](../data/factions.md)(세력별 영웅 등장 순서 = hero index), `party_name = hero_party_name`, `soldiers = UnitTypes.max_hp("hero")`(클래스 HP 풀). **토큰 색 = 세력 색**(플레이어는 기본 금색).
- **부하부대**(그 외 → `kind = KIND_TROOP`) — `troop_type = ` 병종 아키타입([UnitTypes](../data/unit-types.md)), `soldiers = TROOP_SIZE`(10). **토큰 색 = 세력 색을 약간 어둡게**(`Color.darkened(0.35)`)하여 영웅부대와 구분한다.
- **소속(`leader` → `lord`)**: 부하부대의 `leader`(같은 파일 내 영웅 스폰 id)를 그 부대의 **`lord`(소속 영웅부대)**로 연결하고, 이름을 `"{소속 영웅} {병종}"`으로 확정한다([Party 소속](../entities/Party.md#소속-lord)). 소속돼도 부대는 **독립 토큰으로 자유 이동**한다(소속은 메타데이터 — 버프는 `미구현`).
- **재사용**: 플레이어 세력의 **첫 영웅**만 씬의 기존 `$Party` 노드를 재사용하고, 나머지는 `_new_party()`(PartyManager)로 만든다. 활성 부대(`party`)는 이 첫 영웅.
- **초기 유닛 이후**: 인게임 생산 유닛은 CSV가 아니라 게임 로직이 만드는 런타임 [Party](../entities/Party.md)다(초기 유닛과 동일 자료구조).

## 배치 (절대좌표 + 폴백)

각 스폰의 `x,y`(절대 셀 좌표)에 부대를 놓는다.

- **지정 좌표 우선**: `cell`이 [통과 가능](map-and-camera.md)(산·물 제외)이고 미점유면 그대로 배치한다.
- **안전망 보정**: 통과불가·중복이면 `_nearby_free_cells(cell, 1, occupied)`([BFS](map-and-camera.md))로 인접 빈 칸을 찾아 스냅한다. `occupied`를 스폰 간 누적해 겹치지 않게 한다.
- **거점 방어**: 데이터가 세력마다 **거점 건물 중심 셀**([unit_spawns.csv](../data/unit-spawns.md)의 `{faction}_t0` 좌표)에 유닛 1기를 두어 그 자리를 점거한다(별도 상태 없이 창발적 방어 — [거점 방어](camp-capture.md#거점-방어-창발--중심-점거)). `_camp_defender`는 건물 `center_cell()` 점거로 판정한다.
- 4왕국이 네 모서리 안쪽에 흩어져 시작하므로 세력끼리 멀다. 거점 건물 좌표는 [NPC Bases](npc-bases.md).

## 세력 구분 (플레이어 vs NPC)

- **플레이어 세력**(`PLAYER_ID` = `azel`, 푸른 왕국)의 16부대는 모두 `PartyManager.units`에 넣는다 — **선택·이동·AI·부대 일람** 대상.
- **NPC 3세력**(`NPC_IDS`)의 48부대는 `PartyManager.npc_parties`에 넣는다.
  - **안개 반영** — 플레이어 시야 안일 때만 토큰 표시. NPC는 플레이어 시야를 밝히지 않는다. → [Fog of War](fog-of-war.md).
  - **턴 리셋** — 턴 종료 시 NPC 부대도 `reset_turn`. → [Turn](turn.md).
  - **부대 일람 제외** — 일람은 우리 세력 부대만.
  - **정보 패널** — 보이는 NPC 클릭 시 정보 표시(선택 없음). → [Party Info](party-info.md).
  - **이동·공격** — [NPC Movement](npc-movement.md)·[Lang Battle](lang-battle.md) 공격 페이즈.

## 미구현

- 목표 지향 NPC AI·NPC 영지 확장·유닛 충돌 고도화. *(다음 단계)*
- 소속 부대 버프(영웅 근처 소속 부대). → [Party 소속](../entities/Party.md#소속-lord).
- 64부대 규모의 성능 최적화(안개 합산·NPC AI·헤드리스 전투 루프).

## 테스트 시나리오 — PartyManager (`test/unit/test_party_manager.gd`)

- [정상] `make_party` — host에 노드 부착, 이름/세력/셀 설정, 병력 0으로 시작(목록 등록은 호출부)
- [정상] 칸 조회 — `party_on_cell`/`player_party_at`/`npc_at`(안개 visible 필터)/`all`; 병력 0 부대는 조회 제외
- [정상] `first_living_unit` — 병력 0 부대 건너뛰고 병력 있는 첫 부대
- [정상] `apply_survivors(p, final_soldiers)` — 생존(`p.soldiers` 갱신)=ALIVE / 전멸(`0`) 시 목록 제거·free 예약(WIPED_PLAYER·WIPED_NPC) / 해제된 부대=INVALID
- [정상] `remove_party` — 어느 목록에 있든 제거+free; `eliminate_faction_parties` — 그 세력 NPC 부대만 제거

## 테스트

- 스폰 데이터([UnitSpawns](../data/unit-spawns.md) — `test_unit_spawns.gd`)·데이터 계층([FactionCatalog](../data/factions.md))·[Party](../entities/Party.md) `kind`/`lord`는 단위 테스트로 검증한다.
- `game.gd`의 스폰 소비·배치·`kind`/`lord` 설정·NPC `visible` 토글은 씬 트리·터레인 의존이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Party (부대)](../entities/Party.md) · [Faction (세력)](../entities/Faction.md) · [초기 배치](../data/unit-spawns.md) · [세력·영웅](../data/factions.md) · [병종](../data/unit-types.md)
- 선택·이동은 [Selection & Movement](selection-and-movement.md), 안개는 [Fog of War](fog-of-war.md), 부대 일람은 [Party Roster](party-roster.md), 거점 방어는 [Camp Capture](camp-capture.md#거점-방어-창발--중심-점거).
