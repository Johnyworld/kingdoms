class_name LangFieldMath
extends RefCounted
## 전장 렌더러([lang_battlefield.gd](lang_battlefield.gd))에서 추출한 **순수 기하/분배 수학**.
## 상태·노드·rng·상수에 의존하지 않는 결정적 함수만 둔다(단위 테스트 가능). 렌더/애니 로직은 battlefield에 남는다.

## 병사 n명을 3행으로 나눈 행별 인원 [뒤,중,앞]. 나머지는 앞 행부터 채운다(예: 10 → [3,3,4]).
static func row_counts(n: int) -> Array:
	var rows := [n / 3, n / 3, n / 3]
	var rem := n % 3
	var ri := 2
	while rem > 0:
		rows[ri] += 1
		ri -= 1
		rem -= 1
	return rows

## 예측 요격: 화살 속도 speed로 from에서 쏜 화살이 (tpos, 속도 tvel) 타겟과 만나는 지점.
## |R + V·T| = speed·T → (V·V − speed²)T² + 2(R·V)T + R·R = 0. 최소 양수근 T → tpos + V·T. 해 없으면 tpos.
static func predict_intercept(from: Vector2, tpos: Vector2, tvel: Vector2, speed: float) -> Vector2:
	var r: Vector2 = tpos - from
	var a: float = tvel.dot(tvel) - speed * speed
	var b: float = 2.0 * r.dot(tvel)
	var c: float = r.dot(r)
	var t := -1.0
	if absf(a) < 0.0001:
		if absf(b) > 0.0001:
			t = -c / b
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var sq: float = sqrt(disc)
			var t1: float = (-b + sq) / (2.0 * a)
			var t2: float = (-b - sq) / (2.0 * a)
			var lo: float = minf(t1, t2)
			var hi: float = maxf(t1, t2)
			t = lo if lo > 0.0 else hi   # 최소 양수근
	if t <= 0.0:
		return tpos   # 요격 불가(정적/후퇴 등) → 현재 위치
	return tpos + tvel * t
