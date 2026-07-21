# Feature: NPC Movement (NPC 이동 AI)

> 스크립트: `scenes/game/npc_ai.gd` (`class_name NpcAi extends RefCounted` — 순수 판정) · `scenes/game/npc_planner.gd` (`class_name NpcPlanner extends RefCounted` — 의사결정) · `scenes/game/game.gd` (`_move_npcs` — 실행·연출)

턴 종료 시 각 [NPC 부대](parties.md)가 스스로 이동한다. **가장 가까운 적(부대·캠프)을 향해 이동력만큼 접근**하는 목표지향 AI이며, 자기 [거점](npc-bases.md)이 위협받으면 침입한 적을 요격(방어)하고, 향할 적이 없으면 무작위로 배회한다.

**계층 분리**: `NpcAi`(순수 static — 목적지·티어·전력 판정) ← `NpcPlanner`(의사결정 — 표적 조립 `targets_for`·후퇴·포지셔닝·그룹 이동 계획 `plan_group_move`·표적 탐지 `adjacent_enemy`/`adjacent_enemy_camp`) ← `game.gd`(실행·연출 — 애니메이션·전투·카메라·안개). NpcPlanner는 월드 상태를 game.gd의 좁은 조회 인터페이스(`all_parties`/`all_buildings`/`party_on_cell`/`blocked_for`)로만 읽어, 테스트에서는 스텁으로 대체한다(`test_npc_planner.gd`). 반경 상수(`DEFEND_RADIUS` 5 · `RETREAT_SCAN` 6 · `PRIORITY_SCAN` 8)도 NpcPlanner 소유.

## 동작

- **시점**: 플레이어가 턴 종료를 누르면([Turn](turn.md)), 유닛 리셋·자원 수입·건설 진행 뒤에 NPC들이 이동한다.
- **목적지 선택**(`NpcAi.choose_destination(..., blocked_cells, targets)`):
  1. `HexGrid.movement_ranges(terrain, start, move_range, ..., blocked_cells)`로 이동 가능한 목적지 집합(`move`)과 거리 맵(`dist`)을 구한다. 지형 규칙(산 진입 불가·숲 `ceil`·습지 `floor` 반감)·맵 경계·**다른 부대 점유 칸**([유닛 점유](selection-and-movement.md))은 이 헬퍼가 반영한다.
  2. **목표지향**(`targets` 비어 있지 않음): 이동 칸 중 **가장 가까운 적(`targets`)과의 월드 좌표 거리가 최소**인 칸으로 이동한다. 시작 칸보다 더 가까워지는 칸이 없으면 **제자리**(적에게서 멀어지지 않는다). 최소 거리 동률은 `RandomNumberGenerator`로 고른다.
  3. **폴백**(`targets` 비어 있음): 도달 가능한 **이동 칸 중 하나를 무작위**로 고른다(배회 — 거리 무관, 반드시 최대 이동력만큼 가지 않는다).
  - **도달 가능한 이동 칸이 없으면**(이동력 0, 사방이 산/점유/맵 밖 등) 시작 칸을 그대로 반환한다(제자리).
- **타깃 조립**(`NpcPlanner.targets_for`): 각 NPC(세력 `F`)에 대해 아래 두 목록을 만들고, `NpcAi.select_targets`로 우선순위를 정한다.
  - **진격 타깃(advance)** — **적(세력 ≠ `F`)의 부대 + 캠프** 셀 전부. 부대는 소속(`faction_name`)으로, 캠프는 `territory.faction.name`으로 적/아군을 가른다. (전멸한 부대는 제외.) 캠프도 노리므로 근처에 부대가 없으면 적 거점으로 향한다.
  - **방어 타깃(defend)** — 자기 세력 캠프 중심에서 **헥스 거리 `NpcPlanner.DEFEND_RADIUS`(5) 이내**로 침입한 **적 부대** 셀. 자기 거점을 위협하는 적을 요격한다.
  - `NpcAi.select_targets(advance, defend)` — **방어 타깃이 있으면 그것만**(캠프 곁 위협 우선 요격), 없으면 진격 타깃 전체를 쓴다.
  - 적/아군 세력 필터는 순수 함수 `NpcAi.enemy_cells(self_faction, entries)`(각 `{cell, faction}`에서 `faction != self_faction`인 `cell` 목록). 부대·캠프 모두 이 함수로 거른다.
  - 부대 칸은 점유(`blocked_cells`)돼 있어 NPC는 적 부대 칸 위로 못 가고 **인접까지** 접근한다. 캠프 칸은 통행 가능(점유 아님)이라 캠프 위/곁까지 갈 수 있다.
- **이동 반영**(`game.gd` `_move_npcs`): 각 NPC를 선택된 칸까지 **경로를 따라 애니메이션**으로 이동시킨다(아래).

## 전력 인식 (신중한 교전 · 후퇴)

NPC는 전력을 비교해 무모한 교전을 피하고, 약하면 물러선다.

- **전력 지표**: `Party.power()` = `soldiers`(병력수/HP 풀, 부상하면 낮아짐). `NpcAi.should_engage(my_power, enemy_power)` = `my_power >= enemy_power * CAUTION_RATIO`(`CAUTION_RATIO = 0.7`) — 자기 전력이 적의 70% 이상일 때만 교전.
- **신중한 교전**(공격 페이즈, `_npc_unit_act`): 인접 **적** 부대(거점 방어 부대 포함 — 방어자도 그냥 부대다)를 치기 전에 `should_engage`로 판단한다. 대상은 **다른 세력**만(`NpcPlanner.adjacent_enemy`가 같은 세력 부대는 제외). 불리하면(false) 그 NPC는 이번 턴 **교전을 건너뛴다**(대기). 무방비 거점 흡수는 전투가 아니므로 그대로 진행. *(예전 `stationed`(주둔) 상태·주둔 중 사격·이동 제외는 [주둔 제거](camp-capture.md)와 함께 삭제 — 방어자는 이제 일반 부대로 이동·전투하고, 거점 방어는 후퇴로 돌아온 부대가 중심을 점거해 창발한다.)*
- **약하면 후퇴**(이동, `NpcPlanner.targets_for`): NPC 근처(`NpcPlanner.RETREAT_SCAN` 반경) 적 부대 중 가장 강한 것과 비교해 `should_engage`가 false면, 접근 타깃 대신 **안전한 자기 캠프 중심**을 타깃으로 삼아 물러선다. 자연히 거점 수비로 이어진다. **적이 2칸 이내로 붙은 캠프는 후퇴 대상에서 제외**(위협받는 캠프로 도망쳐 오히려 적에게 다가가는 것을 막는다). 안전한 캠프가 없으면 후퇴하지 않는다(기존 접근/방어).

## 표적 우선순위 (`NpcPlanner.targets_for` + `NpcAi.prioritize`)

후퇴하지 않을 때, 접근 타깃을 **우선순위 티어**로 고른다(`NpcAi.prioritize(tiers)` = 첫 비지 않은 티어). 상위 두 티어는 **근처(`NpcPlanner.PRIORITY_SCAN` 반경) 대상만** 우대해, 멀리 있는 우선 대상 때문에 코앞의 적을 버리고 행군하지 않게 한다.

1. **근처 무방비 적 캠프**(중심 타일에 수비 부대 없음) — 손쉬운 점령.
2. **근처 약한 적 부대**(전력 ≤ 내 전력) — 이길 만한 싸움. *(교전 포지셔닝 적용 — 아래.)*
3. **나머지**(전체 적 셀, 기존 `enemy_cells`) — 가장 가까운 것으로 접근(폴백).

이 접근 타깃을 방어 타깃(`_threats_near_own_camp`)과 `select_targets`로 합쳐, **자기 캠프 위협 요격이 최우선**이고 그다음이 위 우선순위다.

### 교전 포지셔닝 — 근·원거리 선호 (`_party_prefers_ranged`·`_combat_band_cells`)

부대는 **자기 강점 거리에서 싸우려** 한다. 약한 적 부대(티어 2)를 노릴 때:

- **원거리 선호 부대**(`attack_range() >= 2` 그리고 `NpcAi.prefers_ranged(melee_power, ranged_power)`)는 적 부대 셀 대신 **적에게서 `[2 ~ attack_range]` 밴드 셀**로 접근한다(`_combat_band_cells`, 5f 밴드 기계 공용). 사거리 안에서 쏘되 적 근접(리치 1)이 못 닿는 거리를 유지 → 적이 붙으면 자연히 물러나는 카이팅.
- **근접 선호 부대**는 기존대로 적 부대에 **붙는다**(접근).
- **강점 판정**(`NpcAi.prefers_ranged`): `ranged_power > melee_power`면 원거리 선호(동률·근접 우위면 근접). **부대 파워**(`Party.melee_power()`·`ranged_power()`) = 병종이 원거리(경궁병)면 원거리 파워 = 클래스 AT × 병력, 근접(경보병/영웅)이면 근접 파워 = 클래스 AT × 병력([GameUnits](../data/units.md)). 반대쪽 파워는 0.
- 티어 3(폴백)과 무방비 캠프(티어 1)에는 포지셔닝을 적용하지 않는다(폴백은 단순 접근).

## 수비대 보충 (미구현)

NPC의 **수비대 병력 자동 보충은 개발하지 않는다** — 수비대가 곧 일반 부대라 별도 병력 보충 로직을 두지 않는다. 초기 각 거점에 부대 1개(경보병 10명 — [시작 편제](parties.md))가 중심을 점거해 방어할 뿐이고, 후퇴로 돌아온 부대가 자연히 방어를 재건한다([거점 방어](camp-capture.md#거점-방어-창발--중심-점거)).

## 이동 애니메이션

NPC는 순간이동하지 않고 시작 칸에서 목적지 칸까지 **헥스 최단 경로를 칸 단위로 걸어가는 모습**을 보여준다.

- **경로 재구성**(`HexGrid.reconstruct_path`): 시작→목적지 최단 헥스 경로(칸 목록, 양끝 포함)를 BFS로 구한다. 지형(산)·경계를 반영하며, 도달 불가면 빈 배열, 제자리(start==dest)면 `[start]`.
- **공용 이동 헬퍼**(`game.gd` `_animate_path`): 부대를 경로의 칸을 차례로 지나도록 Tween으로 이동시키고, 각 칸 도착 시 콜백을 실행한다. NPC(자기 시야 표시 토글)와 플레이어([이동 애니메이션](selection-and-movement.md), 시야 열림)가 공유한다.
- **속도**: 칸당 `MOVE_STEP_TIME`(0.12초, 플레이어 이동과 공유). 이동력 4칸이면 약 0.5초.
- **재생 순서**(세력 → 영웅그룹 → 그룹마다 이동→공격):
  - **세력 간 순차** — 한 세력의 모든 그룹이 끝나야 다음 세력이 시작한다. 세력 차례 시작 시 [세력 배너](turn.md#턴-배너-turn_bannergd).
  - **영웅그룹별 순차, 그룹마다 [이동 → 공격]** — 한 세력 안에서 **영웅부대 + 그 소속 하위부대(`lord==영웅`)를 한 그룹**으로 묶어(`NpcAi.hero_groups`) **한 그룹씩** 처리한다. **그룹이 먼저 이동을 마친 뒤, 그 그룹이 공격**하고(아래 [NPC 공격](#npc-공격-그룹-이동-직후)), 다음 그룹으로 넘어간다. 영웅 없는 독립 부대는 단독 그룹. 이동 계획(목적지·경로)은 **그 그룹 차례에 즉석 수립**하되, **점유 회피(`blocked_for`)만 실시간**이다 — 표적 목록(플레이어 부대·캠프)은 턴 시작 스냅샷이라, 앞 그룹이 죽인 부대·뺏은 캠프는 표적 선택에 즉시 반영되지 않을 수 있다(회피는 반영).
  - **그룹 내 동시(스태거)** — 한 그룹의 부대들은 함께 움직이되 `NPC_PARTY_STAGGER`(0.2초)씩 시작을 늦춘다.
  - **시야 내 그룹 = 카메라 포커스**: 그룹의 부대 중 하나라도 현재 칸/목적지가 플레이어 [시야](fog-of-war.md) 안이면, 이동 전 카메라를 그 그룹으로 옮기고(`_focus_camera`, `NPC_FOCUS_PAUSE`(0.3초) 잠깐 정지) 걸어가는 모습을 보여준다.
  - **시야 밖 그룹 = 즉시 스냅**: 그룹이 전부 시야 밖이면 애니메이션·대기 없이 목적지로 즉시 스냅한다(안개에 가려 안 보이므로 연출 생략 — NPC 턴이 안 늘어짐).

### NPC 편제 — 하위부대 영웅 추종 (`_move_npcs` 이동 계획)

한 영웅그룹 안에서 **하위부대는 영웅을 추종해 대형을 유지**한다(플레이어 [추종 스탠스](squad-stance.md#추종-st_follow)의 NPC판). 그래서 하위부대가 영웅 곁(지휘 범위)에 머물러 [지휘 범위 버프](command-range.md)를 받고, 적 군대도 응집력 있게 싸운다. 그룹의 이동 계획은:

- **영웅**: 기존 목표지향 AI대로 목적지를 고른다(`choose_destination` — 적/캠프 접근·후퇴·우선순위 티어).
- **하위부대**(그 영웅의 `lord==영웅`, `can_move()`):
  - **영웅 지휘 범위(`hero.command_range()`, 2~4칸) 안에 보이는 적 부대가 있으면** → 그 적 쪽으로 접근한다(`choose_destination`으로 근접 교전 준비). "영웅 근처 적은 문다."
  - **없으면** → 영웅을 추종한다(`HexGrid.follow_destination`으로 영웅 목적지 주변 링, 전방 우선). 하위부대끼리 목적지를 예약해 겹치지 않는다.
  - 두 경우 모두 하위부대가 **영웅 지휘 범위 안에 머물러** 흩어지지 않는다(멀리 있는 적을 쫓지 않음).
- **독립 부대**(영웅 없는 단독 그룹): 기존대로 목표지향 접근(`choose_destination`).

이동 뒤 [NPC 공격](#npc-공격-그룹-이동-직후)에서 각 유닛이 인접 적을 친다(변경 없음). 하위부대가 영웅 곁 적에 붙어 있으므로 그 적을 함께 교전한다.

## NPC 공격 (그룹 이동 직후)

그룹이 이동을 마치면 **그 그룹이 곧바로 공격**한다(`_npc_unit_act`). **영웅부대 먼저, 그다음 하위부대 순서로 1유닛씩**(`hero_groups`가 영웅을 앞에 둔다) 처리하고, **한 유닛의 전투가 끝나야 다음 유닛**이 행동한다.

- **행동 결정**(유닛별): 인접 적 부대(`NpcPlanner.adjacent_enemy`)가 있고 [신중 교전](lang-battle.md)(`should_engage`)이면 전투, 없으면 인접 무방비 적 캠프 흡수.
- **교전 연출**(`_npc_engage`): 공격자·대상 중 하나라도 플레이어 [시야](fog-of-war.md) 안이면, 카메라를 공격자로 옮기고 **공격자·대상 토큰에 테두리 하이라이트**(공격자 빨강·대상 흰색, `Party.set_highlight`)를 `NPC_ENGAGE_FOCUS`(1초) 보여줘 **누가 누굴 치는지** 알린다(하이라이트는 이동/공격 fade와 무관하게 선명). 그 뒤 전투를 결산하고 하이라이트를 지운다.
- **전투 결산**:
  - **플레이어 부대가 대상** → [전투 오버레이](lang-battle.md)로 관전(`_run_battle`).
  - **NPC 부대가 대상** → **전투 씬 없이 헤드리스 즉시 결산**(`_resolve_battle_headless`). 시야 안이면 위 포커스+하이라이트 1초로 "누가 누굴"까지만 보여주고, 시야 밖이면 연출 없이 즉시 처리한다.
- **입력 잠금**: NPC 턴이 도는 동안 플레이어 좌클릭·턴 종료는 잠긴다(`_npc_turn_active`, [Turn](turn.md#턴-진행-순서-세력-턴-gamegd)). 카메라 이동·줌만 가능. (`_on_turn_ended`가 NPC 페이즈를 `await`한다 — 예전 비차단 방식에서 변경.)
- **이동 중 안개 표시**: 토큰이 지나는 각 칸에서 `fog.is_cell_visible(cell)`로 `visible`을 토글한다 — 시야 밖 칸을 지날 땐 숨고, 시야 안 칸에서 다시 보인다([Fog of War](fog-of-war.md)).
- **재진입 방지**: NPC 턴 동안 플레이어의 턴 종료가 입력 잠금(`_npc_turn_active`)으로 막히므로, NPC 이동 중 새 라운드가 끼어들지 않는다. (코드에는 옛 비차단 시절의 재진입 안전장치 — 세대 `_npc_move_epoch` 확인·진행 중 이동 목적지 스냅 `_finish_pending_npc_moves` — 가 남아 있으나, 입력 잠금 이후로는 트리거되지 않는다. → [Turn](turn.md#턴-진행-순서-세력-턴-gamegd).)

## 범위 밖 (미구현)

- **표적 우선순위** — 무방비 캠프·약한 적 부대를 우선한다(위 참조). 인지 범위(시야)·자원 가치 판단은 `미구현`.
- **유닛 충돌·점유** — 다른 부대가 점유한 칸은 통과·정지 불가([유닛 점유](selection-and-movement.md)). 단 **동시 계획 한계**: 턴 종료 시 모든 NPC 목적지를 각자의 현재 위치 기준으로 한 번에 계산하므로, 두 NPC가 같은 빈 칸을 목표로 삼을 수 있다(예약 시스템 없음). *(다음 단계)*
- **건물 통행** — 건물 위로는 계속 겹쳐 지날 수 있다(유닛만 서로 막음).
- **이동 상태(`moved_this_turn`)** — NPC 이동은 이 플래그를 건드리지 않는다(흐림 표시는 플레이어 조작용 신호라서). 턴 리셋에 NPC가 포함돼 있어도 무해한 no-op.

## 테스트 시나리오

목적지 선택은 `test/unit/test_npc_ai.gd`, 의사결정(표적·후퇴·계획)은 `test/unit/test_npc_planner.gd`(월드 스텁 주입), 경로 재구성은 `test/unit/test_hex_grid.gd`에서 검증한다.
실제 헥스 타일셋 `TileMapLayer`로 검증한다(엔진 인접 동작 의존). 애니메이션(Tween·타이밍·세력 순서)은 `game.gd` 오케스트레이션이라 실제 실행으로 확인한다.

### 의사결정 — `NpcPlanner`(월드 스텁 주입) (`test_npc_planner.gd`)

- [정상] `party_entries` — 멤버 있는 부대만 `{cell, faction}` 수록(빈 부대 제외)
- [정상] `camp_entries` — 거점(캠프)만 수록(농장 등 비거점 제외), 세력은 영지 경유 이름
- [정상] `_band_cells([중심], 2, 3)` = 헥스 거리 2~3 링(중심 제외, `cells_within` 차집합과 크기 일치)
- [정상] `_should_retreat` — RETREAT_SCAN 안 압도적 적이면 참 / 약한 적·스캔 밖 적이면 거짓
- [정상] `_safe_retreat_cells` — 적이 2칸 안에 붙은 캠프·적 캠프 제외, 안전한 자기 캠프 중심만
- [정상] `adjacent_enemy` — 사거리 내 적 반환(아군 제외)
- [정상] `targets_for` — 근처(PRIORITY_SCAN) 무방비 적 캠프 최우선 / 압도적 적 인접이면 안전한 자기 캠프로 후퇴
- [정상] `plan_group_move` — 영웅 경로는 자기 칸에서 시작해 적에게 가까워진다

### 목적지 선택 — 폴백(무작위 배회, `targets` 없음) (`test_npc_ai.gd`)

- [정상] 초원에서 목적지는 이동 가능 집합(`movement_ranges["move"]`)에 속한다
- [정상] 배회는 **거리 무관 무작위** — 최대 거리보다 짧은 칸도 고를 수 있다(항상 최대 이동력 X)
- [경계] 이동력 0이면 목적지 = 시작 칸(제자리)
- [정상] 같은 시드의 `RandomNumberGenerator` → 같은 목적지(결정적)
- [지형] 산으로 둘러싸인 경우 목적지가 산 칸이 아니다(도달 가능 칸만)
- [점유] `blocked_cells`로 준 점유 칸은 목적지로 고르지 않는다
- [점유] 도달 가능한 칸이 전부 점유되면(이동력 1 + 이웃 전부 점유) 목적지 = 시작 칸(제자리)

### 목적지 선택 — 목표지향(`targets` 있음) (`test_npc_ai.gd`)

- [정상] 동쪽에 타깃이 있으면 목적지는 시작보다 그 타깃에 **더 가까운** 칸이다(접근)
- [정상] 목적지는 이동 칸 중 타깃과의 거리가 **최소**인 칸이다
- [정상] 타깃이 여럿이면 **가장 가까운** 타깃 기준으로 접근한다
- [경계] 더 가까워지는 이동 칸이 없으면(타깃이 시작 칸) 제자리
- [정상] 같은 시드 → 같은 목적지(결정적)

### 영웅그룹 묶기 — `NpcAi.hero_groups(parties)` (`test_npc_ai.gd`)

`hero_groups`는 부대 목록을 **영웅 + 그 소속 하위부대(`lord==영웅`)** 그룹으로 묶어 순서대로 돌려준다(영웅 없는 부대는 단독 그룹). 세력별 순차 이동이 그룹 단위로 진행하는 근거.

- [정상] 영웅 H1(하위 2)·H2(하위 1) → `[[H1,t,t],[H2,t]]`(각 그룹 첫 원소가 영웅, 인원 3·2)
- [정상] 하위 없는 영웅 → 단독 그룹 `[[H]]`
- [경계] 영웅 없는 troop만 → 각자 단독 그룹(그룹 수 = 부대 수)
- [경계] 빈 배열 → 빈 결과

### 지휘 범위 내 적 — `NpcAi.enemies_within(terrain, center, radius, enemy_cells, ...)` (`test_npc_ai.gd`, 실제 헥스 TileMapLayer)

`center`에서 `radius` 헥스 이내인 `enemy_cells`의 부분집합(지형 무관 disk). NPC 하위부대가 "영웅 지휘 범위 안 적"을 칠지 판정하는 근거.

- [정상] center에서 거리 1·2·3 적, radius 2 → 거리 ≤2 적만 반환(3은 제외)
- [경계] 범위 안 적 없으면 빈 배열; enemy_cells 빈 배열이면 빈 배열
- [정상] radius 0이면 center와 같은 칸의 적만

### NPC 편제 이동 (실행 확인)

하위부대 추종/근접 교전 선택(`enemies_within`로 지휘 범위 내 적 판정 → 있으면 `choose_destination` 접근, 없으면 `follow_destination` 추종)·예약·독립부대 처리는 씬 트리·터레인·시야 의존이라 실제 실행으로 확인한다. 재사용하는 `follow_destination`·`choose_destination`·`hero_groups`·`enemies_within`·[지휘 버프](command-range.md)는 단위 테스트가 커버.

### 타깃 선정 — 세력 필터·방어 우선(순수) (`test_npc_ai.gd`)

- [정상] `enemy_cells("사막 술탄국", entries)` → 소속이 다른 항목의 `cell`만 반환(같은 세력 제외)
- [경계] 모든 항목이 같은 세력이면 `enemy_cells`는 빈 배열
- [정상] `select_targets(advance, defend)` — `defend`가 비어 있지 않으면 `defend` 반환(방어 우선)
- [정상] `select_targets(advance, [])` — 방어 대상 없으면 `advance` 반환

### 표적 우선순위 (순수) (`test_npc_ai.gd`)

- [정상] `prioritize([[], [b], [c]])` → `[b]`(첫 비지 않은 티어)
- [정상] `prioritize([[a], [b]])` → `[a]`
- [경계] `prioritize([[], []])` → `[]`

### 전력 인식 (순수) (`test_npc_ai.gd`)

> 전력값 = `Party.power()`(= `soldiers`). `should_engage`는 순수 값 비교라 부대 없이 검증.

- [정상] `should_engage(100, 100)` 참(대등); `should_engage(70, 100)` 참(0.7 경계)
- [정상] `should_engage(60, 100)` 거짓(불리 → 회피)
- [경계] `should_engage(10, 0)` 참(적 전력 0)

### 근·원거리 선호 (순수) (`test_npc_ai.gd`·`test_party.gd`)

- [정상] `NpcAi.prefers_ranged(10, 20)` 참(원거리 우위); `prefers_ranged(20, 10)` 거짓(근접 우위)
- [경계] `prefers_ranged(15, 15)` 거짓(동률은 근접); `prefers_ranged(0, 0)` 거짓
- [정상] `Party.melee_power()`/`ranged_power()` — 근접 병종(경보병)은 melee_power = 클래스 AT × 병력·ranged_power 0; 원거리 병종(경궁병)은 반대

### 경로 재구성 (`HexGrid.reconstruct_path` — `test_hex_grid.gd`)

- [정상] 초원 start→dest(거리 3): 경로 길이 4, 양끝이 start·dest, 이웃끼리 인접, 거리 단조 증가
- [경계] start == dest → `[start]`
- [경계] 인접 칸(거리 1) → 경로 길이 2
- [예외] 도달 불가한 dest(산으로 격리) → `[]`
- [지형] 경로에 산 칸이 없다

## 관련

- 이동 목적지·지형 규칙은 [Selection & Movement](selection-and-movement.md)의 `HexGrid.movement_ranges`.
- 이동 후 표시는 [Fog of War](fog-of-war.md), 이동 시점은 [Turn](turn.md).
- NPC 부대 생성·배치는 [Parties](parties.md).
