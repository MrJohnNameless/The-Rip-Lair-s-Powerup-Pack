local blockManager = require("blockManager")
local propeller = require("powerups/propeller")

local sampleBlock = {}
local blockID = BLOCK_ID

local sampleBlockSettings = {
	id = blockID,

	frames = 1,
	framespeed = 8,
}

blockManager.setBlockSettings(sampleBlockSettings)
propeller.whitelist(blockID)

return sampleBlock