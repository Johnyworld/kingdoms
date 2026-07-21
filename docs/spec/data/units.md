# Data: Units (유닛·부대 카탈로그)

> 스크립트: `scenes/party/unit_types.gd` (`class_name UnitTypes`)

세력별 [부대](../entities/Party.md)를 **데이터로 정의**하는 카탈로그.
[BuildingTypes](buildings.md)·[Terrain](terrain.md)와 동일한 "GDScript 카탈로그" 패턴이다.
게임 시작 시 [game.gd](../features/parties.md)가 여기서 부대를 생성해 맵에 배치한다.

**순수 class+count 모델**(M4-C) — 부대는 "아키타입 + 병력수(`soldiers`)"다. 개별 병사(Human) 객체·스탯은 없다. 전투·이동·사거리는 병종 lang 클래스([GameUnits](../features/lang-battle.md))가 결정한다.

**랑그릿사식 부대 이분화** — 부대는 두 종류다([Party](../entities/Party.md) `kind`):

- **영웅부대**(`KIND_HERO`) — 지휘관(영웅) **1명**이 단독으로 싸운다. 세력마다 영웅 **4명**을 보유하며, 각 영웅이 하나의 영웅부대가 된다. 병력수 = 클래스 HP(`GameUnits.max_hp("hero")`).
- **일반부대**(`KIND_TROOP`) — **병사 [TROOP_SIZE](#상수)(10)명**(병력수)으로 구성된다. 병종 아키타입(경보병·경궁병)으로 정의되며 **세력 공용**이다(색만 세력별). (전투·사거리는 병종 lang 클래스가 결정.)

## 상수

| 상수 | 값 | 설명 |
| --- | --- | --- |
| `PLAYER_ID` | `"azel"` | 플레이어 **세력** id |
| `NPC_IDS` | `["qasim", "balthazar", "batur"]` | NPC 세력 id 목록 (표시 순서) |
| `FACTION_IDS` | `["azel", "qasim", "balthazar", "batur"]` | 전 세력 id (플레이어 + NPC) |
| `TROOP_SIZE` | `10` | 일반부대 1개의 병사 수 |
| `HEROES_PER_FACTION` | `4` | 세력당 영웅 수 |

각 영웅은 [시작 편제](../features/parties.md)에서 **경보병 2 + 경궁병 1**(부하 3부대)을 거느린다 → 세력당 영웅 4 + 부하 12 = **16부대**.

## 세력 카탈로그 (`CATALOG`)

세력 id → 세력 스펙. 스펙 키: `faction`(세력명)·`color`(토큰 색)·`territory`(수도 영지)·`heroes`(영웅 4명 **이름 문자열 배열**, 첫 항목 = 세력 지휘관). (개별 능력치·장비 키는 순수 class+count 전환(M4-C)·장비 계층 삭제(M4-B)로 제거.)

| id | 소속 | 세력(`faction`) | 색(`color`) | 영지(`territory`) |
| --- | --- | --- | --- | --- |
| `azel` | 플레이어 | 푸른 왕국 | `(0.2, 0.3, 0.8)` 청 | 창천성 |
| `qasim` | NPC | 사막 술탄국 | `(0.78, 0.28, 0.22)` 적 | 알사바흐 |
| `balthazar` | NPC | 암흑 제국 | `(0.5, 0.24, 0.6)` 자 | 흑요요새 |
| `batur` | NPC | 초원 칸국 | `(0.27, 0.55, 0.32)` 녹 | 텡그리 언덕 |

### 영웅 (`heroes`, 세력당 4명)

`heroes`는 **영웅 이름 문자열 배열**이다(능력치 없음 — 전투는 lang 클래스가 결정).

| 세력 | 영웅 4명 (첫 번째 = 세력 지휘관) |
| --- | --- |
| `azel` | 아젤 하르윈 · 로엔 카스터 · 미라 벨포드 · 가레스 던 |
| `qasim` | 카심 이븐 라시드 · 자밀라 · 하산 알와히드 · 유수프 |
| `balthazar` | 발타자르 · 모르가나 · 드레이븐 · 카산드라 |
| `batur` | 바트르 칸 · 테무르 · 알탄 · 초로스 |

- **엘윈 사수 제거**: 이전 아젤 부대의 궁수 "엘윈 사수"는 **경궁병 병종**으로 대체되어 영웅 목록에서 빠졌다(세력당 영웅 4명 균일).
- 각 영웅부대: `party_name = "{이름} 부대"`, `kind = KIND_HERO`, `commander_name =` 영웅 이름, 병력수 = 지휘관 클래스 HP(`GameUnits.max_hp("hero")`).
- **전투 우위**: 영웅의 전투 우위는 지휘관 클래스(classId 4)에서 온다([Lang Battle](../features/lang-battle.md)). 개별 능력치(힘·행운·민첩 등)와 그 배율은 순수 class+count 전환(M4-C)으로 제거됐다 — 영웅은 클래스·HP만으로 구분된다.

## 병종 아키타입 (`TROOPS`, 세력 공용)

일반부대 병종. id → 스펙(`name`만 — 전투 스탯은 lang 클래스). 한 부대는 이 아키타입으로 **10명**(병력수) 생성된다. 이 **archetype id는 부대에 [`Party.troop_type`](../entities/Party.md#정체-identity)으로 저장**되어 [병합 가능 판정](../features/party-composition.md)(같은 병종끼리만)의 기준이 된다. 전투·이동·근접/원거리·공격거리는 병종 lang 클래스(GameUnits 아키타입)가 결정한다.

| 병종 | id | 성격 |
| --- | --- | --- |
| 경보병 | `light_infantry` | 근접 |
| 경궁병 | `light_archer` | 원거리(부대 [공격거리](../entities/Party.md) 3) |

- 개별 능력치(str·agi·luck 등)는 순수 class+count 전환(M4-C)으로 제거됐다 — 병종은 lang 클래스 스탯([GameUnits](../features/lang-battle.md))으로만 구분된다.

## API

| 함수 | 반환 | 설명 |
| --- | --- | --- |
| `get_faction(id) -> Dictionary` | 세력 스펙 | 없는 id면 빈 Dictionary |
| `hero_name(faction, index) -> String` | String | 세력의 `index`번째 영웅 이름. 범위 밖이면 빈 문자열 |
| `hero_party_name(faction, index) -> String` | String | `"{영웅 이름} 부대"`. 범위 밖이면 빈 문자열 |
| `troop_name(archetype) -> String` | String | 병종 표시 이름(경보병/경궁병). 없으면 빈 문자열 |

카탈로그는 **이름·상수만** 제공한다(개별 Human을 만들지 않는다 — 순수 class+count). [부대](../entities/Party.md)(Node2D) 인스턴스화·배치·`kind`/`lord`/`soldiers`/`commander_name` 설정은 [game.gd](../features/parties.md)가 한다(영웅부대 `soldiers = GameUnits.max_hp("hero")`, 일반부대 `soldiers = TROOP_SIZE`).

## 테스트 시나리오

`test/unit/test_unit_types.gd`.

- [정상] `PLAYER_ID == "azel"`, `NPC_IDS`는 3개, `FACTION_IDS`는 4개, `TROOP_SIZE == 10`, `HEROES_PER_FACTION == 4`
- [정상] 모든 세력 스펙에 키 존재: `faction`·`color`·`territory`·`heroes`(4명)
- [정상] `get_faction("azel")` — 세력 "푸른 왕국", 영지 "창천성"
- [정상] `hero_name("azel", 0) == "아젤 하르윈"`(세력 지휘관)
- [정상] `heroes["azel"] == ["아젤 하르윈", "로엔 카스터", "미라 벨포드", "가레스 던"]`(**엘윈 사수 없음**, 4명)
- [정상] `hero_party_name("azel", 0) == "아젤 하르윈 부대"`
- [경계] 없는 세력 id → `get_faction` 빈 Dictionary, `hero_name == ""`; 범위 밖 index → `hero_name == ""`, `hero_party_name == ""`
- [경계] 없는 병종 id → `troop_name` 빈 문자열
- [정상] `troop_name("light_infantry") == "경보병"`, `troop_name("light_archer") == "경궁병"`

## 관련

- [Party (부대)](../entities/Party.md) · [Faction (세력)](../entities/Faction.md) · 전투·클래스는 [Lang Battle](../features/lang-battle.md)(GameUnits)
- 맵 배치·표시·`kind`/`lord` 설정은 [Parties (부대 배치)](../features/parties.md).
