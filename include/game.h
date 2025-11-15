#ifndef GAME_H
#define GAME_H

#include <SDL3/SDL.h>
#include <glad/glad.h>
#include <iostream>
#include "vec.h"       // make sure vec3 is defined here

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
    // --- CAMERA ---
    vec3 cameraPos = vec3(0.0f, 0.0f, 0.0f);   
    float yaw = -90.0f;
    float pitch = 0.0f;
    float moveSpeed = 2.5f;
    float mouseSensitivity = 0.1f;

    // --- MOUSE ---
    bool firstMouse = true;
    float lastX = 0.0f;
    float lastY = 0.0f;

    // --- TIMING ---
    Uint64 lastTime = 0;
    int frameCount = 0;

    // --- SDL + OPENGL ---
    SDL_Window *window = nullptr;
    SDL_GLContext context = nullptr;

    int WINDOW_W, WINDOW_H;
    bool isRunning = false;

    // --- GPU Resources ---
    GLuint shader;
    GLuint vao, vbo, ebo;
};

#endif
