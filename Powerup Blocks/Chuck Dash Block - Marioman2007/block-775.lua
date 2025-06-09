local blockManager = require("blockManager")
local chuckSuit = require("powerups/chuckSuit")

local sampleBlock = {}
local blockID = BLOCK_ID

local sampleBlockSettings = {
	id = blockID,

	frames = 1,
	framespeed = 8,
}

blockManager.setBlockSettings(sampleBlockSettings)
chuckSuit.whitelist(blockID)

return sampleBlock