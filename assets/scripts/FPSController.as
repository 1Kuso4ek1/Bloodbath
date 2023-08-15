random_device dev;
default_random_engine rnd(dev());

funcdef void EventFunction();

float Dot(const Vector3& in vec1, const Vector3& in vec2)
{
    return vec1.x * vec2.x +
           vec1.y * vec2.y +
           vec1.z * vec2.z;
}

class FPSController
{
    FPSController(Model@ playerModel, ModelGroup ground)
    {
        @this.playerModel = @playerModel;
        this.ground = ground;
        @playerRB = @playerModel.GetRigidBody();
        playerRB.setAngularLockAxisFactor(Vector3(0, 1, 0));

        PhysicalMaterial mat;
        mat.setBounciness(0.0);
        mat.setFrictionCoefficient(0.0);
        playerRB.setMaterial(mat);
        for(uint i = 0; i < ground.Size(); i++)
            ground[i].GetRigidBody().setMaterial(mat);
    }

    void AddCustomEvent(EventFunction@ func)
    {
        customEvents.insertLast(func);
    }

    void Update()
    {
        auto v = Game::camera.Move(1, true); v.y = 0.0; v *= 250;
        moving = v.length() > 0;
        if(moving && footstepDelay.getElapsedTime().asSeconds() >= (Game::camera.GetSpeed() == 1 ? 0.5 : 0.35) && onGround && bhopDelay.getElapsedTime().asSeconds() >= 0.3)
        {
            auto soundNum = to_string(int(rnd(1, 4)));
            Game::scene.GetSoundManager().SetPosition(playerModel.GetPosition(), "footstep" + soundNum, 0);
            Game::scene.GetSoundManager().PlayMono("footstep" + soundNum, 0);
            footstepDelay.restart();
        }
        if((!Keyboard::isKeyPressed(Keyboard::LControl) || !onGround) && serverConfig.allowBhop)
            playerRB.applyWorldForceAtCenterOfMass((onGround && bhopDelay.getElapsedTime().asSeconds() >= 0.3) ? v : v / (Dot(v / 50, playerRB.getLinearVelocity()) < 0 ? 8 : (serverConfig.allowBhop ? 80 : 50)));
        else if(!serverConfig.allowBhop && onGround)
            playerRB.applyWorldForceAtCenterOfMass(v);

        auto vel = playerRB.getLinearVelocity();
        if(vel.x > serverConfig.maxSpeed) vel.x = serverConfig.maxSpeed;
        if(vel.z > serverConfig.maxSpeed) vel.z = serverConfig.maxSpeed;
        if(vel.x < -serverConfig.maxSpeed) vel.x = -serverConfig.maxSpeed;
        if(vel.z < -serverConfig.maxSpeed) vel.z = -serverConfig.maxSpeed;

        if(onGround && bhopDelay.getElapsedTime().asSeconds() >= 0.3 && !Keyboard::isKeyPressed(Keyboard::LControl))
            playerRB.setLinearVelocity(vel);
        //Log::Write(vel.to_string());

        if((onGround && !Keyboard::isKeyPressed(Keyboard::LControl) && bhopDelay.getElapsedTime().asSeconds() >= 0.3))
            playerRB.setLinearVelocity(
                Vector3(playerRB.getLinearVelocity().x / 1.3,
                        playerRB.getLinearVelocity().y,
                        playerRB.getLinearVelocity().z / 1.3));

        for(uint i = 0; i < customEvents.length(); i++)
            customEvents[i]();

        Ray ray(playerModel.GetPosition(), playerModel.GetPosition() - Vector3(0, playerModel.GetSize().y + 0.05, 0));
        RaycastInfo info;
        int count = 0;
        for(uint i = 0; i < ground.Size(); i++)
        {
            /*onGround = ground[i].GetRigidBody().raycast(ray, info);
            if(onGround) break;*/
            count += ground[i].GetRigidBody().raycast(ray, info) ? 1 : 0;
        }

        if(!onGround && count > 0)
        {
            onGround = true;
            Game::scene.GetSoundManager().SetPosition(playerModel.GetPosition(), "land", 0);
            Game::scene.GetSoundManager().PlayMono("land", 0);
            jumpSound = true;
        }

        onGround = count > 0;

        if(!onGround && serverConfig.allowBhop) bhopDelay.restart();

        if(Keyboard::isKeyPressed(Keyboard::Space))
        {
            if(onGround && canJump)
            {
                playerModel.GetRigidBody().applyWorldForceAtCenterOfMass(Vector3(0, serverConfig.jumpForce, 0) + Game::camera.GetOrientation() * Vector3(0, 0, -80));
                Game::scene.GetSoundManager().SetPosition(playerModel.GetPosition(), "jump", 0);
                if(jumpSound)
                    Game::scene.GetSoundManager().Play("jump", 0);
                jumpSound = false;
                canJump = false;
            }
        }
        else canJump = true;
    }

    bool IsMoving()
    {
        return moving;
    }

    bool IsOnGround()
    {
        return onGround;
    }
    
    private array<EventFunction@> customEvents;
    private Model@ playerModel;
    private ModelGroup ground;
    private RigidBody@ playerRB;
    private bool canJump;
    private bool canVault;
    private bool moving;
    private bool onGround;
    private bool jumpSound;
    private Clock bhopDelay, footstepDelay;
    private float prevVel = 0.0;
};
