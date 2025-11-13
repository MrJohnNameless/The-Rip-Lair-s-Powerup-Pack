--[[
		Big Mushroom by DeviousQuacks23
				
		A customPowerups script that adds the
                 Big Mushroom from Super Mario Maker

	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)	
	MrNameless - Provided the template that I used for this powerup, and also provided the pause fix for the test menu
	MegaDood - Co-worked on the powerup, added the block breaking functionality
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")
local bigShroom = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function bigShroom.onInitPowerupLib()
	bigShroom.spritesheets = {
		bigShroom:registerAsset(CHARACTER_MARIO, "mario-bigShroom.png"),
		bigShroom:registerAsset(CHARACTER_LUIGI, "luigi-bigShroom.png"),
		--bigShroom:registerAsset(CHARACTER_PEACH, "peach-template.png"), --too lazy for the other 3 chars
		--bigShroom:registerAsset(CHARACTER_TOAD,  "toad-template.png"),
		--bigShroom:registerAsset(CHARACTER_LINK,  "link-template.png"),
	}
	
	bigShroom.iniFiles = {
		bigShroom:registerAsset(CHARACTER_MARIO, "mario-bigShroom.ini"),
		bigShroom:registerAsset(CHARACTER_LUIGI, "luigi-bigShroom.ini"),
		--bigShroom:registerAsset(CHARACTER_PEACH, "peach-template.ini"),
		--bigShroom:registerAsset(CHARACTER_TOAD,  "toad-template.ini"),
		--bigShroom:registerAsset(CHARACTER_LINK,  "link-template.ini"),
	}
end

bigShroom.basePowerup = PLAYER_BIG
bigShroom.cheats = {"needabigmushroom","thebiggerthebetter","supersizedmariobros","gobigorgohome","notquitemega","thiccgyatt","nibblemythumb","marioinharlem","soretro","doyouhatethe4x4pixels"}
bigShroom.collectSounds = {
    upgrade = Misc.resolveFile("powerups/player-grow-bigmushroom.ogg"),
    reserve = 12,
}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local testMenu
if Misc.inEditor() then
	testMenu = require("engine/testmodemenu")
end

bigShroom.settings = {
	canBreakHorizontally = false -- Does the player break blocks horizontally, like is SMM1?
}

local pauseFix = 0 -- needed to fix an issue regarding pausing with the editor's test menu

bigShroom.breakableBlocks = {2, 4, 5, 60, 88, 89, 90, 115, 186, 188, 192, 193, 224, 225, 226, 293, 526, 668, 682, 683, 694, 457, 280, 1375, 1374} -- list of breakable blocks

registerEvent(bigShroom, "onBlockHit", "onBlockHit")

--If the player's big, don't trigger item blocks that are set to be destroyed
function bigShroom.onBlockHit(token, v, above, p)
	if not p then return end
	for _,n in ipairs(bigShroom.breakableBlocks) do
		if cp.getCurrentName(p) == "Big Mushroom" and v.id == n then
			v.contentID = 0
		end
	end
end

local function canBreakBlocks(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
	and p.data.canBreakBlocksAsBigMario
    )
end

function bigShroom.onEnable(p)
	p.data.bigShroom = {
		originalCoords = vector(p.x,p.y), -- for fixing an annoying issue regarding pausing with the editor's test menu
		weightGain = p:attachWeight(2), -- makes the player get more weight
	}
	if lunatime.tick() > 1 then
		p.x = p.data.bigShroom.originalCoords.x
		p.y = p.data.bigShroom.originalCoords.y + p.height
	end
	
	p.data.brickCollider = Colliders.Box(p.x, p.y, p:getCurrentPlayerSetting().hitboxWidth, p:getCurrentPlayerSetting().hitboxHeight)
	p.data.brickColliderOffset = vector.zero2
	p.data.canBreakBlocksAsBigMario = false
	p.data.canDoSmallHop = false
	p.data.canBreakBlocksAsBigMarioTimer = 8
	p.data.cantBreakAnymoreBricksWithYSpeed = true
end

function bigShroom.onDisable(p)
	if p.data.bigShroom then
		p:detachWeight(p.data.bigShroom.weightGain) -- resets the player's weight by default
	end
	p.data.bigShroom = nil
	p.data.brickCollider = nil
	p.data.brickColliderOffset = nil
	p.data.canBreakBlocksAsBigMario = nil
	p.data.canDoSmallHop = nil
	p.data.canBreakBlocksAsBigMarioTimer = nil
	p.data.cantBreakAnymoreBricksWithYSpeed = nil
end

function bigShroom.onTickPowerup(p)
	if not p.data.bigShroom then return end
	 -- prevent the player from using shoes and yoshis
	if p.mount ~= 0 and p.mount ~= 2 then
		p.keys.altJump = KEYS_DOWN
	end

	local data = p.data.bigShroom

	-- deals with fixing an annoying issue regarding pausing with the editor's test menu
	if pauseFix > 0 then
		pauseFix = pauseFix - 1
		p.x,p.y = data.originalCoords.x,data.originalCoords.y
	else
		data.originalCoords = vector(p.x,p.y)
	end

	local settings = p:getCurrentPlayerSetting()

	if p:mem(0x0C, FIELD_BOOL) then --if the player is a fairy
		settings.hitboxWidth = 24 --change the hitbox
		settings.hitboxHeight = 30
	else
		settings.hitboxWidth = 48 --revert the hitbox
		settings.hitboxHeight = 52
	end

        --Kill stomped npcs in one hit
        if canBreakBlocks(p) then
           	for _,n in ipairs(NPC.getIntersecting(p.x - 32, p.y - 32, p.x + p.width + 32, p.y + p.height + 32)) do
			if Colliders.bounce(p, n) and Misc.canCollideWith(p, n) then
                    		if not n.isHidden and not n.friendly and NPC.HITTABLE_MAP[n.id] and not NPC.config[n.id].jumphurt then
     	            			n:harm(HARM_TYPE_NPC)
					p:mem(0x11C, FIELD_WORD, Defines.jumpheight)
					p.speedY = -6
                   		end
                	end
            	end
        end

	p.data.brickCollider.x = p.x + p.data.brickColliderOffset.x
	p.data.brickCollider.y = p.y + p.data.brickColliderOffset.y

	--If this player is jumping then make it possible to break blocks
	if p.forcedState == 0 and p.deathTimer == 0 and not p:mem(0x13C,FIELD_BOOL) and p:mem(0x11C,FIELD_WORD) > 0 then
		p.data.canBreakBlocksAsBigMario = true
		p.data.canDoSmallHop = true
		p.data.canBreakBlocksAsBigMarioTimer = 8
	end

	--Break blocks to the side any time on the ground
	if bigShroom.settings.canBreakHorizontally then
		if p:mem(0x148, FIELD_WORD) == 2 or p:mem(0x14C, FIELD_WORD) == 2 then
			p.data.canBreakBlocksAsBigMarioTimer = 8
			if p:isOnGround() then
				p.data.canBreakBlocksAsBigMario = true
				p.data.canDoSmallHop = false
			end 
		end
	end
	
	p.data.brickColliderOffset.y = 0
	p.data.brickColliderOffset.x = 0

	if p.speedY > 0 and not p.data.cantBreakAnymoreBricksWithYSpeed then
		p.data.canBreakBlocksAsBigMarioTimer = 8
		p.data.canBreakBlocksAsBigMario = true
	end

	--Text.print(p.data.canBreakBlocksAsBigMario,0,0)
	--Text.print(p.data.canBreakBlocksAsBigMarioTimer,0,32) -- Debug code

	if canBreakBlocks(p) then
		--The block of code to break blocks that you come into contact with
		local collidingBlocks = Colliders.getColliding{
		a = p.data.brickCollider,
		b = Block.SOLID .. Block.PLAYER,
		btype = Colliders.BLOCK,
		}
		
		--Check if the player's touching a block
		if p:mem(0x146, FIELD_WORD) == 2 then p.data.brickColliderOffset.y = 2 p.data.canBreakBlocksAsBigMarioTimer = p.data.canBreakBlocksAsBigMarioTimer - 1 p.data.cantBreakAnymoreBricksWithYSpeed = true end
		if p:mem(0x14A, FIELD_WORD) == 2 then p.data.brickColliderOffset.y = -2 p.data.cantBreakAnymoreBricksWithYSpeed = false end
		
		if bigShroom.settings.canBreakHorizontally then
			if p:mem(0x148, FIELD_WORD) == 2 then p.data.brickColliderOffset.x = -2 p.data.brickColliderOffset.y = 0 end
			if p:mem(0x14C, FIELD_WORD) == 2 then p.data.brickColliderOffset.x = 2 p.data.brickColliderOffset.y = 0 end
		end
		
		--Remove the blocks
		for _,block in pairs(collidingBlocks) do
			for _,n in ipairs(bigShroom.breakableBlocks) do
				if block.id == n and p.data.canBreakBlocksAsBigMarioTimer > 0 then
					block:remove(true)
					p.data.canBreakBlocksAsBigMario = false
					Defines.earthquake = 3
					if p.data.canDoSmallHop and p:mem(0x146, FIELD_WORD) == 2 then
						p:mem(0x11C, FIELD_WORD, Defines.jumpheight)
						p.speedY = -5
                                                SFX.play(37)
						p.data.canDoSmallHop = false
					end
				end
			end
		end
	end
end

function bigShroom.onDrawPowerup(p)
	if not p.data.bigShroom then return end
	local data = p.data.bigShroom

	-- deals with fixing an annoying issue regarding pausing
	if (testMenu and testMenu.active) then	
		pauseFix = 2
		p.x,p.y = data.originalCoords.x,data.originalCoords.y
	end
end

return bigShroom