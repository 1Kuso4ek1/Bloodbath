FPSController@ player;
Clock delay, buttonTimer;
TcpSocket socket;
tgui::Gui@ menu, hud, pauseMenu;
int fps = 30;
int health = 100; //In future, get health from the server
//Clock fpsClock, bleedingClock;
bool pause = false;

funcdef void GameLoop();

GameLoop@ currentLoop = @menuLoop;/*@mainGameLoop;*/

float lerp(float x, float y, float t)
{
    return x * (1.0 - t) + y * t;
}

void Loop()
{
    currentLoop();
}
