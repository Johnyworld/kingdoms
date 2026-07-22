class_name UnitSprites
## 월드맵 부대 토큰 스프라이트 — 아키타입 → 스프라이트 세트 매핑 + idle SpriteFrames 캐시(64부대 공유).
## 전투 화면(lang_battlefield)과 같은 에셋(100×100)을 쓰되, 맵 토큰은 idle 루프만 필요하다.

const UNIT_DIR := "res://assets/units/"
const FRAME_PX := 100        # 시트 한 프레임(정사각)
const IDLE_COUNT := 6        # idle 시트 프레임 수(soldier/archer_a/sword 공통)
const IDLE_FPS := 6.0        # lang_battlefield IDLE_FPS와 동일

## 아키타입 → 스프라이트 세트 키(전투와 동일 매핑).
##  - hero=sword(영웅), light_infantry=soldier(경보병), light_archer=archer_a(경궁병)
const SET_KEYS := {
	"hero": "sword",
	"light_infantry": "soldier",
	"light_archer": "archer_a",
}

## 세트별 idle SpriteFrames 정적 캐시(부대들이 공유 — 64부대라 매번 만들지 않는다).
static var _idle_cache := {}

## 아키타입에 해당하는 스프라이트 세트 키. 미지원/빈 값은 경보병(soldier)으로 대체.
static func set_key(archetype: String) -> String:
	return SET_KEYS.get(archetype, "soldier")

## 아키타입의 idle SpriteFrames(세트별 캐시). "<set>_idle.png"에서 IDLE_COUNT프레임 루프("default" 애니).
static func idle_frames(archetype: String) -> SpriteFrames:
	var key := set_key(archetype)
	if _idle_cache.has(key):
		return _idle_cache[key]
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", true)
	sf.set_animation_speed("default", IDLE_FPS)
	var tex: Texture2D = load(UNIT_DIR + key + "_idle.png")
	for i in IDLE_COUNT:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_PX, 0, FRAME_PX, FRAME_PX)
		sf.add_frame("default", at)
	_idle_cache[key] = sf
	return sf
