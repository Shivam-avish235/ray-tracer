#include "game.h"
#include "shader_util.h"
#include <iostream>
#include "vec.h"
#include <cmath> // for cosf(), sinf(), etc.

// Define math constants if not provided by your compiler
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#ifndef M_PI_2
#define M_PI_2 1.57079632679489661923
#endif

float vertices[] = {
    -1.0f, 1.0f, // top-left
    1.0f, 1.0f,  // top-right
    1.0f, -1.0f, // bottom-right
    -1.0f, -1.0f // bottom-left
};

unsigned int indices[] = {0, 1, 2, 2, 3, 0};

Game::Game(int W_W, int W_H)
{
    WINDOW_H = W_H;
    WINDOW_W = W_W;
}

Game::~Game() {}

bool Game::init(const char *title)
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) == 0)
    {
        std::cerr << "SDL Init failed: " << SDL_GetError() << "\n";
        return false;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    // Disable libdecor warning under Wayland
    SDL_SetHint(SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR, "0");

    window = SDL_CreateWindow(title, WINDOW_W, WINDOW_H, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!window)
    {
        std::cerr << "Failed to create SDL window: " << SDL_GetError() << "\n";
        return false;
    }

    context = SDL_GL_CreateContext(window);
    SDL_GL_MakeCurrent(window, context);

    if (!gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress))
    {
        std::cerr << "Failed to initialize GLAD\n";
        return false;
    }

    // --- Create the vertex buffer and array objects ---
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glGenBuffers(1, &ebo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(0);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    shader = LoadShader("shaders/vertex.glsl", "shaders/fragment.glsl");

    // Capture mouse for camera look (SDL3)
    SDL_SetWindowRelativeMouseMode(window, true);

    lastTime = SDL_GetTicks();
    frameCount = 0;
    isRunning = true;
    return true;
}

void Game::handleEvent()
{
    SDL_Event e;
    while (SDL_PollEvent(&e))
    {
        if (e.type == SDL_EVENT_QUIT)
        {
            isRunning = false;
        }

        // --- Mouse look (yaw/pitch) ---
        if (e.type == SDL_EVENT_MOUSE_MOTION)
        {
            float xoffset = e.motion.xrel * mouseSensitivity;
            float yoffset = -e.motion.yrel * mouseSensitivity; // invert Y

            yaw += xoffset;
            pitch += yoffset;

            if (pitch > 89.0f)
                pitch = 89.0f;
            if (pitch < -89.0f)
                pitch = -89.0f;
        }
    }
}

void Game::update()
{
    const bool *keys = SDL_GetKeyboardState(NULL);
    float deltaTime = 0.016f; // default 60 FPS fallback
    static Uint64 prevTime = SDL_GetTicks();
    Uint64 currentTime = SDL_GetTicks();
    deltaTime = (currentTime - prevTime) / 1000.0f;
    prevTime = currentTime;

    float velocity = moveSpeed * deltaTime;
    float yawRad = yaw * M_PI / 180.0f;
    float pitchRad = pitch * M_PI / 180.0f;

    float frontX = cosf(yawRad) * cosf(pitchRad);
    float frontY = sinf(pitchRad);
    float frontZ = sinf(yawRad) * cosf(pitchRad);

    // --- Keyboard movement ---
    if (keys[SDL_SCANCODE_W])
    {
        cameraX += frontX * velocity;
        cameraY += frontY * velocity;
        cameraZ += frontZ * velocity;
    }
    if (keys[SDL_SCANCODE_S])
    {
        cameraX -= frontX * velocity;
        cameraY -= frontY * velocity;
        cameraZ -= frontZ * velocity;
    }
    if (keys[SDL_SCANCODE_A])
    {
        cameraX -= cosf(yawRad - M_PI_2) * velocity;
        cameraZ -= sinf(yawRad - M_PI_2) * velocity;
    }
    if (keys[SDL_SCANCODE_D])
    {
        cameraX += cosf(yawRad - M_PI_2) * velocity;
        cameraZ += sinf(yawRad - M_PI_2) * velocity;
    }

    // --- FPS Counter ---
    frameCount++;
    static Uint64 fpsTimer = currentTime;
    if (currentTime - fpsTimer >= 1000)
    {
        std::cout << "FPS: " << frameCount
                  << " | Camera: (" << cameraX << ", " << cameraY << ", " << cameraZ << ")"
                  << " | Yaw: " << yaw << " | Pitch: " << pitch << "\n";
        frameCount = 0;
        fpsTimer = currentTime;
    }
}

void Game::render()
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(shader);
    glBindVertexArray(vao);
    vec3 centers[] = {
        {0.0f, 0.0f, -1.0f},   // main sphere
        {0.0f, -100.5f, -1.0f} // ground sphere
    };
    float radii[] = {0.5f, 100.0f};

    glUniform1i(glGetUniformLocation(shader, "sphere_count"), 2);
    glUniform3fv(glGetUniformLocation(shader, "sphere_centers"), 2, (float *)centers);
    glUniform1fv(glGetUniformLocation(shader, "sphere_radii"), 2, radii);

    glUniform2f(glGetUniformLocation(shader, "WINDOW"), (float)WINDOW_W, (float)WINDOW_H);
 

    // --- Camera uniforms ---
    glUniform3f(glGetUniformLocation(shader, "uCameraOrigin"), cameraX, cameraY, cameraZ);
    glUniform1f(glGetUniformLocation(shader, "uViewportHeight"), 2.0f);
    glUniform1f(glGetUniformLocation(shader, "uFocalLength"), 1.0f);
    glUniform1f(glGetUniformLocation(shader, "uYaw"), yaw);
    glUniform1f(glGetUniformLocation(shader, "uPitch"), pitch);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    SDL_GL_SwapWindow(window);
}
