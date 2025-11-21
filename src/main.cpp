#include"game.h"

Game game(1080, 720);

int main()
{

    if(!game.init("Ray tracer")){
        return -1;
    }

    while (game.running())
    {
        game.handleEvent();
        game.update();
        game.render();
    }
    

    return 0;
}