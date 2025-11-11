#version 330 core
out vec4 FragColor;
in vec2 fPos;

uniform vec2 WINDOW;
uniform vec3 uCameraOrigin;
uniform float uViewportHeight;
uniform float uFocalLength;
uniform float uFrame;  // frame counter for randomness

#define MAX_SPHERES 8
#define MAX_DEPTH 8

uniform int sphere_count;
uniform vec3 sphere_centers[MAX_SPHERES];
uniform float sphere_radii[MAX_SPHERES];

// --------- Utility Functions ---------

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 coordinateToNDC(vec2 cor) {
    float x = (cor.x / WINDOW.x) * 2.0 - 1.0;
    float y = 1.0 - (cor.y / WINDOW.y) * 2.0;
    return vec2(x, y);
}

float hit_sphere(vec3 center, float radius, vec3 ray_origin, vec3 ray_dir) {
    vec3 oc = ray_origin - center;
    float a = dot(ray_dir, ray_dir);
    float b = 2.0 * dot(oc, ray_dir);
    float c = dot(oc, oc) - radius * radius;
    float discriminant = b*b - 4.0*a*c;
    if (discriminant < 0.0) return -1.0;
    return (-b - sqrt(discriminant)) / (2.0*a);
}

// Random unit vector on sphere
vec3 random_unit_vector(vec2 seed) {
    float z = rand(seed * 0.37) * 2.0 - 1.0;
    float a = rand(seed * 1.79) * 6.2831853;
    float r = sqrt(1.0 - z*z);
    return vec3(r * cos(a), r * sin(a), z);
}

// Gamma correction
vec3 gamma_correct(vec3 color) {
    return sqrt(color); // gamma = 2.0
}

// --------- Main Shader ---------
void main() {
    float aspect_ratio = WINDOW.x / WINDOW.y;
    float viewport_width = uViewportHeight * aspect_ratio;

    vec3 horizontal = vec3(viewport_width, 0.0, 0.0);
    vec3 vertical   = vec3(0.0, -uViewportHeight, 0.0);
    vec3 lower_left = uCameraOrigin
                    - horizontal / 2.0
                    - vertical / 2.0
                    - vec3(0.0, 0.0, uFocalLength);

    vec2 ndc = coordinateToNDC(gl_FragCoord.xy);
    vec2 uv = (ndc + 1.0) * 0.5;

    // --- Initial ray setup ---
    vec3 ray_origin = uCameraOrigin;
    vec3 ray_dir = normalize(lower_left + uv.x * horizontal + uv.y * vertical - uCameraOrigin);

    vec3 accumulated_color = vec3(1.0);
    vec3 final_color = vec3(0.0);

    // --- Multiple bounces loop ---
    for (int depth = 0; depth < MAX_DEPTH; ++depth) {
        float closest_t = 1e9;
        int hit_index = -1;

        // Find closest sphere
        for (int i = 0; i < sphere_count; ++i) {
            float t = hit_sphere(sphere_centers[i], sphere_radii[i], ray_origin, ray_dir);
            if (t > 0.001 && t < closest_t) {
                closest_t = t;
                hit_index = i;
            }
        }

        if (hit_index == -1) {
            // Background color
            float t = 0.5 * (ray_dir.y + 1.0);
            vec3 sky = mix(vec3(1.0), vec3(0.5, 0.7, 1.0), t);
            final_color += accumulated_color * sky;
            break;
        }

        // --- Compute hit point & normal ---
        vec3 hit_point = ray_origin + closest_t * ray_dir;
        vec3 normal = normalize(hit_point - sphere_centers[hit_index]);

        if (dot(ray_dir, normal) > 0.0)
            normal = -normal;

        // --- Lambertian diffuse bounce ---
        vec3 bounce_dir = normalize(normal + random_unit_vector(gl_FragCoord.xy + uFrame * 1.7));

        // Update for next bounce
        ray_origin = hit_point + normal * 0.001; // prevent shadow acne
        ray_dir = bounce_dir;

        // Attenuate (simulate light absorption)
        accumulated_color *= 0.5;
    }

    // --- Apply gamma correction ---
    final_color = gamma_correct(final_color);

    FragColor = vec4(final_color, 1.0);
}
