# Feature: Primary Production (1차 생산 건물 · 생산포인트)

> 스크립트: `scenes/building/building.gd`(생산포인트·배정 거점) · `scenes/building/building_types.gd`(`primary_production`·`produces`·`buildable_terrains`) · **`scenes/building/building_manager.gd`**(`BuildingManager` — 거리 계산 `center_distance`·턴 산출 `tick_production`·배정 `assign_production_building`/`cycle_production_center`·배치/개척 `place_building`/`found_camp`·건물/영지 목록) · `scenes/game/game.gd`(건설 모드 UI·위임 호출) · `scenes/building/building_info.gd`(생산력 표시)

**1차 생산 건물**은 지형 위에 지어 자원을 캐는 건물이다. **[자원 4종](../data/resources.md)에 1:1 대응**한다:

| 건물 | `produces` | `buildable_terrains` |
| --- | --- | --- |
| 농장(`farm`) | `식량` | 초원 |
| 벌목소(`lumberjack`) | `목재` | 숲 |
| 철광(`iron_mine`) | `철` | 철맥 |
| 금광(`gold_mine`) | `금` | 금맥 |

생산 속도는 **배정 거점까지의 거리**로만 정해진다 — 가까울수록 빠르다. (예전의 *인원(노동력) 차출* 모델은 폐지됐다. `인구`는 [병력 전용 예약](../data/resources.md#인구-병력-예약)이라 생산에 쓰지 않는다.)

## 생산포인트 메커니즘 (거리 기반)

- 각 1차 생산 건물은 **생산포인트 `production_points`(정수, 기본 0)**를 쌓는다.
- 매 [턴](turn.md) 종료 시: `production_points += 1`(고정, 인원 무관). 그다음 **`production_points ≥ distance`이면 자원 1 산출·`production_points -= distance`**를 반복한다.
  - `distance` = 건물 ↔ **배정 거점** 중심의 [이동력 경로 거리](#거리-이동력-경로).
  - 산출 자원은 카탈로그 `produces`(단일 자원 id). 배정 거점의 [영지](../entities/Territory.md) 자원에 더한다.
- **생산력(표시용)** = `1 / distance`(턴당 자원, 소수). 정수 PP가 원천값이고 생산력은 파생 표시값이다(float 드리프트 방지).
- **순수 로직**(`Building`):
  - `tick_production(distance: int) -> int` — PP를 1 올리고 산출한 자원 수를 반환(PP 차감). `distance ≤ 0`·`produces == ""`면 0(no-op, PP 불변).
  - `production_rate(distance: int) -> float` — `distance ≤ 0`이면 0, 아니면 `1.0 / distance`.

예: 거리 3 → 생산력 0.33/턴. `tick_production(3)`를 매 턴 부르면 PP 1→2→3(자원1, PP0)→1→2→3(자원1)…으로 **3턴마다 자원 1**.

## 배정 거점 (`assigned_center`)

- `Building.assigned_center` — 이 건물이 **자원을 넣고 거리를 재는** 거점([center](../data/buildings.md#동작) 건물). 건물의 소속 영지(`territory`)는 이 거점의 영지다.
- **건설 시**: 가장 가까운([이동력 경로 거리](#거리-이동력-경로) 최소) 아군 거점으로 자동 배정.
- **변경**: 건물 정보 패널에서 언제든 다른 아군 거점으로 변경. 변경 시 자원 도착지·거리·소속 영지가 모두 새 거점 기준으로 옮겨간다.
- (인원 차출/반환 개념은 폐지 — 거점 변경 시 인구 이동 없음.)

## 거리 (경로 거리)

- `distance` = 건물 중심(`center_cell`)에서 배정 거점 중심까지의 **경로 거리**(헥스 스텝 BFS, `Terrain.IMPASSABLE`(산 등) 우회). `BuildingManager.center_distance`가 `HexGrid.bfs_distances(.., Terrain.IMPASSABLE)`로 계산한다(터레인 의존).
- 산 등으로 **경로가 없으면 distance 0 → 생산 정지**(도달 가능한 거점에 배정해야 생산). 최근접 거점 자동 배정도 같은 규칙(`BuildingManager.nearest_player_center`).
- (숲/습지 이동 가중치는 부대 이동의 도달-상한 모델이라 경로 비용 누적과 달라, 거리엔 반영하지 않는다 — 스텝 수로 단순화.)

## 배치 규칙 (`build_planner` · `game.gd`)

건설 가능 판정을 재정의한다.

- **시야**: **건물 시야 ∪ 부대 시야** 안이면 건설 가능. (거점에서 멀수록 생산력↓가 패널티라 허용)
- **1차 생산 건물**(`primary_production == true`):
  - **캠프(거점 tier ≥ 캠프)만 있으면** 건설 가능(마을회관 불요).
  - 건물의 **모든 footprint 셀이 `buildable_terrains`에 든 지형** 위여야 한다(농장=초원, 벌목소=숲, 철광=철맥, 금광=금맥). footprint 1이라 그 한 칸의 지형만 본다.
- **그 외 모든 건물**(비-생산): **거점(tier ≥ 마을회관) footprint에 인접한 타일**에만 건설 가능(town_hall 주변 밀집). 집 등이 이 제한을 받는다.
- 공통(기존 유지): 맵 범위 안 · 다른 건물과 겹치지 않음.

## 생산력 표시 (`building_info`)

1차 생산 건물 정보 패널에 표시:
- **생산력 `X.XX /턴`** (= `1 / distance`)
- 분해: `거리 {distance}`
- 누적: `PP {production_points} / {distance}`(다음 자원까지 진행도)
- 산출 자원명·배정 거점 이름. `[거점 변경]` 버튼. (**`[인원 ±]` 버튼은 폐지**.)

## 카탈로그 (`building_types.gd` · [Buildings](../data/buildings.md))

4개 1차 생산 건물 모두 `primary_production: true`, `produces: "<자원>"`, `buildable_terrains: [<terrain source_id>]`, footprint 1, `required_pop` 없음(0), 선행 `camp`.

## 테스트 시나리오

### 생산포인트(순수) — `test/unit/test_building.gd`
- [정상] 거리 3 건물 `tick_production(3)` 6번 → 산출 `[0,0,1,0,0,1]`(누계 2), 중간 PP `[1,2,0,1,2,0]`
- [정상] 거리 1 → `tick_production(1)` 매번 1 산출(PP 항상 0)
- [경계] `distance=0` → `tick_production(0)` 항상 0(PP 불변); `produces==""`(비생산) → 0
- [정상] `production_rate(3)` ≈ 0.333; `production_rate(1) == 1.0`; [경계] `production_rate(0) == 0.0`
- [정상] 기본값: `production_points == 0`

### 카탈로그 — `test/unit/test_building_types.gd`
- [정상] `farm`: `primary_production==true`, `produces=="식량"`, `buildable_terrains==[초원]`, footprint 1, 선행 camp
- [정상] `lumberjack`/`iron_mine`/`gold_mine`: `produces` = 목재/철/금, `buildable_terrains` = 숲/철맥/금맥
- [경계] 캠프·집 등: `primary_production` false, `produces==""`, `buildable_terrains==[]`

### 배치 판정 — `test/unit/test_build_planner.gd`
- [정상] `can_place(..., buildable_terrains=[숲])` — footprint 셀이 숲이면 참, 초원이면 거짓(지형 제한)
- [경계] `buildable_terrains=[]`(제한 없음) → 지형 무관
- [정상] `town_hall_adjacent_cells(...)` — 완성 마을회관/성 footprint에 인접한 셀 집합; 캠프만 있으면 빈 집합

### 도메인(BuildingManager) — `test/unit/test_building_manager.gd`
- [정상] `place_building`(1차 생산) → 최근접 완성 플레이어 거점 배정 + 그 거점 영지 편입 + 건설 중 생성·목록 등록
- [정상] `place_building`(비생산, 예: 집) → 배정 없음, 지정 영지 편입
- [정상] `center_distance` — 같은 행 3칸 = 3; `cycle_production_center` — 다음 거점으로 배정·영지 이동, 거점 1개면 불가
- [정상] `tick_production` — 완성 벌목소(거리 3) 3턴 → 배정 거점 영지 목재 +1
- [정상] `found_camp` — "전초기지 N" 단조 증가, 건설 중 캠프·플레이어 세력 편입·목록 등록
- [정상] `transfer_camp` — NPC→플레이어(수입 편입)/플레이어→NPC(수입 제외) 목록 재배치, `{territory_name, old_faction_name}` 반환
- [정상] `destroy_camp`/`demolish_building`(salvage 환급)/`demolish_camp_territory`(영지 통째 제거·세력 분리)

> **시야 합집합(건물∪부대)**·건설 모드 입력·생산력 패널은 `game.gd`·UI 의존이라 **실제 실행으로 확인**한다. `can_place`는 호출자가 합친 `vision_cells`를 받아 지형·겹침·범위만 판정한다.

## 관련

- [Construction (건축)](building.md) — 건설 모드·배치 판정. [Buildings (건물 종류)](../data/buildings.md) — 카탈로그. [Building](../entities/Building.md) — `production_points`·`assigned_center`. [Territory](../entities/Territory.md) — 자원. [Terrain](../data/terrain.md) — 지형 id. [Turn](turn.md) — 턴 종료 산출. [Resources](../data/resources.md) — 자원 4종.
