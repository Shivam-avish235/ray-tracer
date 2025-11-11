#ifndef CAMERA_H
#define CAMERA_H

#include "vec.h"
#include <glad/glad.h>

class Camera {
public:
    float aspect_ratio = 16.0f / 9.0f;
    float viewport_height = 2.0f;
    float focal_length = 1.0f;

    vec3 origin = {0.0f, 0.0f, 0.0f};
    float yaw = 0.0f;
    float pitch = 0.0f;

    void setWindowSize(int width, int height);
    void uploadToShader(GLuint shader) const;

private:
    float viewport_width = 0.0f;
    int window_width = 0;
    int window_height = 0;
};

#endif // CAMERA_H
