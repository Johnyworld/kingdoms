# Feature: Scene Transition (씬 전환)

> 스크립트: `autoload/scene_manager.gd` (`extends Node`, Autoload 싱글턴 `SceneManager`)

모든 씬 전환을 페이드 인/아웃으로 통일하는 싱글턴.

## 정의

- 최상위 `CanvasLayer`(layer 128) 위에 전체 화면 검은 `ColorRect` 오버레이를 생성.
- 평소 오버레이는 투명하고 입력을 통과(`MOUSE_FILTER_IGNORE`)시킨다.

## 동작

`SceneManager.change_scene(path: String)`:

1. 전환 중이면 무시(중복 방지).
2. 오버레이 입력 차단(`MOUSE_FILTER_STOP`).
3. 검게 페이드아웃 (`FADE_DURATION = 0.4초`).
4. `change_scene_to_file(path)` → 한 프레임 대기.
5. 다시 투명하게 페이드인.
6. 오버레이 입력 통과로 복구.

## 규칙

- 이후 모든 씬 전환은 `SceneManager.change_scene(path)`로 통일한다.
