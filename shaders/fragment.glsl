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





vec2 corrditnateTOndc(vec2 cor){
    float x = (cor.x / WINDOW.x) * 2.0 - 1.0;
    float y = 1.0 - (cor.y / WINDOW.y) * 2.0;

    return vec2 (x,y);
}
float normaliseOne(float r){
    return (r / WINDOW.y) * 2.0;
}


void main() {

    float aspect_ratio = WINDOW.x / WINDOW.y;
    float viewport_width = uViewportHeight * aspect_ratio;

    vec3 horizontal = vec3(viewport_width, 0.0, 0.0);
    vec3 vertical   = vec3(0.0, -uViewportHeight, 0.0);
    vec3 lower_left = uCameraOrigin
                    - horizontal / 2.0
                    - vertical / 2.0
                    - vec3(0.0, 0.0, uFocalLength);


    vec2 ndc = corrditnateTOndc(gl_FragCoord.xy);
    vec2 uv = (ndc + 1.0) * 0.5;


    vec3 ray_dir = lower_left + uv.x * horizontal + uv.y * vertical - uCameraOrigin;
    ray_dir = normalize(ray_dir);


    float t = 0.5 * (ray_dir.y + 1.0);
    vec3 color = mix(vec3(1.0, 1.0, 1.0), vec3(0.5, 0.7, 1.0), t);
    FragColor = vec4(color, 1.0);


    // float r2 = normaliseOne(radius);
    // vec2 c2 = corrditnateTOndc(center);


    // float dist = distance(fPos,c2);
    // if (dist <= r2)
    //     FragColor = vec4(1.0, 0.0, 0.0, 1.0); 
    // else
    //     FragColor = vec4(0.0, 0.0, 0.0, 1.0); 

    // float t = (fPos.y + 1.0) / 2.0;
    // vec3 color = mix(vec3(1.0, 1.0, 1.0), vec3(0.5, 0.7, 1.0), t);
    // FragColor = vec4(color, 2.0);




}
