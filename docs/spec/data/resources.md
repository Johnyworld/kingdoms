# Data: Resources (자원)

게임에 존재하는 자원 목록. **[영지](../entities/Territory.md)가 모든 자원(인구·금 포함)을 보유**한다
(영지 초기값은 캠프 종류의 [카탈로그](buildings.md) `resources`에서 복사됨).

> **삽입 순서 = 캠프 메뉴 표시 순서** (`territory.resources` Dictionary).

| 자원 | 영지 초기 보유량 | 판매가(금) | 비고 |
| --- | --- | --- | --- |
| 인구 | 10 | — | 건물 건설/철거 시 소비·환산 (소비 로직은 Phase 2). **노동력** — 운반·판매 대상 아님 |
| 밀 | 50 | 1 | |
| 빵 | 20 | 3 | |
| 나무 | 20 | 1 | |
| 목재 | 20 | 2 | |
| 철 | 10 | 5 | |
| 철괴 | 10 | 12 | |
| 금 | 0 | — | **화폐**. [판매](../features/selling.md)로만 획득(생산 없음). 영지 금고 — 부대 화물로 운반 안 함, 판매 대상도 아님 |

## 자원 가치 카탈로그 (`ResourceTypes`)

> 스크립트: `scenes/resource/resource_types.gd` (`class_name ResourceTypes`). `ItemTypes`·`BuildingTypes`와 같은 GDScript 카탈로그 패턴.

- `VALUES: Dictionary` — 자원명 → **판매가(금 단위)**. 위 표의 판매가. `인구`·`금`은 미수록(판매 불가).
- `value(res_name) -> int` — 그 자원 1개의 판매가. 카탈로그에 없으면(인구·금·미등록) `0`.

## 테스트 시나리오

`test/unit/test_resource_types.gd`.

- [정상] `ResourceTypes.value("철괴") == 12`, `value("밀") == 1`, `value("목재") == 2`
- [예외] `value("인구") == 0`, `value("금") == 0`(판매 불가), 없는 자원 → `0`

## 관련

- 표시: [Camp Menu](../features/camp-menu.md). 판매: [Selling](../features/selling.md).
- 소비 로직(건축 등)은 Phase 2 미구현.
