#ifndef GAME_H
#define GAME_H

#include <SDL3/SDL.h>
#include <glad/glad.h>
#include <iostream>

class Game
{
public:
    Game(int W_W, int W_H);
    ~Game();

    bool init(const char *title);
    void handleEvent();
    void update();
    void render();
    bool running() { return isRunning; }

private:
    float cameraX = 0.0f;
    float cameraY = 0.0f;
    float cameraZ = 0.0f;
    float yaw = -90.0f;   // facing -Z
    float pitch = 0.0f;
    float moveSpeed = 2.5f;
    float mouseSensitivity = 0.1f;
    bool firstMouse = true;
    float lastX = 0.0f, lastY = 0.0f;
    Uint64 lastTime = 0;
    int frameCount = 0;

    SDL_Window *window = nullptr;
    SDL_GLContext context = nullptr;
    int WINDOW_W, WINDOW_H;

    bool isRunning = false;

    GLuint shader;      // Store the shader program
    GLuint vao, vbo, ebo; // Store OpenGL resources
};

#endif
