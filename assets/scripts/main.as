FPSController@ player;
Clock delay;
TcpSocket socket;
tgui::Gui@ hud;
int fps = 30;
int health = 100; //In future, get health from the server
Clock fpsClock;//, bleedingClock;
bool pause = false;

float lerp(float x, float y, float t)
{
    return x * (1.0 - t) + y * t;
}

void Loop()
{
    if(fpsClock.getElapsedTime().asSeconds() >= 1)
    {
        Game::scene.GetPhysicsManager().SetTimeStep(1.0 / float(fps));
        fps = 0;
        fpsClock.restart();
    }

    hud.getProgressBar("health").setValue(health);

    /*if(bleedingClock.getElapsedTime().asSeconds() >= 0.2)
    {
        auto pos = Game::camera.GetPosition();
        pos.y = 0.01;
        Game::scene.CloneModel(Game::scene.GetModel("blood"), true).SetPosition(pos);
        bleedingClock.restart();
    }*/

    if(Keyboard::isKeyPressed(Keyboard::Escape)) pause = !pause;
    if(Keyboard::isKeyPressed(Keyboard::K))
    {
        Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.05);
        Game::exposure = lerp(Game::exposure, 0.0, 0.02);
        Game::blurIterations = lerp(Game::blurIterations, 32.0, 0.05);
    }

    Game::mouseCursorGrabbed = !pause;
    Game::mouseCursorVisible = pause;
    Game::manageCameraMouse = !pause;

    Game::scene.GetLight("light").SetColor(Vector3(0, 0, 0));

    Packet p;
    while(socket.receive(p) == Socket::Done)
    {
        int code = -1;
        float x = 0, y = 0, z = 0;
        if(p >> code)
            switch(code)
            {
            case 0:
                Log::Write("someone connected");
                Game::scene.GetModel("enemy:enemy").GetRigidBody().setType(STATIC);
                Game::scene.GetModel("enemy:enemy").GetRigidBody().setIsActive(false);
                break;
            case 1:
                p >> x >> y >> z;
                Game::scene.GetModel("enemy:enemy").SetPosition(Vector3(x, y, z));
                break;
            }
    }
    Game::scene.GetModel("flash").SetIsDrawable(false);
    player.Update();
    Game::camera.SetPosition(Game::scene.GetModel("player").GetPosition() + Vector3(0, 2.5, 0));
    auto l = Game::scene.GetModel("player").GetRigidBody().getLinearVelocity().length();
    Game::camera.SetFOV(lerp(Game::camera.GetFOV(), 80 + l, 0.1));
    if(Game::camera.GetFOV() >= 110)
        Game::camera.SetFOV(110);

    p.clear();
    auto pos = Game::scene.GetModel("player").GetPosition();
    p << 1;
    p << pos.x;
    p << pos.y;
    p << pos.z;
    socket.send(p);
    p.clear();

    fps++;
}
