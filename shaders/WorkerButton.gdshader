shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);

	if (d > 0.5) {
		discard;
	}

	COLOR = COLOR;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
