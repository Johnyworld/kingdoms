shader_type canvas_item;

// 세력색 팔레트 스왑 셰이더 (팀컬러).
// 원본 유닛 스프라이트에서 "세력색 존"(예: 붉은 튜닉)만 골라 team_color로 치환하되,
// 원본 픽셀의 명암(밝기)을 유지해 곱셈 합성한다 → 단색 덩어리가 아니라 명암 있는 세력색.
//
// [임시 마스크] 지금은 key_color 색조(hue)에 가까운 픽셀을 존으로 자동 선택한다.
// 실사용에선 이 hue 판정을 아티스트가 그린 마스크 텍스처 샘플링으로 교체하면 된다.

uniform vec4 team_color : source_color = vec4(0.2, 0.3, 0.8, 1.0);
uniform vec3 key_color : source_color = vec3(0.40, 0.125, 0.125); // 대체할 원본 존 색(붉은 튜닉)
uniform float hue_tolerance = 0.08;   // 색조 허용 오차(원 위 거리)
uniform float min_saturation = 0.25;  // 이 이상 채도인 픽셀만(회색 제외)
uniform float strength = 1.0;         // 0=원본, 1=완전 치환

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	vec3 key = rgb2hsv(key_color);

	// 색조 원형 거리 → 존 여부(마스크). 채도 낮은(회색) 픽셀·투명 픽셀 제외.
	float dh = abs(hsv.x - key.x);
	dh = min(dh, 1.0 - dh);
	float mask = step(dh, hue_tolerance) * step(min_saturation, hsv.y) * step(0.01, tex.a);
	mask *= strength;

	// 원본 밝기(value)를 key 밝기 기준으로 정규화해 team_color에 곱함 → 명암 보존.
	vec3 tteam_hsv = rgb2hsv(team_color.rgb);
	vec3 recolored = team_color.rgb * (hsv.z / max(key.z, 0.001));

	vec3 outc = mix(tex.rgb, recolored, mask);
	COLOR = vec4(outc, tex.a);
}
