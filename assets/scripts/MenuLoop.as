GameLoop@ menuLoop = function()
{
    Game::exposure = lerp(Game::exposure, 1.0, 0.03);
    Game::blurIterations = lerp(Game::blurIterations, 16, 0.8);
    Game::bloomStrength = lerp(Game::bloomStrength, 0.3, 0.015);
};