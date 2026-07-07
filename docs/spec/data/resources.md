# Data: Resources (자원)

게임에 존재하는 자원 목록. 현재는 [건물](../entities/Building.md) 인스턴스가 보유한다(초기값은 [건물 종류 카탈로그](buildings.md)에서 옴).

> **삽입 순서 = 캠프 메뉴 표시 순서** (`building.resources` Dictionary).

| 자원 | 캠프 초기 보유량 | 비고 |
| --- | --- | --- |
| 밀 | 50 | |
| 빵 | 20 | |
| 나무 | 20 | |
| 목재 | 20 | |
| 철 | 10 | |
| 철괴 | 10 | |

## 관련

- 표시: [Camp Menu](../features/camp-menu.md)
- 소비 로직(건축 등)은 Phase 2 미구현.
