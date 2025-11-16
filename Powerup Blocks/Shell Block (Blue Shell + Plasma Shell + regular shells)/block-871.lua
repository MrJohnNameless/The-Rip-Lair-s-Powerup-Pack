local blockmanager = require("blockmanager")
local blockutils = require("blocks/blockutils")
local cp = require("customPowerups")

--Written by MegaDood
--Collision detection written by Quine

local blockID = BLOCK_ID

local block = {}

blockmanager.setBlockSettings({
	id = blockID,
	frames = 1
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

local npcs = {5, 7, 73, 113, 114, 115, 116, 172, 174, 194, 195, 880}

function block:onTickEndBlock()
	if blockutils.hiddenFilter(self) then
	
		for _,p in ipairs(Player.getIntersecting(self.x - 6, self.y - 6, self.x + self.width + 6, self.y + self.height + 6)) do
			if (cp.getCurrentName(p) == "Blue Shell" or cp.getCurrentName(p) == "Bowser Shell") and ((p.data.blueShell and p.data.blueShell.isInShell) or (p.data.bowsershell and p.data.bowsershell.isInShell)) then
				killBlock(self)
			end
		end
	
		local c = Colliders.getColliding{a = blockutils.getHitbox(self, 10), btype = Colliders.NPC, filter = npcfilter }
		for _,v in ipairs(c) do
			for _,n in ipairs(npcs) do
				if v.id == n then
					killBlock(self)
					if v.id == 880 then v:kill() end
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
