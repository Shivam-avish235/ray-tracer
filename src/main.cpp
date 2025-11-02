#include"game.h"

Game game(720, 720);

int main()
{

    if(!game.init("my title")){
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