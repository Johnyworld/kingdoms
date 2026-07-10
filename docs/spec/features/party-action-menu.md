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
| `SHOOT` | **사격 사거리 전체(빨강)** | 사거리 내 사격 가능 적 → **제자리 사격**(전투), 그 외 → `MOVE` 취소 |

- 중앙 메뉴 `[사격]` → `SHOOT` 모드. 적 팝업 `[사격]` → 그 적 바로 사격. 둘 다 현재 위치 원거리 전투.
- 근접 `[공격]`은 적 팝업에서만. `[휴식]`·`[경계]`는 중앙 메뉴에서 즉시 발동(아래 효과).

## 메뉴 버튼 구성 (순수)

노드 비의존 정적 함수(테스트 용이). 각 원소 `{id, label, enabled}`.

- `party_actions(moved: bool, can_shoot_any: bool, can_undo: bool) -> Array` — **중앙 메뉴**. `{id="shoot", label="사격", enabled=can_shoot_any}` 는 항상 첫 버튼.
  - **이동 전**(`moved=false`): `[사격][휴식][경계]` — 휴식·경계는 제자리에서만 가능.
  - **이동 후**(`moved=true`): `[사격][대기]` — 휴식·경계 불가. `{id="wait", label="대기", enabled=true}` 는 **효과 없이 턴만 종료**. `can_undo`면 뒤에 `{id="undo", label="취소", enabled=true}` 추가.
- `enemy_actions(can_melee: bool, can_shoot: bool) -> Array` — **적 클릭 팝업** `[공격][사격]`.
  - `{id="attack", label="공격", enabled=can_melee}` · `{id="shoot", label="사격", enabled=can_shoot}`.
- `capture_actions() -> Array` — **적 거점 클릭 팝업** `[흡수][파괴]`(둘 다 활성). → [Camp Capture](camp-capture.md).
  - `{id="absorb", label="흡수", enabled=true}` · `{id="destroy", label="파괴", enabled=true}`.

## UI (`party_action_menu.gd`)

- 코드 구성 버튼 패널([camp_menu](camp-menu.md)·[party_info](party-info.md) 패턴). 버튼만 클릭 흡수, 나머지 화면은 맵으로 통과.
- `open(buttons: Array, screen_pos: Vector2)` — 버튼을 채우고 **클릭한 부대 토큰의 화면 좌표 근처**(우측 하단 오프셋)에 패널을 띄운다. 화면 밖으로 넘치지 않게 클램프.
- `close()` — 감춘다. 버튼 클릭 시 `action_selected(id)` 방출(팝업 대상은 `game.gd`가 보관).

## 행동 효과 (`game.gd` + [Human](../entities/Human.md))

- **`[공격]`(근접)**: 적 인접 도달 칸으로 이동 후 근접 전투. 승리 시 수비 타일 점령([Battle](battle.md)).
- **`[사격]`(원거리)**: 현재 위치 원거리 전투(이동·점령 없음).
- **`[휴식]`**(이동 전만): 각 멤버 **hp·스태미나 25% 회복**(`Human.apply_rest()`, `max_hp`/`max_stamina` 상한) 후 턴 종료.
- **`[경계]`**(이동 전만): 각 멤버 **스태미나 10% 회복(반올림)** + **`alert` 부여**(전투 시 공격력·방어력 ×1.2 — [Combat](combat.md)) 후 턴 종료. alert는 **NPC(적) 턴이 끝난 뒤 해제**(= 내 다음 턴).
- **`[대기]`**(이동 후만): 효과 없이 턴만 종료.
- **`[취소]`**(이동 후·되돌리기 가능): 아직 공격 전이면 **직전 이동을 되돌린다** — 부대를 이동 전 칸으로 되돌리고 `moved_this_turn`을 해제(다시 이동 가능), 시야 갱신. `game.gd`가 **마지막 이동 1건**만 추적한다(`_undo_party`·`_undo_cell`).
  - 공격/사격/휴식/경계/대기(턴 종료 행동)를 하면 되돌리기가 사라진다. 다른 부대가 이동하면 그 부대로 교체된다(현재 플레이어 부대는 1개라 실질 단일). 턴 종료 시에도 초기화.
- 취소를 제외한 모든 행동은 부대 행동을 끝낸다(공격/사격/경계/대기=`mark_attacked`, 휴식=`mark_rested`).
- **스태미나 소모·최대치 연동은 `미구현`** — 회복만 넣어 값이 오르지만 현재 소모가 없어 실질 효과는 hp·버프다.

## 테스트 시나리오

### 버튼 구성 — `test/unit/test_party_action_menu.gd`
- [정상] `party_actions(false, true, false)` → `[사격(활성), 휴식, 경계]`(이동 전)
- [정상] `party_actions(false, false, false)` → `[사격(비활성), 휴식, 경계]`
- [정상] `party_actions(true, true, false)` → `[사격(활성), 대기]`(이동 후 — 휴식·경계 없음)
- [정상] `party_actions(true, false, true)` → `[사격(비활성), 대기, 취소]`(되돌리기 가능)
- [경계] `party_actions(false, true, true)` → `[사격, 휴식, 경계]`(이동 전이면 취소 없음)
- [정상] `enemy_actions(true, false)` → `[공격(활성), 사격(비활성)]`
- [정상] `enemy_actions(false, true)` → `[공격(비활성), 사격(활성)]`

### 휴식/경계 효과 — `test/unit/test_human.gd`
- [정상] `apply_rest()` — hp·스태미나가 각각 25%(반올림)만큼 오르고 `max_hp()`/`max_stamina` 상한을 넘지 않음
- [경계] 이미 최대면 `apply_rest()`로 변화 없음
- [정상] `apply_alert()` — 스태미나 10%(반올림) 회복 + `alert == true`
- [정상] `alert`면 `CombatResolver.attack_power`·`defense`가 ×1.2(내림) — `test_combat_resolver.gd`

### 휴식/공격 상태 — `test/unit/test_party.gd`
- [정상] `mark_rested()` → `rested_this_turn`·`attacked_this_turn` 참, `can_rest()` 거짓; `reset_turn()` → 거짓

### 모드·연출 (실행 확인)
- 부대 클릭 → 파랑 이동 범위 + 공격 가능 적 빨강 + **토큰 근처** 메뉴 [사격][휴식][경계].
- 공격 가능 적 클릭 → 팝업 [공격][사격]. [공격] 시 인접 이동 후 전투·승리 시 점령.
- [휴식] → hp·스태미나 회복 후 턴 종료. [경계] → 스태미나 회복+alert 후 턴 종료, 적 턴 방어에 ×1.2, 내 다음 턴에 해제.

## 관련

- 공격 가능 판정·범위·이동은 [Selection & Movement](selection-and-movement.md), 전투는 [Battle](battle.md), 사거리 표기(`ItemTypes.range_label`)는 [Items](../data/items.md), 정보 패널은 [Party Info](party-info.md).
