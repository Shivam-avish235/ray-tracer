#include "camera.h"

void Camera::setWindowSize(int width, int height) {
    window_width = width;
    window_height = height;
    aspect_ratio = static_cast<float>(width) / static_cast<float>(height);
    viewport_width = viewport_height * aspect_ratio;
}

void Camera::uploadToShader(GLuint shader) const {
    glUniform3f(glGetUniformLocation(shader, "uCameraOrigin"),
                origin.x, origin.y, origin.z);
    glUniform1f(glGetUniformLocation(shader, "uViewportHeight"), viewport_height);
    glUniform1f(glGetUniformLocation(shader, "uFocalLength"), focal_length);
    glUniform1f(glGetUniformLocation(shader, "uYaw"), yaw);
    glUniform1f(glGetUniformLocation(shader, "uPitch"), pitch);
}
