local cp =require("customPowerups")

--Peach, Toad, and Link don't have Frog Suit sprites yet unfortunately, so this blacklists them just so it doesn't look weird in-game
--If you have sprites for them, feel free to add them into the powerups folder and remove these blacklist lines.
cp.blacklistCharacter(CHARACTER_PEACH, "Wart Suit")
cp.blacklistCharacter(CHARACTER_TOAD, "Wart Suit")
cp.blacklistCharacter(CHARACTER_LINK, "Wart Suit")