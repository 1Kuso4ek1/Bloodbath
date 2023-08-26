GameLoop@ mainGameLoop = function()
{
    hud.getProgressBar("health").setValue(health);

    Game::mouseSensitivity = pauseMenu.getSlider("sensitivity").getValue();
    pauseMenu.getLabel("sensVal").setText(to_string(Game::mouseSensitivity));

    if(Keyboard::isKeyPressed(Keyboard::Escape) && buttonTimer.getElapsedTime().asSeconds() > 0.3)
    {
        buttonTimer.restart();
        pause = !pause;
    }

    if(!pause)
    {
        Game::blurIterations = lerp(Game::blurIterations, 16, 0.03);
        Game::bloomStrength = lerp(Game::bloomStrength, 0.2, 0.015);
        hud.setOpacity(lerp(hud.getOpacity(), 1.0, 0.05));
        pauseMenu.setOpacity(lerp(pauseMenu.getOpacity(), 0.0, 0.05));
    }
    else
    {
        //Game::blurIterations = lerp(Game::blurIterations, 64, 0.8);
        Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.05);
        hud.setOpacity(lerp(hud.getOpacity(), 0.0, 0.05));
        pauseMenu.setOpacity(lerp(pauseMenu.getOpacity(), 1.0, 0.05));
    }

    Game::mouseCursorGrabbed = !pause;
    Game::mouseCursorVisible = pause;
    Game::manageCameraMouse = !pause;

    Game::scene.GetLight("light").SetColor(Vector3(0, 0, 0));

    Packet p;
    while(socket.receive(p) == Socket::Done)
    {
        int code = -1, newId = -1;
        string newName;
        bool moving = false, onGround = true;
        Vector3 pos, euler;
        Quaternion orient;
        if(p >> code)
            switch(code)
            {
            case 0:
                p >> newId >> newName;
                if(clients.find(Client(id, newName, null, null)) < 0)
                {
                    hud.getChatBox("chat").addLine(newName + " connected");
                    Model@ model = @Game::scene.CloneModel(Game::scene.GetModel("enemy:ground"), true, "enemy" + to_string(newId) + ":ground");
                    model.GetRigidBody().setIsActive(true);
                    Model@ chel = @Game::scene.CloneModel(Game::scene.GetModel("chel"), true, "chel" + to_string(newId));
                    chel.SetIsDrawable(true);
                    Model@ rifle = @Game::scene.CloneModel(Game::scene.GetModel("rifle-copy"), true, "rifle-copy" + to_string(newId));
                    rifle.SetIsDrawable(true);
                    cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))).AddChild(cast<Node>(rifle));
                    cast<Node>(rifle).SetParent(cast<Node>(Game::scene.GetBone("Right-Hand-chel" + to_string(newId))));
                    clients.insertLast(Client(newId, newName, model, chel));
                    p.clear();
                    p << 0; p << id; p << "amogus";
                    socket.send(p);
                }
                break;
            case 1:
                p >> newId;
                p >> moving;
                p >> onGround;

                if(onGround && moving && Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).GetState() == Stopped)
                {
                    Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)).Stop();
                    Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).Play();
                    Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).Stop();
                }
                else if(!moving && onGround)
                {
                    Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).Stop();
                    Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)).Play();
                    Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).Stop();
                }
                else if(!onGround && Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).GetState() == Stopped)
                {
                    Game::scene.GetAnimation("Armature|Walk-chel-chel" + to_string(newId)).Stop();
                    Game::scene.GetAnimation("Stand-chel-chel" + to_string(newId)).Stop();
                    Game::scene.GetAnimation("Jump-chel-chel" + to_string(newId)).Play();
                }
                
                p >> pos.x >> pos.y >> pos.z >> orient.x >> orient.y >> orient.z >> orient.w;
                //orient.z = orient.y; orient.z = -orient.z;
                Game::scene.GetModel("enemy" + to_string(newId) + ":ground").SetPosition(pos);
                Game::scene.GetBone("Body-chel" + to_string(newId)).SetOrientation(orient * QuaternionFromEuler(Vector3(radians(90), 0, 0)));

                euler = EulerFromQuaternion(orient); euler.x = 0; euler.y = radians(-30);

                Game::scene.GetBone("Bone.007-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(90))), 0.1));
                euler.y = -euler.y;
                Game::scene.GetBone("Bone.010-chel" + to_string(newId)).SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel" + to_string(newId)).GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(-90))), 0.1));
                break;
            }
    }
    
    for(int i = 0; i < clients.length(); i++)
    {
        clients[i].chel.SetPosition(clients[i].model.GetPosition());
    }

    Game::scene.GetModel("flash").SetIsDrawable(false);
    if(!pause) player.Update();
    Game::camera.SetPosition(Game::scene.GetModel("player").GetPosition() + Vector3(0, 2.5, 0));

    if(health <= 50 && health > 0)
        Game::scene.GetModel("chel").SetMaterial(Game::scene.GetMaterial("character-wounded"));
    if(health == 0)
        Game::scene.GetModel("chel").SetMaterial(Game::scene.GetMaterial("character-dead"));

    p.clear();
    auto pos = Game::scene.GetModel("player").GetPosition();
    auto orient = Game::camera.GetOrientation();
    orient = orient * QuaternionFromEuler(Vector3(0, radians(-90), 0));

    p << 1;

    p << id;

    p << player.IsMoving();
    p << player.IsOnGround();

    p << pos.x;
    p << pos.y;
    p << pos.z;

    p << orient.z;
    p << orient.x;
    p << orient.y;
    p << orient.w;

    socket.send(p);
    p.clear();
};
