# Feature: Wall / 성벽 (거점 방어 구조물)

> 스크립트: `scenes/building/building.gd` (`wall_level`·`is_walled`·성벽 그리기) · `scenes/building/building_types.gd` (`WALL_COST`·`can_build_wall`) · `scenes/camp/camp_menu.gd` (`[성벽 건설]` 버튼·`wall_requested` 시그널) · `scenes/game/game.gd` (`_on_wall_requested`·이동 차단·표적 제외)

**마을회관·성**([center](../data/buildings.md#동작) tier ≥ town_hall) 둘레에 세우는 방어 구조물. 성벽이 있으면 **적 부대가 그 거점에 접근(진입·통과)하지 못해**, 중심 [주둔 부대](garrison.md)를 공격하거나 [점령](camp-capture.md)할 수 없다. 성벽을 넘는 수단(사다리·공성병기)은 **후속 슬라이스**(`미구현`)라, 이번 슬라이스의 성벽은 사실상 난공불락이다(방어측 강화).

캠프(tier 0)는 성벽을 지을 수 없다(무방비로 남아 점령/공격 가능).

## 성벽 상태 (`Building.wall_level`)

- `Building.wall_level: int` — 기본 `0`(성벽 없음). ≥ 1이면 성벽 있음. *이번 슬라이스는 단일 단계(0/1)만* — 기획의 다단계 벽(통나무/나무/돌/성벽)·성문은 후속.
- `is_walled() -> bool` — `wall_level > 0`. 거점 방어·이동 차단 판정에 쓴다. (비거점 건물엔 성벽을 짓지 않으므로 항상 0.)
- 성벽은 **거점에 붙는 값**이다(별도 씬 노드 아님). 거점 footprint(중심+이웃 6 = 7칸)를 두르는 것으로 본다.

## 성벽 건설 (`camp_menu` `[성벽 건설]` · `game.gd` `_on_wall_requested`)

캠프 메뉴에 **[성벽 건설]** 버튼(`_wall_btn`)을 둔다. 거점 업그레이드 버튼과 같은 패턴(즉시 적용 — 배치 모드 없음).

- **표시 조건**: 연 건물이 거점이고 **tier ≥ town_hall**(마을회관·성)이며 **아직 성벽 없음**(`not is_walled()`). 캠프·이미 성벽 있음·비거점이면 숨김.
- **텍스트**: `"성벽 건설  <비용>"`(예: `"성벽 건설  목재 15 · 석재 10"`). 비용 = `BuildingTypes.WALL_COST`.
- **활성**: 여는 영지가 비용을 감당하면([`can_build_wall`](../data/buildings.md) = tier·자재 확인) 활성, 부족하면 비활성.
- 누르면 `wall_requested(building)` 방출 → `game.gd` `_on_wall_requested`: 영지 자재 차감(`Territory.spend(WALL_COST)`) + `building.wall_level = 1` + 맵 다시 그리기. 갱신된 정보로 캠프 메뉴를 재오픈.

## 이동 차단 (`game.gd`)

- **적 세력 부대**는 성벽 있는 거점의 **footprint 7칸에 진입·통과할 수 없다**(산처럼 완전 장애물). **같은 세력 부대는 자유 통행**(수비대 주둔·출입).
- 세력 상대적 — 부대 P의 이동 범위·경로 계산 시, **P의 세력과 다른** walled 거점들의 footprint를 막는 칸(`blocked_cells`)에 더한다([Selection & Movement](selection-and-movement.md) 유닛 점유와 같은 `HexGrid` 인자 재사용). 플레이어·NPC 이동 모두 반영.

## 공격·점령 차단 (`game.gd`)

성벽으로 접근이 막히므로, 성벽 있는 **적 거점**은 이번 슬라이스에서 공격·점령 대상이 아니다.

- **점령 제외**: `_compute_camp_targets`가 walled 적 거점은 점령 대상에서 뺀다(무방비여도 성벽이 있으면 진입 불가).
- **표적 제외**: walled 적 거점 footprint 안에 있는 부대(중심 주둔 수비대)는 근접·사격 표적에서 제외한다(`_compute_attack_targets`·NPC `_adjacent_enemy`) — 성벽이 안쪽을 보호한다.
- 결과: 성벽 있는 마을회관·성은 **사다리·공성병기(후속 슬라이스)** 없이는 함락 불가.

## 맵 표시 (`building.gd` `_draw`)

- 성벽 있는 거점은 중심 둘레(footprint 경계)에 **성벽 링**을 그린다(간단한 선/색). 캠프·성벽 없는 거점은 그리지 않는다.

## 이번 슬라이스 제외 (미구현)

- **다단계 벽·성문**(하급~최상급 방어, 통행로) — 지금은 0/1 단일 단계.
- **사다리·공성병기 돌파** — 성벽을 넘거나 부수는 공성 수단(다음 슬라이스). 지금은 성벽 = 완전 차단.
- **NPC의 성벽 건설** — NPC는 성벽을 짓지 않는다(NPC 거점은 캠프라 성벽 불가). 성벽 파괴·내구도.

## 테스트 시나리오

**성벽 상태** — `test/unit/test_building.gd`:
- [정상] 생성 직후 `wall_level == 0`, `is_walled() == false`
- [정상] `wall_level = 1` → `is_walled() == true`; 설정 가능
- [정상] `upgrade_to`(티어 교체) 후에도 `wall_level` 유지

**성벽 건설 가능 판정** — `test/unit/test_building_types.gd`:
- [정상] `WALL_COST == {목재15, 석재10}`(자재 Dictionary)
- [정상] `can_build_wall(territory, building)` — 마을회관·성 + 자재 충분 → 참
- [경계] 캠프(tier 0) → 거짓(성벽 불가); 이미 성벽 있음 → 거짓; 자재 부족 → 거짓

**성벽 건설 버튼** — `test/unit/test_camp_menu.gd`:
- [정상] 마을회관 거점 + 자재 충분 → `[성벽 건설]` 표시·활성, 텍스트에 `"성벽 건설"`·비용 포함
- [경계] 캠프 거점 → `[성벽 건설]` 숨김; 이미 성벽 있는 거점 → 숨김
- [경계] 자재 부족 → 표시하되 비활성
- [정상] 버튼 누르면 `wall_requested(building)` 방출

`game.gd`의 자재 차감·`wall_level` 설정·적 이동 차단(footprint blocked_cells)·공격/점령 표적 제외(씬 트리·터레인 의존)는 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Garrison / 주둔](garrison.md) — 성벽 안 중심 주둔 부대. [Camp Capture](camp-capture.md) — 성벽 있으면 점령 불가. [Building](../entities/Building.md) — `wall_level`. [Camp Menu](camp-menu.md) — [성벽 건설] 버튼. [Selection & Movement](selection-and-movement.md) — 이동 차단(`blocked_cells`).
- 기획: [건물](../../table/세력/건물.md)(벽·성벽·성문 라인) · 공성 로드맵 슬라이스 3(사다리)·4(고리 사다리 아이템).
