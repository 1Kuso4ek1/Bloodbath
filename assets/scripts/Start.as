class ServerConfig
{
    string name;

	int allowBhop = 1;
	int enableFullGUI = 1;

	int maxPlayers;

	array<int> weaponDamage;
};

ServerConfig serverConfig;

void Start()
{
    Game::bloomStrength = 0.3;
    Game::blurIterations = 16;
    //Game::exposure = 0.5;

    Game::scene.GetModel("map:ground").SetShadowBias(0.0);
    Game::scene.GetModel("rifle").SetShadowBias(0.0000001);

    int status = socket.connect(ResolveIp("localhost"), 2000, seconds(5));
    //Log::Write(to_string(status));
    if(status == Socket::Done)
    {
        Packet p;
        status = socket.receive(p);
        if(status == Socket::Done)
            p >> serverConfig.name >> serverConfig.allowBhop >> serverConfig.enableFullGUI >> serverConfig.maxPlayers/* >> serverConfig.weaponDamage*/;
        Log::Write("Welcome to the " + serverConfig.name);
        if(serverConfig.allowBhop == 0) Log::Write("There's no bhop :(");
    }
    socket.setBlocking(false);

    Game::manageCameraMovement = false;
	
    @player = @FPSController(Game::scene.GetModel("player"), Game::scene.GetModelGroup("ground"), 6.0);
    player.AddCustomEvent(function()
    {
        if(Mouse::isButtonPressed(Mouse::Left) && delay.getElapsedTime().asSeconds() > 0.1 && !pause)
        {
            Game::scene.GetModel("flash").SetIsDrawable(true);
            Game::scene.GetAnimation("lookAtRifle").Stop();
            Game::scene.GetAnimation("shoot").Play();
            Game::scene.GetLight("light").SetColor(Vector3(25, 10, 2));

            Game::scene.GetSoundManager().PlayMono("ak47-shot");
            
            RaycastInfo info;
            Ray ray(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -1000)));
            if(Game::scene.GetModel("enemy:enemy").GetRigidBody().raycast(ray, info))
            {
                Game::scene.GetModel("enemy:enemy").GetRigidBody().applyWorldForceAtWorldPosition(Game::camera.GetOrientation() * Vector3(0, 0, -100), info.worldPoint);
                auto pos = Game::scene.GetModel("enemy:enemy").GetPosition();
                pos.y = 0.01;
                auto model = Game::scene.CloneModel(Game::scene.GetModel("blood"), true);
                model.SetPosition(pos + Vector3(rnd(-5, 5), 0, rnd(-5, 5)));
                model.SetIsDrawable(true);
                health -= 10;
            }
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
        if(Mouse::isButtonPressed(Mouse::Middle))
            Game::camera.SetFOV(lerp(Game::camera.GetFOV(), 55, 0.05));
        else
        {
            auto l = Game::scene.GetModel("player").GetRigidBody().getLinearVelocity().length();
            Game::camera.SetFOV(lerp(Game::camera.GetFOV(), 80 + l, 0.05));
            if(Game::camera.GetFOV() >= 110)
                Game::camera.SetFOV(110);
        }
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
    hud.getChatBox("chat").addLine("hello world");
}