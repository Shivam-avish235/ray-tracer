#version 330 core
out vec4 FragColor;
in vec2 fPos;

uniform vec2 WINDOW;
uniform vec3 uCameraOrigin;
uniform float uViewportHeight;
uniform float uFocalLength;

#define MAX_SPHERES 8
uniform int sphere_count;
uniform vec3 sphere_centers[MAX_SPHERES];
uniform float sphere_radii[MAX_SPHERES];

// Convert pixel to NDC
vec2 corrditnateTOndc(vec2 cor) {
    float x = (cor.x / WINDOW.x) * 2.0 - 1.0;
    float y = 1.0 - (cor.y / WINDOW.y) * 2.0;
    return vec2(x, y);
}

// Ray-sphere intersection
float hit_sphere(vec3 center, float radius, vec3 ray_origin, vec3 ray_dir) {
    vec3 oc = ray_origin - center;
    float a = dot(ray_dir, ray_dir);
    float b = 2.0 * dot(oc, ray_dir);
    float c = dot(oc, oc) - radius * radius;
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) return -1.0;
    return (-b - sqrt(discriminant)) / (2.0 * a);
}

void main() {
    // --- Camera setup ---
    float aspect_ratio = WINDOW.x / WINDOW.y;
    float viewport_width = uViewportHeight * aspect_ratio;

    vec3 horizontal = vec3(viewport_width, 0.0, 0.0);
    vec3 vertical   = vec3(0.0, -uViewportHeight, 0.0);
    vec3 lower_left = uCameraOrigin
                    - horizontal / 2.0
                    - vertical / 2.0
                    - vec3(0.0, 0.0, uFocalLength);

    // --- Convert pixel coordinates ---
    vec2 ndc = corrditnateTOndc(gl_FragCoord.xy);
    vec2 uv = (ndc + 1.0) * 0.5;

    // --- Generate ray ---
    vec3 ray_dir = lower_left + uv.x * horizontal + uv.y * vertical - uCameraOrigin;
    ray_dir = normalize(ray_dir);

    // --- MULTIPLE SPHERES ---
    float closest_t = 1e9;
    vec3 hit_center;
    bool hit_anything = false;

    for (int i = 0; i < sphere_count; ++i) {
        float t = hit_sphere(sphere_centers[i], sphere_radii[i], uCameraOrigin, ray_dir);
        if (t > 0.0 && t < closest_t) {
            closest_t = t;
            hit_center = sphere_centers[i];
            hit_anything = true;
        }
    }

    // --- Shading ---
    if (hit_anything) {
    vec3 hit_point = uCameraOrigin + closest_t * ray_dir;
    vec3 normal = normalize(hit_point - hit_center);

    // Ensure the normal always points outward
    if (dot(ray_dir, normal) > 0.0)
        normal = -normal;

    // Color by normal direction
    vec3 color = 0.5 * (normal + vec3(1.0));
    FragColor = vec4(color, 1.0);
} 
else {
    float t = 0.5 * (ray_dir.y + 1.0);
    vec3 color = mix(vec3(1.0), vec3(0.5, 0.7, 1.0), t);
    FragColor = vec4(color, 1.0);
}

}
