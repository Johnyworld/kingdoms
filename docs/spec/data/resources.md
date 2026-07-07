# Data: Resources (자원)

게임에 존재하는 자원 목록. **[영지](../entities/Territory.md)가 모든 자원(인구 포함)을 보유**한다
(영지 초기값은 캠프 종류의 [카탈로그](buildings.md) `resources`에서 복사됨).

> **삽입 순서 = 캠프 메뉴 표시 순서** (`territory.resources` Dictionary).

| 자원 | 영지 초기 보유량 | 비고 |
| --- | --- | --- |
| 인구 | 10 | 건물 건설/철거 시 소비·환산 (소비 로직은 Phase 2) |
| 밀 | 50 | |
| 빵 | 20 | |
| 나무 | 20 | |
| 목재 | 20 | |
| 철 | 10 | |
| 철괴 | 10 | |

## 관련

- 표시: [Camp Menu](../features/camp-menu.md)
- 소비 로직(건축 등)은 Phase 2 미구현.
