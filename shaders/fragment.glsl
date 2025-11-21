#version 330 core
out vec4 FragColor;

uniform vec2 WINDOW;
uniform float uFrame;

// BOOK camera uniforms
uniform vec3 uCameraOrigin;
uniform vec3 uLookAt;
uniform vec3 uUp;
uniform float uFOV;

// Defocus blur (Chapter 13)
uniform float uDefocusAngle; // degrees, 0 => no defocus
uniform float uFocusDist;    // distance from camera origin to focus plane

#define MAX_SPHERES 512
#define MAX_DEPTH 32

#define MAT_LAMBERTIAN 0
#define MAT_METAL 1
#define MAT_DIELECTRIC 2

uniform int sphere_material[MAX_SPHERES];
uniform vec3 sphere_albedo[MAX_SPHERES];
uniform float sphere_fuzz[MAX_SPHERES];
uniform float sphere_ref_idx[MAX_SPHERES];

uniform int sphere_count;
uniform vec3 sphere_centers[MAX_SPHERES];
uniform float sphere_radii[MAX_SPHERES];

// ---------------- Random helpers ----------------
float rand01(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// concentric mapping from two random numbers to disk (deterministic sample)
vec2 random_in_unit_disk(vec2 seed) {
    float u = rand01(seed);
    float v = rand01(seed + vec2(1.37,3.91));
    float r = sqrt(u);
    float theta = 6.283185307179586 * v;
    return vec2(r * cos(theta), r * sin(theta));
}

vec3 random_unit_vector(vec2 seed) {
    float z = rand01(seed) * 2.0 - 1.0;
    float a = rand01(seed * 1.79) * 6.283185307179586;
    float r = sqrt(max(0.0, 1.0 - z*z));
    return vec3(r * cos(a), r * sin(a), z);
}

vec3 gamma_correct(vec3 c) { return sqrt(c); }

// ---------------- Reflection / Refraction ----------------
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
    k = max(k, 0.0);
    vec3 r_out_parallel = -sqrt(k) * n;
    return r_out_perp + r_out_parallel;
}

// ---------------- Geometry ----------------
// returns nearest positive t > eps or -1.0
float hit_sphere(vec3 center, float radius, vec3 ro, vec3 rd) {
    vec3 oc = ro - center;
    float a = dot(rd, rd);
    float b = 2.0 * dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float disc = b*b - 4.0*a*c;
    if (disc < 0.0) return -1.0;
    float sqrtD = sqrt(disc);
    float t1 = (-b - sqrtD) / (2.0*a);
    float t2 = (-b + sqrtD) / (2.0*a);
    float eps = 0.001;
    if (t1 > eps) return t1;
    if (t2 > eps) return t2;
    return -1.0;
}

// ---------------- Materials ----------------
bool scatter_lambertian(vec3 rd, vec3 p, vec3 normal, vec2 seed, vec3 albedo,
                        out vec3 attenuation, out vec3 scattered)
{
    scattered = normalize(normal + random_unit_vector(seed));
    attenuation = albedo;
    return true;
}

bool scatter_metal(vec3 rd, vec3 p, vec3 normal, vec2 seed, vec3 albedo, float fuzz,
                   out vec3 attenuation, out vec3 scattered)
{
    vec3 reflected = reflect_vec(normalize(rd), normal);
    scattered = normalize(reflected + fuzz * random_unit_vector(seed));
    attenuation = albedo;
    return (dot(scattered, normal) > 0.0);
}

bool scatter_dielectric(vec3 rd, vec3 p, vec3 geom_normal, vec2 seed, float ref_idx,
                        out vec3 attenuation, out vec3 scattered)
{
    attenuation = vec3(1.0);
    vec3 unit_dir = normalize(rd);

    bool front_face = dot(unit_dir, geom_normal) < 0.0;
    vec3 outward_normal = front_face ? geom_normal : -geom_normal;
    float ri = front_face ? (1.0 / ref_idx) : ref_idx;

    float cos_theta = min(dot(-unit_dir, outward_normal), 1.0);
    float sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta));

    bool cannot_refract = (ri * sin_theta > 1.0);
    float reflect_prob = schlick(cos_theta, ref_idx);

    vec3 direction;
    if (cannot_refract || (rand01(seed) < reflect_prob))
        direction = reflect_vec(unit_dir, outward_normal);
    else
        direction = refract_custom(unit_dir, outward_normal, ri);

    scattered = normalize(direction);
    return true;
}

// ---------------- Main ----------------
void main()
{
    // ---------- Camera (book) ----------
    float aspect = WINDOW.x / WINDOW.y;
    float theta = radians(uFOV);
    float h = tan(theta * 0.5);

    // viewport defined on the focus plane (distance = uFocusDist)
    float viewport_height = 2.0 * h * uFocusDist;
    float viewport_width  = viewport_height * aspect;

    vec3 w = normalize(uCameraOrigin - uLookAt); // backwards
    vec3 u = normalize(cross(uUp, w));           // right
    vec3 v = cross(w, u);                        // up

    vec3 horizontal = viewport_width * u;
    vec3 vertical   = viewport_height * v;

    vec3 lower_left_focus = uCameraOrigin - w * uFocusDist - horizontal * 0.5 - vertical * 0.5;

    vec2 pixel_uv = gl_FragCoord.xy / WINDOW;

    vec3 pixel_focus_pos = lower_left_focus + pixel_uv.x * horizontal + pixel_uv.y * vertical;

    // compute defocus disk basis (book)
    float defocus_radius = uFocusDist * tan(radians(uDefocusAngle * 0.5));
    vec3 defocus_disk_u = u * defocus_radius;
    vec3 defocus_disk_v = v * defocus_radius;

    // deterministic sample on lens per pixel (no uFrame jitter)
    vec2 lens_rnd = random_in_unit_disk(gl_FragCoord.xy * vec2(12.9898,78.233));
    vec3 ro;
    if (uDefocusAngle <= 0.0) {
        ro = uCameraOrigin; // pinhole camera
    } else {
        ro = uCameraOrigin + lens_rnd.x * defocus_disk_u + lens_rnd.y * defocus_disk_v;
    }

    vec3 rd = normalize(pixel_focus_pos - ro);

    // ---------- Path-trace loop ----------
    vec3 throughput = vec3(1.0);
    vec3 final_color = vec3(0.0);

    for (int depth = 0; depth < MAX_DEPTH; depth++)
    {
        float closest_t = 1e9;
        int hit_id = -1;
        for (int i = 0; i < sphere_count; i++)
        {
            float t = hit_sphere(sphere_centers[i], sphere_radii[i], ro, rd);
            if (t > 0.001 && t < closest_t) { closest_t = t; hit_id = i; }
        }

        if (hit_id == -1) {
            float tsky = 0.5 * (rd.y + 1.0);
            vec3 sky = mix(vec3(1.0), vec3(0.5,0.7,1.0), tsky);
            final_color += throughput * sky;
            break;
        }

        vec3 p = ro + closest_t * rd;
        vec3 geom_normal = normalize(p - sphere_centers[hit_id]);

        int m = sphere_material[hit_id];
        vec3 albedo = sphere_albedo[hit_id];
        float fuzz = sphere_fuzz[hit_id];
        float ref_idx = sphere_ref_idx[hit_id];

        vec3 attenuation, scattered;
        vec2 seed = gl_FragCoord.xy + vec2(float(depth) * 37.12 + uFrame * 12.98);

        bool ok = false;
        if (m == MAT_LAMBERTIAN)
            ok = scatter_lambertian(rd, p, geom_normal, seed, albedo, attenuation, scattered);
        else if (m == MAT_METAL)
            ok = scatter_metal(rd, p, geom_normal, seed, albedo, fuzz, attenuation, scattered);
        else
            ok = scatter_dielectric(rd, p, geom_normal, seed, ref_idx, attenuation, scattered);

        if (!ok) break;

        throughput *= attenuation;
        ro = p + geom_normal * 0.001;
        rd = scattered;
    }

    FragColor = vec4(gamma_correct(final_color), 1.0);
}
