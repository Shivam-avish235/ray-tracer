#ifndef GAME_H
#define GAME_H

#include <SDL3/SDL.h>
#include <glad/glad.h>
#include <iostream>

class Game{

    public:
        Game(int W_W, int W_H);
        ~Game();

        bool init(const char * title);
        void handleEvent();
        void update();
        void render();
        bool running(){
            return isRunning;
        }

    private:


    SDL_Window * window;
    SDL_GLContext context;
    int WINDOW_W, WINDOW_H;

    bool isRunning;

    GLuint shader;  // Store the shader program
    GLuint vao, vbo, ebo;  // Store OpenGL resources
};  


#endif