# Feature: NPC Bases (NPC 세력 거점)

> 스크립트: `scenes/game/game.gd` (`_setup_factions`, `_setup_npc_base`, `_npc_building_at`, `_update_npc_building_visibility`) · `scenes/party/unit_types.gd` · `scenes/game/fog.gd` (`is_cell_explored`) · `scenes/game/click_router.gd` (`NPC_BASE_INFO`)

게임 시작 시 각 NPC [세력](../entities/Faction.md)마다 수도 [영지](../entities/Territory.md)와 그 중심 캠프([Building](../entities/Building.md))를 배치한다.
이전에는 플레이어 세력·영지·캠프만 있었고 NPC는 부대만 있었다(영지·건물 없음). 이 기능은 NPC에게 **거점**을 부여해 승리조건·거점 기반 AI의 토대를 만든다.

## 생성 (`game.gd` `_setup_factions`)

플레이어 세력·영지·캠프는 이전과 동일하게 만든다(카탈로그 `azel` 스펙 — 세력 "푸른 왕국", 영지 "창천성", 중앙 캠프).
추가로 각 NPC 세력마다 **세력 → 영지 → 캠프**를 만든다([유닛 카탈로그](../data/units.md)의 부대 스펙 사용):

| 세력 | 수도(영지명) | 부대 | id |
| --- | --- | --- | --- |
| 사막 술탄국 | 알사바흐 | 카심 이븐 라시드 | `qasim` |
| 암흑 제국 | 흑요요새 | 발타자르 | `balthazar` |
| 초원 칸국 | 텡그리 언덕 | 바트르 칸 | `batur` |

- 수도명은 카탈로그 `territory` 필드에서 읽는다(NPC의 `territory`가 이전엔 `""`였으나 위 이름으로 채운다).
- 세력 색은 부대 색(`color`)과 같다. 캠프 라벨에 영지명(흰색)·세력명(세력색)이 표시된다([Building](../entities/Building.md) `map_label_lines`).
- 초기 자원은 플레이어와 동일하게 캠프 카탈로그(`BuildingTypes.CAMP`)의 `resources`를 복사해 영지에 넣는다.
  - **NPC 자원 수입·소비는 아직 미사용** — NPC 영지는 턴 종료 수입(`_territories`)에 넣지 않는다. *(NPC 경제 미구현)*
- 캠프는 **완성 상태**로 생성한다(건설 중 아님).
- NPC 캠프는 플레이어 캠프·농장과 별도로 `_npc_buildings` 배열에 담는다(플레이어 `_buildings`와 구분).

## 배치 위치 (초기)

각 NPC 부대와 **같은 방향의 바깥쪽**(부대보다 멀리). 맵 중앙(플레이어 캠프) 기준 오프셋 — 초기 시야 밖이라 처음엔 안개에 가려진다.

| 세력 | 방향 | 캠프 오프셋 (칸) | (참고) 부대 오프셋 |
| --- | --- | --- | --- |
| 사막 술탄국 | 동 | `(+11, 0)` | `(+5, 0)` |
| 암흑 제국 | 북 | `(0, -11)` | `(0, -5)` |
| 초원 칸국 | 서 | `(-12, +1)` | `(-7, +1)` |

- 캠프는 중심 + 이웃 6칸 = 7헥스를 차지한다(모든 건물 공통 발자국).
- 플레이어 캠프(중앙)·부대·서로 겹치지 않게 떨어뜨린다.

## 안개 반영 (`game.gd` `_update_npc_building_visibility`)

NPC 거점은 NPC 부대와 같은 원칙으로 안개를 따른다. → [Fog of War](fog-of-war.md).

- NPC 거점은 플레이어 시야를 **밝히지 않는다** — 적 건물이므로 `_update_fog`의 시야 합산(`buildings_vision`)에 넣지 않는다(플레이어 `_buildings`만 합산).
- **발견 전엔 가려지고, 한 번 발견하면 계속 표시된다**(정적 구조물). 판정 기준은 **탐험됨**(`fog.is_cell_explored`) — 거점의 7칸 중 하나라도 탐험된 적이 있으면 발견으로 본다.
  - 이는 NPC **부대**가 **현재 시야**(`is_cell_visible`)로만 보이는 것과 다르다(부대는 움직이므로 지나가면 다시 숨지만, 거점은 한 번 보면 계속 안다).
  - 발견됐지만 현재 시야 밖인 거점은 탐험됨 안개(반투명 검정) 아래로 지형처럼 흐릿하게 남는다.
- `game.gd` `_update_npc_building_visibility`가 `_update_fog` 직후 각 NPC 캠프의 `Node2D.visible`을 토글한다(시작·이동·턴 종료 시).

## 정보 표시 (클릭)

발견된 NPC 거점을 클릭하면 우측 상단에 [건물 정보 패널](building-info.md)을 연다 — 종류("캠프")·시야·소속 영지·세력을 표시한다.
플레이어 캠프처럼 [건축] 메뉴([Camp Menu](camp-menu.md))를 여는 게 아니라 **정보만** 본다(NPC 거점엔 건축이 없다).
미발견(가려진) 거점은 클릭해도 반응하지 않는다.

### 클릭 라우팅

좌클릭 우선순위는 순수 함수 [`ClickRouter.resolve`](../../scenes/game/click_router.gd)가 결정한다.
인자: `resolve(on_party, on_npc, on_camp, on_building, on_npc_building, selected, reachable, info_open)`.

우선순위(위에서부터):

1. **플레이어 부대 칸** → `FOCUS_PARTY`(캠프 위 재클릭 시 `CAMP_MENU`).
2. **NPC 부대 칸** → `FOCUS_NPC`(정보). NPC 부대가 거점 위에 서 있어도 부대가 앞 순위.
3. **선택 중 + 이동 범위 칸** → `MOVE`(건물 위 통행 — 플레이어·NPC 건물 모두 이동을 막지 않음).
4. **플레이어 캠프 칸** → `CAMP_MENU`.
5. **플레이어 건물(농장) 칸** → `BUILDING_INFO`.
6. **NPC 거점 칸** → `NPC_BASE_INFO` (이 기능). 발견된 거점만 `on_npc_building=true`로 넘어온다.
7. 그 외 → `DESELECT`.

`game.gd`(`_handle_click`)는 `_npc_building_at(cell)`로 **발견된**(`visible`) NPC 거점을 찾아 `on_npc_building`을 넘기고, `NPC_BASE_INFO` 결과면 그 거점으로 `building_info.open(...)`을 호출한다(플레이어 부대 정보·일람은 감춘다). `BUILDING_INFO`·`NPC_BASE_INFO`는 같은 패널 열기 로직(`_open_building_info`)을 공유한다.

## 관련 후속

- 거점 **점령**(흡수/파괴)은 [Camp Capture](camp-capture.md)에서 구현됐다(발견된 거점 인접 시).

## 미구현

- **승리조건**(세력 소멸·정복 승리 → [승패](victory.md), [승리조건](../../table/시스템/승리조건.md)).
- 캠프 **수비대**·NPC의 **거점 기반 생산·AI**(자원 수입, 거점 방어/확장).

## 테스트 시나리오

**클릭 라우팅** — `test/unit/test_click_router.gd`:
- [정상] NPC 거점 칸(`on_npc_building=true`, 나머지 아님) → `NPC_BASE_INFO`
- [정상] 선택 중 + 범위 + NPC 거점 칸 → `MOVE`(건물 위 통행이 우선)
- [정상] NPC 부대 칸 + NPC 거점 칸(부대가 거점 위) → `FOCUS_NPC`(부대 우선)
- [정상] 플레이어 캠프·건물 칸 + NPC 거점 칸 → 플레이어 건물 우선(`CAMP_MENU`/`BUILDING_INFO`)
- [경계] NPC 거점 칸 없음(`on_npc_building=false`)이고 그 외 없음 → `DESELECT`

**안개(탐험됨) 판정** — `test/unit/test_fog.gd`:
- [정상] 한 번 본 셀은 `is_cell_explored`가 `true`
- [정상] 탐험만 되고 현재 시야 밖인 셀도 `is_cell_explored`가 `true`(부대와 달리 거점은 계속 보임)
- [예외] 한 번도 본 적 없는 셀은 `is_cell_explored`가 `false`

**데이터(수도명)** — `test/unit/test_unit_types.gd`:
- [정상] NPC 부대 스펙의 `territory`가 각각 알사바흐·흑요요새·텡그리 언덕
- [정상] 플레이어(`azel`) `territory`는 여전히 창천성

**정보 패널(캠프 표시)** — `test/unit/test_building_info.gd`:
- [정상] 영지·세력에 편입된 캠프 `open` → 제목 "캠프", 요약 "완성 · 시야 5", 정보 리스트에 영지명·세력명(생산 줄 없음)

`game.gd`의 인스턴스화·배치·`visible` 토글은 씬 트리·터레인 의존이라 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Faction (세력)](../entities/Faction.md) · [Territory (영지)](../entities/Territory.md) · [Building (건물)](../entities/Building.md) · [유닛 카탈로그](../data/units.md)
- [Parties (부대 배치)](parties.md) — NPC 부대 생성(이 거점의 소속). [Fog of War](fog-of-war.md) · [Building Info](building-info.md) · [Camp Menu](camp-menu.md).
- 기획: [영지](../../table/세력/영지.md) · [승리조건](../../table/시스템/승리조건.md)
