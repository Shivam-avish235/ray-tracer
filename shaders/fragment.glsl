#version 330 core
out vec4 FragColor;

uniform vec2 WINDOW;

// Camera uniforms
uniform vec3 uCameraOrigin;
uniform vec3 uLookAt;
uniform vec3 uUp;
uniform float uFOV;
uniform vec2 uSeed;         // Varies every frame from C++
uniform int uMaxDepth;

// Defocus blur
uniform float uDefocusAngle;
uniform float uFocusDist;

#define MAX_SPHERES 512
#define MAT_LAMBERTIAN 0
#define MAT_METAL 1
#define MAT_DIELECTRIC 2

uniform int sphere_count;
// Arrays
uniform vec3 sphere_centers[MAX_SPHERES];
uniform float sphere_radii[MAX_SPHERES];
uniform int sphere_material[MAX_SPHERES];
uniform vec3 sphere_albedo[MAX_SPHERES];
uniform float sphere_fuzz[MAX_SPHERES];
uniform float sphere_ref_idx[MAX_SPHERES];

// ---------------- RANDOM HELPERS ----------------
// We use 'inout' to update the seed state after every generation
// This prevents "banding" artifacts where every bounce uses the same random number.

float rand01(inout vec2 seed) {
    seed += vec2(0.123, 0.456); // Perturb seed so next call is different
    return fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 random_in_unit_disk(inout vec2 seed) {
    float u = rand01(seed);
    float v = rand01(seed); 
    float r = sqrt(u);
    float theta = 6.2831853 * v;
    return vec2(r * cos(theta), r * sin(theta));
}

vec3 random_unit_vector(inout vec2 seed) {
    float z = rand01(seed) * 2.0 - 1.0;
    float a = rand01(seed) * 6.2831853;
    float r = sqrt(max(0.0, 1.0 - z*z));
    return vec3(r * cos(a), r * sin(a), z);
}

vec3 gamma_correct(vec3 c) { return sqrt(c); }

// ---------------- OPTICS ----------------
vec3 reflect_vec(vec3 v, vec3 n) {
    return v - 2.0 * dot(v, n) * n;
}

float schlick(float cosine, float ref_idx) {
    float r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(1.0 - cosine, 5.0);
}

vec3 refract_custom(vec3 uv, vec3 n, float etai_over_etat) {
    float cos_theta = min(dot(-uv, n), 1.0);
    vec3 r_out_perp = etai_over_etat * (uv + cos_theta * n);
    float k = 1.0 - dot(r_out_perp, r_out_perp);
    // If k < 0, total internal reflection (handled in scatter function), 
    // but mathematically we clamp here just in case.
    vec3 r_out_parallel = -sqrt(abs(k)) * n; 
    return r_out_perp + r_out_parallel;
}

// ---------------- GEOMETRY ----------------
float hit_sphere(vec3 center, float radius, vec3 ro, vec3 rd) {
    vec3 oc = ro - center;
    float a = dot(rd, rd);
    float b = 2.0 * dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float disc = b*b - 4.0*a*c;
    
    if (disc < 0.0) return -1.0;
    
    float sqrtD = sqrt(disc);
    float t1 = (-b - sqrtD) / (2.0*a);
    if (t1 > 0.001) return t1;
    
    float t2 = (-b + sqrtD) / (2.0*a);
    if (t2 > 0.001) return t2;
    
    return -1.0;
}

// ---------------- MATERIALS ----------------
bool scatter_lambertian(vec3 rd, vec3 p, vec3 normal, inout vec2 seed, vec3 albedo,
                        out vec3 attenuation, out vec3 scattered)
{
    vec3 scatter_dir = normal + random_unit_vector(seed);
    
    // Catch degenerate scatter direction (very rare)
    if (abs(scatter_dir.x) < 1e-8 && abs(scatter_dir.y) < 1e-8 && abs(scatter_dir.z) < 1e-8)
        scatter_dir = normal;

    scattered = normalize(scatter_dir);
    attenuation = albedo;
    return true;
}

bool scatter_metal(vec3 rd, vec3 p, vec3 normal, inout vec2 seed, vec3 albedo, float fuzz,
                   out vec3 attenuation, out vec3 scattered)
{
    vec3 reflected = reflect_vec(normalize(rd), normal);
    scattered = normalize(reflected + fuzz * random_unit_vector(seed));
    attenuation = albedo;
    return (dot(scattered, normal) > 0.0);
}

bool scatter_dielectric(vec3 rd, vec3 p, vec3 geom_normal, inout vec2 seed, float ref_idx,
                        out vec3 attenuation, out vec3 scattered)
{
    attenuation = vec3(1.0); // Glass absorbs nothing
    vec3 unit_dir = normalize(rd);

    bool front_face = dot(unit_dir, geom_normal) < 0.0;
    vec3 outward_normal = front_face ? geom_normal : -geom_normal;
    float ri = front_face ? (1.0 / ref_idx) : ref_idx;

    float cos_theta = min(dot(-unit_dir, outward_normal), 1.0);
    float sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta));

    bool cannot_refract = (ri * sin_theta > 1.0);
    float reflect_prob = schlick(cos_theta, ri); // Use relative Index here? Actually standard Schlick uses simple approx

    // Simplified Schlick for Ray Tracing in One Weekend usually takes the ref_idx directly 
    // or the ratio depending on implementation. The standard code uses the ratio logic inside Schlick 
    // but here we just pass probabilty.
    // Let's use the explicit Schlick logic:
    // R0 = ((1-ref_idx)/(1+ref_idx))^2 ... this assumes air is 1.0.

    vec3 direction;
    // rand01(seed) updates seed
    if (cannot_refract || (rand01(seed) < reflect_prob))
        direction = reflect_vec(unit_dir, outward_normal);
    else
        direction = refract_custom(unit_dir, outward_normal, ri);

    scattered = normalize(direction);
    return true;
}

// ---------------- MAIN ----------------
void main()
{
    // Initialize seed: Screen Coordinate + Time/Frame variation from C++
    vec2 seed = gl_FragCoord.xy * uSeed;

    // --- Camera Setup ---
    float aspect = WINDOW.x / WINDOW.y;
    float theta = radians(uFOV);
    float h = tan(theta * 0.5);

    // Safety: Prevent focus distance of 0
    float fd = max(uFocusDist, 0.1);

    float viewport_height = 2.0 * h * fd;
    float viewport_width  = viewport_height * aspect;

    vec3 w = normalize(uCameraOrigin - uLookAt);
    vec3 u = normalize(cross(uUp, w));
    vec3 v = cross(w, u);

    vec3 horizontal = viewport_width * u;
    vec3 vertical   = viewport_height * v;
    vec3 lower_left_focus = uCameraOrigin - w * fd - horizontal * 0.5 - vertical * 0.5;

    vec2 pixel_uv = gl_FragCoord.xy / WINDOW;
    vec3 pixel_focus_pos = lower_left_focus + pixel_uv.x * horizontal + pixel_uv.y * vertical;

    // --- Defocus Blur (Depth of Field) ---
    float defocus_radius = fd * tan(radians(uDefocusAngle * 0.5));
    vec3 defocus_disk_u = u * defocus_radius;
    vec3 defocus_disk_v = v * defocus_radius;

    vec3 ro;
    if (uDefocusAngle <= 0.0) {
        ro = uCameraOrigin;
    } else {
        vec2 lens_rnd = random_in_unit_disk(seed);
        ro = uCameraOrigin + lens_rnd.x * defocus_disk_u + lens_rnd.y * defocus_disk_v;
    }

    vec3 rd = normalize(pixel_focus_pos - ro);

    // --- Path Tracing Loop ---
    vec3 throughput = vec3(1.0);
    vec3 final_color = vec3(0.0);

    for (int depth = 0; depth < uMaxDepth; depth++)
    {
        float closest_t = 100000.0; // Infinity
        int hit_id = -1;

        // Iterate all spheres
        for (int i = 0; i < sphere_count; i++)
        {
            float t = hit_sphere(sphere_centers[i], sphere_radii[i], ro, rd);
            if (t > 0.001 && t < closest_t) { 
                closest_t = t; 
                hit_id = i; 
            }
        }

        // --- MISS: Sky Background ---
        if (hit_id == -1) {
            vec3 unit_direction = normalize(rd);
            float tsky = 0.5 * (unit_direction.y + 1.0);
            vec3 sky = mix(vec3(1.0), vec3(0.5, 0.7, 1.0), tsky);
            final_color += throughput * sky;
            break;
        }

        // --- HIT: Scatter ---
        vec3 p = ro + closest_t * rd;
        vec3 geom_normal = normalize(p - sphere_centers[hit_id]);

        int m = sphere_material[hit_id];
        vec3 albedo = sphere_albedo[hit_id];
        float fuzz = sphere_fuzz[hit_id];
        float ref_idx = sphere_ref_idx[hit_id];

        vec3 attenuation;
        vec3 scattered;
        bool ok = false;

        if (m == MAT_LAMBERTIAN)
            ok = scatter_lambertian(rd, p, geom_normal, seed, albedo, attenuation, scattered);
        else if (m == MAT_METAL)
            ok = scatter_metal(rd, p, geom_normal, seed, albedo, fuzz, attenuation, scattered);
        else if (m == MAT_DIELECTRIC)
            ok = scatter_dielectric(rd, p, geom_normal, seed, ref_idx, attenuation, scattered);

        if (!ok) {
            // Absorbed completely (shouldn't happen with these mats)
            final_color += vec3(0.0); 
            break;
        }

        throughput *= attenuation;

        // --- IMPORTANT FIX: Shadow Acne ---
        // Do NOT push along normal. Push along the *scattered* ray.
        // This handles reflection (outwards) and refraction (inwards) correctly.
        ro = p + scattered * 0.001; 
        rd = scattered;
    }

    FragColor = vec4(gamma_correct(final_color), 1.0);
}