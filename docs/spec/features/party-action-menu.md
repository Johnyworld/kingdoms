# Feature: Party Action Menu (부대 행동 — 공격 통합 · 팝업)

> 스크립트: `scenes/party/party_action_menu.gd` (`class_name PartyActionMenu extends CanvasLayer`) · `scenes/game/game.gd`

플레이어 [부대](../entities/Party.md)를 선택하면 이동 범위(파랑)와 **공격 가능한 적 타일(빨강)** 이 표시된다. **중앙 행동 메뉴·`SHOOT` 모드는 없다**([Selection & Movement](selection-and-movement.md)) — 이동은 맵 클릭, **공격은 적을 직접 클릭**한다. `PartyActionMenu`(코드 구성 버튼 패널)는 이제 **대상 옆 팝업**(거점 점령 [흡수]/[파괴], 인접 아군 [병합], 작전 메뉴)에만 쓴다. [소속] 버튼은 [부대 정보 패널](party-info.md) 안으로 옮겼다.

## 공격 가능 판정 (`game.gd`)

부대가 이번 턴 그 적을 칠 수 있는지 두 가지로 본다([Selection & Movement](selection-and-movement.md)). 이동해서 붙거나 사거리에 들 수 있으면 포함한다(이동력 범위 기준).

- **근접 가능(`can_melee`)** — (현재 칸 ∪ 이동 범위 칸) 중 그 적에 **인접한 칸**이 있으면 참(이동해 붙을 수 있음). 근접 무기는 인접(거리 1)해야 친다.
- **사격 가능(`can_shoot`)** — 부대가 원거리 무기(사거리 ≥ 2)를 갖고, (현재 칸 ∪ 이동 범위 칸) 중 그 적까지 헥스 거리 ≤ 사거리인 칸이 있으면 참(필요 시 사거리에 들도록 이동 후 제자리 사격).
- **공격 가능한 적** = `can_melee` 또는 `can_shoot`. 그 적 타일에 **빨강 오버레이**를 그리고, 그 타일 위 호버 시 커서를 칼/화살로 바꾼다. 병종이 근접이면 근접, 원거리면 사격으로 **자동 결정**(선택지 없음).

## 공격 통합 (적 클릭)

공격 가능한 적 타일을 클릭하면 팝업 없이 **바로 공격**한다(`game.gd`가 `ClickRouter` 앞단에서 가로챈다 → [Selection & Movement](selection-and-movement.md)). 대상 칸→`_attack_targets[cell]`(= `{enemy, cell, melee, shoot, stand}`).

- **근접(`melee`)**: `stand`(그 적에 인접한 도달 칸; 이미 인접이면 현재 칸)으로 이동한 뒤 근접 전투. `stand`까지 경로 누적비용만큼 이동력을 소모한다. 승리 시 수비 타일 점령([Lang Battle](lang-battle.md)).
- **원거리(`shoot`)**: `stand`(사거리에 드는 **가장 먼** 도달 칸 = `HexGrid.best_fire_cell`; 이미 사거리 안이면 현재 칸)으로 (필요 시) 이동한 뒤 제자리 사격(점령 없음). 접근분만큼 이동력 소모.
- **이동·공격 독립**: 공격은 턴당 1회(`mark_attacked`)지만 **이동력은 별개**다. 접근 이동은 이동력을 쓰되, 타격 자체는 이동력을 쓰지 않는다. 공격 후에도 이동력이 남고 부대가 살아 있으면 `game.gd`가 **전투 종료 뒤 다시 선택**해 계속 이동할 수 있게 한다. 이동을 다 쓴 부대도 공격은 할 수 있다.
- **방어된 적 거점**은 그 중심 타일 위 부대를 이 방식으로 친다(별도 캠프 공격 없음). → [거점 방어](camp-capture.md#거점-방어-창발--중심-점거).

## 팝업 버튼 구성 (순수)

노드 비의존 정적 함수(테스트 용이). 각 원소 `{id, label, enabled}`. (중앙 메뉴 `party_actions`·적 공격 팝업 `enemy_actions`는 **삭제** — 공격은 직접 클릭, [소속]은 [부대 정보](party-info.md)로 이동.)

- `capture_actions() -> Array` — **적 거점 클릭 팝업** `[흡수][파괴]`(둘 다 활성). → [Camp Capture](camp-capture.md). `{id="absorb", label="흡수"}` · `{id="destroy", label="파괴"}`.
- `merge_actions() -> Array` — **인접 아군 부대 클릭 팝업** `[병합]`. → [Party Composition](party-composition.md).
- (`stance_actions` 작전 메뉴는 **삭제** — 영웅 지휘는 [부대 정보](party-info.md)의 [지휘] 지속 설정으로 대체. → [Squad Command](squad-stance.md))

## UI (`party_action_menu.gd`)

- 코드 구성 버튼 패널([camp_menu](camp-menu.md)·[party_info](party-info.md) 패턴). 버튼만 클릭 흡수, 나머지 화면은 맵으로 통과.
- `open(buttons: Array, screen_pos: Vector2)` — 버튼을 채우고 **클릭한 대상의 화면 좌표 근처**에 패널을 띄운다. 화면 밖으로 넘치지 않게 클램프.
- `close()` — 감춘다. 버튼 클릭 시 `action_selected(id)` 방출(팝업 대상은 `game.gd`가 보관).

## 행동 효과 (`game.gd`)

- **근접 공격**: 적 인접 도달 칸으로 이동 후 근접 전투. 승리 시 수비 타일 점령([Lang Battle](lang-battle.md)).
- **원거리 공격**: 사거리에 드는 가장 먼 칸으로 (필요 시) 이동 후 제자리 사격(점령 없음).
- **점령([흡수]/[파괴])**: 무방비 적 거점을 흡수(세력 편입)하거나 파괴. 인접 칸으로 이동 후 실행. 행동 종료(`mark_attacked`).
- **병합([병합])**: 인접 아군 부대를 병합. → [Party Composition](party-composition.md).
- 공격·점령은 부대 공격 행동을 끝낸다(`mark_attacked`). ([사격]/[대기]/[취소] 중앙 버튼, [휴식]·[경계]는 삭제됨.)

## 테스트 시나리오

### 버튼 구성 — `test/unit/test_party_action_menu.gd`
- [정상] `capture_actions()` → `[흡수, 파괴]`(둘 다 활성)
- [정상] `merge_actions()` → `[병합]`
- (중앙 `party_actions`·적 팝업 `enemy_actions`·작전 `stance_actions`는 삭제 — 관련 테스트 제거)

### 공격 판정 (실행 확인 — `game.gd`)
공격 가능 판정(`_attack_targets`)·적 클릭 공격·커서·전투 후 재선택은 씬 트리·전투 오버레이 의존이라 실행으로 확인한다.
- 근접 부대 선택 → 사거리(이동+인접) 안 적 빨강, 호버 시 칼 커서 + 인접 칸까지 경로. 클릭 → 이동 후 전투, 승리 시 점령.
- 원거리 부대 선택 → 이동해 사거리에 들 수 있는 적 빨강, 호버 시 화살 커서 + 사격 위치까지 경로. 클릭 → (필요 시) 이동 후 제자리 사격.
- 공격 후 이동력이 남으면 그 부대가 다시 선택돼 계속 이동 가능(이동·공격 독립).

## 관련

- 공격 가능 판정·범위·이동·경로 미리보기·`best_fire_cell`은 [Selection & Movement](selection-and-movement.md), 전투는 [Lang Battle](lang-battle.md), 정보 패널·[소속] 버튼은 [Party Info](party-info.md).
