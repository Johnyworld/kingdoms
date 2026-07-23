# Feature: Party Info (부대 정보 패널)

> 스크립트: `scenes/party/party_info.gd` (`extends CanvasLayer`, layer 48)

[부대](../entities/Party.md)를 클릭하면 화면 **우측 상단**에 그 부대의 정보를 띄우는 패널.
플레이어 부대뿐 아니라 **NPC 부대**도 클릭하면 같은 패널로 정보를 표시한다(선택·이동은 안 됨 → [Parties](parties.md)).
[캠프 메뉴](camp-menu.md)·[턴 HUD](turn.md)처럼 UI 트리를 씬이 아니라 코드(`_build`)로 구성한다(별도 `.tscn` 없음).

## 레이아웃

- 우측 상단에 `PanelContainer`(앵커 `PRESET_TOP_RIGHT`, 마진 16)를 둔다. 나머지 화면은 클릭을 가로막지 않는다(`MOUSE_FILTER_IGNORE`).
- 세로(VBox)로 쌓는다:
  - **제목** — 부대 이름(`party_name`), 글자 크기 20.
  - **세력** — 소속 세력 이름(`faction_name`). 비어 있으면 이 줄을 숨긴다.
  - **요약** — `"이동력 N · 시야 M · 사거리 <근접|N>"` (`party.movement()`·`party.vision()` + 사거리 표기는 패널 자체 `_range_label(party.attack_range())` — 0이면 "근접", 그 외 "사거리 N").
  - `HSeparator`.
  - **구성** — 한 줄: `"지휘관 <commander_name> · 병력 <soldiers>"` (`party.commander_name`·`party.soldiers`). 순수 class+count 모델이라 개별 멤버 목록은 없다.
  - **행동 버튼 줄**(HBox) — `open`에 넘긴 `actions`(각 `{id, label}`) 버튼을 가로로 놓는다. 비어 있으면 이 줄을 숨긴다. 중앙 메뉴가 없어져 부대 조작 버튼이 이 박스로 들어왔다: **일반부대 선택** 시 소속 관리 가능하면 `[소속]`([Party Lord](party-lord.md)), **영웅부대 선택** 시 명령 가능한 하위부대가 있으면 `[지휘]`([Squad Command](squad-stance.md)). 버튼 클릭 → `action_selected(id)` 방출(`game.gd`가 처리). NPC·조작 대상 아닌 부대는 `actions`가 비어 버튼 줄이 없다.

## 표시 규칙 (`game.gd` `_handle_click`)

- **플레이어 부대 칸 클릭 → 항상 패널을 연다**(`open`). 이번 턴에 이미 이동해 선택되지 않는 부대도 정보는 표시된다(이동 범위는 표시되지 않음).
  - 부대가 이동 가능(`can_move()`)하고 아직 선택 전이면 함께 선택([Selection & Movement](selection-and-movement.md))해 이동 범위도 보여준다.
- **NPC 부대 칸 클릭 → 정보만 연다**(`FOCUS_NPC`). 선택·이동 범위 표시는 없다. 선택 중이던 플레이어 부대는 해제된다. **NPC 정보는 이동보다 우선**이라 이동 범위 안 NPC 칸을 클릭해도 이동하지 않는다. 단 **안개에 가려 보이지 않는(현재 시야 밖) NPC는 클릭 대상이 아니다**.
- **다른 곳 클릭 → 패널을 닫는다**(`close`): 빈 칸/이동 목적지 클릭, 건물(캠프·농장) 클릭, 턴 종료 시.
- **[부대 일람](party-roster.md)·[건물 정보 패널](building-info.md)과 우측 상단을 공유한다**: 이 패널을 열면 일람·건물 정보를 감추고, 닫으면 일람을 다시 표시한다(`game.gd`가 함께 토글).

## 동작

- `open(party, actions := []) -> void` — 부대 정보를 채우고 패널을 보인다.
  - 제목 = `party.party_name`.
  - 세력 = `party.faction_name`. 빈 문자열이면 세력 라벨을 숨긴다(`visible = false`).
  - 요약 = `"이동력 %d · 시야 %d · 사거리 %s"` (`party.movement()`·`party.vision()`·`_range_label(party.attack_range())` — 패널 자체 헬퍼).
  - 구성 리스트를 **비우고** 다시 채운다(재오픈 시 이전 값이 남지 않도록). 한 줄 = `"지휘관 %s · 병력 %d"`(`party.commander_name`·`party.soldiers`).
  - **행동 버튼 줄을 비우고** `actions`(각 `{id, label}`)대로 버튼을 다시 채운다. 비어 있으면 버튼 줄을 숨긴다. 각 버튼 클릭 → `action_selected(id)` 방출.
- `action_selected(id: String)` (signal) — 행동 버튼을 누르면 방출. `game.gd`가 받아 처리(예: `"lord"` → [소속 모달](party-lord.md)).
- `close() -> void` — 숨긴다.

## 테스트 시나리오

`test/unit/test_party_info.gd`.

- [정상] `open(party)` → 제목 라벨 = `party_name`("주인공 부대")
- [정상] `faction_name`이 설정된 부대 `open` → 세력 라벨 = `faction_name`, `visible == true`
- [경계] `faction_name`이 빈 문자열인 부대 `open` → 세력 라벨 숨김(`visible == false`)
- [정상] 요약 라벨 = 근접 병종 → "사거리 근접"
- [정상] 구성 라벨에 지휘관 이름(`commander_name`)·병력수(`soldiers`)가 포함됨
- [정상] 요약(이동력·시야)은 클래스 기반이라 병력수와 무관(병력 0이어도 클래스 값)
- (장비/무기·방어구·개별 멤버 표시는 장비 계층 삭제(M4-B)·순수 class+count(M4-C)로 제거)
- [정상] `open` 후 `visible == true`, `close()` 후 `false`
- [정상] `open(party, [{id="lord", label="소속"}])` → 행동 버튼 줄 보임, 버튼 1개("소속"); 버튼 누르면 `action_selected("lord")` 방출
- [경계] `open(party, [])`(기본) → 행동 버튼 줄 숨김(`visible == false`)
- [경계] `actions` 있는 `open` 뒤 `actions` 없이 재오픈 → 이전 버튼이 남지 않고 줄이 숨겨진다

## 관련

- 표시 데이터는 [부대(Party)](../entities/Party.md) — `party_name`, `movement()`·`vision()`(클래스 기반), `commander_name`, `soldiers`.
- 선택·이동 흐름은 [Selection & Movement](selection-and-movement.md).
