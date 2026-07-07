# Feature: Title (타이틀 메뉴)

> 스크립트: `scenes/title/title.gd` (`extends Control`)
> 씬: `scenes/title/title.tscn`

메인 메뉴. 시작 / 설정 / 종료 버튼을 제공한다.

## 버튼

| 버튼 | 동작 | 상태 |
| --- | --- | --- |
| 시작 (`StartButton`) | `res://scenes/game/game.tscn`으로 전환 | 구현됨 |
| 설정 (`SettingsButton`) | 로그 출력만 (`"준비 중"`) | **TODO** |
| 종료 (`QuitButton`) | `get_tree().quit()` | 구현됨 |

## 규칙

- **모바일(iOS/Android)에서는 종료 버튼을 숨긴다** — iOS 정책 및 모바일 UX 관례.
- 시작 버튼에 기본 포커스(`grab_focus`) — 게임패드/키보드 대응.

## 관련

- 설정 화면은 미구현. [추천 스펙](../SPEC.md#추천-스펙-미구현--제안) 참고.
