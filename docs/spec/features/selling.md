# Feature: Selling (판매 — 노획 장비·화물을 금으로)

> 스크립트: `scenes/camp/camp_menu.gd`(판매 패널) · `scenes/item/item_types.gd`(`item_value`) · `scenes/resource/resource_types.gd`(`ResourceTypes.value`)

부대가 자기 [캠프](camp-menu.md)에 오면, 캠프 메뉴 **판매 패널**에서 부대의 **노획 장비**([`loot_items`](../entities/Party.md#노획-장비-loot-items))와 **화물**([`cargo`](../entities/Party.md#화물-cargo--캐러반))을 **금**([자원](../data/resources.md))으로 판다. 금은 그 캠프의 **영지 금고**(`territory.resources["금"]`)에 쌓인다.

## 판매 패널 (`camp_menu`)

부대가 인접한 자기 캠프 메뉴에 [보급](camp-menu.md)·[수비대 편성](garrison.md) 패널과 함께 표시된다(부대 있을 때만).

- **장비 섹션**: 부대 `loot_items`를 이름별로 묶어(`"<이름> ×<개수>"`) 나열, 각 행 **[판매]**. 누르면 그 장비 **1개**를 팔아 영지 금 += [`ItemTypes.item_value(id)`](../data/items.md), `loot_items`에서 그 id 하나 제거.
- **화물 섹션**: 부대 `cargo`를 자원별(`인구`·`금` 제외) 나열, 각 행 **[판매]**. 누르면 `CARGO_STEP`(5)씩(보유분까지) 팔아 영지 금 += [`ResourceTypes.value(res)`](../data/resources.md) × 실제 판매량, `cargo`에서 차감.
- 판매가 0인 것(가치 미등록 아이템·판매 불가 자원)은 팔아도 금이 안 늘지만, 정상 자원·장비는 위 표대로.
- 판매 후 자원 패널(영지 금)·판매 목록을 갱신한다.

## 금(gold)

- `금`은 [자원](../data/resources.md) 중 하나. 캠프 카탈로그 초기값 `0`으로 모든 영지가 보유(표시).
- **화폐** — 판매로만 늘고(생산 없음), 부대 화물로 운반하지 않는다([보급](camp-menu.md)에서 `인구`와 함께 제외). 판매 대상도 아니다.
- 쓰임(구매 등)은 `미구현`.

## 데이터 API

- `ItemTypes.item_value(id) -> int` — 아이템 판매가(무기=공격력, 방어구·방패=방어력×2, 없으면 0). [Items](../data/items.md).
- `ResourceTypes.value(res_name) -> int` — 자원 1개 판매가(`인구`·`금`·미등록은 0). [Resources](../data/resources.md).

## 테스트 시나리오

### 가치 카탈로그 — `test/unit/test_item_types.gd` · `test/unit/test_resource_types.gd`

- `item_value`·`ResourceTypes.value` 정상·예외는 [Items](../data/items.md#테스트-시나리오)·[Resources](../data/resources.md#테스트-시나리오) 참조.

### 판매 패널 — `test/unit/test_camp_menu.gd`

- [정상] 장비 판매: 부대 `loot_items=["sword"]` → `[판매]` → 영지 금 +14, `loot_items` 비워짐
- [정상] 화물 판매: 부대 화물 철괴 10 → `[판매]`(5씩) → 영지 금 +60(12×5), 화물 철괴 5로 감소
- [경계] 판매 패널 화물 섹션에 `인구`·`금` 행 없음(판매 제외)
- [정상] 부대 없으면 판매 패널 숨김

## 미구현

- 구매, 가격 변동/시장, 상인 방문, 금 생산·소비(건축 비용 등), 금의 쓰임.

## 관련

- [Camp Menu](camp-menu.md)(패널 배치) · [Items](../data/items.md)(가치) · [Resources](../data/resources.md)(금·자원가) · [Party](../entities/Party.md)(loot_items·cargo).
