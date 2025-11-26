local cp = require("customPowerups")

local dashFruit = cp.addPowerup("dashFruit", "powerups/dashFruit", 802)

cp.blacklistCharacter(CHARACTER_PEACH, dashFruit.name)
cp.blacklistCharacter(CHARACTER_TOAD, dashFruit.name)
cp.blacklistCharacter(CHARACTER_LINK, dashFruit.name)
