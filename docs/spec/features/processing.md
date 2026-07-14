# Feature: Secondary Production (2차 생산 · 가공 건물)

> 스크립트: `scenes/building/building.gd`(작업포인트·인원·레시피) · `scenes/building/building_types.gd`(`secondary_production`·`recipes`) · `scenes/game/game.gd`(거점 인접 배치·턴 변환) · `scenes/building/building_info.gd`(레시피·인원 UI)

**2차 생산(가공) 건물**은 자원을 **다른 자원으로 변환**한다(제재소 나무→목재 등). 지형이 아니라 **거점 인접**에 짓고, 배치 인원 수로 작업 속도가 정해진다. [1차 생산](production.md)(생산포인트=인원÷거리)과 달리 **작업포인트=인원 속도**로 배치(batch) 변환한다.

**이 문서는 슬라이스 2차-a**(변환 코어 + 계속 작업 모드)를 다룬다 — 5건물 + 신규 자원 3종 전부. 작업 모드 확장(N개 유지·N턴)은 [2차-b 후속](#슬라이스-2차-b-후속-미구현).

## 변환 메커니즘 (작업포인트)

- 각 가공 건물은 **작업포인트 `work_points`(정수, 기본 0)**를 쌓는다.
- 매 [턴](turn.md) 종료 시: `work_points += work_speed()`. 그다음 **1배치분(`WORK_PER_BATCH = 10`)이 찰 때마다** 레시피 1회 변환(입력 소비→출력 생산)한다.
- **작업 속도**(`work_speed()`) = 배치 인원 수별 포인트/턴. 부동소수 드리프트를 피해 **정수화**(0.8/1.5/2.0 ×10):

  | 인원 | 0 | 1 | 2 | 3 |
  | --- | --- | --- | --- | --- |
  | 포인트/턴 | 0 | 8 | 15 | 20 |
  | (배치/턴) | 0 | 0.8 | 1.5 | 2.0 |

- **입력 부족 시 일시정지**: 변환은 입력 자원이 충분한 배치 수만큼만 실행되고, 남는 작업포인트는 **쌓인 채 유지**된다(자원이 채워지면 이어서 변환).
- **순수 로직**(`Building`):
  - `work_speed() -> int` — `WORK_SPEED[clampi(workers, 0, 3)]`(= `[0,8,15,20]`).
  - `advance_work(max_batches: int) -> int` — `work_points += work_speed()` 후, `min(work_points / WORK_PER_BATCH, max_batches)` 배치를 반환하고 그만큼 `work_points`를 차감한다. `max_batches`(입력·모드 상한, game이 계산)만큼만 소비 — 나머지 포인트는 유지. 가공 건물 아니면 0.

예: 인원 2(15/턴)·1배치 10. 턴1 wp 15 → 1배치(wp 5). 턴2 wp 20 → 2배치(wp 0). 즉 평균 1.5배치/턴.

## 레시피 (`recipes` · 선택)

- 카탈로그 `recipes: Array` — `[{ "in": {자원:수}, "out": {자원:수} }, ...]`. 대부분 1개, **제련소는 3개**(철→철괴 / 은→은괴 / 금→금괴).
- `Building.active_recipe: int` — 현재 레시피 인덱스(기본 0). 제련소는 [건물 정보 패널](#표시-building_info)에서 변경.
- `active_recipe_input() -> Dictionary` / `active_recipe_output() -> Dictionary` — 현재 레시피의 입력/출력(없으면 `{}`).

## 배치 인원·거점 (거점 인접)

- `Building.workers: int` — **0~3**. 기본 건설 시 1. 배정 거점 영지 인구에서 차출(조정·철거 시 반환 — [1차 생산](production.md)과 동일 규칙).
- `Building.assigned_center` — 인접한 거점. 입력 소비·출력 생산·인원 차출을 그 거점 영지에서 한다. 건설 시 인접 거점 자동 배정(거리 없음 — 인접이라 항상 가까움).
- **배치**: 가공 건물은 **거점(캠프 이상 모든 티어) footprint에 인접한 타일**에만 짓는다(`BuildPlanner.center_adjacent_cells(min_tier=0)`). 1차 생산의 "마을회관 인접"(tier≥마을회관)과 달리 **캠프 인접도 허용**. footprint 1.

## 턴 변환 (`game.gd._tick_processing`)

턴 종료 시 완성 가공 건물마다:
1. 배정 거점 영지에서 현재 레시피 입력을 **감당할 수 있는 배치 수** `affordable = min(자원/입력수)` 계산.
2. `batches = building.advance_work(affordable)`(계속 모드 = 입력만 상한).
3. 입력 자원 `× batches` 차감, 출력 자원 `× batches` 영지에 추가.

## 표시 (`building_info`)

가공 건물 정보 패널:
- 레시피 `입력 → 출력` · 작업 속도(인원별) · 누적 `work_points / 10`.
- `[인원 +]`/`[인원 −]`(0-3). **제련소**는 `[레시피 변경]`(철괴/은괴/금괴 순환).

## 카탈로그 (`building_types.gd`) · 신규 자원

| 건물 | recipes | 신규 자원 |
| --- | --- | --- |
| 제재소(`sawmill`) | 나무 1 → 목재 1 | — |
| 축사(`stable`) | 밀 2 → 고기 1 | — |
| 제련소(`smelter`) | 철→철괴 / 은→은괴 / 금→금괴 | 은괴·금괴 |
| 제분소(`mill`) | 밀 1 → 밀가루 1 | 밀가루 |
| 제빵소(`bakery`) | 밀가루 1 → 빵 1 | — |

- 전부 `secondary_production: true`, `prerequisite "camp"`, footprint 1, 인원 배치(가변, `required_pop` 없음).
- **신규 자원**([Resources](../data/resources.md)): `밀가루`(가치 2), `은괴`(가치 20), `금괴`(가치 30). 캠프 초기자원 0.

## 테스트 시나리오

### 변환 순수 — `test/unit/test_building.gd`
- [정상] `work_speed()` — 인원 0/1/2/3 → 0/8/15/20; [경계] 인원 5(클램프) → 20
- [정상] 인원 2 건물 `advance_work(99)` 두 번 → [1,2] 배치(wp 15→5, 20→0), 평균 1.5
- [경계] `advance_work(0)`(입력 0) → 0 배치, wp는 쌓임(15); 다음 턴 `advance_work(99)` → 3배치(wp 30)
- [경계] 가공 건물 아니면 `advance_work(n) == 0`
- [정상] `active_recipe_input/output` — 제련소 기본(철→철괴), `active_recipe=1` → 은→은괴

### 카탈로그 — `test/unit/test_building_types.gd`
- [정상] 5건물 `secondary_production==true`, recipes 내용, prerequisite camp, footprint 1
- [정상] 제련소 recipes 3개(철괴/은괴/금괴), 제재소 recipes 1개(나무→목재)

### 자원 — `test/unit/test_resource_types.gd`
- [정상] `value("밀가루")==2`, `value("은괴")==20`, `value("금괴")==30`

### 배치 판정 — `test/unit/test_build_planner.gd`
- [정상] `center_adjacent_cells(min_tier=0)` — 캠프 인접 셀 포함(1차의 town_hall_adjacent는 캠프 제외와 대비)

> 거점 자동 배정·인원 차출/반환·턴 변환 누적·레시피 변경·패널은 `game.gd`·UI 의존이라 **실제 실행/헤드리스로 확인**한다.

## 작업 모드 (2차-b)

가공 건물은 **얼마나 작업할지**를 3모드로 제어한다. `Building.work_mode`(0 계속·1 N유지·2 N턴), `Building.work_target`(N유지=목표 출력량, N턴=남은 작업 턴; 계속은 무시).

- **계속(`WORK_CONTINUOUS`=0)**: 입력이 있는 한 계속 변환(기본, 2차-a). 배치 상한 = 입력만.
- **N개 유지(`WORK_KEEP`=1)**: 배정 거점 영지의 **출력 자원량이 `work_target` 이상이면 정지**, 미만이면 그 값까지만 변환. 모드 배치 상한 = `max(0, work_target − 현재 출력량)`.
- **N턴 작업(`WORK_TURNS`=2)**: `work_target`이 남은 작업 턴. `work_target > 0`이면 입력 상한까지 변환하고, **실제로 변환한 턴에만 `work_target −= 1`**(입력 부족으로 변환 못 한 턴은 유지 = 일시정지). `work_target == 0`이면 정지.

- **순수 로직**(`Building`):
  - `mode_batch_cap(current_output: int) -> int` — 모드별 이번 턴 배치 상한. 계속·N턴(target>0)=매우 큼, N유지=`max(0, work_target−current_output)`, N턴(target≤0)=0.
- **턴 변환**(`game._tick_processing`): `batches = advance_work(min(affordable, mode_batch_cap(출력량)))`. 변환 후 **N턴 모드면 `batches>0`일 때 `work_target −= 1`**.

- **표시·설정**(`building_info`): `[모드]` 버튼(계속→N유지→N턴 순환, 전환 시 기본 target — N유지 10·N턴 5). N유지·N턴이면 `[값 −][값 +]`로 `work_target` 조정. 현재 모드·목표 표시.

## 이후 후속 (미구현)

- 부산물 다중 산출(가죽·천)·가축 다양화(양계장·목장·마구간)·아이템 제작 건물(대장간 등)은 더 후속. (채석장 1차 전환은 완료.)

## 테스트 시나리오 (2차-b 추가)

### 모드 배치 상한(순수) — `test/unit/test_building.gd`
- [정상] 계속(mode 0) → `mode_batch_cap(현재출력)` 매우 큼(입력만 제한)
- [정상] N유지(mode 1, target 10) → 출력 3이면 cap 7; 출력 10이면 cap 0(정지); 출력 12이면 0
- [정상] N턴(mode 2) → target 3이면 매우 큼, target 0이면 cap 0

> 모드 전환·값 조정·N턴 카운트다운·N유지 정지·패널 버튼은 `game.gd`·UI 의존이라 실제 실행/헤드리스로 확인.

## 관련

- [1차 생산](production.md) — 생산포인트(인원÷거리) 모델과 대비. [Buildings](../data/buildings.md)·[Resources](../data/resources.md). [Building](../entities/Building.md) — `work_points`·`active_recipe`. [Territory](../entities/Territory.md) — 자원. [Construction](building.md) — 배치.
