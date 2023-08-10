class ServerConfig
{
    string name;

	bool allowBhop = true;
	bool enableFullGUI = true;

	int maxPlayers;

	float jumpForce = 500;
	float maxSpeed = 6.0;

	array<int> weaponDamage;
};

ServerConfig serverConfig;

void Start()
{
    Game::manageCameraMouse = false;
    Game::manageCameraMovement = false;
    Game::mouseCursorVisible = true;
    Game::mouseSensitivity = 0.8;

    //Game::scene.GetModel("map:ground").SetShadowBias(0.0003);
    Game::scene.GetModel("rifle").SetShadowBias(0.01);
    Game::scene.GetModel("rifle").SetIsDrawable(false);

    Game::scene.GetPhysicsManager().SetTimeStep(1.0 / 60.0);

    Game::scene.UpdatePhysics(false);

    Game::scene.SaveState();
	
    @player = @FPSController(Game::scene.GetModel("player"), Game::scene.GetModelGroup("ground"));
    player.AddCustomEvent(function()
    {
        if(Mouse::isButtonPressed(Mouse::Left) && delay.getElapsedTime().asSeconds() > 0.1 && !pause)
        {
            Game::scene.GetModel("flash").SetIsDrawable(true);
            Game::scene.GetAnimation("lookAtRifle").Stop();
            Game::scene.GetAnimation("shoot").Play();
            Game::scene.GetLight("light").SetColor(Vector3(25, 10, 2));

            Game::scene.GetSoundManager().PlayMono("ak47-shot");
            
            RaycastInfo info, info1;
            Ray ray(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -1000)));
            bool hit = Game::scene.GetModel("enemy:ground").GetRigidBody().raycast(ray, info);
            Game::scene.GetModel("map:ground").GetRigidBody().raycast(ray, info1);
            if(hit && (info.worldPoint - Game::camera.GetPosition()).length() < (info1.worldPoint - Game::camera.GetPosition()).length())
            {
                Game::scene.GetModel("enemy:ground").GetRigidBody().applyWorldForceAtWorldPosition(Game::camera.GetOrientation() * Vector3(0, 0, -100), info.worldPoint);
                auto pos = Game::scene.GetModel("enemy:ground").GetPosition();
                pos.y = 0.01;
                auto model = Game::scene.CloneModel(Game::scene.GetModel("blood"), true);
                model.SetPosition(pos + Vector3(rnd(-5, 5), 0, rnd(-5, 5)));
                model.SetIsDrawable(true);
                health -= 10;
            }
            if((Game::camera.GetOrientation() * Vector3(0, 0, -1)).y < 0.90)
                Game::camera.SetOrientation(Game::camera.GetOrientation() * QuaternionFromEuler(Vector3(0.04, 0.0, 0.0)));
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
            if(Game::camera.GetFOV() >= 135)
                Game::camera.SetFOV(135);
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

    menu.getButton("exit").onPress(function()
    {
        engine.Close();
    });

    menu.getButton("connect").onPress(function()
    {
        auto ip = menu.getEditBox("ip").getText().toStdString();
        auto port = stoi(menu.getEditBox("port").getText().toStdString());
        int status = socket.connect(ResolveIp(ip), port, seconds(5));
        if(status == Socket::Done)
        {
            Packet p;
            Clock ping;
            status = socket.receive(p);
            int numPlayers = 0, event = 0;
            if(status == Socket::Done)
                p >> event >> serverConfig.name >> serverConfig.allowBhop >> serverConfig.enableFullGUI >> serverConfig.maxPlayers >> serverConfig.jumpForce >> serverConfig.maxSpeed >> numPlayers;// >> serverConfig.weaponDamage;
            menu.getLabel("info").setText("Connected to " + serverConfig.name + "\n" + to_string(numPlayers - 1) + "/" + to_string(serverConfig.maxPlayers) + " players");
            menu.getButton("play").setText("Play");
            socket.setBlocking(false);
            updateInfo.restart();
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
        //Game::scene.LoadEnvironment("assets/textures/sky1.hdr");
        @currentLoop = @mainGameLoop;
        engine.RemoveGui();
        @hud = @engine.CreateGui("assets/hud.txt");
        @pauseMenu = @engine.CreateGui("assets/pause.txt");
        pauseMenu.setOpacity(0.0);
        hud.getEditBox("chatField").setVisible(false);
        hud.getEditBox("chatField").setEnabled(false);

        pauseMenu.getButton("continue").onPress(function()
        {
            if(pause) pause = false;
        });

        pauseMenu.getButton("disconnect").onPress(function()
        {
            if(pause)
            {
                pause = false;
                socket.disconnect();
                Game::scene.LoadState();
                @currentLoop = @menuLoop;
                engine.RemoveGui();
                Start();
            }
        });
        if(serverConfig.name.length() > 0)
            hud.getChatBox("chat").addLine("Welcome to the " + serverConfig.name);
    });

    Game::scene.GetSoundManager().Play("menu-music");

    /*@hud = @engine.CreateGui("assets/hud.txt");
    hud.getChatBox("chat").addLine("hello world");*/
}
