extends Node
## 열린 모달(Modal)을 스택으로 관리하는 싱글턴. 지도 입력 차단·ESC·중첩의 단일 소스.
## project.godot [autoload]에 ModalStack으로 등록. → docs/spec/features/modal.md

var _stack: Array = []   # 열린 Modal 목록. 마지막이 최상단.

## Modal이 open 시 호출. 이미 있으면 무시(중복 push 방지).
func push(modal) -> void:
	if modal in _stack:
		return
	_stack.append(modal)

## Modal이 close(또는 해제) 시 호출.
func pop(modal) -> void:
	_stack.erase(modal)

## 최상단 모달(없으면 null).
func top():
	return _stack.back() if not _stack.is_empty() else null

## 열린 모달이 하나라도 있으면 true — 뒤 화면(지도) 입력 차단 판단용.
func blocking() -> bool:
	return not _stack.is_empty()

## 열린 모달 수(레이어 부여용).
func depth() -> int:
	return _stack.size()
