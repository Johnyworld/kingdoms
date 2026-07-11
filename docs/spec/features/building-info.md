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
    - **수비대** — 캠프면 `"수비대 N명"`(N = `building.garrison.size()`). 캠프가 아닌 건물(농장 등)은 없음. → [Garrison](garrison.md).
    - **생산량** — `building.planned_production()`의 각 자원: `"%s +%d / 턴"` (예: `"밀 +1 / 턴"`). 생산이 없으면(캠프 등) 없음.
      - 건설 중이어도 **완성 시 생산량**을 보여준다(`planned_production()`은 건설 여부와 무관, `production()`과 다름).
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

`game.gd`(`_handle_click`)는 `_building_at(cell)`로 클릭된 **플레이어** 건물을 찾아 **캠프**(`building_type == "camp"`)면 `on_camp`,
그 외 건물이면 `on_building`으로 분류하고, `_npc_building_at(cell)`로 발견된 NPC 거점이면 `on_npc_building`으로 넘긴다.
`BUILDING_INFO`·`NPC_BASE_INFO` 결과면 각각의 건물로 `building_info.open(building, can_demolish)`를 호출한다(공유 헬퍼 `_open_building_info`). `can_demolish`는 `BUILDING_INFO`(내 건물, 캠프 아님)면 참, `NPC_BASE_INFO`면 거짓. → [철거](#철거).

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

- **철거 가능 판정은 `game.gd`가 한다**: `BUILDING_INFO`(플레이어 건물)면 `building_type != "camp"`일 때 `can_demolish = true`, `NPC_BASE_INFO`(적 거점)면 항상 `false`. `_open_building_info(building, can_demolish)`로 넘긴다. 플레이어 캠프는 [캠프 메뉴](camp-menu.md)로 라우팅되므로 이 패널의 철거 대상이 아니다.
- **철거 실행(`game.gd` `_on_demolish_requested`)**: `building.territory.demolish(building)`([Territory](../entities/Territory.md#동작) — 영지에서 떼고 `demolish_refund` 환급) → `_buildings`에서 제거 → 노드 `queue_free`(버튼 처리 중이므로 지연 해제) → [안개](fog-of-war.md)·라벨 갱신(`_update_fog`) → 패널 닫기.
- **건설 중 건물도 철거 가능**(건설 취소). 환급은 완성 건물과 동일한 `demolish_refund`.
- 집을 철거하면 [인구 상한](../entities/Territory.md#인구-상한population_cap)이 내려간다 — 현재 인구가 상한을 초과해도 강제로 줄이지는 않는다([grow_population](turn.md)이 증가만 멈춤).
- **유예(미구현)**: 캠프 철거(영지 상실), 철거 확인 다이얼로그, 건설 중 부분 환급.

## 테스트 시나리오

`test/unit/test_building_info.gd`.

- [정상] 완성 농장 `open` → 제목 = `"농장"`, 요약 = `"완성 · 시야 4"`
- [정상] 영지(파리·프랑스)에 편입된 농장 `open` → 정보 리스트에 `"파리"`·`"프랑스"`·`"밀"`(생산 줄) 포함
- [정상] 건설 중 농장(build_turns 3) `open` → 요약 = `"건설 중 3턴 · 시야 4"`, 생산 줄은 여전히 `"밀 +1 / 턴"`
- [경계] 영지 없는 건물 `open` → 영지/세력 줄 없음(정보 리스트에 생산 줄만)
- [경계] 영지 있는 농장으로 연 뒤 영지 없는 건물로 재오픈 → 정보 리스트가 교체됨(이전 영지 줄 사라짐)
- [정상] 집 `open` → 정보 리스트에 `"인구 상한 +2"` 포함(건설 중에도)
- [경계] 농장(상한 기여 없음) `open` → `"인구 상한"` 줄 없음
- [정상] `open(farm, true)` → **철거 버튼** 표시; `open(farm)`(기본 false) → 철거 버튼 숨김
- [정상] `can_demolish=true`로 연 뒤 철거 버튼을 누르면 `demolish_requested(building)` 방출
- [경계] `can_demolish=true`로 연 뒤 `false`로 재오픈 → 철거 버튼 숨김(토글)
- [정상] `open` 후 `visible == true`, `close()` 후 `false`

캠프 표시(NPC 거점도 이 패널로 정보만):

- [정상] 영지·세력에 편입된 캠프 `open` → 제목 "캠프", 요약 "완성 · 시야 5", 영지·세력 줄, 생산 줄 없음

클릭 라우팅은 `test/unit/test_click_router.gd`:

- [정상] 농장 칸(`on_building=true`, 부대·선택 아님) → `BUILDING_INFO`
- [정상] 선택 중 + 범위 + 농장 칸 → `MOVE`(건물 위 통행이 우선)
- [정상] 캠프 칸(`on_camp=true`) → `CAMP_MENU` (캠프가 건물 정보보다 우선)
- [정상] NPC 거점 칸(`on_npc_building=true`) → `NPC_BASE_INFO` ([NPC Bases](npc-bases.md))

## 관련

- 표시 데이터는 [Building](../entities/Building.md) — `label()`, `vision`, `is_complete()`/`remaining_turns`, `map_label_lines()`, `planned_production()`.
- 종류별 생산·시야 값은 [data/buildings.md](../data/buildings.md).
- 캠프 클릭 시 열리는 [Camp Menu](camp-menu.md)와 우측 상단을 쓰는 [Party Info](party-info.md)와 대응.
