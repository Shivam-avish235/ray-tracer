#version 330 core
out vec4 FragColor;

uniform vec2 WINDOW;
uniform vec3 uCameraOrigin;
uniform float uViewportHeight;
uniform float uFocalLength;
uniform float uFrame;

#define MAX_SPHERES 32
#define MAX_DEPTH 32

// Material types
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

// ---------------- Random ----------------
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Random direction on sphere
vec3 random_unit_vector(vec2 seed) {
    float z = rand(seed * 0.37) * 2.0 - 1.0;
    float a = rand(seed * 1.79) * 6.2831853;
    float r = sqrt(max(0.0, 1.0 - z*z));
    return vec3(r * cos(a), r * sin(a), z);
}

// Gamma correction
vec3 gamma_correct(vec3 c) {
    return sqrt(c);
}

// Reflection
vec3 reflect_vec(vec3 v, vec3 n)
{
    return v - 2.0 * dot(v, n) * n;
}

// Schlick approx
float schlick(float cosine, float ref_idx){
    float r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
    r0 *= r0;
    return r0 + (1.0 - r0) * pow(1.0 - cosine, 5.0);
}

float hit_sphere(vec3 center, float radius, vec3 ro, vec3 rd)
{
    vec3 oc = ro - center;
    float a = dot(rd, rd);
    float b = 2.0 * dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float d = b*b - 4.0*a*c;
    if (d < 0.0) return -1.0;
    return (-b - sqrt(d)) / (2.0*a);
}

// Lambert scatter
bool scatter_lambertian(vec3 rd, vec3 p, vec3 normal, vec2 seed, vec3 albedo,
                        out vec3 attenuation, out vec3 scattered)
{
    scattered = normalize(normal + random_unit_vector(seed));
    attenuation = albedo;
    return true;
}

// Metal scatter
bool scatter_metal(vec3 rd, vec3 p, vec3 normal, vec2 seed, vec3 albedo, float fuzz,
                   out vec3 attenuation, out vec3 scattered)
{
    vec3 reflected = reflect_vec(normalize(rd), normal);
    scattered = normalize(reflected + fuzz * random_unit_vector(seed));
    attenuation = albedo;
    return (dot(scattered, normal) > 0.0);
}

// Glass scatter
bool scatter_dielectric(vec3 rd, vec3 p, vec3 normal, vec2 seed, float ref_idx,
                        out vec3 attenuation, out vec3 scattered)
{
    attenuation = vec3(1.0);
    vec3 unit_dir = normalize(rd);

    float dt = dot(unit_dir, normal);
    vec3 outward_normal;
    float ni_over_nt;
    float cosine;

    if (dt > 0.0) {
        outward_normal = -normal;
        ni_over_nt = ref_idx;
        cosine = ref_idx * dt;
    } else {
        outward_normal = normal;
        ni_over_nt = 1.0 / ref_idx;
        cosine = -dt;
    }

    vec3 refracted = refract(unit_dir, outward_normal, ni_over_nt);
    float reflect_prob;

    if (length(refracted) > 0.001)
        reflect_prob = schlick(cosine, ref_idx);
    else
        reflect_prob = 1.0;

    if (rand(seed) < reflect_prob)
        scattered = reflect_vec(unit_dir, normal);
    else
        scattered = refracted;

    return true;
}

// ---------------- Main ----------------
void main()
{
    float aspect = WINDOW.x / WINDOW.y;
    float viewport_width = uViewportHeight * aspect;

    vec3 horizontal = vec3(viewport_width, 0.0, 0.0);
    vec3 vertical   = vec3(0.0, uViewportHeight, 0.0);
    vec3 lower_left = uCameraOrigin
                    - horizontal * 0.5
                    - vertical * 0.5
                    - vec3(0, 0, uFocalLength);

    vec2 uv = (gl_FragCoord.xy / WINDOW) ;
    vec3 ro = uCameraOrigin;
    vec3 rd = normalize(lower_left + uv.x * horizontal + uv.y * vertical - uCameraOrigin);

    vec3 throughput = vec3(1.0);
    vec3 final_color = vec3(0.0);

    for (int depth = 0; depth < MAX_DEPTH; depth++)
    {
        float closest_t = 1e9;
        int hit_id = -1;

        for (int i = 0; i < sphere_count; i++)
        {
            float t = hit_sphere(sphere_centers[i], sphere_radii[i], ro, rd);
            if (t > 0.001 && t < closest_t)
            {
                closest_t = t;
                hit_id = i;
            }
        }

        if (hit_id == -1)
        {
            float t = 0.5 * (rd.y + 1.0);
            vec3 sky = mix(vec3(1.0), vec3(0.5, 0.7, 1.0), t);
            final_color += throughput * sky;
            break;
        }

        vec3 p = ro + closest_t * rd;
        vec3 normal = normalize(p - sphere_centers[hit_id]);
        if (dot(rd, normal) > 0.0) normal = -normal;

        int m = sphere_material[hit_id];
        vec3 albedo = sphere_albedo[hit_id];
        float fuzz = sphere_fuzz[hit_id];
        float ref_idx = sphere_ref_idx[hit_id];

        vec3 attenuation, scattered;
        vec2 seed = gl_FragCoord.xy + vec2(depth * 37.12 + uFrame * 12.98);

        bool ok = false;
        if (m == MAT_LAMBERTIAN)
            ok = scatter_lambertian(rd, p, normal, seed, albedo, attenuation, scattered);
        else if (m == MAT_METAL)
            ok = scatter_metal(rd, p, normal, seed, albedo, fuzz, attenuation, scattered);
        else
            ok = scatter_dielectric(rd, p, normal, seed, ref_idx, attenuation, scattered);

        if (!ok) break;

        throughput *= attenuation;
        ro = p + normal * 0.001;
        rd = scattered;
    }

    FragColor = vec4(gamma_correct(final_color), 1.0);
}
