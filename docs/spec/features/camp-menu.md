# Feature: Camp Menu (캠프 메뉴)

> 스크립트: `scenes/camp/camp_menu.gd` (`extends CanvasLayer`, layer 64)

**거점**([center](../data/buildings.md#동작) = 캠프·마을회관·성) 헥스를 클릭하면 열리는 오버레이. 그 건물이 속한 **영지** 정보(자원·이름·세력)를 보여준다.
(거점이 아닌 건물(농장·집 등)은 대신 [건물 정보 패널](building-info.md)이 열린다.)
UI 트리는 씬이 아니라 코드(`_build`)로 구성된다.
(스크립트/노드 이름은 `camp_menu`지만 실제로는 클릭한 건물의 **영지** 정보를 표시한다.)

## 레이아웃

- 반투명 배경(`Color(0,0,0,0.45)`) — 클릭 시 닫힘.
- 화면 중앙에 두 패널을 나란히(HBox, separation 16):
  - **좌측 — 자원 패널** (220×260): 제목 "자원" + 2열 그리드(자원명 / 값). 자원 4종(목재·식량·철·금) + `인구`. **`인구` 행의 값은 `"현재 / 상한"`**(예: `10 / 12`, 상한 = `territory.population_cap()` → [인구 상한](../entities/Territory.md#인구-상한population_cap)). 나머지 자원은 수량만.
  - **우측 — 영지 패널** (200×260): 제목 = **영지 이름**(예: "파리") + 그 아래 **세력명**(예: "프랑스", 세력 색상으로 표기) + **업그레이드 버튼**(거점의 다음 티어가 있을 때) + "건축" 버튼 + **건설 리스트**(기본 숨김) + (하단) "닫기" 버튼.

## 동작

- `open(building: Building, can_demolish := false)` — 건물의 영지(`building.territory`)를 읽어 자원 그리드를 채우고(`territory.resources`, 삽입 순서대로), 우측 패널의 이름/세력 라벨을 채운 뒤 메뉴를 연다. `can_demolish`가 참이면 [철거 버튼](#철거-버튼)을 보인다(재오픈 대비 매번 토글).
  - 제목 라벨 = `territory.name`.
  - 세력 라벨 = `territory.faction.name` (색상 = `territory.faction.color`). `faction`이 `null`이면 세력 라벨은 빈 문자열.
  - `building.territory`가 `null`이거나 영지에 세력이 없으면 라벨은 빈 문자열이고, 세력 색상 오버라이드를 제거한다(다른 영지로 재오픈 대비). `territory == null`이면 자원 그리드도 비어 있다.
- `close_menu()` — 숨긴다.
- 닫기 트리거: 배경 좌클릭, "닫기" 버튼.
- **업그레이드 버튼** (`_upgrade_btn`) — 연 건물이 거점이고 [`next_center`](../data/buildings.md#거점-업그레이드)가 있으면(캠프·마을회관) 표시한다. 텍스트 `"<다음 티어 라벨>으로 업그레이드  <비용>"`(예: `"마을회관으로 업그레이드  목재 20 · 식량 20"`). `BuildPlanner.can_upgrade`면 활성, 비용 부족이면 비활성. 최종 티어(성)·비거점이면 **숨김**. 누르면 `upgrade_requested(building)` 방출 → `game.gd`가 지불·`upgrade_to` 처리([건축](building.md#거점-업그레이드)).
- **성벽 건설 버튼** (`_wall_btn`) — 연 건물이 **tier ≥ town_hall**(마을회관·성)이고 **성벽 없음**(`not is_walled()`)일 때 표시. 텍스트 `"성벽 건설  <비용>"`(비용 = [`WALL_COST`](../data/buildings.md#성벽-wall_cost)). `BuildingTypes.can_build_wall(territory, building)`면 활성, 자재 부족이면 비활성. 캠프·이미 성벽 있음·비거점이면 **숨김**. 누르면 `wall_requested(building)` 방출 → `game.gd`가 자재 지불·`wall_level = 1` 처리([성벽](wall.md)).
- **캠프 건설 버튼** (`_found_camp_btn`) — `"캠프 건설 (새 영지)  목재 10 · 식량 10"`. 여는 영지가 캠프 비용을 감당하면(`BuildPlanner.can_build(territory, "camp")`) 활성, 아니면 비활성. 누르면 `found_camp_requested(territory)` 방출 → `game.gd`가 [캠프 건설](building.md#캠프-건설-새-영지-확장) 모드(부대 시야 배치)로 진입. `territory == null`이면 비활성.
- **철거 버튼** (`_demolish_btn`) — `open`의 `can_demolish`가 참일 때만 표시(텍스트 `"캠프 철거 (영지 포기)"`). 누르면 `demolish_requested(building)` 방출 → `game.gd`가 [확인 다이얼로그](confirm-dialog.md) 후 **영지 통째 제거**를 처리한다([건물 정보 철거](building-info.md#철거)와 별개 — 거점은 캠프 메뉴에서). `can_demolish` 판정은 `game.gd` — **캠프(tier 0)**·**내 세력 영지**·**마지막 거점 아님**(세력 소멸 방지)일 때만 참. 마을회관·성은 거짓(철거 불가).
- **건축 버튼** (`_on_build_pressed`) — 우측 패널을 **건설 리스트**로 전환한다(건축 버튼은 숨기고 리스트를 보임).
  - 리스트 = [건물 카탈로그](../data/buildings.md)의 **건축 가능 종류**(`BuildingTypes.BUILDABLE_IDS` — 농장·벌목소·철광·금광·집·공성 작업장). 거점(캠프·마을회관·성)은 제외(캠프=새 영지, 마을회관·성=업그레이드).
  - 각 항목 = 버튼 `"<라벨>  <비용>"`(예: `"농장  목재 5"`). 비용은 종류의 `build_cost`. (`required_pop` 폐지 — 인원 표기 없음.)
  - **영지가 없거나** `BuildPlanner.can_build(territory, type_id)`가 거짓이면 항목 버튼은 **비활성**(`disabled`). `can_build`은 [선행건물](building.md#선행건물-게이트)·자재(`build_cost`)를 함께 본다.
  - 선행 미충족이면 라벨 뒤에 `"  (선행: <선행 라벨> 필요)"`를 덧붙여 이유를 보인다(예: `"농장  ...  (선행: 마을회관 필요)"`).
  - 항목을 누르면 `build_selected(type_id, territory)` 시그널을 방출하고 메뉴를 닫는다. 실제 배치(건설 모드)는 게임이 이 시그널을 받아 처리한다 — **건설 모드 배치(2b)는 미구현**.
- `open`은 열 때마다 리스트를 숨기고 건축 버튼을 다시 보여 **정보 화면 상태로 초기화**한다(이전 오픈에서 리스트가 열려 있던 상태가 남지 않도록).
- **(삭제됨) 보급(화물)·판매·구매·병사 패널** — **화물운반**(영지↔부대 자원 적재/하역)은 [화물 제거](../entities/Party.md)와 함께 삭제됐다(부대가 자원을 나르지 않음). 상거래(판매·구매·병사)도 이미 제거됨. **공성 병기 생산 버튼(투석기·충차)도 제거**됐다([주둔 제거](camp-capture.md)와 함께 — 재구축 예정, [Siege Engines](siege-engines.md)). 캠프 메뉴는 이제 자원 그리드 + 영지 정보 + 건축/업그레이드/성벽/캠프건설/철거 버튼만 띄운다.
- `signal wall_requested(building)` — 성벽 건설 버튼을 누르면 방출. `game.gd`가 받아 자재 지불 + `wall_level` 설정을 처리한다([성벽](wall.md)).
- `signal upgrade_requested(building)` — 업그레이드 버튼을 누르면 방출. `game.gd`가 받아 거점 [업그레이드](building.md#거점-업그레이드)를 처리한다.
- `signal found_camp_requested(territory)` — 캠프 건설 버튼을 누르면 방출. `game.gd`가 받아 [새 영지 캠프 건설](building.md#캠프-건설-새-영지-확장) 모드로 진입한다.
- `signal demolish_requested(building)` — 철거 버튼을 누르면 방출. `game.gd`가 받아 확인 후 [캠프 철거](building-info.md#캠프-철거)를 처리한다.

## 테스트 시나리오

`test/unit/test_camp_menu.gd`.

- [정상] 세력 소속 영지의 건물로 `open` → 제목 라벨 = 영지 이름("파리"), 세력 라벨 = 세력명("프랑스")
- [정상] 세력 라벨 색상 = 세력 색상
- [경계] `territory == null`인 건물로 `open` → 세력 라벨은 빈 문자열
- [경계] 세력 있는 영지로 연 뒤 세력 없는 건물로 재오픈 → 이전 세력 색상 오버라이드가 남지 않음
- [정상] `open` 후 자원 그리드가 영지 자원 5종(목재·식량·철·금·인구)으로 채워진다
- [정상] `인구` 행 값이 `"현재 / 상한"` 형식(예: 마을회관 거점 영지 → `"10 / 10"`)
- [정상] 자원 충분 + **캠프 거점**(tier 0) 영지로 건축 → **농장·벌목소·철광·금광**(선행 camp)이 **활성**; **집·공성 작업장**(선행 town_hall)는 **비활성**이고 라벨에 `"(선행: 마을회관 필요)"` 포함
- [정상] 건축 리스트 항목 수 = 6(농장·벌목소·철광·금광·집·공성 작업장, 거점 미포함), 농장 텍스트에 라벨·비용 포함(인원 표기 없음)
- [정상] 거점을 **마을회관**(tier 1)으로 하면 집·공성 작업장이 **활성**으로 전환
- [경계] 자원 부족·영지 없음 → 항목 **비활성**
- [정상] 활성 항목을 누르면 `build_selected(type_id, territory)` 시그널 방출
- [경계] 건축으로 리스트를 연 뒤 다시 `open` → 리스트 숨김·건축 버튼 표시(정보 화면으로 초기화)
- [정상] **캠프** 거점으로 `open` → 업그레이드 버튼 표시, 텍스트에 `"마을회관"` 포함; 비용 충분하면 활성
- [정상] **성** 거점으로 `open` → 업그레이드 버튼 **숨김**(next_center 없음)
- [정상] 업그레이드 버튼 누르면 `upgrade_requested(building)` 방출
- [정상] **마을회관** 거점 + 자재 충분 → **성벽 건설 버튼** 표시·활성, 텍스트에 `"성벽 건설"`·비용 포함; 누르면 `wall_requested(building)` 방출
- [경계] **캠프** 거점 → 성벽 건설 버튼 **숨김**(tier 0); 이미 성벽 있는 거점(`wall_level=1`) → 숨김
- [경계] 자재 부족 → 성벽 건설 버튼 표시하되 **비활성**
- [정상] 캠프 비용 감당 가능한 영지로 `open` → **캠프 건설 버튼** 활성, 텍스트에 `"캠프 건설"` 포함; 누르면 `found_camp_requested(territory)` 방출
- [경계] 자원 부족·영지 없음 → 캠프 건설 버튼 비활성
- [정상] `open(camp, true)` → **철거 버튼** 표시; `open(camp)`(기본 false) → 철거 버튼 숨김(재오픈 토글)
- [정상] `can_demolish=true`로 연 뒤 철거 버튼 누르면 `demolish_requested(building)` 방출
- [경계] 보급·판매·구매·병사 패널은 **없다**(화물·상거래 제거) — `open`해도 관련 노드 미생성

## 관련

- 표시되는 자원·이름·세력은 [Territory 엔티티](../entities/Territory.md)에서 온다.
- 세력은 [Faction](../entities/Faction.md) 엔티티 참고.
- 건축 흐름 전체(건물 리스트 → 건설 모드 배치)는 [건축](building.md) 참고. 리스트(2a)는 구현됨, 건설 모드 배치(2b)는 미구현.
