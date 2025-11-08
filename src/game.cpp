#include "game.h"
#include "shader_util.h"
#include <iostream>

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
    if (SDL_Init(SDL_INIT_VIDEO) == 0)
    {
        return false;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    SDL_SetHint(SDL_HINT_VIDEO_WAYLAND_ALLOW_LIBDECOR, "0");

    window = SDL_CreateWindow(title, WINDOW_W, WINDOW_H, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!window)
    {
        return false;
    }

    context = SDL_GL_CreateContext(window);
    SDL_GL_MakeCurrent(window, context);

    if (!gladLoadGLLoader((GLADloadproc)SDL_GL_GetProcAddress))
    {
        std::cerr << "Failed to initialize GLAD\n";
        return false;
    }

    // Create the vertex buffer and array objects
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
    // glEnable(GL_BLEND);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    shader = LoadShader("shaders/vertex.glsl", "shaders/fragment.glsl");

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
    }
}

void Game::update()
{
}

void Game::render()
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(shader);
    glBindVertexArray(vao);

    glUniform2f(glGetUniformLocation(shader,"WINDOW"),(float)WINDOW_W, (float)WINDOW_H);
    glUniform2f(glGetUniformLocation(shader,"center"),360.0f, 360.0f);
    glUniform1f(glGetUniformLocation(shader,"radius"),300.0f);

    glUniform2f(glGetUniformLocation(shader, "WINDOW"), (float)WINDOW_W, (float)WINDOW_H);
    glUniform3f(glGetUniformLocation(shader, "uCameraOrigin"), 0.0f, 0.0f, 0.0f);
    glUniform1f(glGetUniformLocation(shader, "uViewportHeight"), 2.0f);
    glUniform1f(glGetUniformLocation(shader, "uFocalLength"), 1.0f);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

    SDL_GL_SwapWindow(window); // Swap buffers

    SDL_Delay(16);
}
