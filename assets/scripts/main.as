FPSController@ player;
Clock delay, buttonTimer;
TcpSocket socket;
tgui::Gui@ menu, hud, pauseMenu;
int health = 100; //In future, get health from the server
Clock physicsTime;
bool pause = false, updateCam = true;

funcdef void GameLoop();

GameLoop@ currentLoop = @menuLoop;/*@mainGameLoop;*/

float lerp(float x, float y, float t)
{
    return x * (1.0 - t) + y * t;
}

Vector3 lerp(Vector3 v, Vector3 v1, float t)
{
    return Vector3(lerp(v.x, v1.x, t), lerp(v.y, v1.y, t), lerp(v.z, v1.z, t));
}

void Loop()
{
    if(physicsTime.getElapsedTime().asSeconds() < (1.0 / 60.0))
    {
        Game::scene.UpdatePhysics(false);
        updateCam = false;
    }
    else
    {
        Game::scene.UpdatePhysics(true);
        updateCam = true;
        physicsTime.restart();
    }

    currentLoop();
}
