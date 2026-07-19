shader_type canvas_item;
// 피격 흰색 플래시 — flash(0~1) 만큼 스프라이트를 흰색으로 덮는다.
// 진입 시 COLOR 는 이미 (텍스처 × modulate) 로 합성된 값이므로 텍스처를 다시 곱하면 안 된다
// (tex² 가 되어 어두워짐). COLOR 를 그대로 두고 rgb 만 흰색으로 mix → flash=0 이면 기본 렌더와 동일.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash * COLOR.a);
}
