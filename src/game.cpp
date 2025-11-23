#include "game.h"
#include "shader_util.h"
#include <iostream>
#include <random>
#include <vector>
#include <cmath>
#include <ctime> // For initializing random seed

// Ensure Math constants are defined
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#ifndef M_PI_2
#define M_PI_2 1.57079632679489661923
#endif

// --- GLOBALS ---
// CORRECTED: Focus distance must be > 0. 
// 10.0 is a good default (distance from (13,2,3) to (0,0,0) is roughly 13)
float focusDist = 0.0f; 
float seedX = 0.0f;
float seedY = 0.0f;
float defocusAngle = 0.0f; // Slight blur by default (try 0.0 for sharp)
int maxDepth = 6;          // Start lower for better FPS, increase to 8 or 12 for quality
// float threshold = 0.001;

#define MAT_LAMBERTIAN 0
#define MAT_METAL 1
#define MAT_DIELECTRIC 2

// Full-screen quad (2D positions only)
float vertices[] = {
    -1.0f, 1.0f,
    1.0f, 1.0f,
    1.0f, -1.0f,
    -1.0f, -1.0f};

unsigned int indices[] = {0, 1, 2, 2, 3, 0};

Game::Game(int W_W, int W_H)
{
    WINDOW_W = W_W;
    WINDOW_H = W_H;
    // Initialize standard C random seed
    srand(static_cast<unsigned int>(time(0)));
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

    // --- Create VBO / VAO / EBO ---
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glGenBuffers(1, &ebo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // attribute 0 = position (vec2)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(0);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Load Shaders (Ensure these paths are correct relative to your executable)
    shader = LoadShader("shaders/vertex.glsl", "shaders/fragment.glsl");

    // Capture mouse for camera look
    SDL_SetWindowRelativeMouseMode(window, true);

    // Build the final random scene once (deterministic)
    buildFinalScene();

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

        // Mouse look
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
        if (e.type == SDL_EVENT_KEY_DOWN)
        {
            switch (e.key.key)
            {
            case SDLK_UP:
                focusDist += 0.5f; // CORRECTED: Float increment
                break;
            case SDLK_DOWN:
                focusDist -= 0.5f; // CORRECTED: Float decrement
                if (focusDist < 0.1f) focusDist = 0.1f; // Prevent negative focus
                break;
            case SDLK_LEFT:
                defocusAngle -= 0.1f;
                if (defocusAngle < 0.0f) defocusAngle = 0.0f;
                break;
            case SDLK_RIGHT:
                defocusAngle += 0.1f;
                break;
            case SDLK_O:
                maxDepth += 1;
                break;
            case SDLK_P:
                maxDepth -= 1;
                if (maxDepth < 1) maxDepth = 1;
                break;
            // case SDLK_H:
            //     seedX -= threshold;
            //     break;
            // case SDLK_L:
            //     seedX += threshold;
            //     break;
            // case SDLK_K:
            //     seedY += threshold;
            //     break;
            // case SDLK_J:
            //     seedY -= threshold;
            //     break;
            
            case SDLK_ESCAPE:
                isRunning = false;
                break;

            default:
                break;
            }
        }
    }
}

void Game::update()
{
    const bool *keys = SDL_GetKeyboardState(NULL);
    float deltaTime = 0.016f;
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

    // Keyboard movement
    if (keys[SDL_SCANCODE_W])
    {
        cameraPos.x += frontX * velocity;
        cameraPos.y += frontY * velocity;
        cameraPos.z += frontZ * velocity;
    }
    if (keys[SDL_SCANCODE_S])
    {
        cameraPos.x -= frontX * velocity;
        cameraPos.y -= frontY * velocity;
        cameraPos.z -= frontZ * velocity;
    }
    if (keys[SDL_SCANCODE_A])
    {
        // Strafe Left
        cameraPos.x += cosf(yawRad - M_PI_2) * velocity;
        cameraPos.z += sinf(yawRad - M_PI_2) * velocity;
    }
    if (keys[SDL_SCANCODE_D])
    {
        // Strafe Right
        cameraPos.x -= cosf(yawRad - M_PI_2) * velocity;
        cameraPos.z -= sinf(yawRad - M_PI_2) * velocity;
    }

    // FPS counter
    frameCount++;
    static Uint64 fpsTimer = currentTime;
    if (currentTime - fpsTimer >= 1000)
    {
        std::cout << "FPS: " << frameCount
                  << " | Cam: " << cameraPos.x << "," << cameraPos.y << "," << cameraPos.z
                  << " | Focus: " << focusDist 
                  << " | Blur: " << defocusAngle 
                  << " | Depth: " << maxDepth 
                  << " | SEEDX: "<<seedX
                  << " | SEEDY: "<<seedY<< 
                  "\n";
        frameCount = 0;
        fpsTimer = currentTime;
    }
}

void Game::render()
{
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(shader);
    glBindVertexArray(vao);

    // Upload cached scene
    int send_count = scene_count;
    if (send_count > 512)
        send_count = 512; // match shader MAX_SPHERES

    glUniform1i(glGetUniformLocation(shader, "sphere_count"), send_count);
    
    // Send vectors
    if (send_count > 0) {
        glUniform3fv(glGetUniformLocation(shader, "sphere_centers"), send_count, reinterpret_cast<const float *>(scene_centers.data()));
        glUniform1fv(glGetUniformLocation(shader, "sphere_radii"), send_count, scene_radii.data());
        glUniform1iv(glGetUniformLocation(shader, "sphere_material"), send_count, scene_material.data());
        glUniform3fv(glGetUniformLocation(shader, "sphere_albedo"), send_count, reinterpret_cast<const float *>(scene_albedo.data()));
        glUniform1fv(glGetUniformLocation(shader, "sphere_fuzz"), send_count, scene_fuzz.data());
        glUniform1fv(glGetUniformLocation(shader, "sphere_ref_idx"), send_count, scene_ref_idx.data());
    }

    // --- Camera uniforms ---
    float yawRad = yaw * M_PI / 180.0f;
    float pitchRad = pitch * M_PI / 180.0f;
    vec3 forward;
    forward.x = cosf(yawRad) * cosf(pitchRad);
    forward.y = sinf(pitchRad);
    forward.z = sinf(yawRad) * cosf(pitchRad);

    vec3 cameraTarget = cameraPos + forward;

    glUniform3f(glGetUniformLocation(shader, "uCameraOrigin"),
                cameraPos.x, cameraPos.y, cameraPos.z);

    glUniform3f(glGetUniformLocation(shader, "uLookAt"),
                cameraTarget.x, cameraTarget.y, cameraTarget.z);

    glUniform3f(glGetUniformLocation(shader, "uUp"), 0.0f, 1.0f, 0.0f);

    glUniform1f(glGetUniformLocation(shader, "uFOV"), 20.0f); // Default ~20 deg for zoom look
    glUniform1f(glGetUniformLocation(shader, "uFocusDist"), focusDist);
    glUniform1f(glGetUniformLocation(shader, "uDefocusAngle"), defocusAngle);

    // --- CORRECTED: Dynamic Seed Generation ---
    // This ensures the noise pattern changes every frame
    // float r1 = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
    // float r2 = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
    
    // Scale it up so dot product in shader varies significantly
    glUniform2f(glGetUniformLocation(shader, "uSeed"), 0.1, 0.1);

    glUniform1i(glGetUniformLocation(shader, "uMaxDepth"), maxDepth);

    // Frame and Window
    glUniform2f(glGetUniformLocation(shader, "WINDOW"), (float)WINDOW_W, (float)WINDOW_H);

    // Draw fullscreen quad
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    SDL_GL_SwapWindow(window);
}

// Build the final random world once
void Game::buildFinalScene()
{
    scene_centers.clear();
    scene_radii.clear();
    scene_material.clear();
    scene_albedo.clear();
    scene_fuzz.clear();
    scene_ref_idx.clear();

    std::mt19937 rng(1337); // fixed seed => deterministic layout
    std::uniform_real_distribution<float> rnd01(0.0f, 1.0f);

    // 1. Large Ground Sphere
    scene_centers.emplace_back(0.0f, -1000.0f, 0.0f);
    scene_radii.push_back(1000.0f);
    scene_material.push_back(MAT_LAMBERTIAN);
    scene_albedo.emplace_back(0.5f, 0.5f, 0.5f);
    scene_fuzz.push_back(0.0f);
    scene_ref_idx.push_back(0.0f);

    // 2. Small Random Spheres
    for (int a = -11; a < 11; ++a)
    {
        for (int b = -11; b < 11; ++b)
        {
            float choose_mat = rnd01(rng);
            float cx = a + 0.9f * rnd01(rng);
            float cz = b + 0.9f * rnd01(rng);
            vec3 center(cx, 0.2f, cz);

            // Avoid intersecting the big 3 spheres in the center
            if (length(center - vec3(4.0f, 0.2f, 0.0f)) <= 0.9f) continue;
            if (length(center - vec3(0.0f, 0.2f, 0.0f)) <= 0.9f) continue;
            if (length(center - vec3(-4.0f, 0.2f, 0.0f)) <= 0.9f) continue;

            if (choose_mat < 0.8f)
            {
                // Diffuse
                scene_material.push_back(MAT_LAMBERTIAN);
                vec3 acol(rnd01(rng) * rnd01(rng), rnd01(rng) * rnd01(rng), rnd01(rng) * rnd01(rng));
                scene_albedo.push_back(acol);
                scene_fuzz.push_back(0.0f);
                scene_ref_idx.push_back(0.0f);
                scene_centers.push_back(center);
                scene_radii.push_back(0.2f);
            }
            else if (choose_mat < 0.95f)
            {
                // Metal
                scene_material.push_back(MAT_METAL);
                vec3 acol(0.5f + 0.5f * rnd01(rng), 0.5f + 0.5f * rnd01(rng), 0.5f + 0.5f * rnd01(rng));
                scene_albedo.push_back(acol);
                scene_fuzz.push_back(0.5f * rnd01(rng));
                scene_ref_idx.push_back(0.0f);
                scene_centers.push_back(center);
                scene_radii.push_back(0.2f);
            }
            else
            {
                // Glass
                scene_material.push_back(MAT_DIELECTRIC);
                scene_albedo.push_back(vec3(1.0f, 1.0f, 1.0f));
                scene_fuzz.push_back(0.0f);
                scene_ref_idx.push_back(1.5f);
                scene_centers.push_back(center);
                scene_radii.push_back(0.2f);
            }
        }
    }

    // 3. Three Main Big Spheres
    
    // Middle: Glass
    scene_centers.push_back(vec3(0.0f, 1.0f, 0.0f));
    scene_radii.push_back(1.0f);
    scene_material.push_back(MAT_DIELECTRIC);
    scene_albedo.push_back(vec3(1.0f, 1.0f, 1.0f));
    scene_fuzz.push_back(0.0f);
    scene_ref_idx.push_back(1.5f);

    // Left: Lambertian (Matte)
    scene_centers.push_back(vec3(-4.0f, 1.0f, 0.0f));
    scene_radii.push_back(1.0f);
    scene_material.push_back(MAT_LAMBERTIAN);
    scene_albedo.push_back(vec3(0.4f, 0.2f, 0.1f));
    scene_fuzz.push_back(0.0f);
    scene_ref_idx.push_back(0.0f);

    // Right: Metal
    scene_centers.push_back(vec3(4.0f, 1.0f, 0.0f));
    scene_radii.push_back(1.0f);
    scene_material.push_back(MAT_METAL);
    scene_albedo.push_back(vec3(0.7f, 0.6f, 0.5f));
    scene_fuzz.push_back(0.0f);
    scene_ref_idx.push_back(0.0f);

    scene_count = (int)scene_centers.size();
}