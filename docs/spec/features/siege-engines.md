# Feature: Siege Engines / 공성병기 (부대 소속 공성 유닛)

> 스크립트: `scenes/siege/siege_types.gd` (`SiegeTypes` — 공성 유닛 카탈로그) · `scenes/siege/siege_unit.gd` (`SiegeUnit` — 부대에 실리는 공성 유닛 인스턴스) · `scenes/party/party.gd` (`siege_units`·`has_siege`·견인 이동 규칙) · `scenes/building/building_types.gd` (`siege_workshop` 종류) · `scenes/territory/territory.gd` (`has_completed_building`) · `scenes/camp/camp_menu.gd` (`[투석기 생산]`·`siege_produced`) · `scenes/game/game.gd` (`_on_siege_produced`) · `scenes/party/party_info.gd` (공성 유닛 표시)

성벽을 두른 거점을 함락하기 위한 **공성 유닛**(투석기·충차·공성탑 …). 일반 병사([Human](../entities/Human.md))와 달리 **부대에 실리는 재사용 장비 유닛**이다. 인구를 차지하지 않고, 부대의 사람(인구)이 조작한다. 일반 전투에는 참여하지 않으며 「투석」 등 전용 명령으로만 공격한다.

**이 문서는 슬라이스 5a-1(유닛 모델·획득·이동·표시)만 다룬다.** 「투석」 공격·성벽 내구도·유닛 폭격·NPC 공성 AI는 후속 슬라이스로 `미구현`이다(아래 [로드맵](#공성병기-로드맵)).

## 공성 유닛 모델 (`SiegeUnit` · `Party.siege_units`)

- 부대([Party](../entities/Party.md))는 `members`(사람)와 별개로 **`siege_units: Array`**(공성 유닛 인스턴스 목록)를 가진다.
- 공성 유닛은 **인구 비소모** — `members`에 들지 않으므로 부대 시야(`vision()`)·공격거리(`attack_range()`)·전투(사상자·[Battle](battle.md))에 **영향을 주지 않는다**. 부대의 사람이 조작한다는 설정만 있고, 별도 조작 인원 배정 로직은 없다.
- `SiegeUnit`(RefCounted)은 종류 id 하나를 들고 카탈로그([SiegeTypes](../data/siege-units.md))에서 스펙을 읽는다:
  - `type_id: String` — 기본 `"catapult"`.
  - `unit_name() -> String` — 카탈로그 이름(예: `"투석기"`).
  - `movement() -> int` — 견인 이동력(투석기 `2`).
- **재사용** — 소모품이 아니다. 생성 후 부대에 계속 남는다(전투 사상·거점 상실 시의 소실 처리는 후속 슬라이스에서 다룬다).
- 충차·공성탑도 같은 모델을 쓸 예정이다(카탈로그에 종류만 추가).

## 획득 — 공성 작업장에서 생산 (`siege_workshop` · `[투석기 생산]`)

투석기는 **전용 건물 「공성 작업장」**([buildings](../data/buildings.md))을 지은 영지에서만 생산한다.

- **공성 작업장(`siege_workshop`)**: 소형(footprint 1) 생산 건물. 선행 `town_hall`. 기존 [건축](building.md) 흐름으로 짓는다(`BUILDABLE_IDS`에 포함). 턴당 생산(`production`)은 없다 — 투석기 생산은 아래 수동 행동으로 한다.
- **[투석기 생산] 버튼** (`camp_menu._siege_btn` — [성벽 건설](wall.md) 버튼과 같은 전용 버튼 패턴):
  - **표시 조건**: 연 건물이 **거점**이고 그 **주둔 부대(`_party`)가 있으며**, 그 거점의 **영지에 완성된 공성 작업장이 있을 때**(`Territory.has_completed_building("siege_workshop")`). 아니면 숨김.
  - **텍스트**: `"투석기  <비용>"`(예: `"투석기  금 40 · 목재 30 · 석재 20"`, `_format_cost`가 `"금 40"`처럼 단위-값 순으로 낸다). 비용 = `SiegeTypes.produce_full_cost`(생산 금 + 생산 자재).
  - **활성**: 영지가 금·자재를 감당하면 활성, 부족하면 비활성. **인구는 소비하지 않는다**(비소모 유닛).
  - 누르면 `siege_produced(building)` 방출 → `game.gd._on_siege_produced`: 영지 금·자재 차감 + 그 **주둔 부대 `siege_units`에 투석기 1대 추가** + 부대 일람·정보 갱신. 갱신된 정보로 캠프 메뉴 재오픈([병사 구매](trade.md)와 같은 패턴).
- 투석기는 주둔 부대에 실린다. 출격하려면 [주둔 종료](garrison.md) 후 이동하는데, **견인 인력(4명) 규칙**(아래)을 만족해야 움직인다.

## 견인 이동 규칙 (`Party.movement`)

공성 유닛을 실은 부대는 느리고, 끌 인력이 있어야 움직인다.

- **견인 속도**: 부대가 공성 유닛을 실으면(`has_siege()`) 그 부대 이동력은 **공성 유닛 견인 이동력(가장 느린 것, 투석기 `2`)으로 상한**된다. 즉 `min(사람 기준 이동력, 견인 속도)`.
- **인력 게이트**: 공성 유닛을 실은 부대의 **사람(`members`) 수가 `SiegeTypes.CREW_MIN`(4) 미만이면 이동력 0**(끌 인력 부족 → 정지). 4명 이상이어야 견인 이동력을 얻는다.
- 공성 유닛이 없으면 규칙은 적용되지 않고 기존 이동력(사람 최소 − 과적)을 그대로 쓴다.
- 과적([overload](../entities/Party.md))으로 이미 이동력이 견인 속도보다 낮으면 그 낮은 값이 유지된다(`min`).

정리(공성 유닛 있는 부대):

| 사람 수 | 이동력 |
| --- | --- |
| ≤ 3 | `0` (견인 불가) |
| ≥ 4 | `min(사람 기준 이동력, 견인 속도 2)` |

## 정보 표시 (`party_info`)

- [부대 정보 패널](party-info.md)은 멤버 목록 아래에 **「공성 유닛」 줄**을 추가한다 — 실은 공성 유닛 이름을 나열(예: `"공성 유닛: 투석기"`). 공성 유닛이 없으면 그 줄은 없다.
- 견인 인력이 부족(사람 ≤ 3 + 공성 유닛 보유)해 이동력이 0이면 그 사실을 덧붙여(예: `"(견인 인력 부족 — 이동 불가)"`) 이동력 0의 이유를 알린다.
- 요약 줄의 `이동력`은 이미 견인 규칙이 반영된 `movement()` 값이라 별도 처리는 없다.

## 이번 슬라이스 제외 (미구현)

- **「투석」 명령**(사거리 5·1턴 1발·전투씬 투석) — 5a-2(성벽)·5b(유닛).
- **성벽 내구도(`wall_hp`)·성벽 붕괴** — 5a-2.
- **유닛 대상 폭격**(최대 5명·유닛별 명중) — 5b.
- **NPC 공성 AI**(NPC의 작업장 건설·투석기 생산·운용) — 5c.
- **맵 토큰의 공성 유닛 표시**(투석기 마커)·공성 유닛 내구도·전투 사상/거점 상실 시 공성 유닛 소실 처리 — 후속.
- 조작 인원 개별 배정·NPC의 고리 사다리류 확장 — 후속.

## 공성병기 로드맵

- **5a-1 유닛 모델** — (이 문서) 투석기 획득·부대 편입(인구 비소모)·견인 이동 규칙·정보 표시.
- **5a-2 성벽 투석 + 내구도** — [투석] 성벽 공격(사거리 5, 1턴 1발) → `wall_hp` 감소 → 붕괴(→ 기존 [점령](camp-capture.md)).
- **5b 유닛 투석** — [투석] 적 부대 공격(최대 5명, 유닛별 명중 판정).
- **5c NPC 공성 AI** / **5d 방어 카운터플레이**.

## 테스트 시나리오

**공성 유닛 카탈로그(순수)** — `test/unit/test_siege_types.gd`:
- [정상] `SiegeTypes.CATAPULT == "catapult"`, `SiegeTypes.CREW_MIN == 4`
- [정상] `SiegeTypes.type_name("catapult") == "투석기"`, `movement("catapult") == 2`
- [정상] `produce_gold("catapult") == 40`, `produce_cost("catapult") == {목재:30, 석재:20}`
- [경계] 없는 id → `type_name` `""`, `movement` `0`, `produce_gold` `0`, `produce_cost` `{}`

**공성 유닛 인스턴스(순수)** — `test/unit/test_siege_unit.gd`:
- [정상] `SiegeUnit.new()` → `type_id == "catapult"`, `unit_name() == "투석기"`, `movement() == 2`
- [정상] `SiegeUnit.new("catapult")` 동일

**부대 공성 유닛·견인 이동** — `test/unit/test_party.gd`:
- [정상] 생성 직후 `siege_units` 빈 배열, `has_siege() == false`
- [정상] `add_siege_unit(SiegeUnit.new())` → `siege_units` 크기 1, `has_siege() == true`
- [정상] 공성 유닛 없으면 이동력 규칙 불변(기존 테스트대로)
- [정상] 사람 4명(이동력 4) + 투석기 1대 → `movement() == 2`(견인 속도 상한)
- [경계] 사람 3명 + 투석기 → `movement() == 0`(견인 인력 부족)
- [경계] 사람 4명 + 투석기 + 과적으로 사람 기준 이동력 1 → `movement() == 1`(min)
- [정상] 투석기 추가는 `vision()`·`attack_range()`·`members`에 영향 없음(인구 비소모)

**영지 완성 건물 판정(순수)** — `test/unit/test_territory.gd`:
- [정상] 완성된 `siege_workshop`이 있으면 `has_completed_building("siege_workshop") == true`
- [경계] 건설 중 작업장만 있으면 `false`; 작업장 없으면 `false`

**공성 작업장 종류** — `test/unit/test_building_types.gd`:
- [정상] `CATALOG`에 `siege_workshop` 존재(label "공성 작업장", footprint 1, prerequisite "town_hall")
- [정상] `BUILDABLE_IDS`에 `"siege_workshop"` 포함

**투석기 생산 버튼(`_siege_btn`)** — `test/unit/test_camp_menu.gd`:
- [정상] 거점 + 주둔 부대 + 영지에 완성 작업장 + 금·자재 충분 → `_siege_btn` 표시·활성, 텍스트에 `"투석기"`·비용 포함
- [경계] 작업장 없음 / 주둔 부대 없음 → 숨김; 금·자재 부족 → 표시하되 비활성
- [정상] `_siege_btn.pressed` → `siege_produced(building)` 방출

`game.gd`의 `_on_siege_produced`(금·자재 차감·`siege_units` 추가·갱신), 작업장 건축, 정보 패널 공성 유닛 표시·이동력 0 사유는 실제 실행으로 확인한다(`game.gd` 통합 테스트는 기존 관례상 두지 않음).

## 관련

- [Party (부대)](../entities/Party.md) — `siege_units`·견인 이동. [SiegeUnits (공성 유닛 카탈로그)](../data/siege-units.md) — `SiegeTypes`·투석기 값. [Buildings](../data/buildings.md) — 공성 작업장. [Camp Menu](../features/camp-menu.md)·[Trade](../features/trade.md) — 생산 버튼(구매 패턴). [Garrison](../features/garrison.md) — 주둔 부대에 편입·출격. [Wall / 성벽](../features/wall.md) — 사다리 공성(이 병기가 함락 대상으로 삼을 성벽).
- 기획: 공성 로드맵 슬라이스 5(공성병기).
