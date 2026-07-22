# Data: Factions (세력·영웅 카탈로그)

> 스크립트: `scenes/party/faction_catalog.gd` (`class_name FactionCatalog`)
> 데이터: `res://data/factions.csv`(세력) · `res://data/heroes.csv`(영웅, faction FK)

세력과 영웅을 **데이터로 정의**하는 카탈로그. 병종 아키타입·전투 스탯은 [UnitTypes](unit-types.md, `unit_types.csv`), 맵에 놓이는 초기 유닛은 [UnitSpawns](unit-spawns.md, `unit_spawns.csv`)가 담당한다.
데이터는 `res://data/`의 **CSV**에서 lazy-load 한다([UnitTypes]·[UnitSpawns]와 동일 패턴). `FactionCatalog`는 정적 API로만 노출하고 내부에서 CSV를 읽는다(호출부는 API·상수만 사용). CSV는 스프레드시트로 표 편집이 가능하며, `importer="keep"`로 Godot 번역 자동임포트를 막는다.
게임 시작 시 [game.gd](../features/parties.md)가 [UnitSpawns](unit-spawns.md)의 배치대로 [부대](../entities/Party.md)를 생성하며, 이름·색·상수는 여기서 가져온다.

**순수 class+count 모델**(M4-C) — 부대는 "아키타입 + 병력수(`soldiers`)"다. 개별 병사(Human) 객체·스탯은 없다. 전투·이동·사거리는 병종 아키타입([UnitTypes](unit-types.md), unit_types.csv 인라인 스탯)이 결정한다.

**랑그릿사식 부대 이분화** — 부대는 두 종류다([Party](../entities/Party.md) `kind`):

- **영웅부대**(`KIND_HERO`) — 지휘관(영웅) **1명**이 단독으로 싸운다. 세력마다 영웅 **4명**을 보유하며, 각 영웅이 하나의 영웅부대가 된다. 병력수 = 클래스 HP(`UnitTypes.max_hp("hero")`).
- **일반부대**(`KIND_TROOP`) — **병사 [TROOP_SIZE](#상수)(10)명**(병력수)으로 구성된다. 병종 아키타입(경보병·경궁병)으로 정의되며 **세력 공용**이다(색만 세력별). (전투·사거리는 병종 lang 클래스가 결정.)

## 상수

| 상수 | 값 | 설명 |
| --- | --- | --- |
| `PLAYER_ID` | `"azel"` | 플레이어 **세력** id (코드 상수) |
| `NPC_IDS` | `["qasim", "balthazar", "batur"]` | NPC 세력 id 목록 — `factions.csv` 순서에서 파생(플레이어 제외) |
| `FACTION_IDS` | `["azel", "qasim", "balthazar", "batur"]` | 전 세력 id — `factions.csv` 행 순서(표시 순서) |
| `TROOP_SIZE` | `10` | 일반부대 1개의 병사 수 (코드 상수) |
| `HEROES_PER_FACTION` | `4` | 세력당 영웅 수 (코드 상수) |

`PLAYER_ID`·`TROOP_SIZE`·`HEROES_PER_FACTION`은 게임 규칙이라 코드 상수로 둔다. `FACTION_IDS`·`NPC_IDS`는 `factions.csv`에서 파생되어 클래스 로드 시(`_static_init`) 채워진다.

## 세력 카탈로그 (`factions.csv`)

`res://data/factions.csv` — 세력 id → 세력 스펙. 컬럼: `id`·`name`(세력명)·`color`(토큰 색, **hex 문자열** → `Color.html`로 복원)·`territory`(수도 영지)·`start_corner`(시작 모서리 SW/NW/NE/SE). `get_faction(id)`는 여기에 `heroes`(영웅 이름 배열, heroes.csv FK join) 키를 더해 반환한다. (개별 능력치·장비 키는 순수 class+count 전환(M4-C)·장비 계층 삭제(M4-B)로 제거.)

| id | 소속 | 세력(`name`) | 색(`color`) | 영지(`territory`) | 시작(`start_corner`) |
| --- | --- | --- | --- | --- | --- |
| `azel` | 플레이어 | 푸른 왕국 | `#334DCC` 청 | 창천성 | SW 남서 |
| `qasim` | NPC | 사막 술탄국 | `#C74738` 적 | 알사바흐 | SE 남동 |
| `balthazar` | NPC | 암흑 제국 | `#803D99` 자 | 흑요요새 | NE 북동 |
| `batur` | NPC | 초원 칸국 | `#458C52` 녹 | 텡그리 언덕 | NW 북서 |

`start_corner`는 **거점 건물**(마을회관·캠프) 배치의 데이터다 — 실제 좌표는 `game.gd`의 `corner_cell(corner, map_w, map_h, margin)`가 맵 크기·`MARGIN`으로 계산한다([NPC Bases](../features/npc-bases.md) · [Map & Camera](../features/map-and-camera.md)). **초기 유닛 배치**는 별도로 [UnitSpawns](unit-spawns.md)(unit_spawns.csv 절대좌표)가 정한다.

### 영웅 (`heroes.csv`, 세력당 4명)

`res://data/heroes.csv` — 컬럼: `id`·`name`(영웅 이름)·`faction`(소속 세력 **외래키** → `factions.csv`). **행 순서가 세력별 영웅 순서**(첫 행 = 세력 지휘관)다. `get_faction(id)["heroes"]`는 이 FK join으로 만든 **이름 문자열 배열**이다(능력치 없음 — 전투는 lang 클래스가 결정). 존재하지 않는 `faction`을 참조하면 로드 시 `push_error`로 경고한다(참조 무결성).

| 세력 | 영웅 4명 (첫 번째 = 세력 지휘관) |
| --- | --- |
| `azel` | 아젤 하르윈 · 로엔 카스터 · 미라 벨포드 · 가레스 던 |
| `qasim` | 카심 이븐 라시드 · 자밀라 · 하산 알와히드 · 유수프 |
| `balthazar` | 발타자르 · 모르가나 · 드레이븐 · 카산드라 |
| `batur` | 바트르 칸 · 테무르 · 알탄 · 초로스 |

- 각 영웅부대: `party_name = "{이름} 부대"`, `kind = KIND_HERO`, `commander_name =` 영웅 이름, 병력수 = 지휘관 클래스 HP(`UnitTypes.max_hp("hero")`).
- **전투 우위**: 영웅의 전투 우위는 `hero` 아키타입 스탯(at27/df24, cmd_range4)에서 온다([Lang Battle](../features/lang-battle.md)). 개별 능력치와 그 배율은 순수 class+count 전환(M4-C)으로 제거됐다 — 영웅은 아키타입·HP만으로 구분된다.
- 영웅 스폰의 **등장 순서**([UnitSpawns](unit-spawns.md) 행 순서)가 세력별 hero index(0=지휘관)를 정한다 — `hero_name(faction, i)`로 이름을 붙인다.

## API

| 함수 | 반환 | 설명 |
| --- | --- | --- |
| `get_faction(id) -> Dictionary` | 세력 스펙 | 없는 id면 빈 Dictionary |
| `hero_name(faction, index) -> String` | String | 세력의 `index`번째 영웅 이름. 범위 밖이면 빈 문자열 |
| `hero_party_name(faction, index) -> String` | String | `"{영웅 이름} 부대"`. 범위 밖이면 빈 문자열 |
| `troop_name(archetype) -> String` | String | 병종 표시 이름(경보병/경궁병) — `UnitTypes.display_name`에 위임. 없으면 빈 문자열 |

카탈로그는 **이름·상수만** 제공한다(개별 Human을 만들지 않는다 — 순수 class+count). [부대](../entities/Party.md)(Node2D) 인스턴스화·배치·`kind`/`lord`/`soldiers`/`commander_name` 설정은 [game.gd](../features/parties.md)가 [UnitSpawns](unit-spawns.md) 데이터대로 한다.

## 테스트 시나리오

`test/unit/test_faction_catalog.gd` · `test/unit/test_game_placement.gd`.

- [정상] `PLAYER_ID == "azel"`, `NPC_IDS`는 3개, `FACTION_IDS`는 4개, `TROOP_SIZE == 10`, `HEROES_PER_FACTION == 4`
- [정상] 모든 세력 스펙에 키 존재: `faction`·`color`·`territory`·`start_corner`·`heroes`(4명)
- [정상] `start_corner` — azel=SW, qasim=SE, balthazar=NE, batur=NW
- [정상] `color` — hex(`#334DCC`)에서 `Color.html`로 복원됨
- [정상] `get_faction("azel")` — 세력 "푸른 왕국", 영지 "창천성"
- [정상] `hero_name("azel", 0) == "아젤 하르윈"`(세력 지휘관); `heroes["azel"] == [아젤 하르윈, 로엔 카스터, 미라 벨포드, 가레스 던]`(4명)
- [정상] **FK 무결성** — 모든 세력이 heroes.csv join으로 영웅 4명 채워짐
- [정상] `hero_party_name("azel", 0) == "아젤 하르윈 부대"`; `troop_name("light_infantry") == "경보병"`
- [경계] 없는 세력 id → `get_faction` 빈 Dictionary, `hero_name == ""`; 범위 밖 index → 빈 문자열; 없는 병종 → `troop_name` 빈 문자열
- [정상] `corner_cell` — SW/NW/NE/SE → `(10,39)`/`(10,10)`/`(39,10)`/`(39,39)`(50×50·MARGIN10), 맵/마진 변화에 스케일, 미지 모서리 → SW

## 관련

- [Unit Types (병종 아키타입)](unit-types.md) · [Unit Spawns (초기 배치)](unit-spawns.md) · [Party (부대)](../entities/Party.md) · [Faction (세력)](../entities/Faction.md)
- 맵 배치·`kind`/`lord` 설정은 [Parties (부대 배치)](../features/parties.md).
