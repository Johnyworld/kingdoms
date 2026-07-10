# Feature: Party Action Menu (부대 행동 메뉴)

> 스크립트: `scenes/party/party_action_menu.gd` (`class_name PartyActionMenu extends CanvasLayer`) · `scenes/game/game.gd`

플레이어 [부대](../entities/Party.md)를 클릭하면 이동 범위(파랑)와 **공격 가능한 적 타일(빨강)** 이 표시되고, 화면 중앙에 행동 메뉴가 뜬다. 이동은 맵 클릭, 공격은 **적 타일 클릭 팝업**, 사격·휴식은 메뉴로 한다.

## 공격 가능 판정 (`game.gd`)

부대가 이번 턴 그 적을 칠 수 있는지 두 가지로 본다([Selection & Movement](selection-and-movement.md)).

- **근접 가능(`can_melee`)** — (현재 칸 ∪ 이동 범위 칸) 중 그 적에 **인접한 칸**이 있으면 참(이동해서 붙을 수 있음). 근접 무기 사거리는 0이라 **인접해야** 친다.
- **사격 가능(`can_shoot`)** — 부대가 원거리 무기(사거리 ≥ 2)를 갖고, **현재 위치**에서 그 적까지 헥스 거리 ≤ 부대 사거리면 참(제자리 사격).
- **공격 가능한 적** = `can_melee` 또는 `can_shoot`. 그 적 타일에 **빨강 오버레이**를 그린다(범위 영역이 아니라 적 타일 자체).

## 상호작용 모드 (`game.gd`)

| 모드 | 표시 | 클릭 |
| --- | --- | --- |
| `MOVE`(기본) | 파랑 이동 범위 + 빨강 공격 가능 적 타일 + 중앙 메뉴 | 도달 빈칸 → 이동, 공격 가능 적 → **적 팝업**, 그 외 NPC → 정보 |
| `SHOOT` | 사격 가능 적 타일(빨강) | 사격 가능 적 → **제자리 사격**(전투), 그 외 → `MOVE` 취소 |

- 중앙 메뉴 `[사격]` → `SHOOT` 모드. 적 팝업 `[사격]` → 그 적 바로 사격. 둘 다 현재 위치 원거리 전투.
- 근접 `[공격]`은 적 팝업에서만. 적 팝업 `[이동]`은 그 적 인접 칸으로 이동만(전투 없음).

## 메뉴 버튼 구성 (순수)

노드 비의존 정적 함수(테스트 용이). 각 원소 `{id, label, enabled}`.

- `party_actions(moved: bool, can_shoot_any: bool) -> Array` — **중앙 메뉴**.
  - `{id="shoot", label="사격", enabled=can_shoot_any}` — 사격 가능한 적이 하나라도 있으면 활성.
  - `{id="rest", label=("대기" if moved else "휴식"), enabled=true}`.
- `enemy_actions(can_move_adj: bool, can_melee: bool, can_shoot: bool) -> Array` — **적 클릭 팝업**.
  - `{id="move", label="이동", enabled=can_move_adj}` — 그 적 인접 도달 칸이 있으면 활성.
  - `{id="attack", label="공격", enabled=can_melee}`.
  - `{id="shoot", label="사격", enabled=can_shoot}`.

## UI (`party_action_menu.gd`)

- 화면 중앙 버튼 패널(코드 구성, [camp_menu](camp-menu.md)·[party_info](party-info.md) 패턴). 버튼만 클릭 흡수, 나머지 화면은 맵으로 통과.
- `open(buttons: Array)` — `{id,label,enabled}` 목록으로 버튼을 채우고 보인다(비활성은 흐리게·안 눌림).
- `close()` — 감춘다.
- 버튼 클릭 시 `action_selected(id)` 방출. 적 팝업일 때는 `game.gd`가 대상 적을 따로 들고 있다가 함께 처리한다.

## 전투 개시·결과 (`game.gd` + [Battle](battle.md))

- **`[공격]`(근접)**: 그 적에 인접한 도달 칸으로 이동한 뒤 전투(근접 모드). **공격 부대가 이기면(수비 전멸·공격 생존) 수비 타일로 이동**한다(전투는 수비 타일에서 벌어진 것으로 간주 = 점령).
- **`[사격]`(원거리)**: 현재 위치에서 사격(원거리 모드). **이동·점령 없음**(제자리).
- **`[이동]`**: 그 적 인접 도달 칸으로 이동만(전투 없음).
- 공격/사격은 부대의 행동을 끝낸다(`mark_attacked`).

## 휴식 상태 (`Party`)

- `rested_this_turn` / `mark_rested()`(행동 종료) / `can_rest()`(`not attacked_this_turn`) — [Party](../entities/Party.md). 회복 연동은 `미구현`.

## 테스트 시나리오

### 버튼 구성 — `test/unit/test_party_action_menu.gd`
- [정상] `party_actions(false, true)` → `[사격(활성), 휴식]`
- [정상] `party_actions(false, false)` → `[사격(비활성), 휴식]`
- [정상] `party_actions(true, true)` → `[사격(활성), 대기]`
- [정상] `enemy_actions(true, true, false)` → `[이동(활성), 공격(활성), 사격(비활성)]`
- [정상] `enemy_actions(false, false, true)` → `[이동(비활성), 공격(비활성), 사격(활성)]`
- [경계] 라벨은 `moved`로만 갈린다(휴식↔대기)

### 휴식 상태 — `test/unit/test_party.gd`
- [정상] `mark_rested()` → `rested_this_turn`·`attacked_this_turn` 참, `can_rest()` 거짓
- [정상] `reset_turn()` → `rested_this_turn` 거짓

### 모드·연출 (실행 확인)
- 부대 클릭 → 파랑 이동 범위 + 공격 가능 적 빨강 + 중앙 [사격]·[휴식].
- 공격 가능 적 클릭 → 팝업 [이동][공격][사격](각 활성 조건). [공격] 시 인접 이동 후 전투, 승리 시 수비 타일 점령.
- 중앙 [사격] → SHOOT 모드, 사격 가능 적 클릭 시 제자리 전투, 빈 칸 클릭 시 취소.
- 이동 후 메뉴 라벨이 [대기]인지 확인.

## 관련

- 공격 가능 판정·범위·이동은 [Selection & Movement](selection-and-movement.md), 전투는 [Battle](battle.md), 사거리 표기(`ItemTypes.range_label`)는 [Items](../data/items.md), 정보 패널은 [Party Info](party-info.md).
