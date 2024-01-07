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

        auto a = Game::camera.ScreenPositionToWorld(true); a.y = -a.y;
        auto l = EulerFromQuaternion(LookAt(Vector3(0, 2.7, 0), Game::camera.GetPosition() - a * 3.5, Vector3(0, 1, 0)).getConjugate());
        
        Game::scene.GetBone("Bone.014-chel").SetOrientation(QuaternionFromEuler(l) * QuaternionFromEuler(Vector3(0.2, 1.57, 0)));
    }

    if(!socket.isBlocking() && updateInfo.getElapsedTime().asSeconds() >= 2.0)
    {
        updateInfo.restart();
        Packet upd; upd << -1; upd << name; upd << password; upd << frontPath; upd << backPath; 
        for(int i = 0; i < hats.length(); i++)
            upd << hats[i];
        upd << "end";
        // upd << version;
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
                upd >> numPlayers; upd >> team; upd >> currentMap; upd >> night; upd >> stats;
                if(!password.isEmpty())
                {
                    upd >> exp; upd >> frontPath; upd >> backPath;
                    string hat;
                    hats.removeRange(0, hats.length());
                    upd >> hat;
                    while(hat != "end")
                    {
                        hats.insertLast(hat);
                        upd >> hat;
                    }
                }
            
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

                if(hats.length() > 0)
                {
                    for(int i = 0; i < hats.length(); i++)
                    {
                        Game::scene.GetModel(hats[i]).Load();
                        Game::scene.GetModel(hats[i]).SetShadowBias(0.005);
                        Game::scene.GetModel(hats[i]).SetIsDrawable(true);
                    }
                }
                
                if(updateInventory)
                {
                    string item;
                    inventory.removeRange(0, inventory.length());
                    menu.getListView("items").removeAllItems();
                    upd >> item;
                    while(item != "end" && !item.isEmpty())
                    {
                        inventory.insertLast(item);
                        menu.getListView("items").addItem(item);
                        upd >> item;
                    }
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
