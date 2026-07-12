# Feature: Camp Menu (캠프 메뉴)

> 스크립트: `scenes/camp/camp_menu.gd` (`extends CanvasLayer`, layer 64)

**거점**([center](../data/buildings.md#동작) = 캠프·마을회관·성) 헥스를 클릭하면 열리는 오버레이. 그 건물이 속한 **영지** 정보(자원·이름·세력)를 보여준다.
(거점이 아닌 건물(농장·집 등)은 대신 [건물 정보 패널](building-info.md)이 열린다.)
UI 트리는 씬이 아니라 코드(`_build`)로 구성된다.
(스크립트/노드 이름은 `camp_menu`지만 실제로는 클릭한 건물의 **영지** 정보를 표시한다.)

## 레이아웃

- 반투명 배경(`Color(0,0,0,0.45)`) — 클릭 시 닫힘.
- 화면 중앙에 두 패널을 나란히(HBox, separation 16):
  - **좌측 — 자원 패널** (220×260): 제목 "자원" + 2열 그리드(자원명 / 값). **`인구` 행의 값은 `"현재 / 상한"`**(예: `10 / 12`, 상한 = `territory.population_cap()` → [인구 상한](../entities/Territory.md#인구-상한population_cap)). 나머지 자원은 수량만.
  - **우측 — 영지 패널** (200×260): 제목 = **영지 이름**(예: "파리") + 그 아래 **세력명**(예: "프랑스", 세력 색상으로 표기) + **업그레이드 버튼**(거점의 다음 티어가 있을 때) + "건축" 버튼 + **건설 리스트**(기본 숨김) + (하단) "닫기" 버튼.

## 동작

- `open(building: Building, party := null, can_demolish := false)` — 건물의 영지(`building.territory`)를 읽어 자원 그리드를 채우고(`territory.resources`, 삽입 순서대로), 우측 패널의 이름/세력 라벨을 채운 뒤 메뉴를 연다. `party`(= 그 거점 **주둔 부대**, [Garrison](garrison.md))가 주어지고 건물이 **거점**(`BuildingTypes.is_center`)이면 보급·판매·구매 패널을 함께 띄운다(아래). `can_demolish`가 참이면 [철거 버튼](#철거-버튼)을 보인다(재오픈 대비 매번 토글).
  - 제목 라벨 = `territory.name`.
  - 세력 라벨 = `territory.faction.name` (색상 = `territory.faction.color`). `faction`이 `null`이면 세력 라벨은 빈 문자열.
  - `building.territory`가 `null`이거나 영지에 세력이 없으면 라벨은 빈 문자열이고, 세력 색상 오버라이드를 제거한다(다른 영지로 재오픈 대비). `territory == null`이면 자원 그리드도 비어 있다.
- `close_menu()` — 숨긴다.
- 닫기 트리거: 배경 좌클릭, "닫기" 버튼.
- **업그레이드 버튼** (`_upgrade_btn`) — 연 건물이 거점이고 [`next_center`](../data/buildings.md#거점-업그레이드)가 있으면(캠프·마을회관) 표시한다. 텍스트 `"<다음 티어 라벨>으로 업그레이드  <비용>"`(예: `"마을회관으로 업그레이드  목재 10 · 석재 10 · 밀 20"`). `BuildPlanner.can_upgrade`면 활성, 비용 부족이면 비활성. 최종 티어(성)·비거점이면 **숨김**. 누르면 `upgrade_requested(building)` 방출 → `game.gd`가 지불·`upgrade_to` 처리([건축](building.md#거점-업그레이드)).
- **캠프 건설 버튼** (`_found_camp_btn`) — `"캠프 건설 (새 영지)  목재 10 · 밀 10"`. 여는 영지가 캠프 비용을 감당하면(`BuildPlanner.can_build(territory, "camp")`) 활성, 아니면 비활성. 누르면 `found_camp_requested(territory)` 방출 → `game.gd`가 [캠프 건설](building.md#캠프-건설-새-영지-확장) 모드(부대 시야 배치)로 진입. `territory == null`이면 비활성.
- **철거 버튼** (`_demolish_btn`) — `open`의 `can_demolish`가 참일 때만 표시(텍스트 `"캠프 철거 (영지 포기)"`). 누르면 `demolish_requested(building)` 방출 → `game.gd`가 [확인 다이얼로그](confirm-dialog.md) 후 **영지 통째 제거**를 처리한다([건물 정보 철거](building-info.md#철거)와 별개 — 거점은 캠프 메뉴에서). `can_demolish` 판정은 `game.gd` — **캠프(tier 0)**·**내 세력 영지**·**마지막 거점 아님**(세력 소멸 방지)일 때만 참. 마을회관·성은 거짓(철거 불가).
- **건축 버튼** (`_on_build_pressed`) — 우측 패널을 **건설 리스트**로 전환한다(건축 버튼은 숨기고 리스트를 보임).
  - 리스트 = [건물 카탈로그](../data/buildings.md)의 **건축 가능 종류**(`BuildingTypes.BUILDABLE_IDS` — 채석장·농장·집·벌목소). 거점(캠프·마을회관·성)은 제외(캠프=새 영지, 마을회관·성=업그레이드).
  - 각 항목 = 버튼 `"<라벨>  <비용>[  인원 N]"`(예: `"농장  목재 5 · 밀 5  인원 2"`). 비용은 종류의 `build_cost`, `인원 N`은 [`required_pop`](../data/buildings.md#필요인원-required_pop)이 0보다 클 때만 덧붙인다.
  - **영지가 없거나** `BuildPlanner.can_build(territory, type_id)`가 거짓이면 항목 버튼은 **비활성**(`disabled`). `can_build`은 [선행건물](building.md#선행건물-게이트)·자재(`build_cost`)·[필요인원](building.md#필요인원-게이트)(인구 ≥ `required_pop`)을 함께 본다.
  - 선행 미충족이면 라벨 뒤에 `"  (선행: <선행 라벨> 필요)"`를 덧붙여 이유를 보인다(예: `"농장  ...  (선행: 마을회관 필요)"`).
  - 항목을 누르면 `build_selected(type_id, territory)` 시그널을 방출하고 메뉴를 닫는다. 실제 배치(건설 모드)는 게임이 이 시그널을 받아 처리한다 — **건설 모드 배치(2b)는 미구현**.
- `open`은 열 때마다 리스트를 숨기고 건축 버튼을 다시 보여 **정보 화면 상태로 초기화**한다(이전 오픈에서 리스트가 열려 있던 상태가 남지 않도록).
- **보급(화물) 패널** (`_cargo_panel`, `party != null` + **거점**(`is_center`)일 때) — 영지 자원 ↔ 부대 [화물](../entities/Party.md#화물-cargo--캐러반)을 적재/하역한다. 자원별 행: `"<자원>  <영지량> / <화물량>"` + **[적재]**(영지→화물) · **[하역]**(화물→영지) 버튼. 한 번에 `CARGO_STEP`(5)씩, 영지 재고·화물 용량·화물 보유분으로 상한. `인구`·`금`은 운반 대상에서 제외(노동력·화폐). 이동할 때마다 화물 목록과 좌측 자원 그리드를 다시 그린다(버튼 free 지연 — locked 방지). → [캐러반](building.md#캠프-건설-새-영지-확장)으로 전초기지에 자원을 옮겨 개발한다.
- **판매 패널** (`_sell_panel`, `party != null` + **거점**일 때 — 보급 패널과 같은 조건) — 부대의 노획 장비·화물을 **금**으로 판다([Trade](trade.md)). **장비 섹션**: `loot_items`를 이름별로 묶어 `[판매]`(1개씩 → 영지 금 += `ItemTypes.item_value`). **화물 섹션**: `cargo` 자원별(`인구`·`금` 제외) `[판매]`(`CARGO_STEP`씩 → 영지 금 += `ResourceTypes.value` × 판매량). 판매할 때마다 판매 목록과 좌측 자원 그리드(금)를 다시 그린다.
- **구매 패널** (`_buy_panel`, `party != null` + **거점**일 때 — 판매 패널과 같은 조건) — 금으로 [상거래](trade.md#구매-camp_menu-구매-패널) 매입. **장비 섹션**: `ItemTypes` 전 카탈로그(무기/방어구/방패) `"<이름> <구매가>금"` + `[구매]`(구매가 = `item_value × BUY_MARKUP`(2), → 부대 `loot_items`). **자원 섹션**: `ResourceTypes.VALUES` 자원 `[구매]`(`CARGO_STEP`씩, 구매가 = `value × BUY_MARKUP × CARGO_STEP`, → 영지 자원). **병사 섹션**: 소집병 `[구매]`(`SOLDIER_GOLD_COST`(20)금 + `SOLDIER_POP_COST`(1)인구, → **주둔 부대**(`_party`) `members`에 소집병 1명 편입). 각 `[구매]`는 비용(금·인구) 부족이면 비활성. 주둔 부대(`_party`)가 없으면 구매 패널 자체가 숨겨져 병사 구매 불가. 구매마다 구매·판매 목록과 좌측 자원 그리드를 다시 그린다.
- `signal garrison_changed` — 병사 구매로 주둔 부대에 병사가 추가될 때 방출. `game.gd`가 받아 [부대 일람](party-roster.md)·[안개](fog-of-war.md)·수비 배지를 갱신한다.
- `signal upgrade_requested(building)` — 업그레이드 버튼을 누르면 방출. `game.gd`가 받아 거점 [업그레이드](building.md#거점-업그레이드)를 처리한다.
- `signal found_camp_requested(territory)` — 캠프 건설 버튼을 누르면 방출. `game.gd`가 받아 [새 영지 캠프 건설](building.md#캠프-건설-새-영지-확장) 모드로 진입한다.
- `signal demolish_requested(building)` — 철거 버튼을 누르면 방출. `game.gd`가 받아 확인 후 [캠프 철거](building-info.md#캠프-철거)를 처리한다.

## 테스트 시나리오

`test/unit/test_camp_menu.gd`.

- [정상] 세력 소속 영지의 건물로 `open` → 제목 라벨 = 영지 이름("파리"), 세력 라벨 = 세력명("프랑스")
- [정상] 세력 라벨 색상 = 세력 색상
- [경계] `territory == null`인 건물로 `open` → 세력 라벨은 빈 문자열
- [경계] 세력 있는 영지로 연 뒤 세력 없는 건물로 재오픈 → 이전 세력 색상 오버라이드가 남지 않음
- [정상] `open` 후 자원 그리드가 영지 자원 7종으로 채워진다
- [정상] `인구` 행 값이 `"현재 / 상한"` 형식(예: 마을회관 거점 영지 → `"10 / 10"`)
- [정상] 자원 충분 + **캠프 거점**(tier 0) 영지로 건축 → **채석장**(선행 camp)이 **활성**; **농장·집·벌목소**(선행 town_hall)는 **비활성**이고 라벨에 `"(선행: 마을회관 필요)"` 포함
- [정상] 건축 리스트 항목 수 = 4(채석장·농장·집·벌목소, 거점 미포함), 채석장 텍스트에 라벨·비용·`"인원 1"` 포함
- [정상] 거점을 **마을회관**(tier 1)으로 하면 농장·집·벌목소가 **활성**으로 전환
- [경계] 인구가 `required_pop` 미만인 영지 → 선행·자재 충족이어도 해당 항목 **비활성**
- [경계] 자원 부족·영지 없음 → 항목 **비활성**
- [정상] 활성 항목을 누르면 `build_selected(type_id, territory)` 시그널 방출
- [경계] 건축으로 리스트를 연 뒤 다시 `open` → 리스트 숨김·건축 버튼 표시(정보 화면으로 초기화)
- [정상] **캠프** 거점으로 `open` → 업그레이드 버튼 표시, 텍스트에 `"마을회관"` 포함; 비용 충분하면 활성
- [정상] **성** 거점으로 `open` → 업그레이드 버튼 **숨김**(next_center 없음)
- [정상] 업그레이드 버튼 누르면 `upgrade_requested(building)` 방출
- [정상] 캠프 비용 감당 가능한 영지로 `open` → **캠프 건설 버튼** 활성, 텍스트에 `"캠프 건설"` 포함; 누르면 `found_camp_requested(territory)` 방출
- [경계] 자원 부족·영지 없음 → 캠프 건설 버튼 비활성
- [정상] `open(camp, party, true)` → **철거 버튼** 표시; `open(camp, party)`(기본 false) → 철거 버튼 숨김(재오픈 토글)
- [정상] `can_demolish=true`로 연 뒤 철거 버튼 누르면 `demolish_requested(building)` 방출
- [정상] 부대 + 거점으로 `open` → 보급 패널 표시(부대 없으면 숨김)
- [정상] 자원 있는 행에서 **적재** → 영지 자원 −5, 부대 화물 +5(용량·재고 상한)
- [정상] 화물 있는 상태서 **하역** → 부대 화물 −5, 영지 자원 +5
- [정상] 보급 패널에 `인구` 행 없음(노동력, 운반 제외)
- [정상] 부대 + 거점으로 `open` → 판매 패널 표시(부대 없으면 숨김)
- [정상] 장비 판매: 부대 `loot_items=["sword"]` → [판매] → 영지 `금` +14, `loot_items` 비워짐
- [정상] 화물 판매: 부대 철괴 10 → [판매] → 영지 `금` +60(12×5), 화물 철괴 5
- [경계] 판매 패널 화물 섹션에 `인구`·`금` 행 없음
- [정상] 부대 + 거점으로 `open` → 구매 패널 표시(부대 없으면 숨김)
- [정상] 장비 구매: 영지 금 30 · `sword`(구매가 28) → 영지 금 2, 부대 `loot_items`에 `sword`
- [경계] 금 부족(10 < 28) → `sword` [구매] 비활성
- [정상] 자원 구매: 영지 금 30 → `밀` [구매](10=1×2×5) → 영지 금 20·`밀 +5`; [경계] 금 부족 시 비활성
- [정상] 병사 구매: 주둔 부대 + 영지 금 30·인구 5 → [구매] → 금 10·인구 4·주둔 부대 `members` +1; [경계] 금<20 또는 인구<1 → 비활성

## 관련

- 표시되는 자원·이름·세력은 [Territory 엔티티](../entities/Territory.md)에서 온다.
- 세력은 [Faction](../entities/Faction.md) 엔티티 참고.
- 건축 흐름 전체(건물 리스트 → 건설 모드 배치)는 [건축](building.md) 참고. 리스트(2a)는 구현됨, 건설 모드 배치(2b)는 미구현.
