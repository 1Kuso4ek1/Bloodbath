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
    
    if(Keyboard::isKeyPressed(Keyboard::K))
    {
        Game::bloomStrength = lerp(Game::bloomStrength, 1.0, 0.05);
        Game::exposure = lerp(Game::exposure, 0.0, 0.02);
        Game::blurIterations = lerp(Game::blurIterations, 32.0, 0.05);
    }

    if(!pause)
    {
        Game::blurIterations = lerp(Game::blurIterations, 16, 0.8);
        Game::bloomStrength = lerp(Game::bloomStrength, 0.3, 0.015);
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
        int code = -1, moving = 0;
        Vector3 pos, euler;
        Quaternion orient;
        if(p >> code)
            switch(code)
            {
            case 0:
                Log::Write("someone connected");
                Game::scene.GetModel("enemy:ground").GetRigidBody().setType(STATIC);
                break;
            case 1:
                p >> moving;
                if(moving == 1 && Game::scene.GetAnimation("Armature|Walk-chel").GetState() == Stopped)
                {
                    Game::scene.GetAnimation("Stand-chel").Stop();
                    Game::scene.GetAnimation("Armature|Walk-chel").Play();
                }
                else if(moving == 0)
                {
                    Game::scene.GetAnimation("Armature|Walk-chel").Stop();
                    Game::scene.GetAnimation("Stand-chel").Play();
                }
                p >> pos.x >> pos.y >> pos.z >> orient.x >> orient.y >> orient.z >> orient.w;
                //orient.z = orient.y; orient.z = -orient.z;
                Game::scene.GetModel("enemy:ground").SetPosition(pos);
                Game::scene.GetBone("Body-chel").SetOrientation(orient * QuaternionFromEuler(Vector3(radians(90), 0, 0)));

                euler = EulerFromQuaternion(orient); euler.x = 0; euler.y = radians(-30);

                Game::scene.GetBone("Bone.007-chel").SetOrientation(slerp(Game::scene.GetBone("Bone.007-chel").GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(90))), 0.1));
                euler.y = -euler.y;
                Game::scene.GetBone("Bone.010-chel").SetOrientation(slerp(Game::scene.GetBone("Bone.010-chel").GetOrientation(), QuaternionFromEuler(euler) * QuaternionFromEuler(Vector3(0, 0, radians(-90))), 0.1));
                break;
            }
    }
    auto enemyPos = Game::scene.GetModel("enemy:ground").GetPosition();
    Game::scene.GetModel("chel").SetPosition(enemyPos);

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

    p << (player.IsMoving() ? 1 : 0);

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
