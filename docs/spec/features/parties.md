# Feature: Parties (부대 배치)

> 스크립트: `scenes/game/game.gd` (`_setup_parties`, `_build_faction_army`, `_place_army`) · **`scenes/party/party_manager.gd`** (`PartyManager` — 부대 목록 `units`/`npc_parties` 단일 출처·노드 생성 `new_party`/`make_party`·전멸 반영 `apply_survivors`·세력 소멸 제거·칸 조회) · `scenes/party/unit_types.gd`

**계층 분리**: `PartyManager`(부대 생명주기 — 목록·생성·전멸/소멸 제거·칸 조회. 테스트는 `test_party_manager.gd`) ← `game.gd`(편성·배치·선택 상태·일람 갱신·패배 확인·연출). game.gd의 `all_parties`/`party_on_cell`은 PartyManager 위임(NpcPlanner·SiegeSystem 월드 조회 겸용). `apply_survivors`는 ALIVE/WIPED_NPC/WIPED_PLAYER를 반환하고, 활성 부대 재할당 등 WIPED_PLAYER 후처리는 game.gd가 한다.

게임 시작 시 [유닛 카탈로그](../data/units.md)에서 [부대](../entities/Party.md)를 생성해 맵에 배치한다.
**랑그릿사식 편제** — 각 세력이 **영웅부대 4 + 부하부대 12 = 16부대**로 시작한다(4세력 = 맵 64부대).

## 세력 군대 편성 (`_build_faction_army`)

각 세력([FACTION_IDS](../data/units.md))마다:

- **영웅부대 4개**(`kind = KIND_HERO`) — [`make_hero`](../data/units.md)로 영웅 1명을 멤버로 넣고 지휘관 지정. `party_name = hero_party_name`, 세력명은 세력 스펙. **토큰 색 = 세력 색**(플레이어는 기본 금색).
- **각 영웅마다 부하부대 3개**(`kind = KIND_TROOP`) — **경보병 2 + 경궁병 1**. [`make_troop`](../data/units.md)로 10명 동일 병사를 넣고, 그 부대의 **`lord`를 소속 영웅부대**로 설정한다([Party](../entities/Party.md) 소속). **토큰 색 = 세력 색을 약간 어둡게**(`Color.darkened(0.35)`)하여 영웅부대와 구분한다.
- 그래서 세력당 4 + 4×3 = **16부대**.

**소속·이동**: 부하부대는 `lord`(소속 영웅)를 갖되 **독립 토큰으로 자유 이동**한다(소속은 메타데이터 — 버프는 `미구현`). → [Party 소속](../entities/Party.md#소속-lord).

## 배치 (`_place_army`)

각 세력 거점(모서리, [NPC Bases](npc-bases.md) `PLAYER_BASE`·`NPC_BASES`) 주변에 16부대를 **영웅 그룹별로 흩어** 배치한다.

- **거점 방어 부대**: 세력당 **경보병 1부대**(영웅 0의 첫 경보병)를 거점 **중심 타일**에 세운다(별도 상태 없이 그 자리를 점거해 방어 — [거점 방어](camp-capture.md#거점-방어-창발--중심-점거)). 나머지 15부대는 자유 이동.
- **영웅 그룹 흩뿌리기**: 거점은 모서리에 있으므로 **맵 안쪽(중앙) 방향으로만** 벌린다. 영웅 4명마다 성 안쪽 **부채꼴 앵커**(2×2, 거점 기준 약 4·10칸 오프셋을 안쪽 부호 `sign(중앙−거점)`로 스케일)를 하나씩 잡고, **그 영웅 + 소속 부하부대**를 그 앵커 근처 [BFS](map-and-camera.md) 통과 가능·미점유 셀에 모아 놓는다. 그룹끼리 앵커가 떨어져 있어 **영웅 지휘부가 성 주변에 흩어진다**.
- `_nearby_free_cells(anchor, count, occupied)`: 앵커에서 반경을 넓혀 가며 **통과 가능**(산 제외)·**미점유** 셀을 거리순으로 확보. `occupied`를 그룹 간 누적해 겹치지 않게 한다.
- 4왕국이 네 모서리에 흩어져 있어 시작 시 세력끼리 멀다. 거점 좌표는 [NPC Bases](npc-bases.md).

## 세력 구분 (플레이어 vs NPC)

- **플레이어 세력**(`PLAYER_ID` = `azel`, 푸른 왕국)의 16부대는 모두 `PartyManager.units`에 넣는다 — **선택·이동·AI·부대 일람** 대상.
- **NPC 3세력**(`NPC_IDS`)의 48부대는 `PartyManager.npc_parties`에 넣는다.
  - **안개 반영** — 플레이어 시야 안일 때만 토큰 표시. NPC는 플레이어 시야를 밝히지 않는다. → [Fog of War](fog-of-war.md).
  - **턴 리셋** — 턴 종료 시 NPC 부대도 `reset_turn`. → [Turn](turn.md).
  - **부대 일람 제외** — 일람은 우리 세력 부대만.
  - **정보 패널** — 보이는 NPC 클릭 시 정보 표시(선택 없음). → [Party Info](party-info.md).
  - **이동·공격** — [NPC Movement](npc-movement.md)·[Battle](battle.md) 공격 페이즈.

## 시작 투석기 (폐지)

이전에는 플레이어 부대·NPC 부대에 **시작 [투석기](siege-engines.md) 1대**를 실어 줬으나, **영웅부대(1명)는 견인 인력(`SiegeTypes.CREW_MIN`=4) 부족으로 투석기를 못 끈다**. 편제가 영웅 중심으로 바뀌며 **시작 투석기 자동 지급은 폐지**했다. 투석기는 [공성 작업장 생산](siege-engines.md#획득--공성-작업장에서-생산)으로만 획득한다(기존 mechanic 유지). *(NPC 방어 포격 시작분(5c)도 이번엔 없음 — 후속.)*
거점 **시작 [성벽](wall.md)**(공성 시험용 스캐폴딩)은 그대로 둔다.

## 미구현

- 목표 지향 NPC AI·NPC 영지 확장·유닛 충돌 고도화. *(다음 단계)*
- 소속 부대 버프(영웅 근처 소속 부대). → [Party 소속](../entities/Party.md#소속-lord).
- 64부대 규모의 성능 최적화(안개 합산·NPC AI·헤드리스 전투 루프).

## 테스트 시나리오 — PartyManager (`test/unit/test_party_manager.gd`)

- [정상] `make_party` — host에 노드 부착, 이름/세력/셀 설정, 빈 부대로 시작(목록 등록은 호출부)
- [정상] 칸 조회 — `party_on_cell`/`player_party_at`/`npc_at`(안개 visible 필터)/`all`; 멤버 0 부대는 조회 제외
- [정상] `first_living_unit` — 빈 부대 건너뛰고 멤버 있는 첫 부대
- [정상] `apply_survivors` — 생존(교체+지휘관 재지정)=ALIVE / 전멸 시 목록 제거·free 예약(WIPED_PLAYER·WIPED_NPC) / 해제된 부대=INVALID
- [정상] `remove_party` — 어느 목록에 있든 제거+free; `eliminate_faction_parties` — 그 세력 NPC 부대만 제거

## 테스트

- 데이터 계층([UnitTypes](../data/units.md))·[Party](../entities/Party.md) `kind`/`lord`는 단위 테스트로 검증한다.
- `game.gd`의 편성·배치·`kind`/`lord` 설정·NPC `visible` 토글은 씬 트리·터레인 의존이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Party (부대)](../entities/Party.md) · [Human (사람)](../entities/Human.md) · [Faction (세력)](../entities/Faction.md) · [유닛 카탈로그](../data/units.md)
- 선택·이동은 [Selection & Movement](selection-and-movement.md), 안개는 [Fog of War](fog-of-war.md), 부대 일람은 [Party Roster](party-roster.md), 거점 방어는 [Camp Capture](camp-capture.md#거점-방어-창발--중심-점거).
