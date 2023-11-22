GameLoop@ mainGameLoop = function()
{
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

    if(Keyboard::isKeyPressed(Keyboard::T) && !pause)
        chatActive = true;

    if(Game::scene.GetAnimation("knifeHit").GetState() == Paused)
        Game::scene.GetAnimation("knifeHit").Stop();
    Game::scene.GetAnimation("HoldRifle-chel").Stop();
    Game::scene.GetAnimation("HoldPistol-chel").Stop();
    Game::scene.GetAnimation("HoldKnife-chel").Stop();

    Game::scene.GetBone("Bone.014-chel").SetSize(Vector3(1, 1, 1));

    for(uint i = 0; i < weapons.length(); i++)
    {
        if(Keyboard::isKeyPressed(Keyboard::Num1 + i) && i != currentWeapon && !pause && !chatActive)
        {
            weapons[currentWeapon].model.SetIsDrawable(false);
            currentWeapon = i;
            weapons[currentWeapon].model.SetIsDrawable(true);
            Game::scene.GetAnimation("knifeHit").Stop();
            Game::scene.GetBone("Left-Arm.0-chel").SetOrientation(QuaternionFromEuler(Vector3(40, 100, -83)));
            Game::scene.GetBone("Right-Arm.0-chel").SetOrientation(QuaternionFromEuler(Vector3(-40, -100, 83)));
            switch(i)
            {
            case 0:
                Game::scene.GetAnimation("HoldRifle-chel").Play();
                break;
            case 1:
                Game::scene.GetAnimation("HoldPistol-chel").Play();
                break;
            case 2:
                Game::scene.GetAnimation("HoldKnife-chel").Play();
                break;
            }
            break;
        }
    }

    if(Keyboard::isKeyPressed(Keyboard::Enter))
    {
        auto text = hud.getEditBox("chatField").getText().toStdString();
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
    	hud.getChatBox("chat").showWithEffect(tgui::Fade, seconds(0.5));
        hidden = false;
    }
    else if(!chatActive && chatTimer.getElapsedTime().asSeconds() > 3.0 && !hidden)
    {
    	hud.getChatBox("chat").hideWithEffect(tgui::Fade, seconds(0.5));
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
            Game::scene.GetModel("flash-copy" + to_string(clients[i].id)).SetIsDrawable(false);
            Game::scene.GetModel("flash-copy1" + to_string(clients[i].id)).SetIsDrawable(false);
            Game::scene.GetLight("light-copy" + to_string(clients[i].id)).SetColor(Vector3(0, 0, 0));
        }
    }

    Packet p;
    while(socket.receive(p) == Socket::Done)
    {
        int code = -1, newId = -1, newTeam = -1, weapon = 0;
        string newName;
        bool moving = false, onGround = true, isRunning = true;
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

	                if(clients.find(Client(newId)) < 0)
	                {
	                    Model@ model = @Game::scene.CloneModel(Game::scene.GetModel("enemy:ground"), true, "enemy" + to_string(newId) + ":ground");
	                    model.GetRigidBody().setIsActive(true);
	                    Model@ chel = @Game::scene.CloneModel(Game::scene.GetModel("chel"), true, "chel" + to_string(newId));
	                    chel.SetIsDrawable(true);
	                    Model@ rifle = @Game::scene.CloneModel(Game::scene.GetModel("rifle-copy"), true, "rifle-copy" + to_string(newId));
                        Model@ deagle = @Game::scene.CloneModel(Game::scene.GetModel("deagle-copy"), true, "deagle-copy" + to_string(newId));
                        Model@ knife = @Game::scene.CloneModel(Game::scene.GetModel("knife-copy"), true, "knife-copy" + to_string(newId));
                        Model@ flash = @Game::scene.CloneModel(Game::scene.GetModel("flash"), true, "flash-copy" + to_string(newId));
                        Model@ flash1 = @Game::scene.CloneModel(Game::scene.GetModel("flash1"), true, "flash-copy1" + to_string(newId));
                        Light@ light = @Game::scene.CloneLight(Game::scene.GetLight("light"), true, "light-copy" + to_string(newId));
	                    
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
                        
	                    clients.insertLast(Client(newId, newTeam, newName, model, chel));
	                    p.clear();
	                    p << 0; p << id; p << name; p << team;
	                    socket.send(p);
	                    player.SetGroundGroup(Game::scene.GetModelGroup("ground"));
	                }
	                break;
	            }
	            
	            case 1:
	            {
	                p >> newId;

                    if(id == newId)
                    {
                        p >> pos.x >> pos.y >> pos.z >> team;
                        Game::scene.GetModel("player").GetRigidBody().setLinearVelocity(Vector3(0, 0, 0));
                        Game::scene.GetModel("player").GetRigidBody().setAngularVelocity(Vector3(0, 0, 0));
                        Game::scene.GetModel("player").SetPosition(pos);
                        Game::scene.GetModel("chel").SetMaterial(Game::scene.GetMaterial("character" + to_string(team)));
                        break;
                    }

	                p >> moving;
	                p >> onGround;
                    p >> isRunning;

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
    	                    Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).Play();
                            
    	                    p >> pos.x >> pos.y >> pos.z >> orient.x >> orient.y >> orient.z >> orient.w;
                            euler = EulerFromQuaternion(orient);
                        
                            clients[clients.find(Client(newId))].chel.SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0) + euler.z, 0)));
                            clients[clients.find(Client(newId))].model.SetPosition(pos);
                        }
                        else
                        {
                        	p >> pos.x >> pos.y >> pos.z;
                        	clients[clients.find(Client(newId))].model.SetPosition(pos);
                        }
                        break;
                    }
                    else if(Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).GetState() != Stopped)
                    {
                        Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)).Stop();
                        clients[clients.find(Client(newId))].chel.DefaultPose();
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

	                clients[clients.find(Client(newId))].model.SetPosition(pos);
                    clients[clients.find(Client(newId))].chel.SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0), 0)));
                    
                    euler = EulerFromQuaternion(orient); 
                    auto euler1 = euler; euler1.x = radians(90.0);
                    auto euler2 = euler; euler2.x /= 2; euler2.y = euler2.z = 0.0;
                    auto euler3 = euler; euler3.y = euler3.x * 0.8; euler3.x = radians(40); euler3.z = radians(-83);
                    euler.x = 0; euler.y = radians(-30);

                    Game::scene.GetBone("Body-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Body-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler1), 0.5));

                    Game::scene.GetBone("Bone.013-chel" + to_string(newId)).SetOrientation(QuaternionFromEuler(euler2));
                    Game::scene.GetBone("Bone.014-chel" + to_string(newId)).SetOrientation(QuaternionFromEuler(euler2));

                    Game::scene.GetBone("Left-Arm.0-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Left-Arm.0-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler3), 0.5));
                    //euler2.x *= -1; euler2.y = radians(-17.659); euler2.z = radians(65.436);
                    euler3.x = radians(-40); euler3.y *= -1; euler3.z = radians(83);
                    Game::scene.GetBone("Right-Arm.0-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Right-Arm.0-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler3), 0.5));

                    Game::scene.GetBone("Bone.007-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(90.0))), 0.1));
                    euler.y = -euler.y;
                    Game::scene.GetBone("Bone.010-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(-90.0))), 0.1));
 
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

                    auto tracer = Game::scene.CloneModel(Game::scene.GetModel("tracer"), false, "tracer-copy" + to_string(tracerCounter++));
                    tracer.SetPosition(clients[it].model.GetPosition() + Vector3(0, 2.7, 0) + (Game::scene.GetBone("Body-chel" + to_string(id0)).GetOrientation() * Vector3(0.6, -0.3, -11)));
                    tracer.SetOrientation(Game::scene.GetBone("Body-chel" + to_string(id0)).GetOrientation());
                    tracer.SetSize(Vector3(0.01, rnd(1, 10), 0.01));
                    tracer.SetIsDrawable(true);
                    tracers.insertLast(tracer);

                    switch(weapon)
                    {
                    case 0:
                        Game::scene.GetModel("flash-copy" + to_string(id0)).SetIsDrawable(true);
                        Game::scene.GetLight("light-copy" + to_string(id0)).SetColor(Vector3(25, 10, 2));
                        break;
                    case 1:
                        Game::scene.GetModel("flash-copy1" + to_string(id0)).SetIsDrawable(true);
                        Game::scene.GetLight("light-copy" + to_string(id0)).SetColor(Vector3(25, 10, 2));
                        break;
                    default: break;
                    }

                    if(id1 > -1)
                    {
                        auto hitNum = to_string(int(rnd(1, 3)));
                        if(id == id1)
                        {
                            pos = Game::camera.GetPosition();
                            Game::scene.GetSoundManager().PlayMono("hit" + hitNum, id);
                            break;
                        }
                        else
                        {
                            it = clients.find(Client(id1));
                            pos = clients[it].model.GetPosition();
                            Game::scene.GetSoundManager().SetPosition(pos, "hit" + hitNum, id1);
                            Game::scene.GetSoundManager().Play("hit" + hitNum, id1);
                        }
                        pos.y = 0.01;
                        auto model = Game::scene.CloneModel(Game::scene.GetModel("blood"), true);
                        model.SetPosition(pos + Vector3(rnd(-5, 5), 0, rnd(-5, 5)));
                        model.SetIsDrawable(true);
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
                    Game::scene.RemoveModel(clients[cl].model);
                    Game::scene.RemoveModel(clients[cl].chel);
                    Game::scene.RemoveLight(Game::scene.GetLight("light-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("rifle-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("deagle-copy" + to_string(newId)));
                    Game::scene.RemoveModel(Game::scene.GetModel("knife-copy" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Default-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Death-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)));
                    Game::scene.RemoveAnimation(Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)));
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
                        break;
                    }

                    int cl = clients.find(Client(newId));
                    if(cl < 0) break;
	                p >> clients[cl].health >> clients[cl].kills >> clients[cl].deaths;
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
	                    clients[cl].chel.SetMaterial(Game::scene.GetMaterial("character-dead"));
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
                    p >> currentMap;

                    for(uint i = 0; i < mapNames.length(); i++)
                        Game::scene.GetModel(mapNames[i] + ":ground").Unload(true);
                    Game::scene.GetModel(currentMap + ":ground").Load();
                    Game::scene.GetModel(currentMap + ":ground").SetIsDrawable(true);
                    Game::scene.GetModel("lobby").SetIsDrawable(false);
                    
                    Game::scene.GetModel(currentMap + ":ground").GetRigidBody().setMaterial(mat);

                    break;
                }
            }
    }
    
    hud.getLabel("score").setText(to_string(score[team]) + "-" + to_string(score[(team < 1 ? 1 : 0)]));

    for(uint i = 0; i < clients.length(); i++)
    {
        clients[i].chel.SetPosition(clients[i].model.GetPosition() - Vector3(0, 0.1, 0));
    }

	if(!freeCamera)
	{
        player.Update();
	    
	    if(player.IsMoving() && Game::scene.GetAnimation("walk").GetState() != Playing && Game::scene.GetAnimation("deploy").GetState() != Playing && player.IsOnGround())
	        Game::scene.GetAnimation("walk").Play();
	    else if((!player.IsMoving() || !player.IsOnGround()) && Game::scene.GetAnimation("walk").GetState() == Playing)
	        Game::scene.GetAnimation("walk").Pause();
	    Game::camera.SetPosition(Game::scene.GetModel("player").GetPosition() + Vector3(0, 1.15, 0) + Game::camera.GetOrientation() * Vector3(0, 0.6, -0.4));

	    hud.getLabel("velocity").setText(to_string(int(Game::scene.GetModel("player").GetRigidBody().getLinearVelocity().length())));

	    p.clear();
	    auto pos = Game::scene.GetModel("player").GetPosition();
	    auto orient = Game::camera.GetOrientation();
	    auto orient1 = orient = orient * QuaternionFromEuler(Vector3(0, radians(-90), 0));
	    orient1.x = orient.z; orient1.y = orient.x; orient1.z = orient.y;

	    Game::scene.GetModel("chel").SetPosition(pos - Vector3(0.0, 0.25, 0.0));
	    Game::scene.GetModel("chel").SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0), 0)));

		auto euler = EulerFromQuaternion(orient1); 
	    auto euler1 = euler; euler1.x = radians(90.0);
	    auto euler2 = euler; euler2.x /= 2; euler2.y = euler2.z = 0.0;
	    auto euler3 = euler; euler3.y = euler3.x; euler3.x = radians(40); euler3.z = radians(-83);
	    euler.x = 0; euler.y = radians(-30);

	    Game::scene.GetBone("Body-chel").SetOrientation(slerp(Game::scene.GetBone("Body-chel").GetOrientation(), QuaternionFromEuler(euler1), 0.5));

	    Game::scene.GetBone("Bone.014-chel").SetSize(Vector3(1.0, 1.0, 0.3));
	    Game::scene.GetBone("Bone.013-chel").SetOrientation(QuaternionFromEuler(euler2));
	    Game::scene.GetBone("Bone.014-chel").SetOrientation(QuaternionFromEuler(euler2));

	    Game::scene.GetBone("Left-Arm.0-chel").SetOrientation(slerp(Game::scene.GetBone("Left-Arm.0-chel").GetOrientation(), QuaternionFromEuler(euler3), 0.5));
	    //euler2.x *= -1; euler2.y = radians(-17.659); euler2.z = radians(65.436);
	    euler3.x = radians(-40); euler3.y *= -1; euler3.z = radians(83);
	    Game::scene.GetBone("Right-Arm.0-chel").SetOrientation(slerp(Game::scene.GetBone("Right-Arm.0-chel").GetOrientation(), QuaternionFromEuler(euler3), 0.5));

		Game::scene.GetBone("Bone.007-chel").SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel").GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(90.0))), 0.1));
		euler.y = -euler.y;
		Game::scene.GetBone("Bone.010-chel").SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel").GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(-90.0))), 0.1));

		if(updatePhysics)
	    {
	        for(uint i = 0; i < tracers.length(); i++)
	        {
	            tracers[i].Move(tracers[i].GetOrientation() * QuaternionFromEuler(Vector3(-1.57, 0.0, 0.0)) * Vector3(0, 0, -25));
	        }
	
	        for(uint i = 0; i < tracers.length(); i++)
	        {
	            if((Game::camera.GetPosition() - tracers[i].GetPosition()).length() > 100.0)
	            {
	                Game::scene.RemoveModel(tracers[i]);
	                tracers.removeAt(i);
	            }
	        }
	        
			for(uint i = 0; i < weapons.length(); i++)
		        if(i != 2)
		        	if(weapons[i].flash.IsDrawable())
		        	{
		            	weapons[i].flash.SetIsDrawable(!removeFlash);
	
						auto tracer = Game::scene.CloneModel(Game::scene.GetModel("tracer"), false, "tracer-copy" + to_string(tracerCounter++));
		            	tracer.SetPosition(Game::camera.GetPosition() + Game::camera.GetOrientation() * Vector3(0.6, -0.3, -11));
	   	                tracer.SetOrientation(Game::camera.GetOrientation() * QuaternionFromEuler(Vector3(1.57, 0.0, 0.0)));
	   	                tracer.SetSize(Vector3(0.01, rnd(1, 10), 0.01));
	   	                tracer.SetIsDrawable(true);
	   	                tracers.insertLast(tracer);
						if(!removeFlash)
	   	                	removeFlash = !removeFlash;
		            }
	
			if(health <= 0)
			{
			    Game::exposure = lerp(Game::exposure, 0.0, 0.005);
			    Game::blurIterations = int(lerp(Game::blurIterations, 64, 0.03));
			    Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.15);
			}
	    }
	
        if(Keyboard::isKeyPressed(Keyboard::Q) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
        {
            Log::Write(pos.to_string());
            buttonTimer.restart();
        }

		p << 1;
		
	    p << id;
	
	    p << player.IsMoving();
	    p << player.IsOnGround();
	    p << player.IsRunning();
	
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
};
