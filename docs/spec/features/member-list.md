# Feature: Member List (구성원 리스트 위젯 · 재사용)

> 스크립트: `scenes/members/member_list.gd` (`class_name MemberList`, `extends Tree`)

[Human](../entities/Human.md) 배열을 받아 **정렬·스크롤·키보드 이동**이 되는 표로 그리는 **재사용 위젯**.
게임·세력·부대를 전혀 모른다(Human만 안다). [구성원 메뉴](members-menu.md)가 첫 사용처이고,
나중에 **유닛 선택 UI** 등에서 그대로 재사용하는 것이 목표다.

Godot `Tree` 컨트롤을 감싸 스크롤(세로·가로)·키보드 이동(↑/↓/PageUp/Down)·행 선택 하이라이트를
엔진 기본 동작으로 얻고, **컬럼 정렬**만 직접 구현한다.

## 컬럼

첫 컬럼은 이름(문자열), 나머지는 모두 숫자 스탯이다. 순서는 [Stats](../data/stats.md)를 따른다.

| # | 라벨 | 키(`key`) | 타입 |
| --- | --- | --- | --- |
| 0 | 이름 | `human_name` | str |
| 1 | 힘 | `strength` | num |
| 2 | 지혜 | `wisdom` | num |
| 3 | 민첩 | `agility` | num |
| 4 | 매력 | `charm` | num |
| 5 | 행운 | `luck` | num |
| 6 | 이동력 | `movement` | num |
| 7 | 시야 | `vision` | num |
| 8 | 지휘력 | `leadership` | num |
| 9 | 화술 | `eloquence` | num |
| 10 | 성실함 | `diligence` | num |
| 11 | 예민함 | `sensitivity` | num |
| 12 | 레벨 | `level` | num |
| 13 | HP | `hit_points` | num |
| 14 | 스태미나 | `stamina` | num |
| 15 | 사기 | `morale` | num |

- 컬럼 정의는 `COLUMNS` 상수(`[{ "key", "label", "numeric" }]`)로 둔다. 컬럼 추가/변경은 이 배열만 고친다.
- 이름 컬럼은 넓게(약 120px), 스탯 컬럼은 좁게(약 48px) 고정폭이라 컬럼 수가 많으면 **가로 스크롤**이 생긴다.

## 레이아웃 / 표시

- `Tree` 자체가 위젯이다. `hide_root = true`, 컬럼 제목 표시(`column_titles_visible = true`), 단일 선택.
- 데이터 행 하나 = `TreeItem` 하나. 셀 텍스트는 각 컬럼 `key`의 `Human` 값을 문자열로 넣는다.
- 세로 스크롤(행이 많을 때)·가로 스크롤(컬럼이 많을 때)은 `Tree` 기본 스크롤바로 처리한다.

## 동작

- `set_members(humans: Array) -> void` — 내부 목록을 교체하고 표를 **비운 뒤 다시 채운다**. 현재 정렬 상태(`_sort_key`, `_sort_asc`)를 그대로 적용해 그린다. 빈 배열이면 행이 없다.
- `sorted_members(key: String, ascending: bool) -> Array` — **순수 함수**. 현재 멤버를 `key` 기준으로 정렬한 새 배열을 반환한다(원본 불변). 숫자 컬럼은 수치 비교, 이름 컬럼은 문자열 비교. 동률은 입력 순서를 유지(안정 정렬).
- `sort_by(key: String) -> void` — 그 `key`로 정렬해 다시 그린다. **같은 키를 다시 지정하면 오름/내림을 토글**한다(다른 키면 오름차순부터). 컬럼 제목 클릭이 이 함수를 호출한다.
- `move_selection(delta: int) -> void` — 선택 행을 `delta`만큼 이동(0~마지막으로 클램프)하고 그 행이 보이도록 스크롤한다. 키보드 ↑/↓/PageUp/Down 대응(엔진 기본 `Tree` 처리에 더해 API로도 노출해 테스트 가능하게 한다).
- `selected_member() -> Human` — 현재 선택된 `Human`(없으면 `null`).

## 시그널

- `member_selected(human)` — 선택 행이 바뀔 때(클릭·키보드 이동 모두) 방출한다. 위젯은 이 시그널만 내보내고, 상세 표시/유닛 선택 등 후속 동작은 **사용하는 쪽**이 정한다.

## 테스트 시나리오

`test/unit/test_member_list.gd`.

- [정상] `set_members([a, b, c])` → 표 행 수 = 3
- [경계] `set_members([])` → 행 수 = 0
- [정상] `sorted_members("strength", true)` → 힘 오름차순 정렬(원본 배열은 불변)
- [정상] `sorted_members("strength", false)` → 힘 내림차순 정렬
- [정상] `sorted_members("human_name", true)` → 이름 사전순 정렬
- [정상] `sort_by("charm")` 두 번 호출 → 첫 번째 오름차순, 두 번째 내림차순(토글)
- [정상] `sort_by("charm")` 후 다른 키 `sort_by("luck")` → 오름차순으로 시작
- [경계] 스탯 동률 두 멤버 → 입력 순서 유지(안정 정렬)
- [정상] 행 선택 시 `member_selected`가 그 `Human`을 실어 방출됨
- [정상] `move_selection(+1)` → 선택 인덱스 1 증가, `move_selection`이 범위를 넘으면 마지막/처음으로 클램프

## 관련

- 표시 데이터는 [Human](../entities/Human.md) — 이름 + [능력치·자원](../data/stats.md).
- 첫 사용처 겸 상세 패널·좌측 하단 버튼은 [Members Menu](members-menu.md).
