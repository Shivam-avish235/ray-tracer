#include "shader_util.h"
#include <fstream>
#include <sstream>
#include <iostream>

GLuint LoadShader(const char* vertexPath, const char* fragmentPath) {
    std::ifstream vFile(vertexPath), fFile(fragmentPath);
    std::stringstream vStream, fStream;
    vStream << vFile.rdbuf();
    fStream << fFile.rdbuf();
    std::string vCode = vStream.str(), fCode = fStream.str();
    const char* vSource = vCode.c_str(), *fSource = fCode.c_str();

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vSource, nullptr);
    glCompileShader(vertexShader);

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fSource, nullptr);
    glCompileShader(fragmentShader);

    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    return program;
}
