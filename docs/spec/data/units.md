# Data: Units (유닛·부대 카탈로그)

> 스크립트: `scenes/party/unit_types.gd` (`class_name UnitTypes`)

세력별 [부대](../entities/Party.md)와 그 멤버([Human](../entities/Human.md))를 **데이터로 정의**하는 카탈로그.
[BuildingTypes](buildings.md)·[Terrain](terrain.md)와 동일한 "GDScript 카탈로그" 패턴이다.
게임 시작 시 [game.gd](../features/parties.md)가 여기서 부대를 생성해 맵에 배치한다.

**랑그릿사식 부대 이분화** — 부대는 두 종류다([Party](../entities/Party.md) `kind`):

- **영웅부대**(`KIND_HERO`) — 지휘관 **1명**이 단독으로 싸운다. 세력마다 영웅 **4명**을 보유하며, 각 영웅이 하나의 영웅부대가 된다. 능력치는 기획 원본 `docs/table/세력/유닛.md`에서 옮긴 값이다.
- **일반부대**(`KIND_TROOP`) — **동일 능력치 병사 [TROOP_SIZE](#상수)(10)명**으로 구성된다. 병종 아키타입(경보병·경궁병)으로 정의되며 **세력 공용**이다(색만 세력별). 각 부대의 병사는 모두 같은 능력치·장비를 가진다.

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

세력 id → 세력 스펙. 스펙 키: `faction`(세력명)·`color`(토큰 색)·`territory`(수도 영지)·기본 장비(`weapons`·`armor`·`shield`)·`heroes`(영웅 4명 dict 배열).

| id | 소속 | 세력(`faction`) | 색(`color`) | 영지(`territory`) | 기본 장비 |
| --- | --- | --- | --- | --- | --- |
| `azel` | 플레이어 | 푸른 왕국 | `(0.2, 0.3, 0.8)` 청 | 창천성 | 장검+가죽세트+라운드실드 |
| `qasim` | NPC | 사막 술탄국 | `(0.78, 0.28, 0.22)` 적 | 알사바흐 | 곡도+가죽+버클러 |
| `balthazar` | NPC | 암흑 제국 | `(0.5, 0.24, 0.6)` 자 | 흑요요새 | 완드(마법)+천(방패 없음) |
| `batur` | NPC | 초원 칸국 | `(0.27, 0.55, 0.32)` 녹 | 텡그리 언덕 | 전투도끼+사슬+타워실드 |

### 영웅 (`heroes`, 세력당 4명)

각 영웅 dict는 이름 + 능력치(+ 개별 장비 override)를 가진다. 능력치 키는 [Human](../entities/Human.md) 필드명과 동일하다.

| 세력 | 영웅 4명 (첫 번째 = 세력 지휘관) |
| --- | --- |
| `azel` | 아젤 하르윈 · 로엔 카스터 · 미라 벨포드 · 가레스 던 |
| `qasim` | 카심 이븐 라시드 · 자밀라 · 하산 알와히드 · 유수프 |
| `balthazar` | 발타자르 · 모르가나 · 드레이븐 · 카산드라 |
| `batur` | 바트르 칸 · 테무르 · 알탄 · 초로스 |

- **엘윈 사수 제거**: 이전 아젤 부대의 궁수 멤버 "엘윈 사수"는 **경궁병 병종**으로 대체되어 영웅 목록에서 빠졌다(세력당 영웅 4명 균일).
- 각 영웅부대: `party_name = "{이름} 부대"`, `kind = KIND_HERO`, 멤버 **1명**(그 영웅).
- 능력치 매핑: `strength`(힘) `wisdom`(지혜) `agility`(민첩) `charm`(매력) `luck`(행운) `leadership`(지휘력) `diligence`(성실함) `sensitivity`(예민함) `stamina`(스태미나) `morale`(사기). 생명점은 `max_hp()`로 계산해 채운다.
- **이동력·시야**: 유닛.md에 개별값이 없어 종족(인간) 기본값 `movement = 4`, `vision = 7`을 모든 유닛에 적용한다.
- **멤버별 장비 override**: 영웅 dict에 `weapons`/`armor`/`shield`가 있으면 세력 기본값을 **덮어쓴다**. 예: 아젤 하르윈은 `weapons: ["longsword", "bow"]`(검+보조 활 — 근접은 장검, 원거리는 활 반격), 자밀라는 `weapons: ["scimitar", "javelin"]`(곡도+투창).
- 예시 앵커값(카탈로그 원본, 배율 적용 전) — 아젤 하르윈: `strength = 78`, `leadership = 88`, `morale = 90`.
- **영웅 전투 배율(회피형 반신)**: `make_hero`/`make_heroes`가 영웅 Human 생성 시 **전투 능력치에 배율을 적용**한다 — `힘 × HERO_STR_MULT(3)`, `행운 × HERO_LUCK_MULT(3)`, `민첩 × HERO_AGI_MULT(2.5)`(내림). **지휘력·지혜·매력 등 비전투 스탯과 장비는 그대로**(지휘범위 폭증 등 전략 부작용 방지). 배율 적용 후 `hit_points = max_hp()`로 재계산해 풀피. 결과: 영웅은 얇은 보병과 달리 **HP 100+·회피율 매우 높음(가끔만 맞음)·치명 잦음·공격간격 최소치**라, 수적 열세에서도 다수를 정리한다. 병종(`make_troop`)에는 배율을 적용하지 않는다. 세부 수치는 추후 튜닝.

## 병종 아키타입 (`TROOPS`, 세력 공용)

일반부대 병종. id → 스펙(`name`·`weapons`·`armor`·`shield`·능력치). 한 부대는 이 아키타입으로 **10명 동일** 생성된다. 이 **archetype id는 부대에 [`Party.troop_type`](../entities/Party.md#정체-identity)으로 저장**되어 [병합 가능 판정](../features/party-composition.md)(같은 병종끼리만)의 기준이 된다.

| 병종 | id | 무기 | 방어구 | 방패 | 주요 능력치 |
| --- | --- | --- | --- | --- | --- |
| 경보병 | `light_infantry` | `["spear"]`(장창·근접·리치 2) | `[leather_helm, leather_armor]` | `""`(없음) | str 46 · agi 55 · luck 48 · morale 58 |
| 경궁병 | `light_archer` | `["bow"]`(활·공격거리 3) | `[leather_helm, leather_armor]` | `""`(없음) | str 46 · agi 62 · luck 52 · morale 55 |

- 공통 능력치: `wisdom 40` · `charm 40` · `leadership 20` · `diligence 55` · `sensitivity 40` · `stamina 40`, `movement 4` · `vision 7`. 영웅보다 약한 보통 병사 수준(기존 소집병 대체).
- 경보병은 근접(장창 리치 2로 선제 유리), 경궁병은 원거리(활 사거리 3 → 부대 [공격거리](../entities/Party.md) 3).
- **밸런스(회피형 영웅 축)**: 보병은 얇게(`힘 46` → `max_hp() = 23`), 경보병은 방패를 뺀다(회피형 영웅에게 어차피 잘 안 맞으니 방어보다 수를 소모품으로). 지휘관(영웅)이 다수 보병을 상대로 우위에 서도록 한 밸런스다. → 아래 영웅 전투 배율.

## API

| 함수 | 반환 | 설명 |
| --- | --- | --- |
| `get_faction(id) -> Dictionary` | 세력 스펙 | 없는 id면 빈 Dictionary |
| `make_hero(faction, index) -> Human` | Human | 세력의 `index`번째 영웅을 Human으로 생성(능력치·장비 반영). 범위 밖이면 `null` |
| `make_heroes(faction) -> Array` | [Human] | 세력 영웅 4명 전부 Human 배열. 없는 세력이면 빈 배열 |
| `hero_party_name(faction, index) -> String` | String | `"{영웅 이름} 부대"`. 범위 밖이면 빈 문자열 |
| `make_troop(archetype) -> Array` | [Human] | 병종 아키타입으로 `TROOP_SIZE`(10)명 **동일** Human 생성. 없는 병종이면 빈 배열 |
| `troop_name(archetype) -> String` | String | 병종 표시 이름(경보병/경궁병). 없으면 빈 문자열 |

생성되는 모든 Human은 `hit_points = max_hp()`(시작 풀피)·`max_stamina = stamina`(풀 스태미나)로 채운다.
`make_*`는 [Human](../entities/Human.md)(RefCounted)만 생성하므로 씬 트리 없이 동작한다. [부대](../entities/Party.md)(Node2D) 인스턴스화·배치·`kind`/`lord` 설정은 [game.gd](../features/parties.md)가 한다.

## 테스트 시나리오

`test/unit/test_unit_types.gd`.

- [정상] `PLAYER_ID == "azel"`, `NPC_IDS`는 3개, `FACTION_IDS`는 4개, `TROOP_SIZE == 10`, `HEROES_PER_FACTION == 4`
- [정상] 모든 세력 스펙에 키 존재: `faction`·`color`·`territory`·`heroes`
- [정상] `get_faction("azel")` — 세력 "푸른 왕국", 영지 "창천성"
- [정상] `make_heroes("azel")` 크기 4, 이름 순서 아젤 하르윈·로엔 카스터·미라 벨포드·가레스 던 (**엘윈 사수 없음**)
- [정상] `make_heroes` 각 세력 크기 4, 첫 명이 그 세력 지휘관(`get_faction`의 첫 영웅)
- [정상] `make_hero("azel", 0)`의 `strength == 78*3`(힘 배율), `agility == int(65*2.5)`(민첩 배율), `luck == 55*3`(행운 배율), `leadership == 88`·`morale == 90`(비전투 스탯 불변)
- [정상] `make_hero("azel", 0)` `hit_points == max_hp()` 이고 `hit_points >= 100`(영웅은 두껍다), 회피율(`CombatResolver.evasion`)이 보병보다 크고 공격간격이 보병보다 짧다
- [정상] `make_hero("azel", 0)` `weapons == ["longsword", "bow"]`(검+보조 활), `shield == "round_shield"`
- [정상] `make_hero("balthazar", 0)` `weapons == ["wand"]`(마법), 방어구에 세력 방어구 포함
- [정상] `make_hero("qasim", 1)`(자밀라) `weapons == ["scimitar", "javelin"]`(투척 무기 보유)
- [정상] `hero_party_name("azel", 0) == "아젤 하르윈 부대"`
- [정상] 모든 영웅·병사 `movement == 4`, `vision == 7`, `hit_points == max_hp()`
- [경계] 없는 세력 id → `get_faction` 빈 Dictionary, `make_heroes` 빈 배열; 범위 밖 index → `make_hero == null`, `hero_party_name == ""`
- [정상] `make_troop("light_infantry")` 크기 10, 전원 동일 능력치(str 46)·장비(`weapons==["spear"]`·`shield==""` 방패 없음), `hit_points == max_hp() == 23`
- [정상] `make_troop("light_archer")` 크기 10, 전원 `weapons==["bow"]`·`shield==""`·`vision==7`
- [경계] `make_troop("light_archer")` 각 멤버가 **독립 배열**(한 명의 `weapons`를 바꿔도 다른 멤버 불변 — `.duplicate()`)
- [경계] 없는 병종 id → `make_troop` 빈 배열, `troop_name` 빈 문자열
- [정상] `troop_name("light_infantry") == "경보병"`, `troop_name("light_archer") == "경궁병"`

## 관련

- [Party (부대)](../entities/Party.md) · [Human (사람)](../entities/Human.md) · [Faction (세력)](../entities/Faction.md)
- 맵 배치·표시·`kind`/`lord` 설정은 [Parties (부대 배치)](../features/parties.md).
