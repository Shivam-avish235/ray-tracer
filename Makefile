all:
	g++ src/*.cpp src/glad.c -I/usr/local/include -L/usr/local/lib -Iinclude -lSDL3  -lGL -o app
