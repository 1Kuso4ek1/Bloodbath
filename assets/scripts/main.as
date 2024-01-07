FPSController@ player;

TcpSocket socket;
tgui::Gui@ menu, hud, pauseMenu;

int health = 100;
int id = 0, team = 0, kills = 0, deaths = 0, lastPort = 0, exp = 0;
uint tracerCounter = 0;
uint decalCounter = 0;
uint decalRemoveCounter = 0;
uint currentWeapon = 0;
uint64 tabId;

const float initialExposure = 1.5;

const string version = "07.01.23";

string currentMap = "town";

string name, password, lastIp, frontPath, backPath;

Quaternion tracerOrient;

PhysicalMaterial mat;

Clock physicsTime, networkTime, logoTime, delay, buttonTimer, chatTimer;

bool pause = false, updatePhysics = true, chatActive = false,
     logo = true, hidden = false, freeCamera = false,
     removeFlash = false, xyNActive = false, enableShadows = false,
     updateMenu = false, freeCameraFollowPlayer = false, night = false,
     updateInventory = true;

array<int> score = { 0, 0 };
array<Weapon> weapons;
array<Model@> tracers;

array<string> mapNames = { "town", "big arena", "$7000$" };
array<string> inventory, hats;

funcdef void GameLoop();
funcdef void lambda();

GameLoop@ currentLoop = @menuLoop;/*@mainGameLoop;*/

Model@ follow = null;

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
    uint64 tabId;
    bool prevOnGround = true;
    bool reloading = false;
    Model@ model;
    Model@ chel;
    Quaternion orient, tracerOrient;
    Clock footsteps;
    array<string> hats;
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

Vector3 normalize(Vector3 vec)
{
    return vec / (vec.length() > 1.0 ? vec.length() : 1.0);
}

void Loop()
{
    if(physicsTime.getElapsedTime().asMilliseconds() < 15)
    	updatePhysics = false;
    else
    {
        updatePhysics = true;
        physicsTime.restart();
    }

    currentLoop();
}
