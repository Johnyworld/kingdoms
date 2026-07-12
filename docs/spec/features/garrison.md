# Feature: Garrison / 주둔 (거점 수비)

> 스크립트: `scenes/game/game.gd` (`_seed_garrison_party`, `_stationed_party_on`, `_compute_camp_targets`, `_open_camp_menu`) · `scenes/party/party.gd` (`stationed`) · `scenes/party/party_action_menu.gd` (`party_actions`의 `[주둔]`/`[주둔 종료]`) · `scenes/party/unit_types.gd` (`make_garrison`) · `scenes/building/building.gd` (수비 배지) · `scenes/building/building_info.gd`

거점을 지키는 **수비대는 별도 개념이 아니라 그냥 [부대](../entities/Party.md)**다. 부대가 거점 안(중심 타일)에 있으면 수비군이고, 밖으로 나가면 정찰·공격 부대다. 거점 안의 부대가 **[주둔]**을 선택하면 명령을 내리기 전까지 대기한다.

이 통합으로 예전의 `Building.garrison`(Human 배열)·임시 방어부대(`_make_garrison_party`)는 **폐지**됐다. 거점 "방어됨"은 이제 **거점 중심 타일 위에 그 거점 세력의 부대가 있음**을 뜻한다.

## 주둔 상태 (`Party.stationed`)

- `Party.stationed: bool` — 기본 `false`. 부대가 거점에서 **주둔(대기)** 중인지. 명령(주둔 종료) 전까지 유지되며 [턴](turn.md) 리셋(`reset_turn`)에도 남는다.
- 주둔은 그 부대의 이번 턴 행동을 끝낸 것으로 본다(`stationed`이면 `can_move()`·`can_attack()` 거짓). 공격받으면 일반 부대로 방어한다(자동).
- **주둔 중 사격**(적이 사거리에 들면 주둔을 풀지 않고 반격)은 `미구현`(다음 슬라이스).

## 초기 주둔 부대 (`game.gd` `_seed_garrison_party`)

- 게임 시작 시 각 거점(캠프·마을회관·성 — [center](../data/buildings.md#동작))의 **중심 타일**에 **주둔 부대 1개**를 배치한다.
  - 멤버: `UnitTypes.make_garrison(4)`([소집병](../entities/Human.md) 4명). 위치: `building.center_cell()`. `stationed = true`.
  - **플레이어 거점** → `_units`에 등록(플레이어 소속·금색). **NPC 거점** → `_npc_parties`에 등록(세력 색). `home_territory` = 그 영지([수비대 노획](raid.md#수비대-노획) 귀속 대상).
- 거점당 **여러 부대 주둔 허용** — 한 중심 타일엔 한 부대만 서지만, 인접 편성·[병합](party-composition.md)으로 병력을 늘린다.

## 소집병 (`UnitTypes.make_garrison`)

- `make_garrison(count := 4) -> Array` — 소집병 `count`명을 [Human](../entities/Human.md)으로 생성한다(초기 주둔 부대·[병사 구매](trade.md#병사-구매)에서 사용).
  - 소집병: 검·가죽 방어구를 든 보통 병사(부대 지휘관보다 약함). 이동력·시야 인간 기본값, 생성 시 풀피(`hit_points = max_hp()`)·풀 스태미나.

## 주둔 / 주둔 종료 (`party_action_menu` + `game.gd`)

플레이어가 **자기 세력 거점 중심 타일 위**에 있는 아군 부대를 클릭하면 [행동 메뉴](party-action-menu.md)에 주둔 항목이 뜬다.

- **[주둔]** — 부대가 그 타일 위 + 이번 턴 **미행동**(주둔 아님)일 때. 선택 → `stationed = true`. 그 턴 행동 종료(대기), 이후 턴에도 명령 없이 유지.
- **[주둔 종료]** — 부대가 **주둔 중** + 이번 턴 미행동일 때. 선택 → `stationed = false`. 이번 턴부터 다시 이동·공격 가능.
- 두 항목은 조건이 맞을 때만 목록에 넣는다(거점 밖이면 없음). 주둔 종료는 `mark_moved`/`mark_attacked` 전에만 가능(이미 움직였으면 없음).

## 방어·점령 게이트 (`game.gd`)

발견된 적 거점에 **인접 가능**할 때, 그 거점 **중심 타일**을 **그 거점 세력의 부대**(진짜 수비대)가 지키는지로 갈린다(`_camp_defender`).

- **그 거점 세력의 부대가 중심을 지킴**(방어됨) → 그 부대를 **[공격]**([일반 부대 전투](battle.md) 재사용). 별도 캠프 공격 분기 없음 — 거점 위 부대를 부대로서 친다. 근접 승리 시 기존대로 그 중심 타일로 이동(진입).
- **그 거점 세력의 수비 부대 없음**(무방비) → **[흡수][파괴]** 점령([Camp Capture](camp-capture.md)). **점령은 중심 타일 진입으로 성립** — 수비 부대가 있으면 먼저 격파해야 진입·점령할 수 있다. 격파 후 중심에 서 있는 **공격자 부대는 그 거점 세력이 아니므로 방어로 치지 않아**, 다음 턴에 그 거점을 점령할 수 있다.
- 미발견·인접 불가·미선택이면 기존 [거점 정보 패널](building-info.md).

## 정보 표시

- **맵 위 수비 배지**([Building](../entities/Building.md) `_draw`): 완성 **거점**이고 중심 타일에 그 거점 세력 부대가 있으면 중심 아래에 `"수비 N"` 배지(N = 그 부대 인원). 건설 중 배지와 같은 자리(겹치지 않음). 부대가 들고 나거나 인원이 바뀌면 다시 그린다. 발견된 적 거점의 수비 인원도 보인다.
- [거점 정보 패널](building-info.md): 거점이면 `"수비대 N명"`(중심 타일 부대 인원, 없으면 0 또는 줄 생략).
- **[부대 일람](party-roster.md)**: 주둔 부대도 일반 부대라 일람에 표시된다(주둔 여부와 무관, 멤버 0이면 제외).

## 병력 편입 ([병사 구매](trade.md#병사-구매))

- 예전의 **수비대 편성 패널**(부대↔수비대 병사 이동)은 **폐지**됐다 — 부대가 곧 수비대라 이동 개념이 없다. 병력 조정은 부대 [병합·분할](party-composition.md)로 한다.
- [캠프 메뉴](camp-menu.md)의 **병사 구매**는 그 거점 **중심 타일 주둔 부대**에 소집병을 편입한다. 주둔 부대가 없으면 [구매] 비활성.

## NPC의 주둔 (`game.gd`)

- NPC 주둔 부대(`stationed`)는 **이동·공격 페이즈에서 제외**(대기)한다 → [NPC Movement](npc-movement.md). 공격받으면 일반 부대로 방어한다.
- NPC의 **수비대 자동 보충은 `미구현`**(개발 안 함) — 주둔 부대가 곧 수비라 별도 보충 로직을 두지 않는다.

## 이번 슬라이스 제외 (미구현)

- **주둔 중 사격**(적이 사거리에 들면 주둔 유지한 채 반격) — *(다음 슬라이스)*.
- **성벽·사다리 공성**(마을회관·성 6면 성벽, 사다리 설치·오르기) — *(후속 슬라이스)*.
- NPC의 주둔 조작·능동적 재편성.

## 테스트 시나리오

**주둔 상태 필드** — `test/unit/test_party.gd`:
- [정상] 생성 직후 `stationed == false`; 설정 가능
- [정상] `stationed = true`면 `can_move()`·`can_attack()` 거짓(주둔은 행동 종료)
- [정상] `reset_turn()` 후에도 `stationed`는 유지(주둔은 턴을 넘겨 지속)

**주둔 메뉴 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] 거점 위·미행동·주둔 아님 → 버튼 목록에 `[주둔]` 포함, `[주둔 종료]` 없음
- [정상] 거점 위·미행동·주둔 중 → `[주둔 종료]` 포함, `[주둔]` 없음
- [경계] 거점 밖 → 둘 다 없음
- [경계] 이미 이동/공격함 → `[주둔]`·`[주둔 종료]` 없음

**소집병 병력** — `test/unit/test_unit_types.gd`(기존 유지):
- [정상] `make_garrison(4)` → 4명, 모두 Human, `hit_points == max_hp()`
- [정상] 기본 4명; [경계] `make_garrison(0)` → 빈 배열

**병사 구매(주둔 부대 편입)** — `test/unit/test_camp_menu.gd`:
- [정상] 거점 주둔 부대 있음 + 금·인구 충분 → [구매] → 그 부대 members +1, 금·인구 차감
- [경계] 주둔 부대 없음 → [구매] 비활성
- [경계] 금<20 또는 인구<1 → [구매] 비활성

`game.gd`의 초기 주둔 부대 배치·방어/점령 게이트·주둔 종료 후 이동·NPC 주둔 제외(씬 트리·터레인 의존)는 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Camp Capture (캠프 점령)](camp-capture.md) — 중심 타일 진입 점령. [Battle (전투)](battle.md) — 거점 위 부대와의 전투 재사용. [NPC Movement](npc-movement.md) — NPC 주둔 제외.
- [Party](../entities/Party.md) — `stationed` 필드. [Party Action Menu](party-action-menu.md) — [주둔]/[주둔 종료]. [Trade](trade.md) — 병사 구매(주둔 부대 편입). [Building Info](building-info.md) — 수비 인원 표시.
- 기획: [건물](../../table/세력/건물.md) · [영지](../../table/세력/영지.md)
