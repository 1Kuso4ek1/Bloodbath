Clock updateInfo, ping;

GameLoop@ menuLoop = function()
{
    if(logoTime.getElapsedTime().asSeconds() > 1.5 && logo)
    {
        menu.getPanel("loadingPanel").hideWithEffect(tgui::Fade, seconds(3.0));
        logo = false;
    }
    else if(logo) return;

    if(updatePhysics)
    {
        Game::exposure = lerp(Game::exposure, 1.0, 0.015);
        Game::blurIterations = int(lerp(Game::blurIterations, 16, 0.8));
        Game::bloomStrength = lerp(Game::bloomStrength, 0.3, 0.002 + Game::exposure / 100.0);

        Game::camera.SetFOV(lerp(Game::camera.GetFOV(), 90.0, 0.002));
    }

    if(!socket.isBlocking() && updateInfo.getElapsedTime().asSeconds() >= 2.0)
    {
        updateInfo.restart();
        Packet upd; upd << -1; upd << name; upd << password;
        socket.send(upd);
        socket.setBlocking(true);
        ping.restart();
        int numPlayers = 0, event = 0;
        while(socket.receive(upd) == Socket::Done)
        {
            upd >> event;
            if(event == -1)
            {
                string stats;
                upd >> id >> serverConfig.name >> serverConfig.allowBhop >> serverConfig.enableFullGUI >> serverConfig.maxPlayers >> serverConfig.jumpForce >> serverConfig.maxSpeed >> numPlayers >> team >> stats;
                menu.getLabel("info").setText("Connected to " + serverConfig.name + "\n" + to_string(numPlayers - 1) + "/" + to_string(serverConfig.maxPlayers) + " players\n" + "ID: " + to_string(id) + "\nPing: " + to_string(ping.getElapsedTime().asMilliseconds()) + "\n" + stats);
                menu.getButton("play").setText("Play");
                break;
            }
            else if(event == -2)
            {
                socket.disconnect();
                menu.getLabel("info").setText("Server refused connection");
            }
        }
        socket.setBlocking(false);
    }
};