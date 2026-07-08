# Data: Units (유닛·부대 카탈로그)

> 스크립트: `scenes/party/unit_types.gd` (`class_name UnitTypes`)

세력별 [부대](../entities/Party.md)와 그 멤버([Human](../entities/Human.md))를 **데이터로 정의**하는 카탈로그.
[BuildingTypes](buildings.md)·[Terrain](terrain.md)와 동일한 "GDScript 카탈로그" 패턴이다.
게임 시작 시 [game.gd](../features/parties.md)가 여기서 부대를 생성해 맵에 배치한다.

멤버 능력치는 기획 원본 `docs/table/세력/유닛.md`에서 옮긴 값이다.

## 상수

| 상수 | 값 | 설명 |
| --- | --- | --- |
| `PLAYER_ID` | `"azel"` | 플레이어 부대 id |
| `NPC_IDS` | `["qasim", "balthazar", "batur"]` | NPC 부대 id 목록 (표시 순서) |

## 카탈로그 (`CATALOG`)

부대 id → 스펙. 스펙 키: `party_name`, `faction`, `color`, `territory`, `commander`, `members`.

| id | 소속 | 세력(`faction`) | 색(`color`) | 영지(`territory`) | 부대(`party_name`) | 지휘관(`commander`) |
| --- | --- | --- | --- | --- | --- | --- |
| `azel` | 플레이어 | 푸른 왕국 | `(0.2, 0.3, 0.8)` 청 | 창천성 | 아젤 하르윈 부대 | 아젤 하르윈 |
| `qasim` | NPC | 사막 술탄국 | `(0.78, 0.28, 0.22)` 적 | — | 카심 이븐 라시드 부대 | 카심 이븐 라시드 |
| `balthazar` | NPC | 암흑 제국 | `(0.5, 0.24, 0.6)` 자 | — | 발타자르 부대 | 발타자르 |
| `batur` | NPC | 초원 칸국 | `(0.27, 0.55, 0.32)` 녹 | — | 바트르 칸 부대 | 바트르 칸 |

### 멤버 (`members`)

각 부대 멤버는 이름 + 능력치를 가진다. 능력치 키는 [Human](../entities/Human.md) 필드명과 동일하다.

| 부대 | 멤버 (첫 번째 = 지휘관) |
| --- | --- |
| `azel` | 아젤 하르윈 · 로엔 카스터 · 미라 벨포드 · 가레스 던 |
| `qasim` | 카심 이븐 라시드 · 자밀라 · 하산 알와히드 · 유수프 |
| `balthazar` | 발타자르 · 모르가나 · 드레이븐 · 카산드라 |
| `batur` | 바트르 칸 · 테무르 · 알탄 · 초로스 |

- 능력치 매핑: `strength`(힘) `wisdom`(지혜) `agility`(민첩) `charm`(매력) `luck`(행운) `leadership`(지휘력) `diligence`(성실함) `sensitivity`(예민함) `hit_points`(생명점) `stamina`(스태미나) `morale`(사기).
- **이동력·시야**: 유닛.md에 개별값이 없어 종족(인간) 기본값 `movement = 4`, `vision = 7`을 모든 멤버에 적용한다.
- 예시 앵커값 — 아젤 하르윈: `strength = 78`, `leadership = 88`, `morale = 90`.

## API

| 함수 | 반환 | 설명 |
| --- | --- | --- |
| `get_party(id) -> Dictionary` | 부대 스펙 | 없는 id면 빈 Dictionary |
| `make_members(id) -> Array` | [Human] 배열 | 스펙의 멤버들을 Human 객체로 생성(능력치 반영). 없는 id면 빈 배열 |
| `commander_name(id) -> String` | String | 스펙의 `commander` 이름 |

`make_members`는 [Human](../entities/Human.md)(RefCounted)만 생성하므로 씬 트리 없이 동작한다. [부대](../entities/Party.md)(Node2D) 인스턴스화·배치는 [game.gd](../features/parties.md)가 한다.

## 테스트 시나리오

`test/unit/test_unit_types.gd`.

- [정상] `PLAYER_ID == "azel"`, `NPC_IDS`는 3개(`qasim`·`balthazar`·`batur`)
- [정상] 모든 부대 스펙에 키 존재: `party_name`·`faction`·`color`·`commander`·`members`
- [정상] `azel` 스펙 — 세력 "푸른 왕국", 부대명 "아젤 하르윈 부대", 지휘관 "아젤 하르윈"
- [정상] `make_members("azel")`의 크기 4, 첫 멤버 이름 "아젤 하르윈"
- [정상] `make_members("azel")` 첫 멤버의 `strength == 78`, `leadership == 88`, `morale == 90` (유닛.md 매핑 확인)
- [정상] 모든 멤버 `movement == 4`, `vision == 7` (인간 기본값)
- [정상] `commander_name("qasim") == "카심 이븐 라시드"`
- [경계] 없는 id → `get_party` 빈 Dictionary, `make_members` 빈 배열
- [정상] 네 부대 모두 멤버 수 4

## 관련

- [Party (부대)](../entities/Party.md) · [Human (사람)](../entities/Human.md) · [Faction (세력)](../entities/Faction.md)
- 맵 배치·표시는 [Parties (부대 배치)](../features/parties.md).
