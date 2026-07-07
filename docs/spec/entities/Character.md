# Entity: Character (주인공)

> 스크립트: `scenes/character/character.gd` (`extends Node2D`)
> 씬: `scenes/character/character.tscn`

맵 위에 표시되는 주인공. 능력치와 자원을 보유하며, 선택 시 강조 링이 표시된다.
현재 외형은 임시 플레이스홀더(원형 마커, 반지름 12px)로 `_draw()`에서 직접 그려진다.

## Properties

### 능력치 (Stats)

| 속성 | export 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 힘 | `strength` | 8 | |
| 지혜 | `wisdom` | 5 | |
| 민첩 | `agility` | 6 | |
| 매력 | `charm` | 10 | |
| 행운 | `luck` | 8 | |
| 이동력 | `movement` | 5 | 한 번에 이동 가능한 헥스 거리 (범위·이동 판정에 사용) |
| 시야 | `vision` | 5 | 전장의 안개를 밝히는 반경 |
| 지휘력 | `leadership` | 7 | |
| 화술 | `eloquence` | 9 | |
| 성실함 | `diligence` | 5 | |
| 예민함 | `sensitivity` | 8 | |

### 자원 (Resources)

| 속성 | export 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 히트포인트 | `hit_points` | 20 | |
| 스태미나 | `stamina` | 20 | |
| 사기 | `morale` | 20 | |

### 상태 (Runtime)

| 속성 | 변수 | 설명 |
| --- | --- | --- |
| 선택됨 | `selected` | 선택 상태. `set_selected(value)`로 변경 시 강조 링을 다시 그린다 |

## 동작

- `set_selected(bool)` — 선택 상태를 토글하고 `queue_redraw()`.
- `_draw()` — 선택 시 발밑 강조 링(노란색) + 그림자 + 몸통 원 + 외곽선을 그린다.

## 관련

- 이동력·시야는 [Selection & Movement](../features/selection-and-movement.md), [Fog of War](../features/fog-of-war.md)에서 사용.
- 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
