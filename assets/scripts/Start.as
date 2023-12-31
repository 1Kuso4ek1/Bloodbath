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
    Game::dofFocusDistance = 0.0;
    Game::dofMinDistance = 1.0;
    Game::dofMaxDistance = 1.0;

    weapons.removeRange(0, weapons.length());
    
    weapons.insertLast(Weapon(Game::scene.GetModel("rifle"), Game::scene.GetModel("flash"), "ak47-shot", "ak47-reload",
                              Game::scene.GetAnimation("rifleShoot"), Game::scene.GetAnimation("lookAtRifle"), 0.03, 0.1, 1000, 30, 2.2));
    weapons.insertLast(Weapon(Game::scene.GetModel("deagle"), Game::scene.GetModel("flash1"), "deagle-shot", "deagle-reload",
                              Game::scene.GetAnimation("deagleShoot"), Game::scene.GetAnimation("lookAtDeagle"), 0.06, 0.3, 1000, 7, 1.7));
    weapons.insertLast(Weapon(Game::scene.GetModel(xyNActive ? "xyN" : "knife"), null, "knife-sound", "",
                              Game::scene.GetAnimation("knifeHit"), Game::scene.GetAnimation("lookAtKnife"), 0.0, 0.75, 5, 0, 0));
    for(uint i = 0; i < weapons.length(); i++)
    {
        //weapons[i].model.SetIsDrawable(false);
        weapons[i].model.SetShadowBias(0.005);
    }

    for(uint i = 0; i < mapNames.length(); i++)
        Game::scene.GetModel(mapNames[i] + ":ground").Unload(false);

    Game::scene.LoadEnvironment("assets/textures/black.hdr");

    Game::scene.GetModel("chel").SetShadowBias(0.005);
    Game::scene.GetModel("chel").SetIsDrawable(true);
    Game::scene.GetModel("lobby").SetIsDrawable(true);
    Game::scene.GetModel("lobby1").SetIsDrawable(true);
    Game::scene.GetLight("lobbyLight").SetIsCastingShadows(true);
    Game::scene.GetLight("lobbyLight").SetColor(Vector3(1, 1, 1));
    Game::scene.GetLight("shadowSource").SetIsCastingShadows(false);
    Game::scene.GetAnimation("Menu-Idle").Play();
    Game::camera.SetFOV(90.0);

    mat.setBounciness(0.01);
    mat.setFrictionCoefficient(0.05);

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
            {
                auto size = rnd(0.1, 0.6);
                weapons[currentWeapon].flash.SetSize(Vector3(size, size, size));
                weapons[currentWeapon].flash.SetIsDrawable(true);
            }
            weapons[currentWeapon].inspect.Stop();
            weapons[currentWeapon].shoot.Play();
            if(currentWeapon != 2)
                Game::scene.GetLight("light").SetColor(Vector3(25, 10, 2));

            Game::scene.GetSoundManager().PlayMono(weapons[currentWeapon].sound, id);
            
            RaycastInfo info, info1, infohs;
            Ray ray(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -weapons[currentWeapon].range)));
            int hit = -1; bool hs = false;
            for(uint i = 0; i < clients.length(); i++)
            {
                if(clients[i].model.GetRigidBody().raycast(ray, info))
                    hit = i;
                Game::scene.GetModel("head" + to_string(clients[i].id)).GetRigidBody().setIsActive(true);
                if(Game::scene.GetModel("head" + to_string(clients[i].id)).GetRigidBody().raycast(ray, infohs))
                {
                    hs = true;
                    info = infohs;
                }
                Game::scene.GetModel("head" + to_string(clients[i].id)).GetRigidBody().setIsActive(false);
                
                if(hit != -1) break;
            }
            Game::scene.GetModel(currentMap + ":ground").GetRigidBody().raycast(ray, info1);
            if(hit != -1 && ((info.worldPoint - Game::camera.GetPosition()).length() < (info1.worldPoint - Game::camera.GetPosition()).length()))
            {
                //auto pos = clients[hit].model.GetPosition();
                //pos.y = 0.01;
                auto pos = info1.worldPoint;
                auto model = Game::scene.CloneModel(Game::scene.GetModel("blood-decal"), true, "decal" + to_string(decalCounter++) + ":decals");
                model.SetOrientation(LookAt(pos, pos + (QuaternionFromEuler(Vector3(1.57, 0, 0)) * Game::camera.GetOrientation() * info1.worldNormal), info1.worldNormal));
                model.SetPosition(pos);
                model.SetIsDrawable(true);

            }
            else hit = -1;
            
            auto pos = info1.worldPoint;
            auto model = Game::scene.CloneModel(Game::scene.GetModel("bullet-decal"), true, "decal" + to_string(decalCounter++) + ":decals");
            model.SetOrientation(LookAt(pos, pos + (QuaternionFromEuler(Vector3(1.57, 0, 0)) * Game::camera.GetOrientation() * info1.worldNormal), info1.worldNormal));
            model.SetPosition(pos);
            model.SetIsDrawable(true);

            if(decalCounter - decalRemoveCounter > 200)
                Game::scene.RemoveModel(Game::scene.GetModel("decal" + to_string(decalRemoveCounter++) + ":decals"));
            
            // code = 2, myId, damagedId, weaponId
            Packet p; p << 2; p << id; p << (hit == -1 ? -1 : clients[hit].id); p << hs; p << currentWeapon;
            socket.send(p);
            tracerOrient = Game::camera.GetOrientation();
            if((Game::camera.GetOrientation() * Vector3(0, 0, -1)).y < 0.90)
                Game::camera.SetOrientation(Game::camera.GetOrientation() * QuaternionFromEuler(Vector3(weapons[currentWeapon].recoil, 0.0, 0.0)));

            weapons[currentWeapon].clock.restart();
            weapons[currentWeapon].currentAmmo--;

            removeFlash = false;
        }
    });

    player.AddCustomEvent(function()
    {
        if(Keyboard::isKeyPressed(Keyboard::R))
        {
            weapons[currentWeapon].Reload();
            if(weapons[currentWeapon].reloading)
                Game::scene.GetSoundManager().PlayMono(weapons[currentWeapon].reloadSound, id);
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
            if(Game::camera.GetFOV() >= 120)
                Game::camera.SetFOV(120);
        }
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
        password = data.readLine(); password.erase(password.length() - 1, 1);
        lastIp = data.readLine(); lastIp.erase(lastIp.length() - 1, 1);
        auto port = data.readLine(); port.erase(port.length() - 1, 1);
        auto sens = data.readLine();
        if(port.length() > 0)
            lastPort = stoi(port);
        if(sens.length() > 0)
            Game::mouseSensitivity = stof(sens);

        /*menu.getEditBox("ip").setText(lastIp);
        menu.getEditBox("port").setText(to_string(lastPort));*/
        menu.getEditBox("nickname").setText(name);
        menu.getEditBox("password").setText(password);

        data.close();
    }

    menu.getLabel("loadingStatus").setText("Connected to " + lastIp);

    menu.getButton("exit").onPress(function()
    {
        engine.Close();
    });

    lambda@ connect = function()
    {
        auto ip = lastIp;
        auto port = lastPort;
        name = menu.getEditBox("nickname").getText().toStdString();
        password = menu.getEditBox("password").getText().toStdString();
        file data;

        if(data.open("assets/default.txt", "w") >= 0)
        {
            data.writeString(name + "\n");
            data.writeString(password + "\n");
            data.writeString(ip + "\n");
            data.writeString(to_string(port) + "\n");
            data.writeString(to_string(Game::mouseSensitivity));

            data.close();
        }
        int i = 0, status;
        while((status = socket.connect(ResolveIp(ip), port, seconds(1))) != Socket::Done && i++ < 5);

        if(status == Socket::Done)
        {
            socket.setBlocking(false);
            menu.getButton("play").setEnabled(true);
            menu.getLabel("loadingStatus").setText("Connected to " + lastIp);
            menu.getLabel("name").setText(name);
            updateMenu = true;
        }
        else menu.getLabel("loadingStatus").setText("Failed to connect to " + ip + ", please try again later");
    };

    menu.getButton("confirm").onPress(connect);

    menu.getButton("customize").onPress(function()
    {
        updateInventory = false;
        
        menu.getChildWindow("inventory").setVisible(true);
        menu.getChildWindow("inventory").setEnabled(true);
    });

    menu.getButton("applyFront").onPress(function()
    {
        auto prev = frontPath;
        frontPath = inventory[menu.getListView("items").getSelectedItemIndex()];
        if(frontPath.findFirst("patch") >= 0)
        {
            Game::scene.GetModel("patch:decals").SetMaterial(Game::scene.GetMaterial(frontPath));
            Game::scene.GetModel("patch:decals").SetIsDrawable(prev == frontPath ? false : true);
            if(prev == frontPath)
                frontPath = "";
        }
    });

    menu.getButton("applyBack").onPress(function()
    {
        auto prev = backPath;
        backPath = inventory[menu.getListView("items").getSelectedItemIndex()];
        if(backPath.findFirst("patch") >= 0)
        {
            Game::scene.GetModel("patch1:decals").SetMaterial(Game::scene.GetMaterial(backPath));
            Game::scene.GetModel("patch1:decals").SetIsDrawable(prev == backPath ? false : true);
            if(prev == backPath)
                backPath = "";
        }
    });

    menu.getButton("applyHat").onPress(function()
    {
        auto hat = inventory[menu.getListView("items").getSelectedItemIndex()];
        if(hat.findFirst("hat") >= 0)
        {
            int it = hats.find(hat);
            if(it < 0)
            {
                Game::scene.GetModel(hat).Load();
                Game::scene.GetModel(hat).SetShadowBias(0.005);
                Game::scene.GetModel(hat).SetIsDrawable(true);
                hats.insertLast(hat);
            }
            else
            {
                Game::scene.GetModel(hats[it]).SetIsDrawable(false);
                hats.removeRange(it, 1);
            }
        }
    });

    menu.getButton("closeInventory").onPress(function()
    {
        updateInventory = true;

        menu.getChildWindow("inventory").setVisible(false);
        menu.getChildWindow("inventory").setEnabled(false);
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

        if(night)
        {
            Game::scene.LoadEnvironment("assets/textures/night.hdr");
            Game::scene.GetLight("light1").SetColor(Vector3(3, 3, 3));
        }
        else Game::scene.LoadEnvironment("assets/textures/sky1.hdr");
        //Game::scene.GetModel("chel").SetIsDrawable(false);
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
        hud.getListView("team0tab").removeAllItems();
        hud.getListView("team1tab").removeAllItems();
        tabId = hud.getListView("team" + to_string(team) + "tab").addItem({ to_string(id), name, "0", "0" });
        hud.getLabel("serverName").setText(serverConfig.name);
        chatTimer.restart();
        socket.setBlocking(false);

        Game::scene.GetModel("chel").SetMaterial(Game::scene.GetMaterial("character" + to_string(team)));

        for(uint i = 0; i < mapNames.length(); i++)
            Game::scene.GetModel(mapNames[i] + ":ground").Unload(true);
        Game::scene.GetModel(currentMap + ":ground").Load();
        Game::scene.GetModel(currentMap + ":ground").SetIsDrawable(true);
        for(uint i = 0; i < weapons.length(); i++)
            weapons[i].model.Load();
        Game::scene.GetModel("lobby").SetIsDrawable(false);
        Game::scene.GetModel("lobby1").SetIsDrawable(false);
        Game::scene.GetLight("lobbyLight").SetIsCastingShadows(false);
        Game::scene.GetLight("lobbyLight").SetColor(Vector3(0, 0, 0));
        
        Game::scene.GetModel(currentMap + ":ground").GetRigidBody().setMaterial(mat);

        if(serverConfig.name.length() > 0)
        {
            hud.getChatBox("chat").addLine("Welcome to the " + serverConfig.name);
            Packet p;
            p << 0; p << id; p << name; p << team;
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

    if(name.length() > 0)
    {
        menu.getChildWindow("welcome").setVisible(false);
        connect();
    }
    else menu.getLabel("loadingStatus").setText("");

    Game::scene.GetSoundManager().Play("menu-music");
}
