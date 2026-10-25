shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D blade_texture : source_color, filter_nearest;
uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform bool debug_normals = false;
varying vec4 blade_tint;
void vertex() {
    blade_tint = COLOR;
    float tip = clamp(VERTEX.y, 0.0, 1.0);
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float gust = texture(wind_noise, world.xz / 512.0 + vec2(TIME * 0.018, TIME * 0.009)).r;
    float sway = sin(TIME * 1.1 + world.x * 0.004 + world.z * 0.003);
    world.xz += vec2(1.0, 0.35) * (sway * 1.6 + (gust - 0.5) * 3.0) * tip * tip;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
    // Godot transforms local normals by inverse-transpose(model).
    // The inverse mapping below yields world-up even with nonuniform card scale.
    NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
}
void fragment() {
    vec4 leaf = texture(blade_texture, UV);
    ALBEDO = leaf.rgb * blade_tint.rgb;
    ROUGHNESS = 1.0;
    ALPHA = leaf.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    if (debug_normals) {
        ALBEDO = vec3(0.0);
        EMISSION = (normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz) + 1.0) * 0.5;
    }
}
