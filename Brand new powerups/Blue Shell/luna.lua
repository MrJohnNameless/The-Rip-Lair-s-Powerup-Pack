
local blueShell = require("powerups/blueShell")
-- makes the SMW Blue Koopa Troopa (NPC-111) be able to drop the Blue Shell powerup in it's SMW variant
blueShell.registerShellDropper(
	111, 	-- id
	2,		-- variant
	true	-- randomized dropping
)