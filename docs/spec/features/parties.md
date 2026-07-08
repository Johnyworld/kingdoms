# Feature: Parties (부대 배치)

> 스크립트: `scenes/game/game.gd` (`_setup_parties`, `_populate_party`, `_place_party`) · `scenes/party/unit_types.gd`

게임 시작 시 [유닛 카탈로그](../data/units.md)에서 [부대](../entities/Party.md)를 생성해 맵에 배치한다.
이전에는 주인공 부대 하나를 `game.gd`에 하드코딩했으나, 이제 **데이터 기반**으로 플레이어 부대 + NPC 부대 3개를 만든다.

## 동작

- **플레이어 부대**(`UnitTypes.PLAYER_ID` = `azel`, 푸른 왕국)
  - 카탈로그에서 멤버(아젤 하르윈 등 4명)를 생성하고 지휘관을 지정한다.
  - 시작 지점(중앙 캠프 아래) 칸에 배치한다.
  - 토큰 색은 기본 금색(플레이어 표시). 선택·이동·턴 리셋·부대 일람·안개 계산 대상은 **플레이어 부대뿐**이다.
- **NPC 부대**(`UnitTypes.NPC_IDS` = 사막 술탄국·암흑 제국·초원 칸국)
  - 각 세력 색으로 토큰을 그린다([Party](../entities/Party.md) `token_color`).
  - 시작 지점 주변(초기 시야 안)에 배치해 화면에 보이게 한다.
  - **이번 단계에선 표시만** — 이동·선택·AI·턴 리셋·안개 반영·부대 일람 등록 없음. *(NPC 행동은 미구현)*

## 세력 구성

플레이어 세력·영지는 카탈로그의 `azel` 스펙을 따른다 — 세력 "푸른 왕국", 영지 "창천성".
(이전의 "프랑스"/"파리"를 대체.) NPC 부대는 소속 세력만 있고 영지·건물은 아직 없다. *(NPC 영지 미구현)*

## 배치 위치 (초기)

시작 지점(맵 중앙) 기준 오프셋 — 초기 시야 안에 들도록 임시 배치한다.

| 부대 | 오프셋 (칸) |
| --- | --- |
| 플레이어(아젤) | `(0, +3)` (캠프 아래) |
| 사막 술탄국(카심) | `(+5, 0)` |
| 암흑 제국(발타자르) | `(0, -5)` |
| 초원 칸국(바트르 칸) | `(-5, +1)` |

## 테스트

- 데이터 계층([UnitTypes](../data/units.md))·[Party](../entities/Party.md) `token_color`는 단위 테스트로 검증한다.
- `game.gd`의 인스턴스화·배치(씬 트리·터레인 의존)는 실제 실행으로 확인한다. *(game.gd 통합 테스트는 기존 관례상 두지 않음)*

## 관련

- [Party (부대)](../entities/Party.md) · [Human (사람)](../entities/Human.md) · [Faction (세력)](../entities/Faction.md) · [유닛 카탈로그](../data/units.md)
- 선택·이동은 [Selection & Movement](selection-and-movement.md), 안개는 [Fog of War](fog-of-war.md), 부대 일람은 [Party Roster](party-roster.md).
