# Feature: Primary Production (1차 생산 건물 · 생산포인트)

> 스크립트: `scenes/building/building.gd`(생산포인트·인원·배정 거점) · `scenes/building/building_types.gd`(`primary_production`·`produces`·`buildable_terrains`) · `scenes/game/game.gd`(거리 계산·턴 산출·거점 배정 UI) · `scenes/building/building_info.gd`(생산력 표시)

**1차 생산 건물**은 지형 위에 지어 자원을 캐는 건물이다(벌목소·농장 등). 기존 *flat 생산*(턴당 고정량)을 대체하는 **생산포인트 모델**을 쓴다 — 배치 인원과 배정 거점까지의 거리로 생산 속도가 정해진다.

**이 문서는 슬라이스 1**(생산 메커니즘 + 배치 규칙)을 다룬다 — 기존 지형에 있는 **벌목소(숲→나무)·농장(초원→밀)**에 적용. 신규 지형·자원·건물(채석장·사냥터·낚시터·철/금/은광)은 [슬라이스 2 후속](#슬라이스-2-후속-미구현).

## 생산포인트 메커니즘

- 각 1차 생산 건물은 **생산포인트 `production_points`(정수, 기본 0)**를 쌓는다.
- 매 [턴](turn.md) 종료 시: `production_points += workers`(배치 인원). 그다음 **`production_points ≥ distance`이면 자원 1 산출·`production_points -= distance`**를 반복한다(인원 ≥ 거리면 한 턴에 여러 개).
  - `distance` = 건물 ↔ **배정 거점** 중심의 [이동력 경로 거리](#거리-이동력-경로).
  - 산출 자원은 카탈로그 `produces`(단일 자원 id, 벌목소=`"나무"`, 농장=`"밀"`). 배정 거점의 [영지](../entities/Territory.md) 자원에 더한다.
- **생산력(표시용)** = `workers / distance`(턴당 자원, 소수). 정수 PP가 원천값이고 생산력은 파생 표시값이다(float 드리프트 방지).
- **순수 로직**(`Building`):
  - `tick_production(distance: int) -> int` — PP를 인원만큼 올리고 산출한 자원 수를 반환(PP 차감). `workers ≤ 0`·`distance ≤ 0`·`produces == ""`면 0(no-op).
  - `production_rate(distance: int) -> float` — `distance ≤ 0`이면 0, 아니면 `workers / distance`.

예: 인원 3·거리 5 → 생산력 0.6/턴. 2턴에 자원 1(PP 6→1), 다시 2턴에 자원 1(PP 7→2), 다음 턴 자원 1(PP 5→0). 5턴에 3자원.

## 배치 인원 (`workers`, 거점 인구 차출)

- `Building.workers: int` — **0~5**. 기본 건설 시 1. 0이면 미가동(생산 0).
- 인원은 **배정 거점 영지의 인구(`인구` 자원)에서 차출**한다. 인원을 늘리면 그 영지 인구가 줄고, 줄이면 되돌아온다(배정 거점 변경 시 함께 이동).
- 인원 조정 UI(건물 정보 패널 `[인원 +]`/`[인원 −]`): 늘릴 땐 배정 거점 영지 인구가 남아 있어야(≥1) 가능. `required_pop`(고정 인력 게이트)을 이 가변 배치가 **대체**한다(1차 생산 건물은 `required_pop` 없음).

## 배정 거점 (`assigned_center`)

- `Building.assigned_center` — 이 건물이 **인원을 차출하고 자원을 넣고 거리를 재는** 거점([center](../data/buildings.md#동작) 건물). 건물의 소속 영지(`territory`)는 이 거점의 영지다.
- **건설 시**: 가장 가까운([이동력 경로 거리](#거리-이동력-경로) 최소) 아군 거점으로 자동 배정.
- **변경**: 건물 정보 패널에서 언제든 다른 아군 거점으로 변경. 변경 시 인원 출처·자원 도착지·거리·소속 영지가 모두 새 거점 기준으로 옮겨간다(기존 거점 인구 반환 → 새 거점에서 차출).

## 거리 (경로 거리)

- `distance` = 건물 중심(`center_cell`)에서 배정 거점 중심까지의 **경로 거리**(헥스 스텝 BFS, `Terrain.IMPASSABLE`(산 등) 우회). `game.gd._center_distance`가 `HexGrid.bfs_distances(.., Terrain.IMPASSABLE)`로 계산한다(터레인 의존).
- 산 등으로 **경로가 없으면 distance 0 → 생산 정지**(도달 가능한 거점에 배정해야 생산). 최근접 거점 자동 배정도 같은 규칙(`_nearest_player_center`).
- (숲/습지 이동 가중치는 부대 이동의 도달-상한 모델이라 경로 비용 누적과 달라, 거리엔 반영하지 않는다 — 스텝 수로 단순화.)

## 배치 규칙 (`build_planner` · `game.gd`)

건설 가능 판정을 재정의한다.

- **시야**: 기존 "건물(영지) 시야 안"에서 → **건물 시야 ∪ 부대 시야** 안이면 건설 가능. (거점에서 멀수록 생산력↓·방어 취약이 패널티라 허용)
- **1차 생산 건물**(`primary_production == true`):
  - **캠프(거점 tier ≥ 캠프)만 있으면** 건설 가능(마을회관 불요).
  - 건물의 **모든 footprint 셀이 `buildable_terrains`에 든 지형** 위여야 한다(벌목소=숲, 농장=초원). footprint 1이라 그 한 칸의 지형만 본다.
- **그 외 모든 건물**(비-생산): **거점(tier ≥ 마을회관 = 마을회관·성) footprint에 인접한 타일**에만 건설 가능(town_hall 주변 밀집). 집·공성 작업장 등 기존 건물도 이 제한을 받는다.
- 공통(기존 유지): 맵 범위 안 · 다른 건물과 겹치지 않음.

## 생산력 표시 (`building_info`)

1차 생산 건물 정보 패널에 표시:
- **생산력 `X.XX /턴`** (= `workers / distance`)
- 분해: `인원 {workers} ÷ 거리 {distance}`
- 누적: `PP {production_points} / {distance}`(다음 자원까지 진행도)
- 산출 자원명·배정 거점 이름. `[인원 +]`/`[인원 −]`·`[거점 변경]` 버튼.

## 카탈로그 변경 (`building_types.gd` · [Buildings](../data/buildings.md))

슬라이스 1에서 **벌목소·농장**을 생산포인트 모델로 전환한다.

| 건물 | `produces` | `buildable_terrains` | footprint | 선행 | 건설비 | flat `production` |
| --- | --- | --- | --- | --- | --- | --- |
| 벌목소(`lumberjack`) | `"나무"` | `[숲]` | 1 | 캠프 | 목재5·석재5 | **제거** |
| 농장(`farm`) | `"밀"` | `[초원]` | 1 | 캠프 | 목재5·밀5 | **제거** |

- 새 스펙 필드: `primary_production: true`, `produces: "<자원>"`, `buildable_terrains: [<terrain source_id>]`. `required_pop` 제거(가변 배치가 대체). 농장 footprint 7→1.
- **채석장(`quarry`)**은 돌 타일(슬라이스 2)이라 **이번 슬라이스에선 기존 flat 유지**, 슬라이스 2에서 전환.
- flat 생산 경로(`Building.production()`·`Territory.collect_income`)는 채석장 등 남은 flat 건물을 위해 유지하되, `primary_production` 건물은 `production()`이 빈 Dictionary(생산포인트 경로만 씀).

## 테스트 시나리오

### 생산포인트(순수) — `test/unit/test_building.gd`
- [정상] `workers=3` 건물 `tick_production(5)` 5번 → 산출 [0,1,0,1,1](누계 3), 중간 PP [3,1,4,2,0]
- [정상] `workers=5`·거리 2 → `tick_production(2)` 한 번에 2 산출(PP 5→1)
- [경계] `workers=0` → `tick_production(d)` 항상 0(PP 불변); `distance=0` → 0; `produces==""` → 0
- [정상] `production_rate(5)` = `workers/5`(예 3→0.6); [경계] `production_rate(0) == 0.0`
- [정상] 기본값: `production_points==0`, `workers==0`

### 카탈로그 — `test/unit/test_building_types.gd`
- [정상] 벌목소: `primary_production==true`, `produces=="나무"`, `buildable_terrains==[숲]`, footprint 1, 선행 camp, `production=={}`(flat 없음)
- [정상] 농장: `primary_production==true`, `produces=="밀"`, `buildable_terrains==[초원]`, footprint 1
- [정상] 채석장: `primary_production` 없음(false), 기존 flat `production=={석재:2}` 유지
- [경계] 캠프·집 등: `primary_production` false, `produces==""`, `buildable_terrains==[]`

### 배치 판정 — `test/unit/test_build_planner.gd`
- [정상] `can_place(..., buildable_terrains=[숲])` — footprint 셀이 숲이면 참, 초원이면 거짓(지형 제한)
- [경계] `buildable_terrains=[]`(제한 없음) → 지형 무관(종전 동작)
- [정상] `town_hall_adjacent_cells(terrain, buildings, ...)` — 완성 마을회관/성 footprint에 인접한 셀 집합(중심 티어 ≥ 마을회관만), 먼 셀 미포함; 캠프만 있으면 빈 집합
- [경계] 겹침·맵 밖·`vision_cells` 밖은 종전대로 불가

> **시야 합집합(건물∪부대)**·거점 자동 배정(최근접)·인원 차출/반환·거점 변경·이동경로 거리·턴 산출 누적·생산력 패널은 `game.gd`·터레인·UI 의존이라 **실제 실행/헤드리스로 확인**한다(game.gd 통합 테스트는 관례상 두지 않음). `can_place`는 호출자가 합친 `vision_cells`(1차=건물∪부대 시야, 기타=마을회관 인접 셀)를 받아 지형·겹침·범위만 판정한다.

## 슬라이스 2 (신규 지형·자원·건물)

**2a — 지형·타일·자원** ✅: 플레이스홀더 지형 6종([Terrain](../data/terrain.md) 5~10: 돌·동물·물가·철맥·금맥·은맥, 전부 통행 가능·기본 이동) + 플레이스홀더 SVG + 맵 생성 패치 + 신규 자원 3종([Resources](../data/resources.md): 고기·생선·은).

**2b — 신규 1차 생산 건물 5종** ✅: 슬라이스 1 모델 그대로 카탈로그만 추가.

| 건물 | `produces` | `buildable_terrains` |
| --- | --- | --- |
| 사냥터(`hunting_ground`) | 고기 | 동물 |
| 낚시터(`fishing_spot`) | 생선 | 물가 |
| 철광(`iron_mine`) | 철 | 철맥 |
| 금광(`gold_mine`) | 금 | 금맥 |
| 은광(`silver_mine`) | 은 | 은맥 |

- **채석장 전환 보류**: 채석장까지 생산포인트로 바꾸면 flat 생산(`production()`/`collect_income`)을 쓰는 건물이 0이 돼 미사용 경로가 된다. flat 경로는 향후 **가공 건물**(제분소·제련소 등 턴당 자원 변환, 인원/거리 무관)이 다시 쓸 인프라라, 채석장은 그 대표로 **flat 유지**하고 전환은 가공 건물 슬라이스와 함께 재검토한다.

## 관련

- [Construction (건축)](building.md) — 건설 모드·배치 판정. [Buildings (건물 종류)](../data/buildings.md) — 카탈로그. [Building](../entities/Building.md) — `production_points`·`workers`·`assigned_center`. [Territory](../entities/Territory.md) — 인구·자원. [Terrain](../data/terrain.md) — 지형 id. [Turn](turn.md) — 턴 종료 산출.
