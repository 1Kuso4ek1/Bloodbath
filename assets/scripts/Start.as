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
    Game::manageCameraMouse = false;
    Game::manageCameraMovement = false;
    Game::mouseCursorVisible = true;

    Game::scene.GetModel("map:ground").SetShadowBias(0.0);
    Game::scene.GetModel("rifle").SetShadowBias(0.0000001);
    Game::scene.GetModel("rifle").SetIsDrawable(false);

    Game::scene.UpdatePhysics(false);
	
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
            if(Game::scene.GetModel("enemy:ground").GetRigidBody().raycast(ray, info))
            {
                Game::scene.GetModel("enemy:ground").GetRigidBody().applyWorldForceAtWorldPosition(Game::camera.GetOrientation() * Vector3(0, 0, -100), info.worldPoint);
                auto pos = Game::scene.GetModel("enemy:ground").GetPosition();
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

    @menu = @engine.CreateGui("assets/menu.txt");
    Game::exposure = 0.0;
    Game::blurIterations = 128;
    Game::bloomStrength = 1.0;
    menu.getPanel("loadingPanel").setVisible(true);
    menu.getPanel("loadingPanel").hideWithEffect(tgui::Fade, seconds(3.0));
    menu.getButton("connect").onPress(function()
    {
        Log::Write("connect");
        auto ip = menu.getEditBox("ip").getText().toStdString();
        Log::Write(menu.getEditBox("ip").getText().toStdString());
        auto port = stoi(menu.getEditBox("port").getText().toStdString());
        Log::Write(menu.getEditBox("port").getText().toStdString());
        int status = socket.connect(ResolveIp(ip), port, seconds(5));
        if(status == Socket::Done)
        {
            Packet p;
            status = socket.receive(p);
            int numPlayers = 0;
            if(status == Socket::Done)
                p >> serverConfig.name >> serverConfig.allowBhop >> serverConfig.enableFullGUI >> serverConfig.maxPlayers >> numPlayers/* >> serverConfig.weaponDamage*/;
            menu.getLabel("info").setText("Connected to " + serverConfig.name + " with " + to_string(numPlayers - 1) + " players");        
            menu.getButton("play").setText("Play");
            socket.setBlocking(false);
        }
        else menu.getLabel("info").setText("Failed to connect!");
    });

    menu.getButton("play").onPress(function()
    {
        Game::manageCameraMouse = true;
        Game::mouseCursorVisible = false;
        Game::exposure = 1.0;
        Game::blurIterations = 16;
        Game::bloomStrength = 0.3;
        Game::scene.UpdatePhysics(true);
        Game::scene.GetModel("rifle").SetIsDrawable(true);
        Game::scene.GetSoundManager().Stop("menu-music");
        @currentLoop = @mainGameLoop;
        engine.RemoveGui();
        @hud = @engine.CreateGui("assets/hud.txt");
        if(serverConfig.name.length() > 0)
            hud.getChatBox("chat").addLine("Welcome to the " + serverConfig.name);
    });

    Game::scene.GetSoundManager().Play("menu-music");

    /*@hud = @engine.CreateGui("assets/hud.txt");
    hud.getChatBox("chat").addLine("hello world");*/
}
