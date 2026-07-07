# Feature: Camp Menu (캠프 메뉴)

> 스크립트: `scenes/camp/camp_menu.gd` (`extends CanvasLayer`, layer 64)

캠프 헥스를 클릭하면 열리는 오버레이. 좌측에 자원 정보, 우측에 선택 메뉴를 표시한다.
UI 트리는 씬이 아니라 코드(`_build`)로 구성된다.

## 레이아웃

- 반투명 배경(`Color(0,0,0,0.45)`) — 클릭 시 닫힘.
- 화면 중앙에 두 패널을 나란히(HBox, separation 16):
  - **좌측 — 자원 패널** (220×260): 제목 "자원" + 2열 그리드(자원명 / 값).
  - **우측 — 캠프 메뉴 패널** (200×260): 제목 = **캠프 이름**(예: "파리") + 그 아래 **세력명**(예: "프랑스", 세력 색상으로 표기) + "건축" 버튼 + (하단) "닫기" 버튼.

## 동작

- `open(camp: Camp)` — 캠프를 받아 자원 그리드를 채우고(`camp.resources`, 삽입 순서대로), 우측 패널의 이름/세력 라벨을 채운 뒤 메뉴를 연다.
  - 제목 라벨 = `camp.camp_name`.
  - 세력 라벨 = `camp.faction.name` (색상 = `camp.faction.color`). `faction`이 `null`이면 세력 라벨은 빈 문자열.
- `close_menu()` — 숨긴다.
- 닫기 트리거: 배경 좌클릭, "닫기" 버튼.
- **건축 버튼** (`_on_build_pressed`) — 아직 기능 없음. **TODO**.

## 테스트 시나리오

`test/unit/test_camp_menu.gd`.

- [정상] 세력 소속 캠프로 `open` → 제목 라벨 = 캠프 이름("파리"), 세력 라벨 = 세력명("프랑스")
- [정상] 세력 라벨 색상 = 세력 색상
- [경계] `faction == null`인 캠프로 `open` → 세력 라벨은 빈 문자열
- [정상] `open` 후 자원 그리드가 자원 6종으로 채워진다

## 관련

- 표시되는 자원은 [Camp 엔티티](../entities/Camp.md)의 `resources`를 그대로 전달받는다.
- 이름·세력은 [Camp](../entities/Camp.md) / [Faction](../entities/Faction.md) 엔티티에서 온다.
- 건축은 미구현. [추천 스펙](../SPEC.md#추천-스펙-미구현--제안) 참고.
