# Feature: Party Roster (부대 일람)

> 스크립트: `scenes/party/party_roster.gd` (`extends CanvasLayer`, layer 47)

화면 **우측 상단**에 게임 내 **모든 [부대](../entities/Party.md)를 나열**하는 상시 패널.
항목을 클릭하면 그 부대 위치로 **카메라를 이동**시킨다.
[캠프 메뉴](camp-menu.md)·[턴 HUD](turn.md)·[부대 정보 패널](party-info.md)처럼 UI 트리를 씬이 아니라 코드(`_build`)로 구성한다(별도 `.tscn` 없음).

## 레이아웃

- 우측 상단에 `PanelContainer`(앵커 `PRESET_TOP_RIGHT`, 마진 16)를 둔다. 나머지 화면은 클릭을 가로막지 않는다(루트 `Control`이 `MOUSE_FILTER_IGNORE`).
- 세로(VBox)로 쌓는다:
  - **제목** — `"부대 일람"`, 글자 크기 20.
  - `HSeparator`.
  - **부대 리스트**(VBox) — 부대 한 개당 `Button` 한 줄.
    - 버튼 텍스트: `"<부대이름>\n지휘관 <지휘관이름> · <N>명"` (`party.commander_name()`, 멤버 수 `party.members.size()`).

## 표시 규칙

- 기본은 **표시 상태**로, 게임 화면 우측 상단에 항상 떠 있다.
- **[부대 정보 패널](party-info.md)과 우측 상단을 번갈아 쓴다**(`game.gd`):
  - 부대 정보 패널이 **열리면** 일람을 **감춘다**(`hide`).
  - 부대 정보 패널이 **닫히면** 일람을 다시 **표시**한다(`show`).

## 동작

- `set_parties(parties: Array) -> void` — 부대 리스트를 **비우고** 다시 채운다(재구성 대비). 부대당 버튼 한 개를 만들고, 버튼을 누르면 그 부대를 실어 `party_selected` 시그널을 방출한다. 거점 방어 부대도 일반 부대라 일람에 포함된다. **멤버가 0명인 부대는 건너뛴다**(분할로 전부 옮겨 사라진 부대).
- `signal party_selected(party)` — 항목 클릭 시 방출. `game.gd`가 받아 카메라를 그 부대 위치로 이동시킨다.

## 카메라 이동 (`game.gd` `_on_party_focused`)

- `camera.position = party.position` 후 맵 이동 범위(`_min_pos`~`_max_pos`)로 클램프한다. 기존 `_center_camera`와 같은 **즉시 이동** 방식(부드러운 팬 없음).
- 카메라 이동만 한다 — 부대 선택·이동 범위 표시·정보 패널 열기는 하지 않는다([Selection & Movement](selection-and-movement.md)의 맵 클릭 흐름과 분리).

## 테스트 시나리오

`test/unit/test_party_roster.gd`.

- [정상] `set_parties([p])` → 부대 리스트 자식 수 = 부대 수(1)
- [정상] 버튼 텍스트에 부대 이름·지휘관 이름·인원 수가 포함됨("주인공 부대", "테스트맨", "2")
- [경계] 지휘관이 없는 부대 → 버튼 텍스트에 `"—"` 포함
- [경계] 부대 2개로 구성한 뒤 1개로 재구성 → 리스트 자식 수가 1로 교체됨
- [정상] 항목 버튼을 누르면 `party_selected` 시그널이 그 부대를 실어 방출됨
- [정상] 기본 `visible == true`

## 관련

- 표시 데이터는 [부대(Party)](../entities/Party.md) — `party_name`, `commander_name()`, `members`.
- 우측 상단 공존 상대는 [Party Info (부대 정보 패널)](party-info.md).
- 카메라·맵 이동 범위는 [Map & Camera](map-and-camera.md).
