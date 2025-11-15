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

function block:onTickEndBlock()
	for _,p in ipairs(Player.get()) do
		
		local left = p.x
		local right = p.x + p.width
		local top = p.y
		local bottom = p.y + p.height - 2
		local hitbox = left
		
		if (cp.getCurrentName(p) == "Cat Suit" or cp.getCurrentName(p) == "Invincible Cat Suit" or cp.getCurrentName(p) == "Lucky Cat Suit") then
		
			if p.data.catSuit.state == 1 then
				left = p.x
				right = p.x + p.width
				top = p.y
				bottom = p.y + p.height - 2
				hitbox = 30
			elseif p.data.catSuit.state == 2 then
				left = p.x
				right = p.x + p.width
				top = p.y
				bottom = p.y + p.height + 4 + math.max(p.speedY,0)
				hitbox = 8
			elseif p.data.catSuit.state == 3 then
				left = p.x
				right = p.x + p.width
				top = p.y - 2
				bottom = p.y + p.height + 4 + math.max(p.speedY,0)
				hitbox = 12 + math.abs(p.speedX)
			end
			
			if p.direction == -1 then
				left = left - hitbox + math.min(p.speedX,0)
			else
				right = right + hitbox + math.max(p.speedX,0)
			end
		
			for _,block in Block.iterateIntersecting(left, top, right, bottom) do 
				if block.idx == self.idx then
					p.data.catSuit.hittedBlocks[self.idx] = true
					if blockutils.hiddenFilter(self) then
						killBlock(self)
					end
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
