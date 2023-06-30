FPSController@ player;
Clock delay;
TcpSocket socket;
tgui::Gui@ hud;
int fps = 0;
//Clock fpsClock, bleedingClock;
bool pause = false;

float lerp(float x, float y, float t)
{
    return x * (1.0 - t) + y * t;
}

void Start()
{   
    Game::bloomStrength = 0.5;
    Game::brightnessThreshold = 2.1;
    Game::blurIterations = 3;

    Game::scene.GetModel("rifle").SetShadowBias(0.6);
    Game::scene.GetModel("map:ground").SetShadowBias(0.0);

    int status = socket.connect(ResolveIp("localhost"), 6969, seconds(5));
    socket.setBlocking(false);
    //Log::Write(to_string(status));
    if(status == Socket::Done)
    {
        Packet p;
        p << 0;
        status = socket.send(p);
    }

    Game::manageCameraMovement = false;
	
    @player = @FPSController(Game::scene.GetModel("player"), Game::scene.GetModelGroup("ground"), 6.0);
    player.AddCustomEvent(function()
    {
        if(Mouse::isButtonPressed(Mouse::Left) && delay.getElapsedTime().asSeconds() > 0.1 && !pause)
        {
            Game::scene.GetModel("flash").SetIsDrawable(true);
            Game::scene.GetAnimation("shoot").Play();
            Game::scene.GetLight("light").SetColor(Vector3(25, 10, 2));
            RaycastInfo info;
            Ray ray(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -1000)));
            if(Game::scene.GetModel("enemy").GetRigidBody().raycast(ray, info))
                Game::scene.GetModel("enemy").GetRigidBody().applyWorldForceAtWorldPosition(Game::camera.GetOrientation() * Vector3(0, 0, -100), info.worldPoint);
            Game::camera.SetOrientation(Game::camera.GetOrientation() * QuaternionFromEuler(Vector3(0.03, 0, 0)));
            delay.restart();
        }
    });

    player.AddCustomEvent(function()
    {
        if(Keyboard::isKeyPressed(Keyboard::F) && Game::scene.GetAnimation("lookAtRifle").GetState() != Playing)
        {
            Game::scene.GetAnimation("shoot").Stop();
            Game::scene.GetAnimation("lookAtRifle").Play();
        }
        if(Game::scene.GetAnimation("lookAtRifle").GetState() == Paused)
            Game::scene.GetAnimation("lookAtRifle").Stop();
    });

    player.AddCustomEvent(function()
    {
        if(player.IsMoving() && Game::scene.GetAnimation("walk").GetState() != Playing && player.IsOnGround())
            Game::scene.GetAnimation("walk").Play();
        else if((!player.IsMoving() || !player.IsOnGround()) && Game::scene.GetAnimation("walk").GetState() == Playing)
            Game::scene.GetAnimation("walk").Pause();
    });

    player.AddCustomEvent(function()
    {
        if(Keyboard::isKeyPressed(Keyboard::LShift))
        {
            Game::scene.GetAnimation("walk").SetTPS(15);
            Game::camera.SetSpeed(2);
        }
        else
        {
            Game::scene.GetAnimation("walk").SetTPS(10);
            Game::camera.SetSpeed(1);
        }
    });

    @hud = @engine.CreateGui("assets/hud.txt");
    hud.getChatBox("ChatBox1").addLine("hello world");
}

void Loop()
{
    /*if(fpsClock.getElapsedTime().asSeconds() >= 1)
    {
        //hud.getChatBox("ChatBox1").addLine(to_string(fps));
        Game::scene.GetPhysicsManager().SetTimeStep(1.0 / float(fps));
        fps = 0;
        fpsClock.restart();
    }*/

    /*if(bleedingClock.getElapsedTime().asSeconds() >= 0.2)
    {
        auto pos = Game::camera.GetPosition();
        pos.y = 0.01;
        Game::scene.CloneModel(Game::scene.GetModel("blood"), true).SetPosition(pos);
        bleedingClock.restart();
    }*/

    if(Keyboard::isKeyPressed(Keyboard::Escape)) pause = !pause;

    Game::mouseCursorGrabbed = !pause;
    Game::mouseCursorVisible = pause;
    Game::manageCameraMouse = !pause;

    Game::scene.GetLight("light").SetColor(Vector3(0, 0, 0));

    Packet p;
    if(socket.receive(p) == Socket::Done)
    {
        int code = -1;
        float x = 0, y = 0, z = 0;
        if(p >> code)
            switch(code)
            {
            case 0:
                Log::Write("someone connected");
                Game::scene.GetModel("enemy").GetRigidBody().setType(STATIC);
                break;
            case 1:
                p >> x >> y >> z;
                Log::Write(to_string(x) + to_string(y) + to_string(z));
                Game::scene.GetModel("enemy").SetPosition(Vector3(x, y, z));
                break;
            }
    }
    Game::scene.GetModel("flash").SetIsDrawable(false);
    player.Update();
    Game::camera.SetPosition(Game::scene.GetModel("player").GetPosition() + Vector3(0, 2.6, 0));
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

    //fps++;
}
