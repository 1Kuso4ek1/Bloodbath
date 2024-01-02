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
        playerRB.setMaterial(mat);
    }

    void AddCustomEvent(EventFunction@ func)
    {
        customEvents.insertLast(func);
    }

    void Update()
    {
		if(!updatePhysics) return;
    
        if(pause || health <= 0 || chatActive)
        {
            UpdateIsOnGround();
            moving = false;
            if(onGround)
                playerRB.setLinearVelocity(
                    Vector3(playerRB.getLinearVelocity().x / 1.3,
                            playerRB.getLinearVelocity().y,
                            playerRB.getLinearVelocity().z / 1.3));
            return;
        }

        isRunning = !Keyboard::isKeyPressed(Keyboard::LShift);
        auto v = Game::camera.Move(isRunning ? 1.0 : 0.5, true); v.y = 0.0; v *= 250;
        moving = v.length() > 0;
        if(moving && onGround && isRunning && footstepDelay.getElapsedTime().asSeconds() >= 0.3 && !BhopDelayActive())
        {
            auto soundNum = to_string(int(rnd(1, 5)));
            //Game::scene.GetSoundManager().SetPosition(playerModel.GetPosition(), "footstep" + soundNum, id);
            Game::scene.GetSoundManager().PlayMono("footstep" + soundNum, id);
            footstepDelay.restart();
        }
        if((!Keyboard::isKeyPressed(Keyboard::LControl) || !onGround) && serverConfig.allowBhop)
            playerRB.applyWorldForceAtCenterOfMass((onGround && !BhopDelayActive()) ? v : 
v / (Dot(normalize(v), normalize(playerRB.getLinearVelocity())) < -0.01 ? 0.75 : (serverConfig.allowBhop ? 100.0 : 50.0)));
        else if(!serverConfig.allowBhop && onGround)
            playerRB.applyWorldForceAtCenterOfMass(v);

        auto vel = playerRB.getLinearVelocity();
        auto maxSpeed = serverConfig.maxSpeed * (isRunning ? 2.5 : 0.25);
        if(vel.x > maxSpeed) vel.x = maxSpeed;
        if(vel.z > maxSpeed) vel.z = maxSpeed;
        if(vel.x < -maxSpeed) vel.x = -maxSpeed;
        if(vel.z < -maxSpeed) vel.z = -maxSpeed;

        if(onGround && !BhopDelayActive() && !Keyboard::isKeyPressed(Keyboard::LControl))
            playerRB.setLinearVelocity(vel);

        if((onGround && !Keyboard::isKeyPressed(Keyboard::LControl) && !BhopDelayActive()))
            playerRB.setLinearVelocity(
                Vector3(playerRB.getLinearVelocity().x / 1.3,
                        playerRB.getLinearVelocity().y,
                        playerRB.getLinearVelocity().z / 1.3));

        for(uint i = 0; i < customEvents.length(); i++)
            customEvents[i]();

        UpdateIsOnGround();
        if(onGround)
        {
            Game::scene.GetAnimation("Jump-chel").Stop();
            Game::scene.GetAnimation("Stand-chel").Stop();
            if(moving)
            {
                if(Game::scene.GetAnimation("Armature|Walk-chel").GetState() != Playing)
                    Game::scene.GetAnimation("Armature|Walk-chel").Play();
            }
            else
            {
                Game::scene.GetAnimation("Armature|Walk-chel").Stop();
                Game::scene.GetAnimation("Stand-chel").Play();
            }
        }

        if(!onGround && serverConfig.allowBhop) bhopDelay.restart();

        if(Keyboard::isKeyPressed(Keyboard::Space))
        {
            if((onGround && canJump) || canVault)
            {
                playerModel.GetRigidBody().applyWorldForceAtCenterOfMass(Vector3(0, serverConfig.jumpForce + (canVault ? serverConfig.jumpForce / 2.0 : 0), 0) + Game::camera.GetOrientation() * Vector3(0, 0, -250));
                Game::scene.GetSoundManager().SetPosition(playerModel.GetPosition(), "jump", 0);
                if(jumpSound)
                    Game::scene.GetSoundManager().Play("jump", 0);
                Game::scene.GetAnimation("Armature|Walk-chel").Stop();
                Game::scene.GetAnimation("Stand-chel").Stop();
                Game::scene.GetAnimation("Jump-chel").Play();
                jumpSound = false;
                canJump = false;
                canVault = false;
            }
        }
        else canJump = true;
    }

    void UpdateIsOnGround()
    {
        Ray ray(playerModel.GetPosition(), playerModel.GetPosition() - Vector3(0, playerModel.GetSize().y + 0.05, 0));
        Ray ray1(Game::camera.GetPosition(true), Game::camera.GetPosition(true) + (Game::camera.GetOrientation() * Vector3(0, 0, -3)));
        Ray ray2(Game::camera.GetPosition(true) - Vector3(0.0, playerModel.GetSize().y - 0.2, 0.0), Game::camera.GetPosition(true) - Vector3(0.0, playerModel.GetSize().y - 0.2, 0.0) + (Game::camera.GetOrientation() * Vector3(0, 0, -3)));
        RaycastInfo info;
        int count = 0;
        for(uint i = 0; i < ground.Size(); i++)
        {
            /*onGround = ground[i].GetRigidBody().raycast(ray, info);
            if(onGround) break;*/
            if(!ground[i].IsLoaded()) continue;

            count += ground[i].GetRigidBody().raycast(ray, info) ? 1 : 0;
            if(!ground[i].GetRigidBody().raycast(ray1, info) && ground[i].GetRigidBody().raycast(ray2, info) && 
               vaultDelay.getElapsedTime().asSeconds() > 1)
            {
                canVault = true && !onGround;
                vaultDelay.restart();
            }
        }

        if(!onGround && count > 0)
        {
            onGround = true;
            Game::scene.GetSoundManager().SetPosition(playerModel.GetPosition(), "land", 0);
            Game::scene.GetSoundManager().PlayMono("land", 0);
            jumpSound = true;
        }

        onGround = count > 0;
    }
    
    void SetGroundGroup(ModelGroup ground)
    {
        this.ground = ground;
    }

    bool BhopDelayActive()
    {
        return bhopDelay.getElapsedTime().asSeconds() < 0.3;
    }

    bool IsMoving()
    {
        return moving;
    }

    bool IsRunning()
    {
        return isRunning;
    }

    bool IsOnGround()
    {
        return onGround;
    }
    
    private array<EventFunction@> customEvents;
    private Model@ playerModel;
    private ModelGroup ground;
    private RigidBody@ playerRB;
    private bool isRunning;
    private bool canJump;
    private bool canVault;
    private bool moving;
    private bool onGround;
    private bool jumpSound;
    private Clock bhopDelay, footstepDelay, vaultDelay;
    private float prevVel = 0.0;
};
