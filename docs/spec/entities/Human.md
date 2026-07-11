# Entity: Human (사람)

> 스크립트: `scenes/human/human.gd` (`class_name Human extends RefCounted`)

능력치와 자원을 보유하는 **순수 데이터** 사람. [부대(Party)](Party.md)의 멤버로 존재한다.
**주인공은 이 Human의 객체**이자 주인공 부대의 멤버다 (`human_name = "아젤 하르윈"`). 부대 멤버는 [유닛 카탈로그](../data/units.md)에서 생성된다.

시각 요소가 없는 데이터 엔티티라 씬(`.tscn`) 없이 스크립트만 둔다([Faction](Faction.md)·[Territory](Territory.md)와 동일 패턴).
맵 위 표시·선택·이동은 개별 Human이 아니라 이들을 거느린 [부대(Party)](Party.md)가 담당한다.

## Properties

### 정체 (Identity)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 이름 | `human_name` | `""` | 사람의 이름. `_init(p_name)`로 설정 가능. 주인공은 `"아젤 하르윈"` |

### 능력치 (Stats)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 힘 | `strength` | 8 | |
| 지혜 | `wisdom` | 5 | |
| 민첩 | `agility` | 6 | |
| 매력 | `charm` | 10 | |
| 행운 | `luck` | 8 | |
| 이동력 | `movement` | 3 | 부대 이동력 계산에 쓰인다 — [부대](Party.md) `movement()`는 멤버 중 **최소값** |
| 시야 | `vision` | 5 | 부대 시야 계산에 쓰인다 — [부대](Party.md) `vision()`은 멤버 중 **최대값** |
| 지휘력 | `leadership` | 7 | |
| 화술 | `eloquence` | 9 | |
| 성실함 | `diligence` | 5 | |
| 예민함 | `sensitivity` | 8 | |

### 자원 (Resources)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 히트포인트(현재) | `hit_points` | 20 | 현재 생명점. 전투에서 깎이고 **전투 후에도 지속**된다([Battle](../features/battle.md)). 유닛 생성 시 `max_hp()`로 채운다(시작 풀피) |
| 전투 레벨 | `level` | 1 | `max_hp()` 계산에 쓰는 배수. 경험치·성장은 `미구현`(기본 1 고정) |
| 스태미나(현재) | `stamina` | 20 | 유닛 생성 시 `max_stamina`로 채움. **소모 시스템은 `미구현`**([행동 메뉴](../features/party-action-menu.md) 휴식/경계로 회복만) |
| 최대 스태미나 | `max_stamina` | 20 | 스태미나 상한. 유닛 생성 시 `stamina`와 같게 설정 |
| 사기 | `morale` | 20 | |
| 경계 버프 | `alert` | `false` | 참이면 전투 공격력·방어력 ×1.2([Combat](../features/combat.md)). [경계](../features/party-action-menu.md) 선택 시 부여, 적 턴 종료 후 해제 |

### 계산·행동 (Computed / Actions)

| 함수 | 설명 |
| --- | --- |
| `max_hp()` | `BASE_HIT_POINTS(40) + floor(힘/10) × level` — 최대 생명점(상한). 민첩 등 다른 스탯 기여 `미구현` |
| `apply_rest()` | 휴식 — `hit_points`·`stamina`를 각각 최대의 **25%(반올림)** 만큼 회복(상한 clamp) |
| `apply_alert()` | 경계 — `stamina`를 최대의 **10%(반올림)** 회복 + `alert = true` |

### 장비 (Equipment)

| 속성 | 변수 | 초기값 | 설명 |
| --- | --- | --- | --- |
| 무기 | `weapons` | `[]` | [ItemTypes](../data/items.md) 무기 id **목록(2~3개)**. **첫 원소 = 주무기**. 근접 전투는 주무기, 원거리 전투는 목록 중 원거리 무기(활 등)를 쓴다. 월드맵 공격거리는 목록 중 최대. 무게는 전부 합산(회피 페널티). `[]`=맨몸 |
| 방어구 | `armor` | `[]` | 착용 방어구 id 목록(최대 4). DF=방어력 합, 상성 분류=방어력 최대 조각. `[]`=맨몸 |
| 방패 | `shield` | `""` | [ItemTypes](../data/items.md) 방패 id. DF에 방어력 합산 + 막기 확률. `""`=없음. 검+방패를 들고도 활을 보조무기로 가질 수 있다 |

슬롯 상한(상수): `MAX_WEAPONS`=`3`(무기), `MAX_ARMOR`=`4`(방어구), 방패는 1개(단일 슬롯). [장비 관리](../features/equipment.md)의 장착이 이 상한을 지킨다.

## 동작

- `_init(p_name := "")` — 이름을 받아 생성한다. 능력치·자원은 위 초기값으로 시작.

## 관련

- 맵 표시·선택·턴당 1회 이동·마커 그리기는 [부대(Party)](Party.md)가 담당한다.
- 이동력·시야는 부대의 유도 능력치([Party](Party.md) `movement()`/`vision()`) 계산에 쓰이고, 최종적으로 [Selection & Movement](../features/selection-and-movement.md)·[Fog of War](../features/fog-of-war.md)에서 사용된다.
- 능력치 정의는 [data/stats.md](../data/stats.md) 참고.
