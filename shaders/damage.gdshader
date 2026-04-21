shader_type canvas_item;

uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform vec4 vignette_color : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float pulse_speed = 4.0;

void fragment() {
	// Only start showing the effect below 50% health
	float health_factor = clamp((0.5 - health) * 2.0, 0.0, 1.0);
	
	// Create a circular vignette mask
	// Distance from center (0.5, 0.5)
	float dist = distance(UV, vec2(0.5));
	
	// Create a pulsing effect using sine wave
	float pulse = (sin(TIME * pulse_speed) * 0.1) + 0.9;
	
	// Calculate intensity: higher dist + lower health = stronger red
	// We use smoothstep to keep the center clear
	float vignette = smoothstep(0.3, 0.7, dist * (health_factor + 0.5));
	
	// Final alpha calculation
	float alpha = vignette * health_factor * pulse;
	
	COLOR = vec4(vignette_color.rgb, alpha);
}