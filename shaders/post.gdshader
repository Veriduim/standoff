// The stage's after-pass (drawn over the stage, under the cards and panels):
//   split - the picture splits into colours from a point (supers, KOs, Bursts - pick 13), fading
//   pixel - the pixel look (pick 2, a switch on the home screen): the stage read back in blocks this many screen px wide
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float split = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float pixel = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (pixel > 1.0) {
		vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
		uv = (floor(uv * res / pixel) + 0.5) * pixel / res;
	}
	vec2 off = (uv - centre) * split * 0.03 + vec2(split * 0.007, 0.0);
	float r = texture(screen, uv + off).r;
	float g = texture(screen, uv).g;
	float b = texture(screen, uv - off).b;
	COLOR = vec4(r, g, b, 1.0);
}
