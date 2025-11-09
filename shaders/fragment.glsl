#version 330 core
out vec4 FragColor;
in vec2 fPos;
uniform vec2 WINDOW;
uniform vec2 center;
uniform float radius;
uniform vec2 uResolution;
uniform vec3 uCameraOrigin;
uniform float uViewportHeight;
uniform float uFocalLength;


// Convert window pixel coordinates to NDC 
vec2 corrditnateTOndc(vec2 cor) {
    float x = (cor.x / WINDOW.x) * 2.0 - 1.0;
    float y = 1.0 - (cor.y / WINDOW.y) * 2.0;
    return vec2(x, y);
}


// Normalize a length
float normaliseOne(float r){
    return (r / WINDOW.y) * 2.0;
}


//  Ray-sphere intersection function
float hit_sphere(vec3 center, float radius, vec3 ray_origin, vec3 ray_dir) {
    vec3 oc = ray_origin - center;
    float a = dot(ray_dir, ray_dir);
    float b = 2.0 * dot(oc, ray_dir);
    float c = dot(oc, oc) - radius * radius;
    float discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0)
        return -1.0;  
    else
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



  // --- Convert pixel coordinates to NDC and UV ---

    vec2 ndc = corrditnateTOndc(gl_FragCoord.xy);
    vec2 uv = (ndc + 1.0) * 0.5;



    // --- Generate ray direction ---
    vec3 ray_dir = lower_left + uv.x * horizontal + uv.y * vertical - uCameraOrigin;
    ray_dir = normalize(ray_dir);




    // --- Sphere setup ---
    vec3 sphere_center = vec3(0.0, 0.0, -1.0);
    float radius = 0.5;


    // --- Compute intersection ---

float t_sphere = hit_sphere(sphere_center, radius, uCameraOrigin, ray_dir);



if (t_sphere > 0.0) {
    // Compute hit point
    vec3 hit_point = uCameraOrigin + t_sphere * ray_dir;

    // Compute surface normal
    vec3 normal = normalize(hit_point - sphere_center);

    // Map normal [-1, 1] to [0, 1] for color display
    vec3 color = 0.5 * (normal + vec3(1.0));

    FragColor = vec4(color, 1.0);
} 
else {
    float t = 0.5 * (ray_dir.y + 1.0);
    vec3 color = mix(vec3(1.0), vec3(0.5, 0.7, 1.0), t);
    FragColor = vec4(color, 1.0);
}

}
