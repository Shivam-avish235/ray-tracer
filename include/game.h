#ifndef GAME_H
#define GAME_H

#include <SDL3/SDL.h>
#include <glad/glad.h>
#include <iostream>
#include <vector>
#include "vec.h"

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

    // -------------------
    // CAMERA DATA
    // -------------------
    vec3 cameraPos = vec3(0.0f, 0.0f, 3.0f);
    float yaw = -90.0f;
    float pitch = 0.0f;
    float moveSpeed = 3.0f;
    float mouseSensitivity = 0.1f;

    // -------------------
    // TIME
    // -------------------
    Uint64 lastTime = 0;
    int frameCount = 0;

    // -------------------
    // SDL
    // -------------------
    SDL_Window *window = nullptr;
    SDL_GLContext context = nullptr;

    int WINDOW_W;
    int WINDOW_H;
    bool isRunning = false;

    // -------------------
    // OpenGL Resources
    // -------------------
    GLuint shader = 0;
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint ebo = 0;

    // -------------------
    // Scene storage (built once)
    // -------------------
    void buildFinalScene();
    int scene_count = 0;
    std::vector<vec3> scene_centers;
    std::vector<float> scene_radii;
    std::vector<int> scene_material;
    std::vector<vec3> scene_albedo;
    std::vector<float> scene_fuzz;
    std::vector<float> scene_ref_idx;
};

#endif
