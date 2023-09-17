class ServerConfig
{
    string name;

	bool allowBhop = true;
	bool enableFullGUI = true;

	int maxPlayers;

	float jumpForce = 500;
	float maxSpeed = 6.0;
};

ServerConfig serverConfig;

void Start()
{
    Game::manageCameraMouse = false;
    Game::manageCameraMovement = false;
    Game::mouseCursorVisible = true;
    Game::mouseCursorGrabbed = false;

    //Game::scene.GetModel("map:ground").SetShadowBias(0.0003);
    weapons.removeRange(0, weapons.length());
    
    weapons.insertLast(Weapon(Game::scene.GetModel("rifle"), Game::scene.GetModel("flash"), "ak47-shot",
                              Game::scene.GetAnimation("rifleShoot"), Game::scene.GetAnimation("lookAtRifle"), 0.03, 0.1, 1000));
    weapons.insertLast(Weapon(Game::scene.GetModel("deagle"), Game::scene.GetModel("flash1"), "deagle-shot",
                              Game::scene.GetAnimation("deagleShoot"), Game::scene.GetAnimation("lookAtDeagle"), 0.06, 0.3, 1000));
    weapons.insertLast(Weapon(Game::scene.GetModel("knife"), null, "knife-sound",
                              Game::scene.GetAnimation("knifeHit"), Game::scene.GetAnimation("lookAtKnife"), 0.0, 1.0, 5));
    for(uint i = 0; i < weapons.length(); i++)
    {
        weapons[i].model.SetIsDrawable(false);
        weapons[i].model.SetShadowBias(0.005);
    }
    //Game::scene.GetModel("chel").SetShadowBias(0.005);
    Game::scene.GetModel("chel").SetIsDrawable(true);
    Game::scene.GetModel("rifle-copy").SetIsDrawable(false);
    Game::scene.GetModel("deagle-copy").SetIsDrawable(false);
    Game::scene.GetModel("knife-copy").SetIsDrawable(false);
    Game::scene.GetAnimation("Menu-Idle").Play();

    Game::scene.GetPhysicsManager().SetTimeStep(1.0 / 60.0);

    Game::scene.UpdatePhysics(false);

    Game::scene.SaveState();

    socket.setBlocking(true);
    
    for(uint i = 0; i < clients.length(); i++)
    {
        Game::scene.RemoveAnimation(Game::scene.GetAnimation("Default-chel-chel" + clients[i].id));                                             
        Game::scene.RemoveAnimation(Game::scene.GetAnimation("Death-chel-chel" + clients[i].id));
        Game::scene.RemoveAnimation(Game::scene.GetAnimation("Jump-chel-chel" + clients[i].id));
        Game::scene.RemoveAnimation(Game::scene.GetAnimation("Stand-chel-chel" + clients[i].id));
        Game::scene.RemoveAnimation(Game::scene.GetAnimation("Armature|Walk-chel-chel" + clients[i].id));
    }

    clients.removeRange(0, clients.length());
	
    @player = @FPSController(Game::scene.GetModel("player"), Game::scene.GetModelGroup("ground"));
    player.AddCustomEvent(function()
    {
        if(weapons[currentWeapon].clock.getElapsedTime().asSeconds() < 0.2)
            Game::camera.SetOrientation(slerp(Game::camera.GetOrientation(), Game::camera.GetOrientation() * QuaternionFromEuler(Vector3(-weapons[currentWeapon].recoil, 0.0, 0.0)), 0.12));
        if(Mouse::isButtonPressed(Mouse::Left) && weapons[currentWeapon].IsReady() && !pause && Game::scene.GetAnimation("deploy").GetState() != Playing)
        {
            if(currentWeapon != 2)
                weapons[currentWeapon].flash.SetIsDrawable(true);
            weapons[currentWeapon].inspect.Stop();
            weapons[currentWeapon].shoot.Play();
            if(currentWeapon != 2)
                Game::scene.GetLight("light").SetColor(Vector3(25, 10, 2));

            Game::scene.GetSoundManager().PlayMono(weapons[currentWeapon].sound, id);
            
            RaycastInfo info, info1;
            Ray ray(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -weapons[currentWeapon].range)));
            int hit = -1; bool hs = false;
            for(uint i = 0; i < clients.length(); i++)
            {
                if(clients[i].model.GetRigidBody().raycast(ray, info))
                    hit = i;
                Game::scene.GetModel("head" + to_string(clients[i].id)).GetRigidBody().setIsActive(true);
                if(Game::scene.GetModel("head" + to_string(clients[i].id)).GetRigidBody().raycast(ray, info))
                    hs = true;
                Game::scene.GetModel("head" + to_string(clients[i].id)).GetRigidBody().setIsActive(false);
            }
            Game::scene.GetModel("map:ground").GetRigidBody().raycast(ray, info1);
            if(hit != -1 && (info.worldPoint - Game::camera.GetPosition()).length() < (info1.worldPoint - Game::camera.GetPosition()).length())
            {
                auto pos = clients[hit].model.GetPosition();
                pos.y = 0.01;
                auto model = Game::scene.CloneModel(Game::scene.GetModel("blood"), true);
                model.SetPosition(pos + Vector3(rnd(-5, 5), 0, rnd(-5, 5)));
                model.SetIsDrawable(true);
            }
            // code = 2, myId, damagedId, weaponId
            Packet p; p << 2; p << id; p << (hit == -1 ? -1 : clients[hit].id); p << hs; p << currentWeapon;
            socket.send(p);
            if((Game::camera.GetOrientation() * Vector3(0, 0, -1)).y < 0.90)
                Game::camera.SetOrientation(Game::camera.GetOrientation() * QuaternionFromEuler(Vector3(weapons[currentWeapon].recoil, 0.0, 0.0)));
            weapons[currentWeapon].clock.restart();
        }
    });

    player.AddCustomEvent(function()
    {
        if(Keyboard::isKeyPressed(Keyboard::F) && weapons[currentWeapon].inspect.GetState() != Playing)
        {
            weapons[currentWeapon].shoot.Stop();
            weapons[currentWeapon].inspect.Play();
        }
    });
    
    player.AddCustomEvent(function()
    {
        if(Mouse::isButtonPressed(Mouse::Right))
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
    menu.getPanel("loadingPanel").setVisible(logo);
    Game::exposure = 0.0;
    Game::blurIterations = 128;
    Game::bloomStrength = 1.0;

    file data;
    if(data.open("assets/default.txt", "r") >= 0)
    {
        name = data.readLine(); name.erase(name.length() - 1, 1);
        defaultMessage = data.readLine(); defaultMessage.erase(defaultMessage.length() - 1, 1);
        lastIp = data.readLine(); lastIp.erase(lastIp.length() - 1, 1);
        auto port = data.readLine(); port.erase(port.length() - 1, 1);
        auto sens = data.readLine();
        if(port.length() > 0)
            lastPort = stoi(port);
        if(sens.length() > 0)
            Game::mouseSensitivity = stof(sens);

        menu.getEditBox("ip").setText(lastIp);
        menu.getEditBox("port").setText(to_string(lastPort));
        menu.getEditBox("nickname").setText(name);

        data.close();
    }

    menu.getButton("exit").onPress(function()
    {
        engine.Close();
    });

    menu.getButton("connect").onPress(function()
    {
        auto ip = menu.getEditBox("ip").getText().toStdString();
        auto port = stoi(menu.getEditBox("port").getText().toStdString());
        name = menu.getEditBox("nickname").getText().toStdString();
        file data;

        if(data.open("assets/default.txt", "w") >= 0)
        {
            data.writeString(name + "\n");
            data.writeString(defaultMessage + "\n");
            data.writeString(ip + "\n");
            data.writeString(to_string(port) + "\n");
            data.writeString(to_string(Game::mouseSensitivity));

            data.close();
        }
        int status = socket.connect(ResolveIp(ip), port, seconds(5));
        if(status == Socket::Done)
            socket.setBlocking(false);
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
        weapons[currentWeapon].model.SetIsDrawable(true);
        Game::scene.GetSoundManager().Stop("menu-music");
        Game::scene.GetAnimation("Menu-Idle").Stop();
        Game::scene.GetModel("chel").DefaultPose();
        Game::scene.GetModel("chel").SetIsDrawable(false);
        Game::scene.GetModel("enemy:ground").GetRigidBody().setIsActive(false);
        //Game::scene.GetSoundManager().Play("game-music");
        //Game::scene.LoadEnvironment("assets/textures/doom_sky.hdr");
        @currentLoop = @mainGameLoop;
        engine.RemoveGui();
        @hud = @engine.CreateGui("assets/hud.txt");
        @pauseMenu = @engine.CreateGui("assets/pause.txt");
        pauseMenu.getSlider("sensitivity").setValue(Game::mouseSensitivity);
        pauseMenu.setOpacity(0.0);
        hud.getEditBox("chatField").setVisible(false);
        hud.getEditBox("chatField").setEnabled(false);
        socket.setBlocking(false);

        if(serverConfig.name.length() > 0)
        {
            hud.getChatBox("chat").addLine("Welcome to the " + serverConfig.name);
            Packet p;
            p << 0; p << id; p << name; p << team;
            socket.send(p);
        }

        if(defaultMessage.length() > 0)
        {
            hud.getChatBox("chat").addLine(name + ": " + defaultMessage);
            Packet p;
            p << 3; p << name + ": " + defaultMessage; p << 0;
            socket.send(p);
        }

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
    });

    Game::scene.GetSoundManager().Play("menu-music");
}
