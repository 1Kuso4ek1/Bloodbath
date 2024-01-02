Clock updateInfo, ping;

GameLoop@ menuLoop = function()
{
    if(logoTime.getElapsedTime().asSeconds() > 1.5 && logo && updateMenu)
    {
        menu.getPanel("loadingPanel").hideWithEffect(tgui::Fade, seconds(3.0));
        logo = false;
    }
    else if(logo) return;

    if(updatePhysics && updateMenu)
    {
        Game::exposure = lerp(Game::exposure, initialExposure, 0.015);
        Game::blurIterations = int(lerp(Game::blurIterations, 16, 0.8));
        Game::bloomStrength = lerp(Game::bloomStrength, 0.3, 0.002 + Game::exposure / 100.0);
    }

    if(!socket.isBlocking() && updateInfo.getElapsedTime().asSeconds() >= 2.0)
    {
        updateInfo.restart();
        Packet upd; upd << -1; upd << name; upd << password; upd << frontPath; upd << backPath; upd << hat;
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
                upd >> id; upd >> serverConfig.name; upd >> serverConfig.allowBhop; upd >> serverConfig.enableFullGUI; upd >> serverConfig.maxPlayers; upd >> serverConfig.jumpForce; upd >> serverConfig.maxSpeed;
                upd >> numPlayers; upd >> team; upd >> currentMap; upd >> stats;
                upd >> exp; upd >> frontPath; upd >> backPath; upd >> hat;
            
                if(!frontPath.isEmpty())
                {
                    Game::scene.GetModel("patch:decals").SetMaterial(Game::scene.GetMaterial(frontPath));
                    Game::scene.GetModel("patch:decals").SetIsDrawable(true);
                }

                if(!backPath.isEmpty())
                {
                    Game::scene.GetModel("patch1:decals").SetMaterial(Game::scene.GetMaterial(backPath));
                    Game::scene.GetModel("patch1:decals").SetIsDrawable(true);
                }

                if(!hat.isEmpty())
                {
                    Game::scene.GetModel(hat).Load();
                    Game::scene.GetModel(hat).SetShadowBias(0.005);
                    Game::scene.GetModel(hat).SetIsDrawable(true);
                }
                
                if(updateInventory)
                {
                    string item;
                    inventory.removeRange(0, inventory.length());
                    menu.getListView("items").removeAllItems();
                    upd >> item;
                    while(item != "end" && !item.isEmpty())
                    {
                        Log::Write(item);
                        inventory.insertLast(item);
                        menu.getListView("items").addItem(item);
                        upd >> item;
                    }
                    //updateInventory = false;
                }
                menu.getLabel("info").setText("Connected to " + serverConfig.name + "\n" + to_string(numPlayers - 1) + "/" + to_string(serverConfig.maxPlayers) + " players\n" + "ID: " + to_string(id) + "\nPing: " + to_string(ping.getElapsedTime().asMilliseconds()) + "\nMap: " + currentMap + "\n" + stats);
                menu.getProgressBar("exp").setValue(exp - (50 * int(floor(exp / 50))));
                menu.getLabel("lvl").setText(to_string(int(floor(exp / 50))) + " lvl");
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