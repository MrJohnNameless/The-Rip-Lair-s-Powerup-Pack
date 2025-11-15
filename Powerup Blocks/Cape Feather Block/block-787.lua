local blockmanager = require("blockmanager")
local blockutils = require("blocks/blockutils")
local cp = require("customPowerups")

--Written by MegaDood
--Collision detection written by Quine

local blockID = BLOCK_ID

local block = {}

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

local function powerupAbilitiesDisabled(p)
    return (
        p.forcedState > 0 or p.deathTimer > 0 or p:mem(0x13C,FIELD_BOOL) -- In a forced state/dead
        or p:mem(0x40,FIELD_WORD) > 0 -- Climbing
        or p:mem(0x0C,FIELD_BOOL)     -- Fairy
        or p.mount == MOUNT_CLOWNCAR
    )
end

local function canSpin(p)
    return (
        not powerupAbilitiesDisabled(p)
        and not p:mem(0x12E,FIELD_BOOL) -- Ducking
        and not p:mem(0x3C,FIELD_BOOL)  -- Sliding
        and p.character ~= CHARACTER_LINK
        and p.mount == MOUNT_NONE
        and p.holdingNPC == nil
    )
end

function block:onTickEndBlock()
	if blockutils.hiddenFilter(self) then
		for _,p in ipairs(Player.getIntersecting(self.x - 6, self.y - 6, self.x + self.width + 6, self.y + self.height + 6)) do
			if cp.getCurrentName(p) == "Cape Feather" and (Level.winState() == 0 and canSpin(p) and (p:mem(0x50,FIELD_BOOL) or p:mem(0x164,FIELD_WORD) == -1)) then
				killBlock(self)
			end
		end
	end
end

function block.onInitAPI()
    blockmanager.registerEvent(blockID, block, "onTickEndBlock")
    blockmanager.registerEvent(blockID, blockutils, "onStartBlock", "storeContainedNPC")
end

return block
