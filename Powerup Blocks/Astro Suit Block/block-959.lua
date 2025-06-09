local blockmanager = require("blockmanager")
local blockutils = require("blocks/blockutils")

--Written by MegaDood
--Collision detection written by Quine

local blockID = BLOCK_ID

local block = {}

blockmanager.setBlockSettings({
	id = blockID,
	frames = 3
})

local function SpawnNPC(v)
	local section = blockutils.getBlockSection(v)

	local id = v.contentID
	if v.data._basegame.content then
		id = v.data._basegame.content
	end
	
	if id > 1000 then
		NPC.spawn(id-1000,v.x + 0.5 * v.width - 0.5 * NPC.config[id - 1000].width, v.y + 0.5 * v.height - 0.5 * NPC.config[id - 1000].height,section)
	elseif (id >= 1 and id < 100 and v.id ~= 754) or (id >= 2 and id < 100 and v.id == 754) then
		for i=1,id do
			local coin = NPC.spawn(10,v.x + 0.5 * v.width - 0.5 * NPC.config[10].width, v.y + 0.5 * v.height - 0.5 * NPC.config[10].height, section)
			coin.speedX = RNG.randomInt(-3,3)
			coin.speedY = RNG.randomInt(-5,-1)
			coin.ai1 = 1;
		end
	elseif id == 1 and v.id == 754 then
		NPC.spawn(10,v.x + 0.5 * v.width - 0.5 * NPC.config[10].width, v.y + 0.5 * v.height - 0.5 * NPC.config[10].height, section)
	end
end

local function killBlock(v)	
	Animation.spawn(100,v.x,v.y)
	SpawnNPC(v)
	v:remove()
	SFX.play(4)
end

--Add NPCs here to make them able to break fiery blocks.
local npcs = {960}

function block:onTickEndBlock()
	if blockutils.hiddenFilter(self) then
		local c = Colliders.getColliding{a = blockutils.getHitbox(self, 10), btype = Colliders.NPC, filter = npcfilter }
		for _,v in ipairs(c) do
			for _,n in ipairs(npcs) do
				if v.id == n then
					killBlock(self)
					Animation.spawn(10,v.x,v.y)
					v:kill()
				end
			end
		end
	end
end

function block.onInitAPI()
    blockmanager.registerEvent(blockID, block, "onTickEndBlock")
    blockmanager.registerEvent(blockID, blockutils, "onStartBlock", "storeContainedNPC")
end

return block
