# Feature: Building Info (건물 정보 패널)

> 스크립트: `scenes/building/building_info.gd` (`extends CanvasLayer`, layer 48)

캠프가 아닌 [건물](../entities/Building.md)(현재 **농장**)을 클릭하면 화면 **우측 상단**에 그 건물의
정보를 띄우는 패널. [부대 정보 패널](party-info.md)·[캠프 메뉴](camp-menu.md)처럼 UI 트리를
씬이 아니라 코드(`_build`)로 구성한다(별도 `.tscn` 없음).

캠프 칸을 클릭하면 자원·건축이 있는 [캠프 메뉴](camp-menu.md)가 열리고, **캠프가 아닌 건물**은
이 정보 패널이 열린다(아래 [클릭 라우팅](#클릭-라우팅) 참고).

## 레이아웃

- 우측 상단에 `PanelContainer`(앵커 `PRESET_TOP_RIGHT`, 마진 16)를 둔다. 나머지 화면은 클릭을 가로막지 않는다(`MOUSE_FILTER_IGNORE`).
- 세로(VBox)로 쌓는다:
  - **제목** — 건물 종류 라벨(`building.label()`, 예: `"농장"`), 글자 크기 20.
  - **요약** — 건설 상태 · 시야를 한 줄로.
    - 완성: `"완성 · 시야 %d"` (`building.vision`)
    - 건설 중: `"건설 중 %d턴 · 시야 %d"` (`building.remaining_turns`, `building.vision`)
  - `HSeparator`.
  - **철거 버튼** — `can_demolish`가 참일 때만 정보 리스트 아래에 `"철거"` 버튼을 둔다(아래 [철거](#철거)). 누르면 `demolish_requested(building)` 시그널을 방출한다.
  - **정보 리스트**(VBox) — 아래 줄들을 순서대로 채운다. 없는 항목은 줄을 만들지 않는다.
    - **영지·세력** — `building.map_label_lines()`의 각 줄(`{text, color}`): 영지명(흰색), 세력명(세력색). 영지가 없으면 없음.
    - **수비** — 거점이면 `"수비대 N명"`(N = 그 거점 중심 타일 위 [방어 부대](camp-capture.md#거점-방어-창발--중심-점거) 인원, `building.defender_count`). 거점이 아닌 건물(농장 등)은 없음.
    - **1차 생산** — [1차 생산 건물](production.md)이면 산출 자원·생산력(1÷거리)·누적·배정 거점. `[거점 변경]`. (**`[인원 ±]`은 폐지** — 거리-only 생산.)
      - (flat `planned_production`·2차 가공 표시 줄은 폐지 — 모든 생산이 [1차 생산](production.md) 단일 모델.)
    - **인구 상한 기여** — 종류의 [`pop_cap`](../data/buildings.md)이 0보다 크면 `"인구 상한 +N"`(예: 집 `"인구 상한 +2"`). 생산 줄처럼 건설 중에도 완성 시 기여분(카탈로그 값)을 보여준다. **캠프는 제외**(기본 상한 10을 이 패널에 노출하지 않음 — 캠프 정보는 [캠프 메뉴](camp-menu.md)가 담당).

## 클릭 라우팅

좌클릭 우선순위는 순수 함수 [`ClickRouter.resolve`](../../scenes/game/click_router.gd)가 결정한다.
인자: `resolve(on_party, on_npc, on_camp, on_building, on_npc_building, selected, reachable, info_open)`.

우선순위(위에서부터):

1. **플레이어 부대 칸** → 부대 우선(`FOCUS_PARTY`). 단 캠프 위에 서 있고 정보가 이미 열려 있으면 `CAMP_MENU`.
2. **NPC 부대 칸** → `FOCUS_NPC` (정보).
3. **선택 중 + 이동 범위 칸** → `MOVE`. 건물(플레이어·NPC) 칸이어도 이동이 우선(건물 위 통행).
4. **플레이어 캠프 칸** → `CAMP_MENU` (자원·건축).
5. **그 외 플레이어 건물 칸**(`on_building`, 캠프 아님) → `BUILDING_INFO` (이 패널).
6. **발견된 NPC 거점 칸**(`on_npc_building`) → `NPC_BASE_INFO` (이 패널, 정보만). → [NPC Bases](npc-bases.md).
7. 그 외 → `DESELECT`.

`game.gd`(`_handle_click`)는 `_building_at(cell)`로 클릭된 **플레이어** 건물을 찾아 **거점**([center](../data/buildings.md#동작) = 캠프·마을회관·성, `BuildingTypes.is_center`)이면 `on_camp`(→ [캠프 메뉴](camp-menu.md)),
거점이 아닌 건물(농장·집 등)이면 `on_building`으로 분류하고, `_npc_building_at(cell)`로 발견된 NPC 거점이면 `on_npc_building`으로 넘긴다.
`BUILDING_INFO`·`NPC_BASE_INFO` 결과면 각각의 건물로 `building_info.open(building, can_demolish)`를 호출한다(공유 헬퍼 `_open_building_info`). `can_demolish`는 `BUILDING_INFO`(내 건물, **거점 아님**)면 참, `NPC_BASE_INFO`면 거짓 — **거점(캠프·마을회관·성)은 철거 불가**(캠프 메뉴로 라우팅되어 이 패널에 오지 않음). → [철거](#철거).

## 표시 규칙 (`game.gd` `_handle_click`)

- **농장 칸 클릭 → 패널을 연다**(`open`). 건설 중인 농장도 정보를 표시한다(요약에 남은 턴).
- **다른 곳 클릭 → 패널을 닫는다**(`close`): 빈 칸/이동 목적지 클릭, 캠프 클릭, 부대 클릭, 턴 종료 시.
- **[부대 정보 패널](party-info.md)·[부대 일람](party-roster.md)과 우측 상단을 공유한다**: 이 패널을 열면 둘을 감추고, 닫으면 부대 일람을 다시 표시한다(`game.gd`가 함께 토글).
- 선택 중이던 부대가 있으면 정보 패널을 열 때 선택을 해제한다(캠프 메뉴와 동일).

## 동작

- `open(building, can_demolish := false) -> void` — 건물 정보를 채우고 패널을 보인다.
  - 제목 = `building.label()`.
  - 요약 = 완성/건설 중에 따라 위 형식.
  - 정보 리스트를 **비우고** 다시 채운다(재오픈 시 이전 내용이 남지 않도록): 영지·세력 줄 → 수비대 → 생산 줄 → 인구 상한 줄.
  - `can_demolish`가 참이면 **철거 버튼**을 보이고, 거짓이면 숨긴다(재오픈 대비 매번 토글).
- `close() -> void` — 숨긴다.
- `signal demolish_requested(building)` — 철거 버튼을 누르면 방출. `game.gd`가 받아 실제 철거를 처리한다.

## 철거

내 소유이고 캠프가 아닌 건물은 정보 패널에서 **철거**할 수 있다.

- **철거 가능 판정은 `game.gd`가 한다**: `BUILDING_INFO`(플레이어 건물)면 `not BuildingTypes.is_center(building_type)`일 때 `can_demolish = true`, `NPC_BASE_INFO`(적 거점)면 항상 `false`. `_open_building_info(building, can_demolish)`로 넘긴다. 플레이어 **거점**(캠프·마을회관·성)은 [캠프 메뉴](camp-menu.md)로 라우팅되므로 이 패널의 철거 대상이 아니다.
- **철거 확인 게이트(`game.gd`)**: `demolish_requested`를 받으면 바로 철거하지 않고 [확인 다이얼로그](confirm-dialog.md)를 띄운다(`_on_demolish_requested` → `confirm_dialog.open(메시지, "철거", _do_demolish.bind(building))`). 메시지는 `"「<건물이름>」 철거 — 환급: <자재>"`(`refund_on_demolish`를 `자원 수량` 나열, 없으면 `"환급 없음"`). **[철거] 확인** → 콜백으로 실제 철거 실행. **[취소]/배경** → 아무 일 없음(콜백 미호출).
- **철거 실행(`game.gd` `_do_demolish`)**: `building.territory.demolish(building)`([Territory](../entities/Territory.md#동작) — 영지에서 떼고 `demolish_refund` 환급) → `_buildings`에서 제거 → 노드 `queue_free`(지연 해제) → [안개](fog-of-war.md)·라벨 갱신(`_update_fog`) → 패널 닫기.
- **건설 중 건물도 철거 가능**(건설 취소). 환급은 **낸 `build_cost`를 진행도 비례로 회수**(`refund_on_demolish` — 안 쓴 자재만, [Building](../entities/Building.md#동작)). 완성 건물은 `demolish_refund`(salvage). 미리보기 메시지도 이 실제 환급을 보여준다.
- 집을 철거하면 [인구 상한](../entities/Territory.md#인구-상한population_cap)이 내려간다 — 현재 인구가 상한을 초과해도 강제로 줄이지는 않는다([grow_population](turn.md)이 증가만 멈춤).

## 캠프 철거

거점(캠프·마을회관·성)은 클릭 시 [캠프 메뉴](camp-menu.md)로 라우팅되므로 위 건물 정보 철거 대상이 아니다. 대신 **캠프 메뉴의 [철거] 버튼**으로 **캠프(tier 0)만** 철거한다 — 영지를 통째로 포기(영지 상실).

- **철거 가능 판정(`game.gd` `_can_demolish_camp`)**: ① 건물이 **`camp`(tier 0)** ② **내 세력**(`territory.faction == _player_faction`) 영지 ③ **마지막 거점 아님**(`_faction_center_count(_player_faction) > 1` — 자기 세력 소멸 방지) — 셋 다 참일 때만 `can_demolish=true`로 [캠프 메뉴](camp-menu.md)를 연다. **마을회관·성은 항상 거짓**(다운그레이드 미구현).
- **확인**: `demolish_requested`를 받으면 [확인 다이얼로그](confirm-dialog.md)를 띄운다(`"「<영지명>」 캠프를 철거하고 영지를 포기할까요?"`, 확인 라벨 `"철거"`). [철거] 확인 시 `_do_demolish_camp(camp)`.
- **철거 실행(`game.gd` `_do_demolish_camp`)**: 그 **영지의 모든 건물**(캠프+농장·집 등)을 `_buildings`·맵에서 제거하고 `queue_free` → `Faction.remove_territory(territory)`([Faction](../entities/Faction.md) — 세력에서 영지 분리) → `_territories`에서 제거([안개](fog-of-war.md)·수입 대상 제외) → `toast` 알림 → 캠프 메뉴 닫기.
- **환급 없음** — 영지 통째 포기라 그 영지의 자원·금도 함께 상실한다.
- **유예(미구현)**: 마을회관·성 철거(또는 다운그레이드), 캠프 철거 부분 환급, NPC의 캠프 철거.

## 테스트 시나리오

`test/unit/test_building_info.gd`.

- [정상] 완성 농장 `open` → 제목 = `"농장"`, 요약 = `"완성 · 시야 4"`
- [정상] 영지(파리·프랑스)에 편입된 농장 `open` → 정보 리스트에 `"파리"`·`"프랑스"`·`"식량"`(생산 줄) 포함
- [정상] 건설 중 농장(build_turns 3) `open` → 요약 = `"건설 중 3턴 · 시야 4"`, 생산 줄은 여전히 산출 자원(`"식량"`) 표시
- [경계] 영지 없는 건물 `open` → 영지/세력 줄 없음(정보 리스트에 생산 줄만)
- [경계] 영지 있는 농장으로 연 뒤 영지 없는 건물로 재오픈 → 정보 리스트가 교체됨(이전 영지 줄 사라짐)
- [정상] 집 `open` → 정보 리스트에 `"인구 상한 +2"` 포함(건설 중에도)
- [경계] 농장(상한 기여 없음) `open` → `"인구 상한"` 줄 없음
- [정상] `open(farm, true)` → **철거 버튼** 표시; `open(farm)`(기본 false) → 철거 버튼 숨김
- [정상] `can_demolish=true`로 연 뒤 철거 버튼을 누르면 `demolish_requested(building)` 방출
- [경계] `can_demolish=true`로 연 뒤 `false`로 재오픈 → 철거 버튼 숨김(토글)
- [정상] `open` 후 `visible == true`, `close()` 후 `false`
- **캠프 철거**: 캠프 메뉴 [철거] 버튼 표시는 [Camp Menu 시나리오](camp-menu.md#테스트-시나리오)로 검증. `_can_demolish_camp` 판정(캠프·내 세력·마지막 거점 아님)과 `_do_demolish_camp` 영지 통째 제거는 `game.gd` 배선이라 실제 실행으로 확인한다.

캠프 표시(NPC 거점도 이 패널로 정보만):

- [정상] 영지·세력에 편입된 캠프 `open` → 제목 "캠프", 요약 "완성 · 시야 5", 영지·세력 줄, 생산 줄 없음

클릭 라우팅은 `test/unit/test_click_router.gd`:

- [정상] 농장 칸(`on_building=true`, 부대·선택 아님) → `BUILDING_INFO`
- [정상] 선택 중 + 범위 + 농장 칸 → `MOVE`(건물 위 통행이 우선)
- [정상] 캠프 칸(`on_camp=true`) → `CAMP_MENU` (캠프가 건물 정보보다 우선)
- [정상] NPC 거점 칸(`on_npc_building=true`) → `NPC_BASE_INFO` ([NPC Bases](npc-bases.md))

## 관련

- 표시 데이터는 [Building](../entities/Building.md) — `label()`, `vision`, `is_complete()`/`remaining_turns`, `map_label_lines()`, [1차 생산](production.md) 상태(`production_points`·`assigned_center` 등).
- 종류별 생산·시야 값은 [data/buildings.md](../data/buildings.md).
- 캠프 클릭 시 열리는 [Camp Menu](camp-menu.md)와 우측 상단을 쓰는 [Party Info](party-info.md)와 대응.
