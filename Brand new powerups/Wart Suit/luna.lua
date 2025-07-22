local cp = require("customPowerups")

-- Link doesn't work with the Wart Suit yet unfortunately, so this blacklists them just so it doesn't look weird in-game
-- If you modify it to work with him & made sprites for them, feel free to add them into the powerups folder and remove these blacklist lines.
cp.blacklistCharacter(CHARACTER_LINK, "Wart Suit")