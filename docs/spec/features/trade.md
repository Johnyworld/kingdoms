# Feature: Trade (상거래 — 판매·구매)

> 스크립트: `scenes/camp/camp_menu.gd`(판매·구매 패널) · `scenes/item/item_types.gd`(`item_value`) · `scenes/resource/resource_types.gd`(`ResourceTypes.value`)

부대가 자기 [캠프](camp-menu.md)에 오면, 캠프 메뉴에서 **금**([자원](../data/resources.md))으로 상거래한다 — 부대의 노획 장비·화물을 **팔거나**(→ 영지 금고), 금으로 장비를 **산다**(→ 부대 노획 장비). 금은 그 캠프의 **영지 금고**(`territory.resources["금"]`)에 오간다.

판매·구매 패널은 [보급](camp-menu.md)·[수비대 편성](garrison.md) 패널과 함께 표시된다(부대 있고 거점일 때만).

## 판매 (`camp_menu` 판매 패널)

- **장비 섹션**: 부대 `loot_items`를 이름별로 묶어(`"<이름> ×<개수>"`) 나열, 각 행 **[판매]**. 그 장비 **1개**를 팔아 영지 금 += [`ItemTypes.item_value(id)`](../data/items.md), `loot_items`에서 그 id 하나 제거.
- **화물 섹션**: 부대 `cargo`를 자원별(`인구`·`금` 제외) 나열, 각 행 **[판매]**. `CARGO_STEP`(5)씩(보유분까지) 팔아 영지 금 += [`ResourceTypes.value(res)`](../data/resources.md) × 실제 판매량, `cargo`에서 차감.

## 구매 (`camp_menu` 구매 패널)

- **구매가 = `ItemTypes.item_value(id) × BUY_MARKUP`** (마크업 `BUY_MARKUP`=2 → 판매가의 2배, 상인 스프레드). 판매는 `value`로 받고, 구매는 `value×2`로 낸다.
- [`ItemTypes`](../data/items.md) **전 카탈로그**(무기·방어구·방패)를 무기/방어구/방패 섹션으로 나열, 각 행 `"<이름> <구매가>금"` + **[구매]**. 재고 무제한. **가치(구매가) 0인 아이템은 구매 목록에서 제외**(금 0 무한 구매 방지).
- **[구매]**: 영지 금 ≥ 구매가면 영지 금 −= 구매가, 부대 `loot_items`에 그 id 추가. **금이 모자라면 [구매] 비활성**.
- 구매 후 구매 목록(가용성)·판매 장비 목록·좌측 자원 그리드(금)를 갱신한다.

## 금(gold)

- `금`은 [자원](../data/resources.md) 중 하나(캠프 카탈로그 초기 `0`). **화폐** — 상거래로만 오가고(생산 없음), 부대 화물로 운반하지 않는다([보급](camp-menu.md)·[분할 분배](party-composition.md)에서 `인구`와 함께 제외). 판매 대상도 아니다.

## 데이터 API

- `ItemTypes.item_value(id) -> int` — 아이템 기준가(판매가; 구매가 = ×`BUY_MARKUP`). 무기=공격력, 방어구·방패=방어력×2, 없으면 0. [Items](../data/items.md).
- `ResourceTypes.value(res_name) -> int` — 자원 1개 판매가(`인구`·`금`·미등록은 0). [Resources](../data/resources.md).

## 테스트 시나리오

### 가치 카탈로그 — `test/unit/test_item_types.gd` · `test/unit/test_resource_types.gd`

- `item_value`·`ResourceTypes.value` 정상·예외는 [Items](../data/items.md#테스트-시나리오)·[Resources](../data/resources.md#테스트-시나리오) 참조.

### 판매·구매 패널 — `test/unit/test_camp_menu.gd`

- [정상] 장비 판매: 부대 `loot_items=["sword"]` → `[판매]` → 영지 금 +14, `loot_items` 비워짐
- [정상] 화물 판매: 부대 철괴 10 → `[판매]`(5씩) → 영지 금 +60(12×5), 화물 철괴 5로 감소
- [경계] 판매 패널 화물 섹션에 `인구`·`금` 행 없음
- [정상] 장비 구매: 영지 금 30 · `sword`(구매가 28) `[구매]` → 영지 금 2, 부대 `loot_items`에 `sword`
- [경계] 금 부족: 영지 금 10 · `sword`(28) → `[구매]` 비활성(no-op)
- [정상] 부대 없으면 판매·구매 패널 숨김

## 미구현

- 자원·병사 구매, 상인 방문 게이트(거점 티어), 재고 제한·가격 변동, 금 생산.

## 관련

- [Camp Menu](camp-menu.md)(패널 배치) · [Items](../data/items.md)(가치) · [Resources](../data/resources.md)(금·자원가) · [Party](../entities/Party.md)(loot_items·cargo).
