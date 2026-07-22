extends GutTest
## MapText 공용 헬퍼(지도 위 world-space 텍스트) — 폰트 계약 검증.
## draw_centered는 렌더 결과라 단위 테스트 불가(실제 실행/렌더로 확인). 여기선 폰트(볼드·캐싱)만.

func test_font_is_bold_galmuri() -> void:
	var f := MapText.font()
	assert_true(f is FontVariation, "MapText.font()는 FontVariation")
	assert_almost_eq(f.variation_embolden, MapText.EMBOLDEN, 0.001, "합성 볼드 강도 = EMBOLDEN(작은 글자 가독성)")
	assert_eq(f.base_font, MapText.TTF, "base_font = 갈무리14")

func test_font_cached() -> void:
	assert_same(MapText.font(), MapText.font(), "폰트는 전역 공유(같은 인스턴스 재사용)")
