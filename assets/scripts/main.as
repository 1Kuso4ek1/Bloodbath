FPSController@ player;

TcpSocket socket;
tgui::Gui@ menu, hud, pauseMenu;

int health = 100;
int id = 0, team = 0, kills = 0, deaths = 0, lastPort = 0;
uint currentWeapon = 0;

string name, password, lastIp;

Clock physicsTime, logoTime, delay, buttonTimer;

bool pause = false, updatePhysics = true, chatActive = false, logo = true;

array<int> score = { 0, 0 };
array<Weapon> weapons;

funcdef void GameLoop();

GameLoop@ currentLoop = @menuLoop;/*@mainGameLoop;*/

class Client
{
    Client() {}

    Client(int id, int team, string name, Model@ model, Model@ chel)
    {
        this.id = id;
        this.team = team;
        this.name = name;
        @this.model = @model;
        @this.chel = @chel;
    }

    Client(int id)
    {
        this.id = id;
    }

    bool opEquals(const Client& in client)
    {
        return id == client.id;
    }

    string name;
    int id, team, kills, deaths;
    int health = 100;
    bool prevOnGround = true;
    Model@ model;
    Model@ chel;
    Clock footsteps;
};

array<Client> clients;

float lerp(float x, float y, float t)
{
    return x * (1.0 - t) + y * t;
}

Vector3 lerp(Vector3 v, Vector3 v1, float t)
{
    return Vector3(lerp(v.x, v1.x, t), lerp(v.y, v1.y, t), lerp(v.z, v1.z, t));
}

void Loop()
{
    if(physicsTime.getElapsedTime().asSeconds() < (1.0 / 60.0))
        updatePhysics = false;
    else
    {
        updatePhysics = true;
        physicsTime.restart();
    }

    Game::scene.UpdatePhysics(updatePhysics);

    currentLoop();
}
