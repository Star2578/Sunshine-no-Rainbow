shader_type canvas_item;

// 0.0 = base water droplet, 1.0 = high pressure jet
uniform float pressure : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);
    float t = TIME + time_offset;

    // -------------------------------------------------------
    // SHAPE — soft circle with wobbly edge
    // pressure tightens the wobble: base = lazy, upgraded = crisp
    // -------------------------------------------------------
    float angle = atan(uv.y, uv.x);

    float wobble_speed  = mix(2.0, 5.0, pressure);
    float wobble_amount = mix(0.06, 0.02, pressure);  // less wobbly when pressurized
    float wobble_freq   = mix(4.0, 7.0, pressure);    // more ripple segments when pressurized

    float wobble = sin(angle * wobble_freq + t * wobble_speed) * wobble_amount;
             wobble += sin(angle * (wobble_freq + 2.0) - t * wobble_speed * 0.7) * wobble_amount * 0.5;

    float radius = mix(0.38, 0.42, pressure) + wobble;  // pressurized = slightly smaller, tighter
    float edge_softness = mix(0.10, 0.04, pressure);     // pressurized = harder edge

    float body = smoothstep(radius, radius - edge_softness, dist);

    // -------------------------------------------------------
    // DEPTH — fake 3D sphere feel
    // light source top-left, darker at edges
    // -------------------------------------------------------
    vec2 light_dir = normalize(vec2(-0.4, -0.6));
    float diffuse = dot(normalize(vec3(uv, sqrt(max(0.0, 1.0 - dot(uv * 2.0, uv * 2.0))))), vec3(light_dir, 0.6));
    diffuse = clamp(diffuse, 0.0, 1.0);

    // -------------------------------------------------------
    // SPECULAR — water surface highlight
    // pressure makes highlight tighter and brighter (more like a jet than a droplet)
    // -------------------------------------------------------
    float spec_power = mix(12.0, 40.0, pressure);
    float specular = pow(diffuse, spec_power);

    // Small secondary highlight — the inner light bounce
    vec2 bounce_offset = vec2(0.12, 0.1);
    float bounce = smoothstep(0.22, 0.0, length(uv - bounce_offset));
    bounce *= mix(0.3, 0.15, pressure);

    // -------------------------------------------------------
    // COLOR
    // base: soft translucent water blue
    // pressurized: deeper, more saturated, colder
    // -------------------------------------------------------
    vec3 deep_color    = mix(vec3(0.05, 0.30, 0.70), vec3(0.00, 0.15, 0.60), pressure);
    vec3 mid_color     = mix(vec3(0.20, 0.60, 0.95), vec3(0.10, 0.45, 0.90), pressure);
    vec3 surface_color = mix(vec3(0.70, 0.90, 1.00), vec3(0.85, 0.95, 1.00), pressure);

    // Blend by distance from center: deep → mid → surface
    float depth_blend = smoothstep(0.0, 0.38, dist);
    vec3 color = mix(deep_color, mid_color, depth_blend);
    color = mix(color, surface_color, smoothstep(0.25, 0.42, dist));

    // Add diffuse shading for the sphere illusion
    color = mix(color * 0.5, color, diffuse * 0.7 + 0.3);

    // Layer on specular and bounce
    color += vec3(specular * mix(0.8, 1.2, pressure));
    color += surface_color * bounce;

    // -------------------------------------------------------
    // INNER RIPPLE — pulse radiating from center
    // feels like the water is alive/under pressure
    // -------------------------------------------------------
    float ripple_speed = mix(3.0, 7.0, pressure);
    float ripple = sin(dist * 18.0 - t * ripple_speed) * 0.5 + 0.5;
    ripple *= smoothstep(0.38, 0.1, dist);   // only inside the body
    ripple *= smoothstep(0.0, 0.1, dist);    // not at dead center
    ripple *= mix(0.04, 0.08, pressure);     // subtle — just enough to read
    color += vec3(0.6, 0.85, 1.0) * ripple;

    // -------------------------------------------------------
    // ALPHA — translucent water, less so under pressure
    // -------------------------------------------------------
    float base_alpha = mix(0.82, 0.96, pressure);
    float alpha = body * base_alpha;

    // Soft outer glow — watery refraction feel at the very edge
    float glow = smoothstep(radius + 0.12, radius, dist) * (1.0 - body);
    glow *= mix(0.25, 0.1, pressure);
    alpha += glow;

    COLOR = vec4(color, alpha * COLOR.a);
}