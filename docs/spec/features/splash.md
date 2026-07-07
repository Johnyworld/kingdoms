# Feature: Splash (스플래시 화면)

> 스크립트: `scenes/splash/splash.gd` (`extends Control`)
> 씬: `scenes/splash/splash.tscn` — 게임 진입점(`run/main_scene`)

로고를 페이드 인 → 유지 → 페이드 아웃한 뒤 타이틀로 전환한다.

## 동작

1. 로고(`$Logo`) 투명에서 시작.
2. Tween 시퀀스:
   - 페이드 인 0.6초
   - 유지 1.0초
   - 페이드 아웃 0.6초
   - → 타이틀 씬으로 전환
3. **스킵**: 아무 입력(키/마우스/터치 눌림)이 들어오면 즉시 타이틀로 전환.

## 규칙

- `_done` 플래그로 자동 전환과 입력 스킵의 중복 실행을 막는다.
- 전환 대상: `res://scenes/title/title.tscn` (via `SceneManager`).
