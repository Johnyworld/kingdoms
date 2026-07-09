# Feature: Battle (전투씬 · 개시 · 복귀)

> 스크립트: `scenes/combat/battle.gd` (`extends CanvasLayer`) · `scenes/combat/battle_field.gd` (`class_name BattleField extends RefCounted`) · `scenes/game/game.gd`

플레이어 부대가 인접한 적을 공격하면 **게임 내 오버레이 전투씬**이 열려, 양 부대원이 실시간으로 교전하는 모습을 관전한다. 판정은 [CombatResolver](combat.md)를 재사용한다. 전투가 끝나면 사상자를 부대에 반영하고 오버레이를 닫는다.

이 문서는 **슬라이스 2**(전투씬·개시·복귀)다. 판정 수학은 [combat.md](combat.md).

## 개시 (`game.gd` + `ClickRouter`)

- 플레이어 부대를 **선택한 상태**에서, **공격 범위(빨강) 안**의 **보이는 적 NPC**를 클릭하면(그 부대가 공격 가능하면) 전투를 개시한다([Selection & Movement](selection-and-movement.md)).
  - `ClickRouter`에 `ATTACK` 액션 추가. 인자 `enemy_attackable`(기본 `false`)를 받아, `on_npc`일 때 **선택 중 + 공격 가능 범위**면 `ATTACK`, 아니면 `FOCUS_NPC`(정보)로 분기한다.
  - 우선순위: 플레이어 부대 > (NPC: 공격/정보) > 이동 > 캠프 > 건물 > 해제.
- 개시 처리: 부대가 적과 **인접**하면 그대로 전투하고, 아니면 **적에 인접한 도달 가능 칸으로 자동 이동**(이동 애니메이션)한 뒤 전투한다. 이동했다면 `mark_moved`, 전투 개시 시 `mark_attacked`로 그 부대의 행동을 끝낸다.
- **공격측 = 플레이어 부대, 방어측 = 클릭한 NPC 부대.** (NPC가 먼저 거는 전투는 미구현 — NPC AI는 이동만.)
- 전투 중에는 월드맵 좌클릭·턴 종료를 잠근다(`_in_battle`).

## 전투 오버레이 (`battle.gd`, 관전 전용)

- 월드맵 위를 어둡게 덮는 `CanvasLayer`(높은 layer). 플레이어 입력을 받지 않는다(관전).
- 각 부대의 **살아있는 멤버**마다 토큰을 만든다. 공격측은 화면 좌측 열, 방어측은 우측 열에 세로로 배치한다.
- 유닛 상태: `{human, team("a"/"b"), hp(현재 생명점), pos, alive, cooldown, node}`.
- **실시간 진행**(`_process`):
  1. 각 살아있는 유닛의 대상이 없거나 죽었으면 **가장 가까운 살아있는 적**으로 재탐색(`BattleField.nearest_enemy`).
  2. 대상과 **접촉**(거리 ≤ `CONTACT_DIST`)하고 쿨다운이 끝났으면 그 쌍이 **1회 교전**(`CombatResolver.resolve_engagement`, 접촉한 유닛이 개시자). 결과 hp를 반영하고, 0 이하가 된 유닛은 `alive=false`로 페이드아웃한다. 두 유닛에 짧은 쿨다운을 준다.
  3. 접촉 전이면 대상 쪽으로 `UNIT_SPEED`만큼 이동한다.
- **종료**: 한 팀이 전멸하거나 안전 상한 시간(`MAX_TIME`)을 넘으면 종료하고 `finished` 시그널을 방출한다(양 팀 생존 멤버 목록).
- 토큰은 팀 색 사각(공격측=부대 토큰 색, 방어측=세력 색) + 위에 현재 hp 라벨(간단). 세부 연출·근접/원거리 구분·리치 선제권은 미구현.
- **생존자 생명점은 전투 후 회복**된다(현재 hp를 Human에 되쓰지 않음). *(hp 지속은 미구현.)*

## 결과 반영 (`game.gd` `_on_battle_finished`)

- 각 부대의 `members`를 **생존자로 교체**한다. 지휘관이 사망했으면 생존 멤버 중 첫 명으로 재지정한다.
- **NPC 부대가 전멸**하면 맵에서 제거한다(토큰 `queue_free`, `_npc_parties`에서 제외).
- **플레이어 부대가 전멸**하면 `members`가 빈 상태(이동력·시야 0)로 무력화되지만 노드·게임은 유지한다. *(전멸 후 게임오버/재편은 미구현.)*
- 오버레이를 닫고 안개·부대 일람을 갱신한다.

## BattleField 헬퍼 (`battle_field.gd`, 순수)

전투씬의 공간 판정을 노드 없이 계산하는 순수 함수(테스트 용이). 유닛은 `{team, alive, pos, human}` 형태의 Dictionary로 다룬다.

- `nearest_enemy(unit, units) -> Dictionary` — `unit`과 **다른 팀**의 **살아있는** 유닛 중 `pos` 거리가 가장 가까운 것. 없으면 빈 Dictionary(`{}`).
- `team_wiped(units, team) -> bool` — 그 팀에 살아있는 유닛이 하나도 없으면 `true`.
- `survivors(units, team) -> Array` — 그 팀의 살아있는 유닛들의 `human` 목록.

## 미구현

- NPC가 거는 전투·자동 전투 개시(조우), 근접/원거리·리치·지휘범위·지형·상태이상 등 [combat.md](combat.md)의 미구현 항목 전부.
- 전투 애니메이션 디테일(타격 이펙트 등), 승리조건·게임오버, 플레이어 전멸 후 처리.

## 테스트 시나리오

### 개시 라우팅 — `test/unit/test_click_router.gd`
- [정상] `on_npc` + 선택 중 + `enemy_attackable` → `ATTACK`
- [정상] `on_npc` + 선택 중 + **공격 범위 밖** → `FOCUS_NPC`
- [정상] `on_npc` + **미선택** + 공격 범위 → `FOCUS_NPC`(정보만)
- [경계] 플레이어 부대 칸이면 `enemy_attackable`와 무관하게 `FOCUS_PARTY`

### BattleField 헬퍼 — `test/unit/test_battle_field.gd`
- [정상] `nearest_enemy`는 다른 팀 중 가장 가까운 살아있는 유닛을 고른다
- [정상] `nearest_enemy`는 같은 팀·죽은 유닛을 무시한다
- [경계] 적이 없으면 `nearest_enemy`는 빈 Dictionary
- [정상] `team_wiped`는 그 팀 전원이 죽으면 `true`, 하나라도 살아있으면 `false`
- [정상] `survivors`는 그 팀의 살아있는 유닛의 human만 반환

### 전투 흐름 (실행 확인)
- 오버레이를 헤드리스로 끝까지 돌려 **한 팀이 전멸**하거나 상한 시간에 종료되고, 생존자 집계가 타당한지 확인.
- 개시(인접 적 클릭)→전투→사상자 반영→복귀와 NPC 전멸 시 맵 제거는 `game.gd` 배선이라 실제 실행으로 확인한다.

## 관련

- 판정 수학은 [Combat](combat.md), 능력치는 [Stats](../data/stats.md), 부대·멤버는 [Party](../entities/Party.md)·[Human](../entities/Human.md).
- 개시 클릭 우선순위는 [Selection & Movement](selection-and-movement.md).
- 기획 원본: `docs/table/시스템/전투.md`.
