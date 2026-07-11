# Feature: Battle (전투씬 · 개시 · 복귀)

> 스크립트: `scenes/combat/battle.gd` (`extends CanvasLayer`) · `scenes/combat/battle_field.gd` (`class_name BattleField extends RefCounted`) · `scenes/game/game.gd`

플레이어 부대가 인접한 적을 공격하면 **게임 내 오버레이 전투씬**이 열려, 양 부대원이 실시간으로 교전하는 모습을 관전한다. 판정은 [CombatResolver](combat.md)를 재사용한다. 전투가 끝나면 사상자를 부대에 반영하고 오버레이를 닫는다.

이 문서는 **슬라이스 2**(전투씬·개시·복귀)다. 판정 수학은 [combat.md](combat.md).

## 개시 (`game.gd` + 행동 메뉴)

공격은 [행동 메뉴](party-action-menu.md)로 개시한다(근접 무기 월드맵 사거리는 0이라 붙어야 침).

- **근접 `[공격]`**(공격 가능 적 클릭 팝업): 그 적에 **인접한 도달 칸으로 자동 이동**(이동 애니메이션)한 뒤 근접 전투. **승리 시(수비 전멸·공격 생존) 공격 부대가 수비 타일로 이동**한다(점령).
- **사격 `[사격]`**(중앙 SHOOT 모드 또는 적 팝업): **현재 위치**에서 원거리 전투(이동·점령 없음). 사거리(활 3·완드 2) 내 적만.
- 이동을 했으면 `mark_moved`, 개시 시 `mark_attacked`로 행동을 끝낸다. `ClickRouter`는 `MOVE` 모드의 빈칸/건물/부대 클릭만 처리(`ATTACK` 제거).
- **공격측 = 플레이어 부대, 방어측 = 클릭한 NPC 부대.** (NPC가 먼저 거는 전투는 미구현 — NPC AI는 이동만.)
- 전투 중에는 월드맵 좌클릭·턴 종료를 잠근다(`_in_battle`).

## NPC가 거는 전투 (공격 페이즈)

NPC [이동 페이즈](npc-movement.md)가 끝난 뒤 **공격 페이즈**가 이어진다.

- 각 NPC(살아있고 이번 턴 아직 공격 안 함)가 **공격 가능 범위 안의 적 부대**(플레이어 또는 다른 NPC)가 있으면 전투를 건다. 범위 = `max(attack_range(), 1)` — **근접(사거리 0)은 인접(1)까지, 원거리는 사거리까지**(`_adjacent_enemy`). NPC 순서대로 하나씩 처리한다.
- 공격을 건 NPC는 `mark_attacked`로 이번 턴 행동을 끝낸다. 범위 내 적이 없으면 넘어간다.
- 전투 중 사망으로 목록이 바뀌므로, 처리 중 제거된(전멸) 부대는 건너뛴다.
- 이동 애니메이션과 겹치지 않게 **이동 페이즈 완료 후** 공격 페이즈를 돈다. 도중 새 턴이 시작되면(세대 가드) 중단한다.

## 전투 모드: 근접 vs 원거리

전투 개시 시 두 부대의 거리로 모드가 정해진다(기획 원본 "공격 유형").

- **근접 모드**(개시 시 두 부대가 **인접**): 전원 행동 — 근접 유닛은 돌격, 원거리 유닛은 사격.
- **원거리 모드**(개시 시 **떨어져 있음** = 원거리 무기로 사거리를 두고 침): **양측 모두 원거리 무기(사거리 ≥ 2) 유닛만 행동**한다. 근접 무기 유닛은 정지하고 공격하지 못한다(너무 멀어서 닿지 않음). 공격 측 근접은 못 치고, 방어 측은 원거리 유닛만 반격한다. 근접 유닛은 대상은 될 수 있으나 반격 불가.
- `game.gd`가 개시 시 공격자·대상의 **인접 여부**로 모드를 판정해 오버레이(`battle.gd`)·헤드리스(`BattleSim`)에 전달한다.

## 전투 재생 분기: 오버레이 vs 헤드리스

- **플레이어가 참여하는 전투**(플레이어가 개시했거나 NPC가 플레이어를 공격) → **오버레이로 관전**한다(`_run_battle`, 아래). 공격 페이즈에서는 순차로 `await`한다.
- **NPC ↔ NPC 전투** → **화면 없이 즉시 결산**한다(`BattleSim.resolve_battle`, 아래). 플레이어가 보지 않는 전투라 위치·이동을 생략한 근사 결산이다.
- 두 경로 모두 결과(생존자)를 `_apply_survivors`로 반영한다.

## 헤드리스 전투 결산 (`battle_sim.gd`, 순수)

> `class_name BattleSim extends RefCounted`

오버레이 없이 두 부대의 교전 결과만 계산하는 순수 함수(테스트 용이). 위치·이동·리치·투척을 무시하는 **시간 기반 추상 결산**이라 오버레이의 공간 전투와 결과가 다를 수 있다(플레이어가 안 보는 NPC끼리 전투에만 쓴다).

- `BATTLE_TIME = 10.0` — 한 전투 지속 시간(초).
- `resolve_battle(a_members, b_members, rng, ranged_mode := false) -> Dictionary` — `{a: 생존 human 목록, b: 생존 human 목록}`.
  - 각 멤버를 유닛(`{human, team, hp=hit_points, alive, weapon, can_attack, interval, next_t, effects}`)으로 만든다. `weapon` = `ItemTypes.active_weapon(멤버.weapons, ranged_mode)`(근접=주무기, 원거리=활), `interval` = `CombatResolver.attack_interval(멤버, weapon)`(공격 간격 초). `effects` = `{}`([상태이상](status-effects.md)).
  - **시간 기반 이산 시뮬**: 다음 공격 시점(`next_t`)이 가장 이른 유닛부터 처리한다. 그 유닛이 상대 팀의 살아있는 유닛 하나를 [1회 공격](combat.md)(`resolve_hit`)하고, `next_t += interval`. `next_t`가 `BATTLE_TIME`을 넘으면 종료. 즉 각 유닛은 10초 동안 `10 ÷ interval`회쯤 공격한다.
  - **[상태이상](status-effects.md)**: 이벤트 사이 경과 시간만큼 모든 유닛에 `StatusEffects.advance`로 **출혈 도트**를 hp에서 차감한다(0 이하면 사망). 공격 차례가 온 유닛이 **기절**(`is_stunned`) 상태면 공격을 건너뛴다. `resolve_hit`의 `inflict`가 있으면 피해 적용 후 대상에 `StatusEffects.apply`. 시간 만료로 끝나면 마지막 이벤트~종료 사이 잔여 도트를 적용하지만, **한 팀이 전멸해 끝나면 그 시점이 종료라 이후 도트는 없다**(오버레이가 전멸 즉시 `_finish`하는 것과 동일).
  - **원거리 모드**(`ranged_mode = true`): 원거리 무기(활)가 없는 유닛은 `can_attack=false`(공격 불가). 근접 유닛은 대상은 되지만 반격 못 함.
  - **위치·리치·투척은 무시**한다(근사) — 대상은 목록 앞쪽의 살아있는 적, 투척 무기 유닛도 활성(주무기/활)으로만 공격. 공간 재현은 오버레이 몫. NPC끼리 전투에만 쓰므로 허용.
  - `RandomNumberGenerator`로 결정적. **단, 생존자 `Human.hit_points`를 최종 hp로 덮어써 반영한다(부작용)** — 같은 Human 배열을 재사용하면 두 번째 호출은 이미 깎인 hp에서 시작하므로, 결정성 확인 시 입력을 매번 새로 만든다.

## 전투 오버레이 (`battle.gd`, 관전 전용)

- 월드맵 위를 어둡게 덮는 `CanvasLayer`(높은 layer). 플레이어 입력을 받지 않는다(관전).
- 각 부대의 **살아있는 멤버**마다 토큰을 만든다. 공격측은 화면 좌측 열, 방어측은 우측 열에 세로로 배치한다.
- 전투는 **근접 모드 `BATTLE_TIME = 10초` / 원거리 모드 `RANGED_BATTLE_TIME = 5초`** 동안 진행된다. 유닛마다 **쿨다운**이 있어, 0이 되면 대상에 1회 공격하고 쿨다운을 그 무기의 **공격 간격**(`CombatResolver.attack_interval`)으로 리셋한다. 민첩이 높을수록 공격이 잦다.
- **원거리 모드 2배속 재생**: 원거리 전투는 **공격 간격 × 0.5(2배 빠름) + 전투시간 5초**로, 근접 10초 전투와 **같은 교전 내용을 절반 시간에** 보여준다(발사 횟수는 동일). 헤드리스 [BattleSim](#헤드리스-전투-결산-battle_simgd-순수)은 결과가 같아 변경하지 않는다(10초·1배 = 5초·2배 발사 수 동일).
- 각 부대의 **살아있는 멤버**마다 토큰을 만든다. 공격측은 화면 좌측 열, 방어측은 우측 열에 세로로 배치한다.
- 유닛 상태: `{human, team, hp, pos, alive, cooldown, node, weapon, range, melee_reach, throw, throws, throw_reach, effects}`. `effects` = 상태이상 상태(`{}`). `weapon` = `active_weapon(멤버.weapons, ranged_mode)`, `range` = 그 무기 공격거리. `melee_reach` = `weapon_reach(weapon) × MELEE_REACH_PX`(근접 공격 개시 거리 — **리치 긴 무기가 더 멀리서 = 선제**). `throw` = `throwing_weapon(멤버.weapons)`, `throws` = 투척 횟수, `throw_reach` = `melee_reach + throw_range × THROW_PX`.
- **실시간 진행**(`_process`, delta) — 살아있는 각 유닛(원거리 모드에서 원거리 무기 없는 근접 유닛은 정지):
  1. 쿨다운 감소. 대상 = **가장 가까운 살아있는 적**(`BattleField.nearest_enemy`, 매 프레임 재탐색 → 상대가 죽으면 새 상대).
  2. **원거리**(range ≥ 2): **이동 없이 제자리**에서 쿨다운마다 사격(`resolve_hit`, 일방, 투사체 연출).
     - **근접 전환(근접 모드 한정)**: 최근접 적이 `CHARGE_RANGE_PX`(초안 120px) 안으로 들어오면 그 유닛을 **근접 교전으로 전환**한다 — `weapon`을 `melee_weapon`(없으면 현재 무기=활)으로, `range`를 1로 바꿔 이후 프레임부터 접근·근접 공격(3번 분기)한다. 한 번 전환되면 되돌리지 않는다. (원거리 모드에서는 근접 유닛이 얼어 있어 접근하는 적이 없으므로 전환도 없다.)
  3. **근접/투척**(range 1): 대상 쪽으로 `UNIT_SPEED`만큼 접근하며 —
     - **투척**: `throw`가 있고 `throws < MAX_THROWS`(3)이며 거리가 `melee_reach`~`throw_reach` 사이면 쿨다운마다 투척(`resolve_hit`, 투척 무기, 일방, 투사체). `throws++`.
     - **근접**: 거리가 `melee_reach` 이내면 쿨다운마다 근접 공격(`resolve_hit`, 주무기). 아니면 계속 접근.
     - 즉 투척 유닛은 **접근 중 최대 3회 투척 → 근접 리치 도달 시 주무기 근접**으로 전환한다.
  - `_attack`은 피해 적용 직후 **대상의 hp 라벨을 즉시 갱신**한다(죽는 프레임에도 표시가 0이 되도록 — 살아있는 유닛만 매 프레임 `_sync_node`되므로, 갱신 없이 죽으면 라벨이 직전 양수에 멈춘다).
  - 0 이하가 된 유닛은 `alive=false` 처리하고 사망 넉백([Combat Feedback](combat-feedback.md)).
  - **[상태이상](status-effects.md)**: 매 프레임 `StatusEffects.advance(effects, delta)`로 출혈 피해를 hp에서 차감(0 이하면 사망). **기절**(`is_stunned`) 유닛은 그 프레임 공격을 건너뛴다. `_attack`에서 `resolve_hit`의 `inflict`가 있으면 대상에 `StatusEffects.apply`. **최소 시각 표시**: 출혈 = 토큰 붉은 tint, 기절 = 토큰 흐림.
- **투사체 속도·궤적**: 화살·투창은 `PROJECTILE_TIME`(0.24초, 기존의 1/2 속도) 동안 대상까지 **포물선**(아치 높이 `PROJECTILE_ARC` 40px, 중간 지점 최고)으로 난다(피해는 발사 즉시 적용, 연출만).
- **종료**: 전투시간(근접 10초/원거리 5초)이 지나거나 한 팀이 전멸하면 종료한다. **종료 시점에 아직 날아가는 투사체가 남아 있으면, 마지막 투사체가 착탄할 때까지 기다렸다가 +1초 뒤** `finished`를 방출한다. 날아가는 투사체가 없으면 기존 `END_DELAY`(0.6초) 뒤 방출한다.
- 토큰은 팀 색 사각 + 현재 hp 라벨. **원거리(활·완드)는 제자리 사격(단, 근접 모드에서 적이 `CHARGE_RANGE_PX` 안에 들면 근접 전환·돌격), 투척 무기는 접근 중 투척 후 근접 전환, 그 외 근접은 리치 사거리까지 돌격**. LOS는 미구현.
- **타격 연출**(대미지 숫자·반짝임·흔들림·돌진·상태이상 텍스트·사망 넉백)은 [Combat Feedback](combat-feedback.md) 참조. 연출은 판정·생존 결과에 영향을 주지 않는다.
- **생존자 생명점은 전투 후 지속**된다 — 종료 시 각 생존 유닛의 최종 hp를 `Human.hit_points`에 되쓴다(`maxi(1, hp)`). 다음 전투는 이 값에서 시작(`_make_unit`이 `hit_points`를 읽음). 사망자는 `members`에서 빠진다. 회복·자연 재생은 `미구현`([Human](../entities/Human.md) `max_hp()`가 향후 상한 기준).

## 전투 실행·결과 반영 (`game.gd`)

- `_run_battle(attacker, defender)`(awaitable) — 오버레이를 띄우고(`_in_battle` 잠금) `finished`를 `await`한 뒤 생존자를 반영하고 오버레이를 닫는다. 플레이어 개시 전투는 이 함수를 쓰고, 공격 페이즈에서 플레이어가 낀 전투도 순차로 `await`한다.
- `_apply_survivors(party, survivors)` — 각 부대의 `members`를 **생존자로 교체**한다. 지휘관이 사망했으면 생존 멤버 중 첫 명으로 재지정한다.
  - **NPC 부대가 전멸**하면 맵에서 제거한다(토큰 `queue_free`, `_npc_parties`에서 제외).
  - **플레이어 부대가 전멸**하면 `members`가 빈 상태(이동력·시야 0)로 무력화되지만 노드·게임은 유지한다. *(전멸 후 게임오버/재편은 미구현.)*
- **점령(근접 승리)**: `[공격]`(근접)으로 개시해 **수비 NPC가 전멸하고 공격 부대가 생존**하면, 공격 부대를 **수비가 있던 타일로 이동**시킨다(전투는 수비 타일에서 벌어진 것으로 간주). **사격 승리는 이동 없음**(제자리).
- **약탈(노획)**: 전투로 **한 부대만 전멸**하면 승자가 패자 화물·전사자 장비를 노획한다([Raid](raid.md)) — `_apply_survivors`가 패자를 제거(`queue_free`)하기 **전에** 처리한다(전사자 장비를 읽어야 하므로). 플레이어 승자는 선택 패널, NPC 승자는 자동 전량.
- 전투 후 안개·부대 일람을 갱신한다.

## BattleField 헬퍼 (`battle_field.gd`, 순수)

전투씬의 공간 판정을 노드 없이 계산하는 순수 함수(테스트 용이). 유닛은 `{team, alive, pos, human}` 형태의 Dictionary로 다룬다.

- `nearest_enemy(unit, units) -> Dictionary` — `unit`과 **다른 팀**의 **살아있는** 유닛 중 `pos` 거리가 가장 가까운 것. 없으면 빈 Dictionary(`{}`). 오버레이가 매 프레임 대상 재탐색(상대 사망 시 새 상대)에 쓴다.
- `team_wiped(units, team) -> bool` — 그 팀에 살아있는 유닛이 하나도 없으면 `true`.
- `survivors(units, team) -> Array` — 그 팀의 살아있는 유닛들의 `human` 목록.
- `archer_should_charge(unit_range, dist, threshold) -> bool` — 사거리 ≥ 2인 유닛이 최근접 적과의 거리 `dist`가 `threshold` 이하이면 `true`(근접 전환 판정). 사거리 < 2(이미 근접)면 항상 `false`.

## 미구현

- 지휘범위·지형·마법 위력 공식 등 [combat.md](combat.md)의 미구현 항목. 치명타 연동 상태이상(출혈·기절)은 [status-effects.md](status-effects.md)로 도입됨(전투씬 내 완결, 월드맵 이월은 미구현).
- **헤드리스 결산은 근사** — 위치·이동을 무시하므로 오버레이 결과와 다를 수 있다(플레이어가 안 보는 NPC끼리 전투에만 적용).
- 전투 애니메이션 디테일(타격 이펙트 등), 승리조건·게임오버, 플레이어 전멸 후 처리.

## 테스트 시나리오

### 개시 라우팅 — `test/unit/test_click_router.gd`
- [정상] `on_npc`(선택 중이든 아니든) → `FOCUS_NPC` (공격은 `ClickRouter`가 아니라 행동 메뉴 `ATTACK` 모드에서)
- [경계] 플레이어 부대 칸이면 `FOCUS_PARTY`(NPC보다 앞 순위)
- 공격 버튼 활성·타겟팅은 [party-action-menu](party-action-menu.md) 시나리오 참조

### BattleField 헬퍼 — `test/unit/test_battle_field.gd`
- [정상] `nearest_enemy`는 다른 팀 중 가장 가까운 살아있는 유닛을 고른다
- [정상] `nearest_enemy`는 같은 팀·죽은 유닛을 무시한다
- [경계] 적이 없으면 `nearest_enemy`는 빈 Dictionary
- [정상] `team_wiped`는 그 팀 전원이 죽으면 `true`, 하나라도 살아있으면 `false`
- [정상] `survivors`는 그 팀의 살아있는 유닛의 human만 반환
- [정상] `archer_should_charge`: 사거리 3·거리 ≤ 임계 → `true`, 거리 > 임계 → `false`
- [경계] `archer_should_charge`: 사거리 1(근접)이면 거리와 무관하게 `false`

### 헤드리스 전투 결산 — `test/unit/test_battle_sim.gd`
- [정상] 압도적인 A(항상 명중·일격)면 10초 내 B 전멸, A 생존자 존재
- [정상] 원거리 모드 — 근접 유닛만 있는 팀은 공격 못 하고, 원거리 팀이 일방적으로 처치
- [정상] 원거리 모드 — **검+활(보조)** 든 유닛은 활로 반격(공격)한다; 검만 든 유닛은 못 함
- [경계] 원거리 모드 + 양팀 근접만 → 아무도 공격 못 해 전원 생존
- [정상] 생존자 목록은 원래 멤버의 부분집합
- [경계] 양측 전원 회피(항상 빗나감)면 10초간 공격해도 **아무도 안 죽는다**(양측 전원 생존)
- [경계] 한쪽 멤버가 비어 있으면 다른 쪽 전원 생존
- [정상] 같은 시드 → 같은 결과(결정적)
- [정상] 출혈 도트 — 참격 치명 확정 셋업에서 도트가 더해져 방어측이 더 빨리 전멸한다 ([status-effects.md](status-effects.md))
- [정상] 기절 — 타격 치명으로 기절한 유닛은 기절 지속 동안 공격을 걸지 못한다
- [정상] hp 지속 — 피해를 입고 **생존한** 유닛의 `Human.hit_points`가 전투 후 감소해 있고(풀피 아님) `1 ≤ hit_points ≤ max_hp()`
- [정상] hp 지속 — 피해를 전혀 안 받은 생존자는 `hit_points` 불변

### 전투 흐름 (실행 확인)
- 오버레이를 헤드리스로 돌려 **한 팀이 전멸하거나 10초(`BATTLE_TIME`)에 종료**되고 생존자 집계가 타당한지 확인(양측 전원 회피면 10초 꽉 채우고 전원 생존).
- **원거리 유닛은 이동하지 않고 제자리에서 반복 사격**한다 — 최종 위치가 시작 위치와 같고 쿨다운마다 피해가 들어가는지 확인.
- **리치 긴 무기가 선제**한다 — 장창(리치 2.0) vs 검(리치 1.2) 접근 시 장창이 먼저 피해를 주는지 확인.
- **투척 무기 유닛은 접근 중 최대 3회 투척 후 근접 리치 도달 시 주무기 근접**으로 전환하는지 확인.
- **궁수 근접 전환**: 근접 모드에서 순수 궁수가 적이 `CHARGE_RANGE_PX` 안에 들면 제자리 사격을 멈추고 접근·근접 공격으로 바뀌는지 확인.
- **원거리 2배속**: 원거리 전투가 5초에 종료되고, 근접 10초 전투와 발사·처치 양상이 비슷한지 확인.
- **화살 속도·종료 대기**: 화살이 기존의 절반 속도로 날고, 종료 시점에 날아가던 화살이 착탄한 뒤 약 1초 후 전투가 닫히는지 확인.
- **사망 넉백**: 처치된 토큰이 공격자 반대쪽으로 껑충 뛰어 날아가며 흐려지는지(opacity 0.5) 확인. 출혈 도트 사망은 넉백 없이 페이드.
- 개시(인접 적 클릭)→전투→사상자 반영→복귀, NPC 공격 페이즈, NPC끼리 헤드리스 즉시 결산은 `game.gd` 배선이라 실제 실행으로 확인한다.

## 관련

- 판정 수학은 [Combat](combat.md), 능력치는 [Stats](../data/stats.md), 부대·멤버는 [Party](../entities/Party.md)·[Human](../entities/Human.md).
- 개시 클릭 우선순위는 [Selection & Movement](selection-and-movement.md).
- 기획 원본: `docs/table/시스템/전투.md`.
