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
    Game::scene.GetModel("rifle").SetShadowBias(0.005);
    Game::scene.GetModel("rifle").SetIsDrawable(false);
    Game::scene.GetModel("chel").SetIsDrawable(true);
    Game::scene.GetModel("rifle-copy").SetIsDrawable(false);
    Game::scene.GetAnimation("Menu-Idle").Play();

    Game::scene.GetPhysicsManager().SetTimeStep(1.0 / 60.0);

    Game::scene.UpdatePhysics(false);

    Game::scene.SaveState();

    socket.setBlocking(true);
	
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
            int hit = -1;
            for(uint i = 0; i < clients.length(); i++)
            {
                if(clients[i].model.GetRigidBody().raycast(ray, info))
                    hit = i;
            }
            Game::scene.GetModel("map:ground").GetRigidBody().raycast(ray, info1);
            if(hit != -1 && (info.worldPoint - Game::camera.GetPosition()).length() < (info1.worldPoint - Game::camera.GetPosition()).length())
            {
                auto pos = clients[hit].model.GetPosition();
                pos.y = 0.01;
                auto model = Game::scene.CloneModel(Game::scene.GetModel("blood"), true);
                model.SetPosition(pos + Vector3(rnd(-5, 5), 0, rnd(-5, 5)));
                model.SetIsDrawable(true);
                // code = 2, myId, damagedId, weaponId
                Packet p; p << 2; p << id; p << clients[hit].id; p << 0;
                socket.send(p);
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
        if(player.IsRunning())
            Game::scene.GetAnimation("walk").SetTPS(15);
        else
            Game::scene.GetAnimation("walk").SetTPS(5);
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
            /*Packet p;
            Clock ping;
            status = socket.receive(p);
            int numPlayers = 0, event = 0;
            if(status == Socket::Done)
                p >> id >> event >> serverConfig.name >> serverConfig.allowBhop >> serverConfig.enableFullGUI >> serverConfig.maxPlayers >> serverConfig.jumpForce >> serverConfig.maxSpeed >> numPlayers;// >> serverConfig.weaponDamage;
            menu.getLabel("info").setText("Connected to " + serverConfig.name + "\n" + to_string(numPlayers - 1) + "/" + to_string(serverConfig.maxPlayers) + " players\n" + "ID: " + to_string(id));
            updateInfo.restart();*/
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
        Game::bloomStrength = 0.2;
        Game::scene.UpdatePhysics(true);
        Game::scene.GetModel("rifle").SetIsDrawable(true);
        Game::scene.GetSoundManager().Stop("menu-music");
        Game::scene.GetAnimation("Menu-Idle").Stop();
        Game::scene.GetModel("chel").DefaultPose();
        Game::scene.GetModel("chel").SetIsDrawable(false);
        Game::scene.GetModel("enemy:ground").GetRigidBody().setIsActive(false);
        //Game::scene.GetSoundManager().Play("game-music");
        //Game::scene.LoadEnvironment("assets/textures/doom_sky.hdr");
        @currentLoop = @mainGameLoop;
        name = menu.getEditBox("nickname").getText().toStdString();
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
        {
            hud.getChatBox("chat").addLine("Welcome to the " + serverConfig.name);
            Packet p;
            p << 0; p << id; p << name;
            socket.send(p);
        }
    });

    Game::scene.GetSoundManager().Play("menu-music");

    /*@hud = @engine.CreateGui("assets/hud.txt");
    hud.getChatBox("chat").addLine("hello world");*/
}
