# Data: Unit Spawns (초기 유닛 배치)

> 스크립트: `scenes/party/unit_spawns.gd` (`class_name UnitSpawns`)
> 데이터: `res://data/unit_spawns.csv`

게임 시작 시 맵에 놓이는 **초기 유닛을 개별 행으로 정의**하는 카탈로그. 유닛을 하나씩 절대좌표로 찍고, 각 부하부대가 어느 영웅부대에 소속되는지를 `leader` 컬럼으로 연결한다. 병종 정의(스탯·표시명)는 [UnitTypes](unit-types.md, `unit_types.csv`), 세력·영웅 이름은 [FactionCatalog](factions.md)가 담당한다.
데이터는 `res://data/unit_spawns.csv`에서 **lazy-load** 한다([UnitTypes]·[FactionCatalog]와 동일 패턴). `importer="keep"`로 Godot 번역 자동임포트를 막는다.

**초기 유닛 vs 생산 유닛** — 이 CSV는 시작 시점의 **seed**일 뿐이다. 스폰된 순간부터 모든 유닛은 [Party](../entities/Party.md) 노드(런타임 변수)로만 존재하며, 초기 유닛과 인게임 생산 유닛은 **동일 자료구조**다(차이는 태어난 경로뿐 — CSV vs 게임 로직).

## CSV 계약 (`unit_spawns.csv`)

컬럼: `id,faction,type,leader,x,y`

| 컬럼 | 설명 |
| --- | --- |
| `id` | 스폰 인스턴스 식별자(파일 내 유일). `leader` 참조 대상 |
| `faction` | 세력 id — [factions.csv](factions.md) **FK** |
| `type` | 병종 아키타입 id — [unit_types.csv](unit-types.md)(`hero`/`light_infantry`/`light_archer`) |
| `leader` | 소속 영웅부대의 `id`(같은 파일). **영웅 행은 빈 값**, 부하 행은 `type=="hero"`인 id |
| `x,y` | 절대 셀 좌표(맵 셀, y↑=남·x↑=동) |

**참조 무결성**(로드 시 `push_error`): `id` 유일 · `faction`이 factions.csv에 존재 · `type`이 unit_types.csv에 존재 · `leader`가 비었거나 같은 파일 내 영웅(`type=="hero"`) id.

## 편제 (현재 데이터)

세력당 **영웅 4 + 각 영웅 소속 경보병 2·경궁병 1(부하 12) = 16행**, 총 **64행**. 세력별 영웅 행의 등장 순서가 그 세력 hero index(0=지휘관)를 정한다([FactionCatalog.hero_name](factions.md)).

좌표는 각 세력의 **거점 건물 중심 셀**을 기준으로 16유닛을 안쪽(맵 중앙 방향)으로 뭉치게 배치한다. 각 세력의 **첫 부하부대(`{faction}_t0`)를 거점 건물 중심 셀에 두어 캠프를 점거**한다 → [거점 방어](../features/camp-capture.md)(`_camp_defender`는 건물 `center_cell()` 점거로 판정). 개별 좌표는 손으로 튜닝·플레이테스트로 조정하는 것을 전제로 한다(절대좌표 모델).

> **주의(마커 결합)**: 거점 건물 중심 셀은 씬의 배치 마커(`Placements/*`)로 정해진다([Map & Camera](../features/map-and-camera.md)). 마커를 옮기면 건물은 따라가지만 이 CSV 좌표는 **자동으로 따라가지 않는다** — 방어자(t0) 좌표를 새 건물 중심에 맞춰 다시 적어야 캠프 방어가 유지된다(절대좌표 모델의 트레이드오프).

```
id,faction,type,leader,x,y
azel_h0,azel,hero,,12,39
azel_t0,azel,light_infantry,azel_h0,11,40
azel_t1,azel,light_infantry,azel_h0,13,39
azel_t2,azel,light_archer,azel_h0,12,38
...
```

## API

| 함수 | 반환 | 설명 |
| --- | --- | --- |
| `entries() -> Array` | 스폰 entry 배열(행 순서 유지) | 각 원소 `{id, faction, type, leader, cell: Vector2i}` |

## 배치 소비 (`game.gd`)

[game.gd](../features/parties.md) `_setup_parties()`가 `entries()`를 소비한다:
1. entry마다 [Party](../entities/Party.md) 생성 — 영웅/부하 `kind`, 병종 `troop_type`, 병력수, 토큰 색 설정. 플레이어 첫 영웅만 기존 `$Party` 노드를 재사용.
2. **배치**: 지정 `cell`이 통과가능·미점유면 그대로, 아니면 인접 빈 칸(`_nearby_free_cells` BFS)으로 보정한다(산·물·겹침 안전망).
3. `leader` → `lord` 소속 연결 + 부하부대 이름 확정(`"{소속 영웅} {병종}"`).
4. 플레이어 부대는 `_pmgr.units`, NPC는 `_pmgr.npc_parties`. 활성 부대(`party`)는 플레이어 첫 영웅.

## 테스트 시나리오

`test/unit/test_unit_spawns.gd`.

- [정상] `entries()` 64행; 세력별 16(영웅 4 + 부하 12)
- [정상] `id` 유일; faction·type FK 유효
- [정상] 영웅은 `leader` 빈 값, 부하 `leader`는 같은 세력의 영웅 id
- [정상] 좌표는 맵(50×50) 안; 같은 세력 스폰끼리 좌표 충돌 없음
- [정상] 세력마다 방어자 스폰(`{faction}_t0`, 일반부대) 존재 (실제 거점 중심 점거는 런타임 배치가 건물 중심에 맞춤)

## 관련

- [Factions (세력·영웅)](factions.md) · [Unit Types (병종)](unit-types.md) · [Party (부대)](../entities/Party.md)
- 생성·배치 흐름은 [Parties (부대 배치)](../features/parties.md).
