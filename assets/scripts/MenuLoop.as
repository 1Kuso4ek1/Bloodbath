Clock updateInfo;

GameLoop@ menuLoop = function()
{
    Game::exposure = lerp(Game::exposure, 1.0, 0.015);
    Game::blurIterations = lerp(Game::blurIterations, 16, 0.8);
    Game::bloomStrength = lerp(Game::bloomStrength, 0.3, 0.002 + Game::exposure / 100.0);

    auto pos = Game::camera.GetPosition();
    Game::camera.SetPosition(Vector3(lerp(pos.x, 13.8, 0.01), lerp(pos.y, 4.6, 0.01), lerp(pos.z, 7.2, 0.01)));

    if(!socket.isBlocking() && updateInfo.getElapsedTime().asSeconds() >= 1.0)
    {
        updateInfo.restart();
        Packet upd; upd << -1;
        socket.send(upd);
        int numPlayers = 0, event = 0;
        while(socket.receive(upd) == Socket::Done)
        {
            upd >> event;
            if(event == -1)
            {
                upd >> id >> serverConfig.name >> serverConfig.allowBhop >> serverConfig.enableFullGUI >> serverConfig.maxPlayers >> serverConfig.jumpForce >> serverConfig.maxSpeed >> numPlayers;// >> serverConfig.weaponDamage;
                menu.getLabel("info").setText("Connected to " + serverConfig.name + "\n" + to_string(numPlayers - 1) + "/" + to_string(serverConfig.maxPlayers) + " players\n" + "ID: " + to_string(id));
                break;
            }
            else if(event == -2)
            {
                socket.disconnect();
                menu.getLabel("info").setText("Server refused connection");
            }
        }
    }
};