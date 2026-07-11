# Feature: Garrison (캠프 수비대)

> 스크립트: `scenes/building/building.gd` (`garrison`) · `scenes/party/unit_types.gd` (`make_garrison`) · `scenes/game/game.gd` (`_compute_camp_targets`, `_open_camp_attack_popup`, `_attack_camp`, `_run_camp_battle`, `_make_garrison_party`, `_adjacent_enemy_camp`) · `scenes/party/party_action_menu.gd` (`camp_attack_actions`) · `scenes/building/building_info.gd`

각 [캠프](../entities/Building.md)에 **수비대**(방어 병력)를 두어, 점령하려면 먼저 수비대를 격파하게 한다.
스치기만 하면 함락되던([Camp Capture](camp-capture.md)) 거점에 방어 긴장감을 더한다.

## 수비대 데이터 (`Building.garrison`)

- `Building.garrison: Array` — 그 캠프를 지키는 [Human](../entities/Human.md) 병력. 기본 `[]`.
- **캠프는 생성 시 기본 수비대 4명**을 받는다(`game.gd`가 `UnitTypes.make_garrison(4)`로 채움 — 플레이어·NPC 캠프 모두).
- 캠프가 **방어됨** = `garrison`이 비어 있지 않음.
- 소속: 수비대는 그 캠프의 세력에 속한다(표시·전투 시 세력 색). 캠프가 [점령](camp-capture.md)될 때 수비대는 이미 격파돼 비어 있다(점령의 전제).

## 수비대 병력 (`UnitTypes.make_garrison`)

- `make_garrison(count := 4) -> Array` — 소집병(garrison 아키타입) `count`명을 [Human](../entities/Human.md)으로 생성한다.
  - 소집병: 검·가죽 방어구를 든 보통 병사(부대 지휘관보다 약함). 이동력·시야는 인간 기본값, 생성 시 풀피(`hit_points = max_hp()`)·풀 스태미나.

## 점령 게이트 (`game.gd`)

발견된 적 캠프에 **인접 가능**할 때, 수비대 유무로 행동이 갈린다(`_compute_camp_targets`).

- **방어된 캠프**(garrison 있음) → **[공격]** 팝업(`camp_attack_actions`). 수비대와 전투한다. 점령 불가.
- **무방비 캠프**(garrison 빈) → **[흡수][파괴]** 팝업([Camp Capture](camp-capture.md)). 점령한다.
- 두 경우 모두 캠프 칸을 빨강 오버레이로 표시한다(MOVE 모드).
- 미발견·인접 불가·미선택이면 기존 [거점 정보 패널](building-info.md).

## 수비대 전투 (`game.gd`)

수비대는 지도 위 상시 토큰이 아니라, 공격받을 때 **임시 방어 부대**로 만들어 기존 [전투](battle.md)를 재사용한다.

- `_make_garrison_party(camp)` — `camp.garrison`을 멤버로, 세력 색·캠프 중심 위치를 가진 임시 [Party](../entities/Party.md)를 만든다. `_npc_parties`에 넣지 않는다(이동/AI 대상 아님).
- **플레이어 공격**: 방어된 적 캠프 [공격] → 인접 칸으로 이동 후 임시 방어부대와 전투. 공격은 행동을 끝낸다(`mark_attacked`).
- **관전/헤드리스**: 공격받는 캠프가 **플레이어 소유면 오버레이**(플레이어가 수비대를 관전), 그 외는 **헤드리스 즉시 결산**(기존 부대 전투와 같은 규칙).
- **생존자 반영**: 전투 뒤 임시 부대의 생존 멤버를 `camp.garrison`에 다시 쓰고 임시 부대를 해제한다. 수비대가 0명이 되면 그 캠프는 무방비(다음에 점령 가능).

## NPC의 수비대 처리 (`_npc_attack_phase`)

NPC도 이동 뒤 공격 페이즈에서(→ [NPC Movement](npc-movement.md)) 인접한 적 캠프를 처리한다. 우선순위: **인접 적 부대 전투 → 방어된 적 캠프 공격(수비대) → 무방비 적 캠프 흡수**. 한 NPC는 턴당 한 행동(`mark_attacked`).

- 방어된 캠프 공격: 임시 방어부대와 전투. 그 캠프가 플레이어 소유면 오버레이, 아니면 헤드리스. 생존자 반영.
- 무방비 캠프: [흡수](camp-capture.md#소유권-이전-_transfer_camp).

## 정보 표시

- [거점 정보 패널](building-info.md)에서 **거점**([center](../data/buildings.md#동작) = 캠프·마을회관·성)이면 정보 리스트에 `"수비대 N명"`을 표시한다(N = `garrison.size()`). 거점이 아닌 건물(농장 등)은 표시하지 않는다. *(단 거점은 [캠프 메뉴](camp-menu.md)로 라우팅되므로 실제 표시는 주로 미발견 대비용.)*
- **맵 위 배지**([Building](../entities/Building.md) `_draw`): 완성 **거점**(`BuildingTypes.is_center`)이고 수비대가 있으면 중심 아래에 `"수비 N"` 배지를 그린다(건설 중 배지와 같은 자리, 서로 겹치지 않음). 수비대가 바뀌면(편성·전투) 다시 그려 배지를 갱신한다(`queue_redraw`). 발견된 적 거점의 수비대 수도 보인다.

## 수비대 편성 (`camp_menu`)

플레이어 부대가 **자기 캠프에 인접**한 상태에서 그 캠프를 클릭하면([Camp Menu](camp-menu.md)) **수비대 편성** 패널이 뜬다 — 부대↔캠프 병사를 옮긴다.

- **트리거**: `game.gd`가 캠프 메뉴를 열 때, 그 거점에 인접(또는 위)한 플레이어 [부대](../entities/Party.md)를 함께 넘긴다(`camp_menu.open(building, party)`). 인접 부대가 없으면(또는 **거점**(`is_center`)이 아니면) 편성 패널은 숨는다.
- **패널**: 두 목록 — **부대**(party.members)와 **수비대**(camp.garrison). 각 병사는 버튼.
  - **부대원 클릭** → 그 병사를 수비대로 옮긴다(`Party.remove_member` → `garrison.append`).
  - **수비대원 클릭** → 그 병사를 부대로 옮긴다(`garrison.erase` → `Party.add_member`).
  - 이동은 **양방향 자유**(수 제한 없음). 옮길 때마다 패널을 다시 그린다.
- **부대 0명 허용**: 부대원을 전부 수비대로 옮기면 부대가 **사라진다** — 토큰을 그리지 않고([Party](../entities/Party.md) `_draw`가 멤버 없으면 그림 생략) [부대 일람](party-roster.md)에서도 빠진다. 노드는 유지되므로, 인접 상태에서 수비대 병사를 다시 넣으면 부대가 되살아난다.
- **반영**: 편성 변경 때마다 `camp_menu`가 `garrison_changed`를 방출 → `game.gd`가 [부대 일람](party-roster.md)·[안개](fog-of-war.md)(부대 시야)를 갱신한다. 캠프 수비대가 비면 무방비(위 [점령 게이트](#점령-게이트-gamegd)), 채우면 방어로 실시간 전환된다.

## 이번 슬라이스 제외 (미구현)

- **부대 편성**(여러 부대 생성·분할·병합) — 지금은 캠프↔단일 부대 이동만. *(다음 슬라이스)*
- 수비대 **원거리 방어 반격**·성벽 보정 — 현재 임시 부대는 일반 부대와 동일 전투. [공격]은 근접만(사격 없음).
- 수비대 **보충/재생**·자동 재편성.

## 테스트 시나리오

**수비대 병력** — `test/unit/test_unit_types.gd`:
- [정상] `make_garrison(4)` → 4명, 모두 Human이고 생성 시 `hit_points == max_hp()`
- [정상] `make_garrison()` 기본 4명; [경계] `make_garrison(0)` → 빈 배열

**수비대 필드** — `test/unit/test_building.gd`:
- [정상] 생성 직후 `garrison == []`; 설정·조회 가능

**팝업 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `camp_attack_actions()` → `["attack"]`(공격), 활성

**정보 표시** — `test/unit/test_building_info.gd`:
- [정상] 수비대 3명인 캠프 `open` → 정보 리스트에 `"수비대 3명"` 포함
- [경계] 농장(캠프 아님) `open` → 수비대 줄 없음

**부대 멤버 제거** — `test/unit/test_party.gd`:
- [정상] `remove_member(h)` 후 members에서 빠짐; 지휘관이면 남은 첫 멤버로 재지정, 없으면 null
- [경계] 없는 멤버 `remove_member` → no-op

**편성 UI** — `test/unit/test_camp_menu.gd`:
- [정상] `open(camp, party)` → 부대·수비대 목록이 각 인원수로 채워지고 편성 패널 표시
- [정상] 부대원 이동 → party.members −1, garrison +1(반대도)
- [정상] `open(camp)`(부대 없음) → 편성 패널 숨김

**빈 부대 제외** — `test/unit/test_party_roster.gd`:
- [정상] 멤버 0명 부대는 일람에 표시되지 않음

`game.gd`의 캠프 타깃 판정·[공격]/점령 분기·임시 방어부대 전투·생존자 반영·NPC 처리(씬 트리·터레인 의존)는 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Camp Capture (캠프 점령)](camp-capture.md) — 수비대 격파 후 점령. [Battle (전투)](battle.md) — 재사용하는 전투. [NPC Movement](npc-movement.md) — NPC의 캠프 공격/점령.
- [Building](../entities/Building.md) — `garrison` 필드. [Party Action Menu](party-action-menu.md) — [공격] 팝업. [Building Info](building-info.md) — 수비대 수 표시.
- 기획: [건물](../../table/세력/건물.md) · [영지](../../table/세력/영지.md)
