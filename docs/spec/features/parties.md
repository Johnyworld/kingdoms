# Feature: Parties (부대 배치)

> 스크립트: `scenes/game/game.gd` (`_setup_parties`, `_populate_party`, `_place_party`) · `scenes/party/unit_types.gd`

게임 시작 시 [유닛 카탈로그](../data/units.md)에서 [부대](../entities/Party.md)를 생성해 맵에 배치한다.
이전에는 주인공 부대 하나를 `game.gd`에 하드코딩했으나, 이제 **데이터 기반**으로 플레이어 부대 + NPC 부대 3개를 만든다.

## 동작

- **플레이어 부대**(`UnitTypes.PLAYER_ID` = `azel`, 푸른 왕국)
  - 카탈로그에서 멤버(아젤 하르윈 등 5명, 궁수 1명 포함)를 생성하고 지휘관을 지정한다.
  - **시작 [투석기](siege-engines.md) 1대**를 실어 준다(`add_siege_unit` — 공성 시험/운용용 시작 장비). 첫 거점(마을회관)과 **NPC 거점(캠프)** 모두 **시작 [성벽](wall.md)**을 두른다(`wall_level=1`·만피 — 공성 시험용 스캐폴딩. 캠프 성벽은 정상 규칙상 불가하나 테스트로 강제).
  - 시작 지점(중앙 캠프 아래) 칸에 배치한다.
  - 토큰 색은 기본 금색(플레이어 표시). **선택·이동·AI·부대 일람** 대상은 플레이어 부대뿐이다.
- **NPC 부대**(`UnitTypes.NPC_IDS` = 사막 술탄국·암흑 제국·초원 칸국)
  - 각 세력 색으로 토큰을 그린다([Party](../entities/Party.md) `token_color`).
  - 시작 지점 주변에 배치한다.
  - **기존 시스템 편입**:
    - **안개 반영** — 플레이어의 현재 시야 안일 때만 토큰을 보이고, 시야 밖이면 숨긴다. NPC는 플레이어 시야를 밝히지 않는다. → [Fog of War](fog-of-war.md).
    - **턴 리셋** — 턴 종료 시 NPC 부대의 이동 상태(`reset_turn`)도 리셋 대상에 포함한다(다음 단계 이동 AI 대비). → [Turn](turn.md).
    - **부대 일람 제외** — 일람은 우리 세력 부대만 표시하므로 NPC는 등록하지 않는다.
    - **정보 패널** — 보이는 NPC를 클릭하면 우측 상단에 정보를 표시한다(선택은 없음). → [Party Info](party-info.md).
    - **이동** — 턴 종료 시 각 NPC가 이동력만큼 가장 먼 칸으로 무작위 이동한다. → [NPC Movement](npc-movement.md).
  - **미구현** — 목표 지향 AI·전투·유닛 충돌·NPC 영지. *(다음 단계)*

## 세력 구성

플레이어 세력·영지는 카탈로그의 `azel` 스펙을 따른다 — 세력 "푸른 왕국", 영지 "창천성".
(이전의 "프랑스"/"파리"를 대체.) NPC 세력도 각자 수도 영지·거점(캠프)을 가진다 → [NPC Bases](npc-bases.md).

## 배치 위치 (초기)

시작 지점(맵 중앙) 기준 오프셋 — 초기 시야 안에 들도록 임시 배치한다.

| 부대 | 오프셋 (칸) |
| --- | --- |
| 플레이어(아젤) | `(0, +3)` (캠프 아래) |
| 사막 술탄국(카심) | `(+5, 0)` |
| 암흑 제국(발타자르) | `(0, -5)` |
| 초원 칸국(바트르 칸) | `(-7, +1)` |

## 테스트

- 데이터 계층([UnitTypes](../data/units.md))·[Party](../entities/Party.md) `token_color`는 단위 테스트로 검증한다.
- NPC 안개 표시의 판정 규칙(`fog.is_cell_visible`)은 `test/unit/test_fog.gd`로 검증한다.
- `game.gd`의 인스턴스화·배치·NPC `visible` 토글·턴 리셋 편입(씬 트리·터레인 의존)은 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Party (부대)](../entities/Party.md) · [Human (사람)](../entities/Human.md) · [Faction (세력)](../entities/Faction.md) · [유닛 카탈로그](../data/units.md)
- 선택·이동은 [Selection & Movement](selection-and-movement.md), 안개는 [Fog of War](fog-of-war.md), 부대 일람은 [Party Roster](party-roster.md).
