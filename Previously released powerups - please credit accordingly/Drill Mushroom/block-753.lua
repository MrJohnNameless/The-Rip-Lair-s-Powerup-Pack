local blockManager = require("blockManager")
local AI = require("AI/drillSpot")

local sampleBlock = {}
local blockID = BLOCK_ID

local sampleBlockSettings = {
	id = blockID,

	frames = 1,
	framespeed = 8,

	passthrough = true,

	priority = -60,
	lightPriority = -5,
	useSaveData = false, -- if true, drill spots will be collected permanently
}

blockManager.setBlockSettings(sampleBlockSettings)
AI.register(blockID)

return sampleBlock