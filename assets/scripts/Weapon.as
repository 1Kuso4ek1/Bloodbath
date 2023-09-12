class Weapon
{
    Weapon() {}

    Weapon(Model@ model, Model@ flash, string sound, Animation@ shoot, Animation@ inspect, float recoil, float delay, float range)
    {
        @this.model = @model; @this.flash = @flash;
        this.sound = sound; this.range = range;
        @this.shoot = @shoot; @this.inspect = @inspect;
        this.recoil = recoil; this.delay = delay;
    }

    bool IsReady()
    {
        return clock.getElapsedTime().asSeconds() >= delay;
    }

    Clock clock;

    string sound;

    float recoil, delay, range;

    Model@ model, flash;
    Animation@ shoot, inspect;
};
