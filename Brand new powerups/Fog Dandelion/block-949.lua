--Blockmanager is required for setting basic Block properties
local blockManager = require("blockManager")

local powerup = require("powerups/fogDandelion")

--Create the library table
local zone = {}
--BLOCK_ID is dynamic based on the name of the library file
local blockID = BLOCK_ID

--Defines Block config for our Block. You can remove superfluous definitions.
local zoneSettings = {
	id = blockID,
	frames = 1,
	sizable = true, --sizable block
	passthrough = true, --no collision
}

--Applies blockID settings
blockManager.setBlockSettings(zoneSettings)

--Register events
function zone.onInitAPI()
	powerup.settings.antiTeleportZoneID = blockID
end

return zone