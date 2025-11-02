#version 330 core
out vec4 FragColor;
in vec2 fPos;
uniform vec2 WINDOW;
uniform vec2 center;
uniform float radius;


vec2 corrditnateTOndc(vec2 cor){
    float x = (cor.x / WINDOW.x) * 2.0 - 1.0;
    float y = 1.0 - (cor.y / WINDOW.y) * 2.0;

    return vec2 (x,y);
}
float normaliseOne(float r){
    return (r / WINDOW.y) * 2.0;
}
void main() {
     float r2 = normaliseOne(radius);
     vec2 c2 = corrditnateTOndc(center);


    float dist = distance(fPos,c2);
    if (dist <= r2)
        FragColor = vec4(1.0, 0.0, 0.0, 1 -dist / r2); 
    else
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); 
    

    // vec2 color = fPos;
    // float r = (color.x + 1.0) / 2.0;
    // float g = (  1.0-color.y) / 2.0;+
    // float b=    0.0;
    // FragColor = vec4(1.0-fPos.x,0,0, 1.0);


}
