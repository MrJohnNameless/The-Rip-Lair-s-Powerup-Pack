local blockManager = require("blockManager")
local drill = require("powerups/drill")

local sampleBlock = {}
local blockID = BLOCK_ID

local sampleBlockSettings = {
	id = blockID,

	frames = 1,
	framespeed = 8,

	passthrough = true,
}

blockManager.setBlockSettings(sampleBlockSettings)
drill.passBlockID = blockID

return sampleBlock