# Feature: Members Menu (구성원 메뉴)

> 스크립트: `scenes/members/members_menu.gd` (`extends CanvasLayer`, layer 33)

화면 **좌측 하단**에 항상 떠 있는 `"구성원"` 버튼과, 클릭 시 열리는 **우리 세력 전 군인 명단 오버레이**.
명단 표는 재사용 위젯 [Member List](member-list.md)를 그대로 쓰고, 옆에 선택한 군인의 **상세 정보 패널**을 붙인다.
[캠프 메뉴](camp-menu.md)·[턴 HUD](turn.md)처럼 UI를 코드(`_build`)로 구성한다(별도 `.tscn` 없음).

## 대상 (누가 "우리 세력 군인"인가)

- **우리 세력의 모든 부대의 전원**. `game.gd`가 모든 [부대](../entities/Party.md) 중 `faction_name`이 [플레이어 세력](../entities/Faction.md)(`_player_faction.name`)인 부대를 골라, 그 `members`([Human](../entities/Human.md))를 전부 모은다. 필드 부대와 거점 [주둔 부대](garrison.md)를 모두 포함한다.
- 수집 로직은 재사용·테스트 가능한 **정적 헬퍼** `MembersMenu.collect_faction_members(parties: Array, faction_name: String) -> Array`로 둔다 — `parties` 중 `faction_name`이 일치하는 부대의 `members`를 순서대로 모으고 **중복을 제거**해 반환(부대 지휘관 유무·순서 무관).
- `game.gd._player_faction_members() -> Array` — `MembersMenu.collect_faction_members(_units, _player_faction.name)`을 호출한다(모든 플레이어 부대는 `_units`에 있음). 오버레이를 **열 때** 이 스냅샷을 넘긴다.

## 좌측 하단 버튼

- 루트 `Control`은 `MOUSE_FILTER_IGNORE`(나머지 화면 클릭을 막지 않음).
- `"구성원"` `Button`을 `PRESET_BOTTOM_LEFT`(마진 16)에 둔다. 항상 표시.
- 누르면 `open_requested` 시그널을 방출한다. `game.gd`가 받아 `open(_player_faction_members())`를 호출한다(데이터는 게임 쪽에서 주입 → 오버레이는 세력을 모른다).

## 오버레이

- `open(members: Array) -> void` — 반투명 배경(`ColorRect`, `0,0,0,0.45`)을 깔고 패널을 표시한다. 배경 **좌클릭** 시 닫힌다(휠·우클릭은 무시 — 휠도 `InputEventMouseButton`이라 오작동 방지). 좌측 하단 버튼은 오버레이가 열려 있는 동안 숨긴다.
- `is_open() -> bool` — 오버레이 표시 여부. `game.gd`가 지도 카메라 입력 차단 판단에 쓴다.
- 중앙에 가로(HBox)로:
  - **명단 패널** — 제목 `"구성원"` + 인원 수 + [Member List](member-list.md) 위젯 + 닫기 버튼.
  - **상세 패널** — 선택한 군인의 전체 스탯을 세로로 표시(아래 "상세 정보"). 선택 전에는 안내 문구.
- `close() -> void` — 오버레이를 감추고 좌측 하단 버튼을 다시 표시한다.
- 오버레이를 열면 명단의 **첫 행이 자동 선택**되어 상세 패널이 채워지고, 명단에 **포커스**를 줘 키보드 ↑/↓ 이동을 바로 쓸 수 있다(멤버가 있을 때).

## 상세 정보 (`member_selected` 수신)

Member List의 `member_selected(human)`을 받아 상세 패널을 갱신한다. 표시 항목:

- 이름
- 능력치 11종(힘·지혜·민첩·매력·행운·이동력·시야·지휘력·화술·성실함·예민함)
- 레벨 · HP(`hit_points` / `max_hp()`) · 스태미나(`stamina` / `max_stamina`) · 사기

## 게임 연동 (`game.gd`)

- game.tscn에 `MembersMenu` 노드를 추가하고 `@onready var members_menu = $MembersMenu`.
- `members_menu.open_requested`를 `_on_members_requested`에 연결 → `members_menu.open(_player_faction_members())`.
- 명단은 **여는 시점의 스냅샷**이다(열려 있는 동안 부대 변화는 반영하지 않음).
- **지도 입력 차단** — 오버레이가 열려 있는 동안(`members_menu.is_open()`) `game.gd`의 `_process`(WASD·엣지 스크롤 카메라 팬)와 `_unhandled_input`(클릭·줌)이 즉시 반환해 지도 조작을 막는다. 반투명 배경은 마우스 클릭만 소비하고 폴링 기반 카메라 팬은 못 막으므로 명시적 확인이 필요하다. (향후 공용 Modal/ModalStack로 일반화 예정 — [SPEC.md 추천 스펙](../SPEC.md))

## 테스트 시나리오

`test/unit/test_members_menu.gd` (오버레이·헬퍼), Member List 자체는 [member-list.md](member-list.md).

- [정상] `collect_faction_members(parties, "푸른")` — faction_name이 일치하는 부대들의 members만 모음(다른 세력 부대 제외)
- [경계] 같은 세력에 부대 2개 → 두 부대 members 합집합(중복 없음)
- [정상] `open([a, b])` 후 Member List 행 수 = 2
- [정상] `open(...)` 시 좌측 하단 버튼 숨김 / `close()` 시 다시 표시
- [정상] 좌측 하단 버튼 누르면 `open_requested` 방출
- [정상] `open`에 멤버가 있으면 첫 행 자동 선택 → 상세 패널이 그 군인 이름을 포함
- [경계] `open([])` → 행 0, 상세 패널은 안내 문구
- [정상] `is_open()` — 기본 false, `open` 후 true, `close` 후 false
- [정상] 배경 **좌클릭** → 닫힘(`is_open()` false)
- [경계] 배경 **우클릭·휠** → 닫히지 않음(`is_open()` true 유지)

## 관련

- 명단 표 위젯은 [Member List](member-list.md) — 재사용 대상.
- 표시 데이터: [Human](../entities/Human.md), [능력치·자원 정의](../data/stats.md), 소속은 [Faction](../entities/Faction.md)·[Party](../entities/Party.md).
