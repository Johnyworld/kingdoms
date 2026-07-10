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
  - **요약** — `"이동력 N · 시야 M"` (부대 집계값 `party.movement()`/`party.vision()`).
  - `HSeparator`.
  - **멤버 리스트**(VBox) — 멤버 한 명당 라벨. 이름·이동·시야 + **장비 줄**:
    - `"<이름>   HP <hit_points>/<max_hp()>   이동 <movement> / 시야 <vision>"` (HP는 [Human](../entities/Human.md)의 현재 생명점 / 계산된 최대 생명점 — 전투 후 지속됨)
    - `"  <주무기이름>[ (+<보조무기들>)] · 공격 <AT> · 방어 <DF> · 회피 <EV>"` (방패를 들면 뒤에 `" · 막기 <N>%"`) — 무기이름은 [ItemTypes](../data/items.md), 없으면 `"맨손"`. **무기를 여럿 들면** 주무기(첫 원소) 뒤에 보조무기 이름을 `" (+활)"`처럼 덧붙인다. AT=`CombatResolver.attack_power`(주무기 기준), DF=`CombatResolver.defense`, EV=`CombatResolver.evasion`(보유 무기 전부 무게 반영, 정수 반올림), 막기=`CombatResolver.block_chance`(방패 없으면 표시 안 함).
    - `"  방어구: <조각 이름들, 콤마 구분>"` — 착용 방어구 조각 이름(`ItemTypes.armor_name`). **방어구가 없으면(맨몸) 이 줄은 표시하지 않는다.** 방패는 위 막기%로 이미 표시.

## 표시 규칙 (`game.gd` `_handle_click`)

- **플레이어 부대 칸 클릭 → 항상 패널을 연다**(`open`). 이번 턴에 이미 이동해 선택되지 않는 부대도 정보는 표시된다(이동 범위는 표시되지 않음).
  - 부대가 이동 가능(`can_move()`)하고 아직 선택 전이면 함께 선택([Selection & Movement](selection-and-movement.md))해 이동 범위도 보여준다.
- **NPC 부대 칸 클릭 → 정보만 연다**(`FOCUS_NPC`). 선택·이동 범위 표시는 없다. 선택 중이던 플레이어 부대는 해제된다. **NPC 정보는 이동보다 우선**이라 이동 범위 안 NPC 칸을 클릭해도 이동하지 않는다. 단 **안개에 가려 보이지 않는(현재 시야 밖) NPC는 클릭 대상이 아니다**.
- **다른 곳 클릭 → 패널을 닫는다**(`close`): 빈 칸/이동 목적지 클릭, 건물(캠프·농장) 클릭, 턴 종료 시.
- **[부대 일람](party-roster.md)·[건물 정보 패널](building-info.md)과 우측 상단을 공유한다**: 이 패널을 열면 일람·건물 정보를 감추고, 닫으면 일람을 다시 표시한다(`game.gd`가 함께 토글).

## 동작

- `open(party) -> void` — 부대 정보를 채우고 패널을 보인다.
  - 제목 = `party.party_name`.
  - 세력 = `party.faction_name`. 빈 문자열이면 세력 라벨을 숨긴다(`visible = false`).
  - 요약 = `"이동력 %d · 시야 %d"` (`party.movement()`, `party.vision()`).
  - 멤버 리스트를 **비우고** 다시 채운다(재오픈 시 이전 멤버가 남지 않도록). 각 멤버 = 이름·HP(현재/최대)·이동·시야 줄 + 장비 줄(무기 이름·공격 AT·방어 DF).
- `close() -> void` — 숨긴다.

## 테스트 시나리오

`test/unit/test_party_info.gd`.

- [정상] `open(party)` → 제목 라벨 = `party_name`("주인공 부대")
- [정상] `faction_name`이 설정된 부대 `open` → 세력 라벨 = `faction_name`, `visible == true`
- [경계] `faction_name`이 빈 문자열인 부대 `open` → 세력 라벨 숨김(`visible == false`)
- [정상] 요약 라벨 = `"이동력 2 · 시야 5"` (이동력 3·2 → min 2, 시야 5·5 → max 5)
- [정상] 멤버 리스트 자식 수 = 멤버 수(2)
- [정상] 멤버 라벨에 이름·이동력·시야가 포함됨("테스트맨", "3", "5")
- [정상] 멤버 라벨에 `HP <현재>/<max_hp()>`가 포함됨(예: `hit_points 25`·힘<10(`max_hp()==40`) → `"HP 25/40"`)
- [정상] 장비 장착 멤버 라벨에 무기 이름·공격(AT)·방어(DF)가 포함됨
- [정상] 무기가 없으면 멤버 라벨에 "맨손" 표시
- [정상] 무기를 여럿 든 멤버(검+활)는 주무기 뒤에 보조무기 이름(`(+단궁)`)이 표시됨
- [정상] 방패를 든 멤버 라벨에 "막기 N%"가 포함되고, 방패 없으면 "막기"가 없음
- [정상] 멤버 라벨 전투 스탯 줄에 "회피"가 포함됨
- [정상] 방어구를 착용한 멤버 라벨에 "방어구:"와 조각 이름이 포함됨
- [정상] 맨몸(방어구 없음) 멤버 라벨에는 "방어구:" 줄이 없음
- [경계] 멤버 없는 부대 `open` → 요약 `"이동력 0 · 시야 0"`, 멤버 리스트 비어 있음
- [경계] 멤버 2명 부대로 연 뒤 1명 부대로 재오픈 → 멤버 리스트 자식 수가 1로 교체됨
- [정상] `open` 후 `visible == true`, `close()` 후 `false`

## 관련

- 표시 데이터는 [부대(Party)](../entities/Party.md) — `party_name`, `movement()`(멤버 최소), `vision()`(멤버 최대), `members`.
- 멤버 개별 능력치는 [Human](../entities/Human.md).
- 선택·이동 흐름은 [Selection & Movement](selection-and-movement.md).
