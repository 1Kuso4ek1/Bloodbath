GameLoop@ mainGameLoop = function()
{
    if(enableShadows)
    {
        Game::scene.GetLight("shadowSource").SetIsCastingShadows(true);
        enableShadows = false;
    }
    else enableShadows = !Game::scene.GetLight("shadowSource").IsCastingShadows();

    hud.getProgressBar("health").setValue(health);

    if(Game::mouseSensitivity != pauseMenu.getSlider("sensitivity").getValue())
    {
        Game::mouseSensitivity = pauseMenu.getSlider("sensitivity").getValue();
        file data;
        if(data.open("assets/default.txt", "r") >= 0)
        {
            auto str = data.readString(data.getSize() - to_string(Game::mouseSensitivity).length());
            data.close();
            data.open("assets/default.txt", "w");
            data.writeString(str + to_string(Game::mouseSensitivity));
            data.close();
        }
    }

    pauseMenu.getLabel("sensVal").setText(to_string(Game::mouseSensitivity));
    hud.getPanel("tab").setVisible(Keyboard::isKeyPressed(Keyboard::Tab));

    if(Keyboard::isKeyPressed(Keyboard::T) && !pause)
    {
        chatActive = true;
        hud.getEditBox("chatField").setFocused(true);
    }

    if(Game::scene.GetAnimation("knifeHit").GetState() == Paused)
        Game::scene.GetAnimation("knifeHit").Stop();
    Game::scene.GetAnimation("HoldRifle-chel").Stop();
    Game::scene.GetAnimation("HoldPistol-chel").Stop();
    Game::scene.GetAnimation("HoldKnife-chel").Stop();

    if(hats.length() > 0)
        for(int i = 0; i < hats.length(); i++)
            Game::scene.GetModel(hats[i]).SetIsDrawable(true);
    Game::scene.GetBone("Bone.014-chel").SetSize(Vector3(1, 1, 1));

    for(uint i = 0; i < weapons.length(); i++)
    {
        if(Keyboard::isKeyPressed(Keyboard::Num1 + i) && i != currentWeapon && !pause && !chatActive)
        {
            weapons[currentWeapon].model.SetIsDrawable(false);
            currentWeapon = i;
            weapons[currentWeapon].model.SetIsDrawable(true);
            Game::scene.GetAnimation("knifeHit").Stop();
            Game::scene.GetBone("Left-Arm.0-chel").SetOrientation(QuaternionFromEuler(Vector3(0, radians(80), radians(-90))));
            Game::scene.GetBone("Right-Arm.0-chel").SetOrientation(QuaternionFromEuler(Vector3(0, radians(-80), radians(90))));
            hud.getLabel("ammo").setVisible(true);
            hud.getLabel("reserve").setVisible(true);
            switch(i)
            {
            case 0:
                Game::scene.GetAnimation("HoldRifle-chel").Play();
                break;
            case 1:
                Game::scene.GetAnimation("HoldPistol-chel").Play();
                break;
            case 2:
                hud.getLabel("ammo").setVisible(false);
                hud.getLabel("reserve").setVisible(false);
                Game::scene.GetAnimation("HoldKnife-chel").Play();
                break;
            }
            break;
        }

        if(i != currentWeapon)
        {
            Game::scene.GetSoundManager().Stop(weapons[i].reloadSound, id);
            weapons[i].reloadClock.restart();
            weapons[i].reloading = false;
        }
    }

    weapons[currentWeapon].Update();

    if(Keyboard::isKeyPressed(Keyboard::Enter))
    {
        auto text = hud.getEditBox("chatField").getText().toStdString();
        if(text == "хуй" && !xyNActive)
        {
            xyNActive = true;
            weapons[2].model.SetIsDrawable(false);
            weapons.removeAt(2);
            weapons.insertLast(Weapon(Game::scene.GetModel("xyN"), null, "knife-sound", "",
                                      Game::scene.GetAnimation("knifeHit"), Game::scene.GetAnimation("lookAtKnife"), 0.0, 1.0, 5, 0, 0));
            weapons[2].model.SetIsDrawable(false);
            weapons[2].model.SetShadowBias(0.005);
        }
        hud.getEditBox("chatField").setText("");
        if(text.length() > 0)
        {
            hud.getChatBox("chat").addLine(name + ": " + text);
            Packet p;
            p << 3; p << name + ": " + text; p << 0;
            socket.send(p);
        }
    }

    if(Keyboard::isKeyPressed(Keyboard::F1) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
    {
    	buttonTimer.restart();
    	freeCamera = !freeCamera;
    	Game::manageCameraMovement = freeCamera;
        if(freeCamera) hud.setOpacity(0.0);
        else hud.setOpacity(1.0);
    }

    if(Keyboard::isKeyPressed(Keyboard::F2) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
    {
    	buttonTimer.restart();
        if(!freeCameraFollowPlayer)
        {
            RaycastInfo info;
            Ray ray(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -1000)));
            for(uint i = 0; i < clients.length(); i++)
                if(clients[i].model.GetRigidBody().raycast(ray, info))
                {
                    @follow = @clients[i].model;
                    freeCameraFollowPlayer = true;
                    break;
                }
        }
        else freeCameraFollowPlayer = false;
    }

    if(Keyboard::isKeyPressed(Keyboard::Escape) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
    {
        buttonTimer.restart();
        if(chatActive)
        {
            chatActive = false;
            chatTimer.restart();
        }
        else
            pause = !pause;
    }

    hud.getEditBox("chatField").setVisible(chatActive);
    hud.getEditBox("chatField").setEnabled(chatActive);
    if(chatActive && hidden)
    {
    	hud.getChatBox("chat").setVisible(true);
        hidden = false;
    }
    else if(!chatActive && chatTimer.getElapsedTime().asSeconds() > 3.0 && !hidden)
    {
    	hud.getChatBox("chat").setVisible(false);
        hidden = true;
    }

    if(!pause && health > 0)
    {
        Game::blurIterations = int(lerp(Game::blurIterations, 16, 0.03));
        Game::bloomStrength = lerp(Game::bloomStrength, 0.2, 0.015);
        Game::exposure = lerp(Game::exposure, initialExposure, 0.005);
        if(!freeCamera)
            hud.setOpacity(lerp(hud.getOpacity(), 1.0, 0.05));
        pauseMenu.setOpacity(lerp(pauseMenu.getOpacity(), 0.0, 0.05));
    }
    else if(pause)
    {
        //Game::blurIterations = lerp(Game::blurIterations, 64, 0.8);
        Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.05);
        if(!freeCamera)
            hud.setOpacity(lerp(hud.getOpacity(), 0.0, 0.05));
        pauseMenu.setOpacity(lerp(pauseMenu.getOpacity(), 1.0, 0.05));
    }

    Game::mouseCursorVisible = pause || chatActive;
    Game::manageCameraMouse = !pause && !chatActive;

    if(updatePhysics)
    {
        Game::scene.GetLight("light").SetColor(Vector3(0, 0, 0));

        for(uint i = 0; i < clients.length(); i++)
        {
            if(clients[i].team == team)
            {
                auto screenPos = Game::camera.WorldPositionToScreen(clients[i].model.GetPosition() + Vector3(0, 3, 0));
                hud.getLabel("client" + to_string(clients[i].id)).setPosition(screenPos.x, screenPos.y);
            }
            else hud.getLabel("client" + to_string(clients[i].id)).setPosition(-1000, -1000);

            Game::scene.GetModel("flash-rifle" + to_string(clients[i].id)).SetIsDrawable(false);
            Game::scene.GetModel("flash-deagle" + to_string(clients[i].id)).SetIsDrawable(false);
            Game::scene.GetLight("light-copy" + to_string(clients[i].id)).SetColor(Vector3(0, 0, 0));
        }
    }

    Packet p;
    while(socket.receive(p) == Socket::Done)
    {
        int code = -1, newId = -1, newTeam = -1, weapon = 0;
        string newName;
        bool moving = false, onGround = true, isRunning = true, isReloading = false;
        Vector3 pos, euler;
        Quaternion orient;
        if(p >> code)
            switch(code)
            {
	            case 0:
	            {
	                p >> newId;
	                p >> newName;
                    p >> newTeam;

	                if(clients.find(Client(newId)) < 0 && newId != id)
	                {
	                    Model@ model = @Game::scene.CloneModel(Game::scene.GetModel("enemy:ground"), true, "enemy" + to_string(newId) + ":ground");
                        model.SetPosition(Vector3(0, 1000, 0));
	                    model.GetRigidBody().setIsActive(true);
	                    Model@ chel = @Game::scene.CloneModel(Game::scene.GetModel("chel"), true, "chel" + to_string(newId));
                        chel.SetPosition(Vector3(0, 1000, 0));
	                    chel.SetIsDrawable(true);
	                    Model@ rifle = @Game::scene.CloneModel(Game::scene.GetModel("rifle-copy"), true, "rifle-copy" + to_string(newId));
                        Model@ deagle = @Game::scene.CloneModel(Game::scene.GetModel("deagle-copy"), true, "deagle-copy" + to_string(newId));
                        Model@ knife = @Game::scene.CloneModel(Game::scene.GetModel("knife-copy"), true, "knife-copy" + to_string(newId));
                        Model@ flash = @Game::scene.CloneModel(Game::scene.GetModel("flash"), true, "flash-rifle" + to_string(newId));
                        Model@ flash1 = @Game::scene.CloneModel(Game::scene.GetModel("flash1"), true, "flash-deagle" + to_string(newId));
                        Light@ light = @Game::scene.CloneLight(Game::scene.GetLight("light"), true, "light-copy" + to_string(newId));
                        Light@ light1 = @Game::scene.CloneLight(Game::scene.GetLight("light1"), true, "light1-copy" + to_string(newId));

                        clients.insertLast(Client(newId, newTeam, newName, model, chel));
                        clients[clients.length() - 1].tabId = hud.getListView("team" + to_string(newTeam) + "tab").addItem({ to_string(newId), newName, "0", "0" });

                        string tmp;
                        p >> tmp;
                        if(!tmp.isEmpty())
                        {
                            Model@ frontPatchModel = @Game::scene.CloneModel(Game::scene.GetModel("patch:decals"), true, "frontPatch" + to_string(newId) + ":decals");
                            frontPatchModel.SetMaterial(Game::scene.GetMaterial(tmp));
                            frontPatchModel.SetIsDrawable(true);
                            cast<Node>(Game::scene.GetBone("Body-chel" + to_string(newId))).AddChild(cast<Node>(frontPatchModel));
	                        cast<Node>(frontPatchModel).SetParent(cast<Node>(Game::scene.GetBone("Body-chel" + to_string(newId))));
                        }
                        p >> tmp;
                        if(!tmp.isEmpty())
                        {
                            Model@ backPatchModel = @Game::scene.CloneModel(Game::scene.GetModel("patch1:decals"), true, "backPatch" + to_string(newId) + ":decals");
                            backPatchModel.SetMaterial(Game::scene.GetMaterial(tmp));
                            backPatchModel.SetIsDrawable(true);
                            cast<Node>(Game::scene.GetBone("Body-chel" + to_string(newId))).AddChild(cast<Node>(backPatchModel));
	                        cast<Node>(backPatchModel).SetParent(cast<Node>(Game::scene.GetBone("Body-chel" + to_string(newId))));
                        }
                        p >> tmp;
                        while(tmp != "end")
                        {
                            clients[clients.length() - 1].hats.insertLast(tmp);
                            Model@ hatModel = @Game::scene.CloneModel(Game::scene.GetModel(tmp), true, tmp + to_string(newId));
                            hatModel.Load();
                            hatModel.SetShadowBias(0.005);
                            hatModel.SetIsDrawable(true);
                            cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))).AddChild(cast<Node>(hatModel));
	                        cast<Node>(hatModel).SetParent(cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))));
                            p >> tmp;
                        }
	                    
                        rifle.SetIsDrawable(true);
	                    deagle.SetIsDrawable(true);
	                    knife.SetIsDrawable(true);
                        flash.SetIsDrawable(false);
                        flash1.SetIsDrawable(false);
                        light.SetColor(Vector3(0, 0, 0));

                        Model@ head = @Game::scene.CloneModel(Game::scene.GetModel("head"), true, "head" + to_string(newId));

	                    cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))).AddChild(cast<Node>(rifle));
	                    cast<Node>(rifle).SetParent(cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))));
	                    cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))).AddChild(cast<Node>(deagle));
	                    cast<Node>(deagle).SetParent(cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))));
                        
                        cast<Node>(rifle).AddChild(cast<Node>(flash));
	                    cast<Node>(flash).SetParent(cast<Node>(rifle));
	                    cast<Node>(deagle).AddChild(cast<Node>(flash1));
	                    cast<Node>(flash1).SetParent(cast<Node>(deagle));

	                    cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))).AddChild(cast<Node>(knife));
	                    cast<Node>(knife).SetParent(cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))));
	                    cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))).AddChild(cast<Node>(head));
	                    cast<Node>(head).SetParent(cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))));

                        cast<Node>(model).AddChild(cast<Node>(light));
	                    cast<Node>(light).SetParent(cast<Node>(model));

                        cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))).AddChild(cast<Node>(light1));
	                    cast<Node>(light1).SetParent(cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))));

                        hud.copyLabel(hud.getLabel("name"), "client" + to_string(newId));
                        hud.getLabel("client" + to_string(newId)).setText(newName);
                        hud.getLabel("client" + to_string(newId)).setVisible(true);
                        hud.getLabel("client" + to_string(newId)).setPosition(-1000, -1000);

                        player.SetGroundGroup(Game::scene.GetModelGroup("ground"));
                        
	                    p.clear();
	                    p << 0; p << id; p << name; p << team;
	                    socket.send(p);
	                }
	                break;
	            }
	            
	            case 1:
	            {
	                p >> newId;

                    if(id == newId)
                    {
                        int tmpTeam = team;
                        p >> pos.x >> pos.y >> pos.z >> team;
                        if(team != tmpTeam)
                        {
                            hud.getListView("team" + to_string(tmpTeam) + "tab").removeItem(tabId);
                            tabId = hud.getListView("team" + to_string(team) + "tab").addItem({ to_string(id), name, to_string(kills), to_string(deaths) });
                        }
                        Game::scene.GetModel("player").GetRigidBody().setLinearVelocity(Vector3(0, 0, 0));
                        Game::scene.GetModel("player").GetRigidBody().setAngularVelocity(Vector3(0, 0, 0));
                        Game::scene.GetModel("player").SetPosition(pos);
                        Game::scene.GetModel("chel").SetMaterial(Game::scene.GetMaterial("character" + to_string(team)));
                        break;
                    }

	                p >> moving;
	                p >> onGround;
                    p >> isRunning;
                    p >> isReloading;

                    int cl = clients.find(Client(newId));
                    if(cl < 0) break;

                    if(clients[cl].prevOnGround && !onGround)
                    {
                        Game::scene.GetSoundManager().SetPosition(clients[cl].model.GetPosition(), "jump", newId);
                        Game::scene.GetSoundManager().Play("jump", newId);
                    }
                    else if(!clients[cl].prevOnGround && onGround)
                    {
                        Game::scene.GetSoundManager().SetPosition(clients[cl].model.GetPosition(), "land", newId);
                        Game::scene.GetSoundManager().Play("land", newId);
                    }

                    clients[cl].prevOnGround = onGround;

                    if(moving && onGround && isRunning && clients[cl].footsteps.getElapsedTime().asSeconds() >= 0.3)
                    {
                        auto soundNum = to_string(int(rnd(1, 5)));
                        Game::scene.GetSoundManager().SetPosition(clients[cl].model.GetPosition(), "footstep" + soundNum, newId);
                        Game::scene.GetSoundManager().Play("footstep" + soundNum, newId);
                        clients[cl].footsteps.restart();
                    }

                    if(clients[cl].health <= 0)
                    {
                        if(Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).GetState() == Stopped)
                        {
                            Game::scene.GetAnimation("HoldRifle-chel-chel" + to_string(newId)).Stop();
                            Game::scene.GetAnimation("HoldPistol-chel-chel" + to_string(newId)).Stop();
                            Game::scene.GetAnimation("HoldKnife-chel-chel" + to_string(newId)).Stop();
    	                    Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).Play();
                            
    	                    p >> pos.x >> pos.y >> pos.z >> orient.x >> orient.y >> orient.z >> orient.w;
                            euler = EulerFromQuaternion(orient);
                        
                            clients[cl].chel.SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0) + euler.z, 0)));
                            clients[cl].model.SetPosition(pos);
                        }
                        else
                        {
                        	p >> pos.x >> pos.y >> pos.z;
                        	clients[cl].model.SetPosition(pos);
                            clients[cl].chel.SetPosition(pos - Vector3(0, 0.7, 0));
                        }
                        break;
                    }
                    else if(Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).GetState() != Stopped)
                    {
                        Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).Stop();
                        clients[cl].chel.DefaultPose();
                        break;
                    }
	                else if(onGround && moving && Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).GetState() == Stopped)
	                {
	                    Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).Play();
                        Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)).Stop();
                        Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).Stop();
	                }
	                else if(!moving && onGround)
	                {
	                    Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)).Play();
                        Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).Stop();
                        Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).Stop();
	                }
	                else if(!onGround && Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).GetState() == Stopped)
	                {
	                    Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).Play();
                        Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)).Stop();
                        Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).Stop();
	                }
	                
	                p >> pos.x >> pos.y >> pos.z >> orient.x >> orient.y >> orient.z >> orient.w >> weapon;

                    Game::scene.GetAnimation("HoldRifle-chel-chel" + to_string(newId)).Stop();
                    Game::scene.GetAnimation("HoldPistol-chel-chel" + to_string(newId)).Stop();
                    Game::scene.GetAnimation("HoldKnife-chel-chel" + to_string(newId)).Stop();

                    switch(weapon)
                    {
                    case 0:
                        Game::scene.GetModel("rifle-copy" + to_string(newId)).SetIsDrawable(true);
                        Game::scene.GetModel("deagle-copy" + to_string(newId)).SetIsDrawable(false);
                        Game::scene.GetModel("knife-copy" + to_string(newId)).SetIsDrawable(false);
                        Game::scene.GetAnimation("HoldRifle-chel-chel" + to_string(newId)).Play();
                        break;
                    case 1:
                        Game::scene.GetModel("rifle-copy" + to_string(newId)).SetIsDrawable(false);
                        Game::scene.GetModel("deagle-copy" + to_string(newId)).SetIsDrawable(true);
                        Game::scene.GetModel("knife-copy" + to_string(newId)).SetIsDrawable(false);
                        Game::scene.GetAnimation("HoldPistol-chel-chel" + to_string(newId)).Play();
                        break;
                    case 2:
                        Game::scene.GetModel("rifle-copy" + to_string(newId)).SetIsDrawable(false);
                        Game::scene.GetModel("deagle-copy" + to_string(newId)).SetIsDrawable(false);
                        Game::scene.GetModel("knife-copy" + to_string(newId)).SetIsDrawable(true);
                        Game::scene.GetAnimation("HoldKnife-chel-chel" + to_string(newId)).Play();
                        break;
                    }

                    if(isReloading && !clients[cl].reloading)
                        Game::scene.GetSoundManager().Play(weapons[weapon].reloadSound, newId);
                    if(!weapons[weapon].reloadSound.isEmpty())
                        Game::scene.GetSoundManager().SetPosition(pos, weapons[weapon].reloadSound, newId);

                    clients[cl].reloading = isReloading;

                    float offset = (moving && onGround ? sin(logoTime.getElapsedTime().asSeconds() * 20) * 0.05 : 0.0);

	                clients[cl].model.SetPosition(pos);
                    clients[cl].chel.SetPosition(pos - Vector3(0, 0.7 + offset, 0));
                    clients[cl].chel.SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0), 0)));
                    clients[cl].orient = Quaternion(orient.y, orient.z, orient.x, orient.w);
                    clients[cl].tracerOrient = clients[cl].orient * QuaternionFromEuler(Vector3(0, radians(90), 0));
                    
                    auto euler = EulerFromQuaternion(orient);
                    auto euler1 = euler; euler1.x = radians(90.0);
                    auto euler2 = euler; euler2.x /= 2; euler2.y = euler2.z = 0.0;
                    auto euler3 = euler; euler3.y = euler3.x; euler3.x = radians(5.5); euler3.z = radians(-90);
                    if(isReloading)
                        euler3.y = radians(40);
                    euler.x = radians(-5); euler.y = moving || !onGround ? radians(-40) : radians(-35);

                    Game::scene.GetBone("Body-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Body-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler1), 0.5));

                    Game::scene.GetBone("Bone.013-chel" + to_string(newId)).SetOrientation(QuaternionFromEuler(euler2));
                    Game::scene.GetBone("Bone.014-chel" + to_string(newId)).SetOrientation(QuaternionFromEuler(euler2));

                    Game::scene.GetBone("Left-Arm.0-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Left-Arm.0-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler3 + Vector3(0, 0.057, 0)), 0.5));
                    Game::scene.GetBone("Right-Arm.0-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Right-Arm.0-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(Vector3(-0.25, -euler3.y - 0.03, 1.57)), 0.5));

                    Game::scene.GetBone("Bone.007-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(moving || !onGround ? Vector3(0, 0, 1.57) : Vector3(-0.05, radians(20), radians(60.0))), 0.07));
                    euler.y = -euler.y;
                    Game::scene.GetBone("Bone.010-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, -1.57)), 0.1));
 
                    break;
	            }

                case 2:
                {
                    int id0 = -1, id1 = -1;
                    bool hs = false;
                    p >> id0 >> id1 >> hs >> weapon;
                    int it = clients.find(Client(id0));
                    Game::scene.GetSoundManager().SetPosition(clients[it].model.GetPosition(), weapons[weapon].sound, id0);
                    Game::scene.GetSoundManager().Play(weapons[weapon].sound, id0);

                    if(weapon != 2)
                    {
                        auto tracer = Game::scene.CloneModel(Game::scene.GetModel("tracer"), false, "tracer-copy" + to_string(tracerCounter++));
                        tracer.SetPosition(clients[it].model.GetPosition() + Vector3(0, 2.5, 0) + clients[it].tracerOrient * Vector3(0.6, -0.3, -11));
                        tracer.SetOrientation(clients[it].tracerOrient * QuaternionFromEuler(Vector3(1.57, 0.0, 0.0)));
                        tracer.SetSize(Vector3(0.01, rnd(1, 10), 0.01));
                        tracer.SetIsDrawable(true);
                        tracers.insertLast(tracer);
                    }

                    switch(weapon)
                    {
                    case 0:
                        Game::scene.GetModel("flash-rifle" + to_string(id0)).SetIsDrawable(true);
                        Game::scene.GetLight("light-copy" + to_string(id0)).SetColor(Vector3(25, 10, 2));
                        break;
                    case 1:
                        Game::scene.GetModel("flash-deagle" + to_string(id0)).SetIsDrawable(true);
                        Game::scene.GetLight("light-copy" + to_string(id0)).SetColor(Vector3(25, 10, 2));
                        break;
                    default: break;
                    }

                    RaycastInfo info;
                    Ray ray(clients[it].model.GetPosition() + Vector3(0, 2.8, 0), clients[it].model.GetPosition() + Vector3(0, 2.8, 0) + clients[it].tracerOrient * Vector3(0, 0, -1000));
                    bool hit = Game::scene.GetModel(currentMap + ":ground").GetRigidBody().raycast(ray, info);
                    if(id1 > -1)
                    {
                        auto hitNum = to_string(int(rnd(1, 3)));
                        if(id == id1)
                        {
                            pos = Game::camera.GetPosition();
                            Game::scene.GetSoundManager().PlayMono("hit" + hitNum, id);
                        }
                        else
                        {
                            int it = clients.find(Client(id1));
                            pos = clients[it].model.GetPosition();
                            Game::scene.GetSoundManager().SetPosition(pos, "hit" + hitNum, id1);
                            Game::scene.GetSoundManager().Play("hit" + hitNum, id1);
                        }
                        
                        if(hit)
                        {
                            auto model = Game::scene.CloneModel(Game::scene.GetModel("blood-decal"), true, "decal" + to_string(decalCounter++) + ":decals");
                            auto pos = info.worldPoint;
                            model.SetPosition(pos);
                            model.SetOrientation(LookAt(pos, pos + (QuaternionFromEuler(Vector3(1.57, 0, 0)) * clients[it].tracerOrient * info.worldNormal), info.worldNormal));
                            model.SetIsDrawable(true);
                            if(decalCounter - decalRemoveCounter > 200)
                                Game::scene.RemoveModel(Game::scene.GetModel("decal" + to_string(decalRemoveCounter++) + ":decals"));
                        }
                    }

                    if(hit)
                    {
                        auto model = Game::scene.CloneModel(Game::scene.GetModel("bullet-decal"), true, "decal" + to_string(decalCounter++) + ":decals");
                        auto pos = info.worldPoint;
                        model.SetPosition(pos);
                        model.SetOrientation(LookAt(pos, pos + (QuaternionFromEuler(Vector3(1.57, 0, 0)) * clients[it].tracerOrient * info.worldNormal), info.worldNormal));
                        model.SetIsDrawable(true);
                        if(decalCounter - decalRemoveCounter > 200)
                            Game::scene.RemoveModel(Game::scene.GetModel("decal" + to_string(decalRemoveCounter++) + ":decals"));
                    }
                    break;
                }

                case 3:
                {
                    hud.getChatBox("chat").showWithEffect(tgui::Fade, seconds(0.5));
                    hidden = false;
                    chatTimer.restart();
                    string message; 
                    int type = 0;
                    p >> message >> type;
                    if(type == 0)
                        hud.getChatBox("chat").addLine(message);
                    else if(type == 1)
                        hud.getChatBox("chat").addLine(message, tgui::Color(150, 150, 255));
                    else if(type == 2)
                        hud.getChatBox("chat").addLine(message, tgui::Color(255, 150, 150));
                    break;
                }

                case 4:
                {
                    p >> newId;
                    int cl = clients.find(Client(newId));
                    hud.getChatBox("chat").addLine(clients[cl].name + " disconnected", tgui::Color(150, 150, 255));
                    hud.getListView("team" + to_string(clients[cl].team) + "tab").removeItem(clients[cl].tabId);
                    Game::scene.RemoveModel(clients[cl].model);
                    Game::scene.RemoveModel(clients[cl].chel);
                    Game::scene.RemoveLight(Game::scene.GetLight("light-copy" + to_string(newId)));
                    Game::scene.RemoveLight(Game::scene.GetLight("light1-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("rifle-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("deagle-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("knife-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("flash-rifle" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("flash-deagle" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Default-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)));
                    for(int i = 0; i < clients[cl].hats.length(); i++)
                        Game::scene.RemoveModel(Game::scene.GetModel(clients[cl].hats[i] + to_string(newId)));
                    hud.getLabel("client" + to_string(newId)).setVisible(false);
                    clients.removeAt(cl);
                    player.SetGroundGroup(Game::scene.GetModelGroup("ground"));
                    break;
                }

                case 5:
                {
                    p >> newId;
                    if(newId == id)
                    {
                        p >> health >> kills >> deaths;
                        hud.getListView("team" + to_string(team) + "tab").changeItem(tabId, { to_string(id), name, to_string(kills), to_string(deaths) });
                        break;
                    }

                    int cl = clients.find(Client(newId));
                    if(cl < 0) break;
                    int tmpTeam = clients[cl].team;
	                p >> clients[cl].health >> clients[cl].kills >> clients[cl].deaths >> clients[cl].team;
                    if(clients[cl].team != tmpTeam)
                    {
                        hud.getListView("team" + to_string(tmpTeam) + "tab").removeItem(clients[cl].tabId);
                        clients[cl].tabId = hud.getListView("team" + to_string(clients[cl].team) + "tab").addItem({ "", "", "", "" });
                    }
                    hud.getListView("team" + to_string(clients[cl].team) + "tab").changeItem(clients[cl].tabId, { to_string(clients[cl].id), clients[cl].name, to_string(clients[cl].kills), to_string(clients[cl].deaths) });
	                if(clients[cl].health > 0)
                    {
	                    clients[cl].chel.SetMaterial(Game::scene.GetMaterial("character" + to_string(clients[cl].team)));
                        /*if(!Game::scene.GetModel("rifle-copy" + to_string(clients[cl].id)).IsDrawable())
                            Game::scene.GetModel("rifle-copy" + to_string(clients[cl].id)).SetIsDrawable(true);*/
                    }
	                else
                    {
                        Game::scene.GetModel("rifle-copy" + to_string(clients[cl].id)).SetIsDrawable(false);
                        Game::scene.GetModel("deagle-copy" + to_string(clients[cl].id)).SetIsDrawable(false);
                        Game::scene.GetModel("knife-copy" + to_string(clients[cl].id)).SetIsDrawable(false);
                    }
                    break;
                }

                case 6:
                {
                    p >> score[0] >> score[1];
                    break;
                }

                case 7:
                {
                    p >> currentMap >> night;

                    if(night)
                    {
                        Game::scene.LoadEnvironment("assets/textures/night.hdr");
                        Game::scene.GetLight("light1").SetColor(Vector3(3, 3, 3));
                        for(int i = 0; i < clients.length(); i++)
                            Game::scene.GetLight("light1-copy" + to_string(clients[i].id)).SetColor(Vector3(3, 3, 3));
                    }
                    else
                    {
                        Game::scene.LoadEnvironment("assets/textures/sky1.hdr");
                        Game::scene.GetLight("light1").SetColor(Vector3(0, 0, 0));
                        for(int i = 0; i < clients.length(); i++)
                            Game::scene.GetLight("light1-copy" + to_string(clients[i].id)).SetColor(Vector3(0, 0, 0));
                    }
                    for(uint i = 0; i < mapNames.length(); i++)
                        Game::scene.GetModel(mapNames[i] + ":ground").Unload(true);
                    Game::scene.GetModel(currentMap + ":ground").Load();
                    Game::scene.GetModel(currentMap + ":ground").SetIsDrawable(true);
                    
                    Game::scene.GetModel(currentMap + ":ground").GetRigidBody().setMaterial(mat);

                    break;
                }
            }
    }
    
    hud.getLabel("score").setText(to_string(score[team]) + "-" + to_string(score[(team < 1 ? 1 : 0)]));
    hud.getLabel("team0score").setText(to_string(score[0]));
    hud.getLabel("team1score").setText(to_string(score[1]));

	if(!freeCamera)
	{
        player.Update();
        
        float offset = (player.IsMoving() && player.IsOnGround() && !player.BhopDelayActive() ? sin(logoTime.getElapsedTime().asSeconds() * 20) * 0.05 : 0.0);
        float offset1 = (player.IsMoving() && player.IsOnGround() && !player.BhopDelayActive() ? sin(logoTime.getElapsedTime().asSeconds() * 10) * 0.05 : 0.0);

	    Game::camera.SetPosition(Game::scene.GetModel("player").GetPosition() + Vector3(0, 1.65, 0) + Game::camera.GetOrientation() * Vector3(offset1, 0.6, -0.5));

		int vel = int(Game::scene.GetModel("player").GetRigidBody().getLinearVelocity().length());
	    hud.getLabel("velocity").setText(to_string(vel));
	    if(vel < 0) engine.Close();

        hud.getLabel("ammo").setText(to_string(weapons[currentWeapon].currentAmmo));
        hud.getLabel("reserve").setText(to_string(weapons[currentWeapon].reserve));

	    p.clear();
	    auto pos = Game::scene.GetModel("player").GetPosition();
	    auto orient = Game::camera.GetOrientation();
	    auto orient1 = orient = orient * QuaternionFromEuler(Vector3(0, radians(-90), 0));
	    orient1.x = orient.z; orient1.y = orient.x; orient1.z = orient.y;

	    Game::scene.GetModel("chel").SetPosition(pos - Vector3(0, 0.7 + offset, 0));
	    Game::scene.GetModel("chel").SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0), 0)));
	    if(hats.length() > 0)
            for(int i = 0; i < hats.length(); i++)
                Game::scene.GetModel(hats[i]).SetIsDrawable(false);
        Game::scene.GetBone("Bone.014-chel").SetSize(Vector3(1.0, 1.0, 0.1));

        auto euler = EulerFromQuaternion(orient1);
        auto euler1 = euler; euler1.x = radians(90.0);
        auto euler2 = euler; euler2.x /= 2; euler2.y = euler2.z = 0.0;
        auto euler3 = euler; euler3.y = euler3.x; euler3.x = radians(5.5); euler3.z = radians(-90);
        if(weapons[currentWeapon].reloading)
            euler3.y = radians(40);
        euler.x = radians(-5); euler.y = player.IsMoving() || !player.IsOnGround() ? radians(-40) : radians(-35);

        Game::scene.GetBone("Body-chel").SetOrientation(slerp(Game::scene.GetBone("Body-chel").GetOrientation(), QuaternionFromEuler(euler1), 0.5));

        Game::scene.GetBone("Bone.013-chel").SetOrientation(QuaternionFromEuler(euler2));
        Game::scene.GetBone("Bone.014-chel").SetOrientation(QuaternionFromEuler(euler2));

        Game::scene.GetBone("Left-Arm.0-chel").SetOrientation(slerp(Game::scene.GetBone("Left-Arm.0-chel").GetOrientation(), QuaternionFromEuler(euler3 + Vector3(0.0, 0.057, 0.0)), weapons[currentWeapon].reloading ? 0.05 : 0.5));
        Game::scene.GetBone("Right-Arm.0-chel").SetOrientation(slerp(Game::scene.GetBone("Right-Arm.0-chel").GetOrientation(), QuaternionFromEuler(Vector3(-0.25, -euler3.y - 0.03, 1.57)), weapons[currentWeapon].reloading ? 0.05 : 0.5));

        Game::scene.GetBone("Bone.007-chel").SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel").GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(player.IsMoving() || !player.IsOnGround() ? Vector3(0, 0, 1.57) : Vector3(-0.05, radians(20), radians(60.0))), 0.07));
        euler.y = -euler.y;
        Game::scene.GetBone("Bone.010-chel").SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel").GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, -1.57)), 0.1));
        
        if(updatePhysics)
	    {
	        for(uint i = 0; i < tracers.length(); i++)
	        {
	            tracers[i].Move(tracers[i].GetOrientation() * QuaternionFromEuler(Vector3(-1.57, 0.0, 0.0)) * Vector3(0, 0, -17));
	            //tracers[i].Expand(Vector3(0.015, -0.0005, 0.015));
	            float y = tracers[i].GetSize().y;
	            tracers[i].SetSize((Vector3(0.01, 0.0, 0.01) * (Game::camera.GetPosition() - tracers[i].GetPosition()).length() / 10.0) + Vector3(0, y, 0));
	        }
	
	        for(uint i = 0; i < tracers.length(); i++)
	        {
                Ray ray(tracers[i].GetPosition(), tracers[i].GetPosition() + (tracers[i].GetOrientation() * QuaternionFromEuler(Vector3(-1.57, 0.0, 0.0)) * Vector3(0, 0, -17)));
                RaycastInfo info;
	            if((Game::camera.GetPosition() - tracers[i].GetPosition()).length() > 500.0 || Game::scene.GetModel(currentMap + ":ground").GetRigidBody().raycast(ray, info))
	            {
	                Game::scene.RemoveModel(tracers[i]);
	                tracers.removeAt(i);
	            }
	        }
	        
			for(uint i = 0; i < weapons.length(); i++)
		        if(i != 2)
		        	if(weapons[i].flash.IsDrawable() && removeFlash)
		        	{
		            	weapons[i].flash.SetIsDrawable(false);
	
						auto tracer = Game::scene.CloneModel(Game::scene.GetModel("tracer"), false, "tracer-copy" + to_string(tracerCounter++));
                        if(i == 0)
		            	    tracer.SetPosition(Game::camera.GetPosition() + tracerOrient * Vector3(0.52, -0.48, -11));
                        else tracer.SetPosition(Game::camera.GetPosition() + tracerOrient * Vector3(0.4, -0.3, -11));
	   	                tracer.SetOrientation(tracerOrient * QuaternionFromEuler(Vector3(1.57, 0.005, -0.1)));
	   	                tracer.SetSize(Vector3(0.01, rnd(1, 10), 0.01));
	   	                tracer.SetIsDrawable(true);
	   	                tracers.insertLast(tracer);
						removeFlash = false;
		            }
		            else if(weapons[i].flash.IsDrawable() && !removeFlash)
		            	removeFlash = true;
	
			if(health <= 0)
			{
			    Game::exposure = lerp(Game::exposure, 0.0, 0.005);
			    Game::blurIterations = int(lerp(Game::blurIterations, 64, 0.03));
			    Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.15);
                for(int i = 0; i < weapons.length(); i++)
                    weapons[i].ResetAmmo();
			}
	    }
	
        if(Keyboard::isKeyPressed(Keyboard::Q) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
        {
            Log::Write(pos.to_string() + ",");
            buttonTimer.restart();
        }

        if(networkTime.getElapsedTime().asMilliseconds() < 15)
            return;

        networkTime.restart();

		p << 1;
		
	    p << id;
	
	    p << player.IsMoving();
	    p << player.IsOnGround();
	    p << player.IsRunning();
        p << weapons[currentWeapon].reloading;
	
	    p << pos.x;
	    p << pos.y;
	    p << pos.z;
	
	    p << orient.z;
	    p << orient.x;
	    p << orient.y;
	    p << orient.w;
	
	    p << currentWeapon;
	
	    socket.send(p);
	    p.clear();
	    if(pos.y < -10)
	    {
	        p << -69;
	        socket.send(p);
	        p.clear();
	    }
	}
    else
    {
        if(freeCameraFollowPlayer)
            Game::camera.SetOrientation(LookAt(Game::camera.GetPosition(true), follow.GetPosition(), Vector3(0, 1, 0)));
        if(Keyboard::isKeyPressed(Keyboard::LControl))
            Game::camera.SetSpeed(Game::camera.GetSpeed() - 0.001);
        if(Keyboard::isKeyPressed(Keyboard::LShift))
            Game::camera.SetSpeed(Game::camera.GetSpeed() + 0.001);
        if(Keyboard::isKeyPressed(Keyboard::U))
            Game::dofMinDistance += 0.001;
        if(Keyboard::isKeyPressed(Keyboard::J))
            Game::dofMinDistance -= 0.001;
        if(Keyboard::isKeyPressed(Keyboard::I))
            Game::dofMaxDistance += 0.001;
        if(Keyboard::isKeyPressed(Keyboard::K))
            Game::dofMaxDistance -= 0.001;
        if(Keyboard::isKeyPressed(Keyboard::O))
            Game::dofFocusDistance += 0.001;
        if(Keyboard::isKeyPressed(Keyboard::L))
            Game::dofFocusDistance -= 0.001;
    }
};
