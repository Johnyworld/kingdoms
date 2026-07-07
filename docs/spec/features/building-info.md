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
  - **정보 리스트**(VBox) — 아래 줄들을 순서대로 채운다. 없는 항목은 줄을 만들지 않는다.
    - **영지·세력** — `building.map_label_lines()`의 각 줄(`{text, color}`): 영지명(흰색), 세력명(세력색). 영지가 없으면 없음.
    - **생산량** — `building.planned_production()`의 각 자원: `"%s +%d / 턴"` (예: `"밀 +1 / 턴"`). 생산이 없으면(캠프 등) 없음.
      - 건설 중이어도 **완성 시 생산량**을 보여준다(`planned_production()`은 건설 여부와 무관, `production()`과 다름).

## 클릭 라우팅

좌클릭 우선순위는 순수 함수 [`ClickRouter.resolve`](../../scenes/game/click_router.gd)가 결정한다.
인자: `resolve(on_party, on_camp, on_building, selected, reachable, info_open)`.

우선순위(위에서부터):

1. **부대 칸** → 부대 우선(`FOCUS_PARTY`). 단 캠프 위에 서 있고 정보가 이미 열려 있으면 `CAMP_MENU`.
2. **선택 중 + 이동 범위 칸** → `MOVE`. 건물(캠프·농장) 칸이어도 이동이 우선(건물 위 통행).
3. **캠프 칸** → `CAMP_MENU` (자원·건축).
4. **그 외 건물 칸**(`on_building`, 캠프 아님) → `BUILDING_INFO` (이 패널).
5. 그 외 → `DESELECT`.

`game.gd`(`_handle_click`)는 `_building_at(cell)`로 클릭된 건물을 찾아 **캠프**(`building_type == "camp"`)면 `on_camp`,
그 외 건물이면 `on_building`으로 분류해 넘긴다. `BUILDING_INFO` 결과면 찾은 건물로 `building_info.open(building)`.

## 표시 규칙 (`game.gd` `_handle_click`)

- **농장 칸 클릭 → 패널을 연다**(`open`). 건설 중인 농장도 정보를 표시한다(요약에 남은 턴).
- **다른 곳 클릭 → 패널을 닫는다**(`close`): 빈 칸/이동 목적지 클릭, 캠프 클릭, 부대 클릭, 턴 종료 시.
- **[부대 정보 패널](party-info.md)·[부대 일람](party-roster.md)과 우측 상단을 공유한다**: 이 패널을 열면 둘을 감추고, 닫으면 부대 일람을 다시 표시한다(`game.gd`가 함께 토글).
- 선택 중이던 부대가 있으면 정보 패널을 열 때 선택을 해제한다(캠프 메뉴와 동일).

## 동작

- `open(building) -> void` — 건물 정보를 채우고 패널을 보인다.
  - 제목 = `building.label()`.
  - 요약 = 완성/건설 중에 따라 위 형식.
  - 정보 리스트를 **비우고** 다시 채운다(재오픈 시 이전 내용이 남지 않도록): 영지·세력 줄 → 생산 줄.
- `close() -> void` — 숨긴다.

## 테스트 시나리오

`test/unit/test_building_info.gd`.

- [정상] 완성 농장 `open` → 제목 = `"농장"`, 요약 = `"완성 · 시야 4"`
- [정상] 영지(파리·프랑스)에 편입된 농장 `open` → 정보 리스트에 `"파리"`·`"프랑스"`·`"밀"`(생산 줄) 포함
- [정상] 건설 중 농장(build_turns 3) `open` → 요약 = `"건설 중 3턴 · 시야 4"`, 생산 줄은 여전히 `"밀 +1 / 턴"`
- [경계] 영지 없는 건물 `open` → 영지/세력 줄 없음(정보 리스트에 생산 줄만)
- [경계] 영지 있는 농장으로 연 뒤 영지 없는 건물로 재오픈 → 정보 리스트가 교체됨(이전 영지 줄 사라짐)
- [정상] `open` 후 `visible == true`, `close()` 후 `false`

클릭 라우팅은 `test/unit/test_click_router.gd`:

- [정상] 농장 칸(`on_building=true`, 부대·선택 아님) → `BUILDING_INFO`
- [정상] 선택 중 + 범위 + 농장 칸 → `MOVE`(건물 위 통행이 우선)
- [정상] 캠프 칸(`on_camp=true`) → `CAMP_MENU` (캠프가 건물 정보보다 우선)

## 관련

- 표시 데이터는 [Building](../entities/Building.md) — `label()`, `vision`, `is_complete()`/`remaining_turns`, `map_label_lines()`, `planned_production()`.
- 종류별 생산·시야 값은 [data/buildings.md](../data/buildings.md).
- 캠프 클릭 시 열리는 [Camp Menu](camp-menu.md)와 우측 상단을 쓰는 [Party Info](party-info.md)와 대응.
