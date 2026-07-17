class_name LangRng
extends RefCounted
## 랑그릿사 1(MD) RNG 재현 — 스펙 §2.5 (원본 0x6722).
## 32비트 LCG 변형. 상태는 상위 16비트만 유효.
##
## 결정론적: 같은 시드 → 같은 수열. Resolver가 이 RNG 하나만 소비하므로
## 전투 결과 전체가 재현 가능하다(연출 스킵과 무관하게 동일 결과).
##
## 검증 수열 (상태 0에서 next() % 100):
##   [43,43,79,79,51,99,99,3,27,63,3,51]

const _MASK32 := 0xFFFFFFFF
const _SEED := 0x2A6D365A  # 상태 0일 때 쓰는 초기 시드

var _state: int  # 상위 16비트가 유효분

func _init(seed_state: int = 0) -> void:
	_state = seed_state & _MASK32

## 16비트 난수 하나를 뽑고 상태를 전진시킨다.
func next() -> int:
	var s := _state
	if s == 0:
		s = _SEED
	s = (s * 41) & _MASK32                       # ×41
	var r := ((s & 0xFFFF) + (s >> 16)) & 0xFFFF  # 상·하위 워드 fold
	_state = (r << 16) & _MASK32
	return r

## 0..(n-1) 범위 정수.
func next_mod(n: int) -> int:
	return next() % n
