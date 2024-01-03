class Weapon
{
    Weapon() {}

    Weapon(Model@ model, Model@ flash, string sound, string reloadSound, Animation@ shoot, Animation@ inspect, float recoil, float delay, float range, int maxAmmo, float reloadTime)
    {
        @this.model = @model; @this.flash = @flash;
        this.sound = sound; this.range = range;
        @this.shoot = @shoot; @this.inspect = @inspect;
        this.recoil = recoil; this.delay = delay;
        this.reloadTime = reloadTime; this.maxAmmo = maxAmmo;
        this.reloadSound = reloadSound;
        ResetAmmo();
    }

    void ResetAmmo()
    {
        currentAmmo = maxAmmo;
        reserve = maxAmmo * 6;
    }

    void Reload()
    {
        if(!reloading && currentAmmo != maxAmmo && maxAmmo > 0)
        {
            reloadClock.restart();
            reloading = true;
        }
    }

    void Update()
    {
        if(reloading && reloadClock.getElapsedTime().asSeconds() >= reloadTime)
        {
            reserve -= (maxAmmo - currentAmmo);
            currentAmmo = maxAmmo;
            reloading = false;
        }
    }

    bool IsReady()
    {
        return clock.getElapsedTime().asSeconds() >= delay && currentAmmo > 0 && !reloading;
    }

    Clock clock, reloadClock;

    string sound, reloadSound;

    float recoil, delay, range, reloadTime;

    int currentAmmo, maxAmmo, reserve;

    bool reloading = false;

    Model@ model, flash;
    Animation@ shoot, inspect;
};
