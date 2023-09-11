GameLoop@ mainGameLoop = function()
{
    hud.getProgressBar("health").setValue(health);

    Game::mouseSensitivity = pauseMenu.getSlider("sensitivity").getValue();
    pauseMenu.getLabel("sensVal").setText(to_string(Game::mouseSensitivity));

    if(Keyboard::isKeyPressed(Keyboard::T) && !pause)
        chatActive = true;

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

    if(Keyboard::isKeyPressed(Keyboard::Escape) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
    {
        buttonTimer.restart();
        if(chatActive)
            chatActive = false;
        else
            pause = !pause;
    }

    hud.getEditBox("chatField").setVisible(chatActive);
    hud.getEditBox("chatField").setEnabled(chatActive);

    if(!pause && health > 0)
    {
        Game::blurIterations = int(lerp(Game::blurIterations, 16, 0.03));
        Game::bloomStrength = lerp(Game::bloomStrength, 0.2, 0.015);
        Game::exposure = lerp(Game::exposure, 1.0, 0.005);
        hud.setOpacity(lerp(hud.getOpacity(), 1.0, 0.05));
        pauseMenu.setOpacity(lerp(pauseMenu.getOpacity(), 0.0, 0.05));
    }
    else if(pause)
    {
        //Game::blurIterations = lerp(Game::blurIterations, 64, 0.8);
        Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.05);
        hud.setOpacity(lerp(hud.getOpacity(), 0.0, 0.05));
        pauseMenu.setOpacity(lerp(pauseMenu.getOpacity(), 1.0, 0.05));
    }

    Game::mouseCursorVisible = pause || chatActive;
    Game::manageCameraMouse = !pause && !chatActive;

    Game::scene.GetLight("light").SetColor(Vector3(0, 0, 0));

    Packet p;
    while(socket.receive(p) == Socket::Done)
    {
        int code = -1, newId = -1, newTeam = -1;
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
	                    rifle.SetIsDrawable(true);
                        Model@ head = @Game::scene.CloneModel(Game::scene.GetModel("head"), true, "head" + to_string(newId));
	                    cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))).AddChild(cast<Node>(rifle));
	                    cast<Node>(rifle).SetParent(cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))));
	                    cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))).AddChild(cast<Node>(head));
	                    cast<Node>(head).SetParent(cast<Node>(Game::scene.GetBone("Bone.014-chel" + to_string(newId))));
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
                        p >> pos.x >> pos.y >> pos.z;
                        Game::scene.GetModel("player").GetRigidBody().setLinearVelocity(Vector3(0, 0, 0));
                        Game::scene.GetModel("player").SetPosition(pos);
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
	                
	                p >> pos.x >> pos.y >> pos.z >> orient.x >> orient.y >> orient.z >> orient.w;

	                clients[clients.find(Client(newId))].model.SetPosition(pos);
                    clients[clients.find(Client(newId))].chel.SetOrientation(QuaternionFromEuler(Vector3(radians(-90.0), radians(-90.0), 0)));
	                Game::scene.GetBone("Body-chel" + to_string(newId)).SetOrientation(orient * QuaternionFromEuler(Vector3(radians(90), 0, 0)));

	                euler = EulerFromQuaternion(orient); euler.x = 0; euler.y = radians(-30);

	                Game::scene.GetBone("Bone.007-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(90))), 0.1));
	                euler.y = -euler.y;
	                Game::scene.GetBone("Bone.010-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(-90))), 0.1));
	                break;
	            }

                case 2:
                {
                    int id0 = -1, id1 = -1;
                    p >> id0 >> id1;
                    int it = clients.find(Client(id0));
                    Game::scene.GetSoundManager().SetPosition(clients[it].model.GetPosition(), "ak47-shot", id0);
                    Game::scene.GetSoundManager().Play("ak47-shot", id0);
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
                    Game::scene.RemoveModel(Game::scene.GetModel("rifle-copy" + to_string(newId)));
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
                        if(!Game::scene.GetModel("rifle-copy" + to_string(clients[cl].id)).IsDrawable())
                            Game::scene.GetModel("rifle-copy" + to_string(clients[cl].id)).SetIsDrawable(true);
                    }
	                else
                    {
                        Game::scene.GetModel("rifle-copy" + to_string(clients[cl].id)).SetIsDrawable(false);
	                    clients[cl].chel.SetMaterial(Game::scene.GetMaterial("character-dead"));
                    }
                    break;
                }

                case 6:
                {
                    p >> score[0] >> score[1];
                    break;
                }
            }
    }
    
    hud.getLabel("score").setText(to_string(score[team]) + "-" + to_string(score[(team < 1 ? 1 : 0)]));

    for(uint i = 0; i < clients.length(); i++)
    {
        clients[i].chel.SetPosition(clients[i].model.GetPosition() - Vector3(0, 0.1, 0));
    }

    if(updatePhysics)
        Game::scene.GetModel("flash").SetIsDrawable(false);
    if(!pause && health > 0 && !chatActive) player.Update();
    else if(health <= 0)
    {
        Game::exposure = lerp(Game::exposure, 0.0, 0.005);
        Game::blurIterations = int(lerp(Game::blurIterations, 64, 0.03));
        Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.15);
    }
    Game::camera.SetPosition(Game::scene.GetModel("player").GetPosition() + Vector3(0, 2.5, 0));

    hud.getLabel("velocity").setText(to_string(int(Game::scene.GetModel("player").GetRigidBody().getLinearVelocity().length())));

    p.clear();
    auto pos = Game::scene.GetModel("player").GetPosition();
    auto orient = Game::camera.GetOrientation();
    orient = orient * QuaternionFromEuler(Vector3(0, radians(-90), 0));

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

    socket.send(p);
    p.clear();
    if(pos.y < -10)
    {
        p << -69;
        socket.send(p);
        p.clear();
    }
};
