# Feature: Camp Menu (캠프 메뉴)

> 스크립트: `scenes/camp/camp_menu.gd` (`extends CanvasLayer`)

**거점**([center](../data/buildings.md#동작) = 캠프·마을회관·성) 헥스를 클릭하면 열리는 오버레이. 그 건물이 속한 **영지** 정보(자원·이름·세력)를 보여준다.
(거점이 아닌 건물(농장·집 등)은 대신 [건물 정보 패널](building-info.md)이 열린다.)
UI 트리는 씬이 아니라 코드(`_build`)로 구성된다.
(스크립트/노드 이름은 `camp_menu`지만 실제로는 클릭한 건물의 **영지** 정보를 표시한다.)

chrome(딤 배경·제목 바·X·ESC·`ModalStack` 등록 = 지도 입력 차단)은 **공용 [Modal](modal.md)에 위임**하고, 콘텐츠(두 패널)만 `set_content`로 주입한다([구성원 메뉴](members-menu.md)·[장비](equipment.md)와 같은 패턴).

## 레이아웃

- chrome = [Modal](modal.md): 딤 배경(클릭 시 닫힘) + **제목 바 = 영지 이름**(예: "파리") + X 버튼.
- 콘텐츠: 두 패널을 나란히(HBox, separation 16):
  - **좌측 — 자원 패널** (220×260): 제목 "자원" + 2열 그리드(자원명 / 값). 자원 4종(목재·식량·철·금) + `인구`. **`인구` 행의 값은 `"현재 / 상한"`**(예: `10 / 12`, 상한 = `territory.population_cap()` → [인구 상한](../entities/Territory.md#인구-상한population_cap)). 나머지 자원은 수량만.
  - **우측 — 영지 패널** (200×260): **세력명**(예: "프랑스", 세력 색상으로 표기) + **업그레이드 버튼**(거점의 다음 티어가 있을 때) + "건축" 버튼 + **건설 리스트**(기본 숨김). (별도 "닫기" 버튼 없음 — 닫기는 Modal chrome.)

## 동작

- `open(building: Building)` — 건물의 영지(`building.territory`)를 읽어 자원 그리드(`territory.resources`, 삽입 순서대로)·제목·세력 라벨·버튼들을 채우고(`_refresh`) `modal.open()`한다(이미 열려 있으면 no-op).
- **event-driven 자동 갱신**: 열 때 영지의 [`changed` 시그널](../entities/Territory.md)을 구독한다(다른 영지로 재오픈 시 구독 교체). 열려 있는 동안 자원·건물·세력이 바뀌면 **다음 idle 프레임에 한 번만** `_refresh`한다(코얼레싱 — 같은 프레임에서 시그널 뒤에 오는 `upgrade_to` 등 건물 변경까지 최종 상태로 반영). 업그레이드·성벽 건설 후 game.gd의 수동 재-open은 없다. `_refresh`는 정보 화면(리스트 숨김·건축 버튼 표시)으로 초기화한다.
- **철거 버튼 판정(`_can_demolish`)** — 메뉴 내부 도메인 판정(단일 출처): 건물이 **캠프(tier 0)** 이고 세력 소속이며 **마지막 거점이 아닐 때**(`Faction.center_count() > 1` — 세력 소멸 방지)만 표시. 캠프 메뉴는 클릭 라우팅상 플레이어 거점에서만 열리므로 "내 세력" 조건은 자동 충족. 마을회관·성은 항상 숨김(다운그레이드 미구현).
  - Modal 제목 = `territory.name`.
  - 세력 라벨 = `territory.faction.name` (색상 = `territory.faction.color`). `faction`이 `null`이면 세력 라벨은 빈 문자열.
  - `building.territory`가 `null`이거나 영지에 세력이 없으면 라벨은 빈 문자열이고, 세력 색상 오버라이드를 제거한다(다른 영지로 재오픈 대비). `territory == null`이면 자원 그리드도 비어 있다.
- `close_menu()` — `modal.close()` 위임.
- 닫기 트리거: X 버튼·배경 좌클릭·ESC([Modal](modal.md) chrome 공통).
- **업그레이드 버튼** (`_upgrade_btn`) — 연 건물이 거점이고 [`next_center`](../data/buildings.md#거점-업그레이드)가 있으면(캠프·마을회관) 표시한다. 텍스트 `"<다음 티어 라벨>으로 업그레이드  <비용>"`(예: `"마을회관으로 업그레이드  목재 20 · 식량 20"`). `BuildPlanner.can_upgrade`면 활성, 비용 부족이면 비활성. 최종 티어(성)·비거점이면 **숨김**. 누르면 `upgrade_requested(building)` 방출 → `game.gd`가 지불·`upgrade_to` 처리([건축](building.md#거점-업그레이드)).
- **성벽 건설 버튼** (`_wall_btn`) — 연 건물이 **tier ≥ town_hall**(마을회관·성)이고 **성벽 없음**(`not is_walled()`)일 때 표시. 텍스트 `"성벽 건설  <비용>"`(비용 = [`WALL_COST`](../data/buildings.md#성벽-wall_cost)). `BuildingTypes.can_build_wall(territory, building)`면 활성, 자재 부족이면 비활성. 캠프·이미 성벽 있음·비거점이면 **숨김**. 누르면 `wall_requested(building)` 방출 → `game.gd`가 자재 지불·`wall_level = 1` 처리([성벽](wall.md)).
- **캠프 건설 버튼** (`_found_camp_btn`) — `"캠프 건설 (새 영지)  목재 10 · 식량 10"`. 여는 영지가 캠프 비용을 감당하면(`BuildPlanner.can_build(territory, "camp")`) 활성, 아니면 비활성. 누르면 `found_camp_requested(territory)` 방출 → `game.gd`가 [캠프 건설](building.md#캠프-건설-새-영지-확장) 모드(부대 시야 배치)로 진입. `territory == null`이면 비활성.
- **철거 버튼** (`_demolish_btn`) — 내부 판정 `_can_demolish`(위 참조 — 캠프 + `Faction.center_count() > 1`)가 참일 때만 표시(텍스트 `"캠프 철거 (영지 포기)"`). 누르면 `demolish_requested(building)` 방출 → `game.gd`가 [확인 다이얼로그](confirm-dialog.md) 후 **영지 통째 제거**를 처리한다([건물 정보 철거](building-info.md#철거)와 별개 — 거점은 캠프 메뉴에서).
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

- [정상] 세력 소속 영지의 건물로 `open` → Modal 제목 = 영지 이름("파리"), 세력 라벨 = 세력명("프랑스")
- [정상] `open` → 내부 Modal 열림(`ModalStack` 등록 = 지도 입력 차단), `close_menu` → 닫힘
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
- [정상] 캠프 + 세력 거점 2개 → **철거 버튼** 표시; 마지막 거점이면 숨김(세력 소멸 방지)
- [경계] 마을회관·성은 거점이 여럿이어도 숨김(캠프만); 무소속 캠프도 숨김
- [정상] 철거 버튼 누르면 `demolish_requested(building)` 방출
- [정상] **event-driven 갱신** — 연 상태에서 `territory.spend` → 다음 프레임에 자원 그리드 자동 갱신(재-open 없음)
- [경계] 닫힌 뒤 영지 변화 → 다시 열리지 않음(가드)
- [경계] 보급·판매·구매·병사 패널은 **없다**(화물·상거래 제거) — `open`해도 관련 노드 미생성

## 관련

- 표시되는 자원·이름·세력은 [Territory 엔티티](../entities/Territory.md)에서 온다.
- 세력은 [Faction](../entities/Faction.md) 엔티티 참고.
- 건축 흐름 전체(건물 리스트 → 건설 모드 배치)는 [건축](building.md) 참고. 리스트(2a)는 구현됨, 건설 모드 배치(2b)는 미구현.
