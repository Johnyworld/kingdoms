extends GutTest
## MapDraw 공용 헬퍼(지도 위 world-space 벡터 오버레이) — 계약 검증.
## ring/disc/polyline/segment/polygon은 렌더 결과라 단위 테스트 불가(실제 실행/렌더로 확인).
## 여기선 슈퍼샘플 배율 계약만(1보다 커야 확대에서 선명 — 원리는 MapText와 동일).

func test_supersample_gt_one() -> void:
	assert_gt(MapDraw.SUPERSAMPLE, 1, "슈퍼샘플 배율은 1보다 커야 카메라 확대에서 선명")

func test_supersample_matches_text() -> void:
	assert_eq(MapDraw.SUPERSAMPLE, MapText.SUPERSAMPLE, "텍스트/벡터 오버레이가 같은 배율로 일관")
