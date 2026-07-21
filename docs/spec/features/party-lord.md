# Feature: Party Lord (소속 영웅 설정)

> 스크립트: `scenes/party/lord_menu.gd` (`LordMenu`) · `scenes/party/party_action_menu.gd` (`party_actions`의 `[소속]`) · `scenes/game/game.gd` (`_on_party_action("lord")`, `_adjacent_player_heroes`, `_can_manage_lord`) · `scenes/party/party.gd` (`set_lord`/`clear_lord`)

랑그릿사식 편제에서 **일반부대**([Party](../entities/Party.md) `KIND_TROOP`)는 하나의 **영웅부대**(`KIND_HERO`)에 소속될 수 있다. 이 기능은 그 소속을 **런타임에 바꾸는 UI**다. 소속돼도 부대는 독립 토큰으로 자유 이동하며, 소속은 지금은 **메타데이터**다(영웅 근처 소속 부대 버프는 `미구현`). 초기 소속은 [시작 편제](parties.md)에서 정해진다.

## 진입 — `[소속]` 버튼 ([행동 메뉴](party-action-menu.md))

- 플레이어가 **일반부대**를 선택하면 [행동 메뉴](party-action-menu.md)에 **[소속]**이 뜬다(맨 뒤).
- 노출 조건(`game.gd` `_can_manage_lord(party)`): `party.kind == KIND_TROOP` **그리고** (**인접한 아군 영웅부대가 있음** 또는 **이미 소속 보유**(`has_lord`)). 즉 붙일 영웅도 없고 뗄 소속도 없으면 버튼을 숨긴다.
- 영웅부대(`KIND_HERO`)에는 [소속]이 없다(영웅은 소속을 갖지 않는다).

## 소속 모달 (`LordMenu`)

`[소속]` → 공용 [Modal](modal.md) 기반 `LordMenu`가 열린다(캠프 메뉴와 같은 컴포지션 패턴, 별도 `.tscn` 없음).

- **현재 소속** 라벨: `현재 소속: {영웅 이름}` 또는 `현재 소속: 없음(독립)`.
- **후보 영웅 버튼**: 그 일반부대에 **인접한 아군 영웅부대** 목록(`game.gd`가 계산해 넘김). 각 버튼 = 그 영웅 이름. 클릭 → `party.set_lord(hero)`(소속 확정) → `changed` 방출 → 닫기.
  - **현재 소속 영웅**은 목록에 나오더라도 버튼을 **비활성**(이미 소속)으로 둔다.
- **[독립]** 버튼: `party.has_lord()`일 때만 **활성**. 클릭 → `party.clear_lord()` → `changed` 방출 → 닫기.

### 규칙

- **소속(합류)은 그 영웅부대에 인접**(헥스 거리 1)해야 가능하다 — 후보 목록 자체가 인접 영웅만 담으므로 UI로 강제된다.
- **해제(독립)는 위치 무관** 항상 가능(소속 보유 시).
- **턴 소비 없음** — 순수 재편이라 `mark_moved`/`mark_attacked`를 부르지 않는다(인접 게이트만). [분할·병합](party-composition.md)이 턴을 소비하는 것과 다르다.
- **대상은 플레이어 세력 영웅부대만**. 소속 수 상한 없음.

## API (`LordMenu`)

| 함수/시그널 | 설명 |
| --- | --- |
| `open(troop, candidates: Array) -> void` | `troop`의 소속을 관리한다. `candidates` = 인접 아군 영웅부대([Party](../entities/Party.md)) 목록. 현재 소속 라벨 + 후보 버튼 + [독립]을 그리고 모달을 연다 |
| `changed` (signal) | 소속을 바꾼 뒤 방출. `game.gd`가 [부대 일람](party-roster.md)·[부대 정보](party-info.md)를 갱신한다 |

`game.gd`:
- `_adjacent_player_heroes(troop) -> Array` — `troop` 칸에 헥스 인접한 **플레이어 영웅부대**(멤버 있는 `KIND_HERO`) 목록. `LordMenu.open`의 `candidates`.
- `_can_manage_lord(party) -> bool` — 위 [노출 조건](#진입--소속-버튼-행동-메뉴).

## 미구현

- **소속 부대 버프** — 영웅부대 근처의 소속 일반부대에 세력·영웅별 버프. 지금 소속은 메타데이터일 뿐이다.
- NPC의 소속 관리(플레이어 전용 UI).

## 테스트 시나리오

**`[소속]` 버튼** — `test/unit/test_party_action_menu.gd`:
- [정상] `can_manage_lord=true` → 버튼 목록에 `[소속]` 포함(맨 뒤)
- [경계] `can_manage_lord=false` → `[소속]` 없음

**소속 메서드** — `test/unit/test_party.gd`:
- [정상] `set_lord(hero)`/`clear_lord()` ([Party 시나리오](../entities/Party.md#테스트-시나리오))

**소속 모달** — `test/unit/test_lord_menu.gd`:
- [정상] `open(troop, [heroA, heroB])` → 후보 버튼 2개(영웅 이름) + [독립] 구성
- [정상] 후보 영웅 버튼 클릭 → `troop.lord == 그 영웅`, `changed` 방출
- [정상] 이미 소속인 영웅 버튼은 비활성; [독립]은 `has_lord`일 때만 활성
- [정상] [독립] 클릭 → `troop.lord == null`, `changed` 방출
- [경계] 후보가 빈 배열이면 후보 버튼 없음([독립]만, 소속 보유 시)

game.gd의 인접 영웅 계산(`_adjacent_player_heroes`)·`_can_manage_lord`·모달 배선은 씬 트리·터레인 의존이라 실제 실행으로 확인한다.

## 관련

- [Party (부대)](../entities/Party.md) — `kind`·`lord`·`set_lord`/`clear_lord`. [Parties (시작 편제)](parties.md) — 초기 소속.
- [Party Action Menu](party-action-menu.md) — `[소속]` 버튼. [Modal](modal.md) — 오버레이 기반. [Party Composition](party-composition.md) — 분할·병합(턴 소비 재편과 대비).
