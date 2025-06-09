--[[
		Spring Mushroom by DeviousQuacks23
				
		A customPowerups script that adds the
	Spring Mushroom from Super Mario Galaxy 1 & 2 into SMBX2
			
	CREDITS:
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrNameless - made the powerup template which I used for this script
	AwesomeZack - made the player sprites, edited by me
	DaCulDood - made the powerup sprite 
	
	Version 1.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local springMushroom = {}

springMushroom.forcedStateType = 2
springMushroom.basePowerup = PLAYER_FIREFLOWER
springMushroom.cheats = {"needaspringmushroom","needaspringshroom","gettingoverit","metallicmadness","bouncy","slinky","everyonesfavourite","frogsuittwopointo","boyoyoing","gravitycoil","boingcartoonallversionsoundeffectsdotmpfour"}
springMushroom.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

local emptyImage = Graphics.loadImageResolved("stock-32.png")
local iniFile = Misc.resolveFile("powerups/springShroom.ini")

local starShader = Shader.fromFile(nil, Misc.multiResolveFile("starman.frag", "shaders\\npc\\starman.frag"))

springMushroom.spritesheets = {
    emptyImage,
    emptyImage,
    emptyImage,
    emptyImage,
}

springMushroom.iniFiles = {
    iniFile,
    iniFile,
    iniFile,
    iniFile,
}

function springMushroom.onInitPowerupLib()
    springMushroom.playerImages = {
        springMushroom:registerAsset(CHARACTER_MARIO, "springShroom-mario.png"),
        springMushroom:registerAsset(CHARACTER_LUIGI, "springShroom-luigi.png"),
        springMushroom:registerAsset(CHARACTER_PEACH, "springShroom-toad.png"), -- placeholder
        springMushroom:registerAsset(CHARACTER_TOAD,  "springShroom-toad.png"),
    }
end

local smb2Chars = table.map{3,4,6,9,10,11,16}
local linkChars = table.map{5,12,16}

local GP
pcall(function() GP = require("GroundPound") end)

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p:isGroundTouching() -- on a block
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local function canBounceAround(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

function springMushroom.onInitAPI()
end

function springMushroom.onEnable(p)	
	p.data.springMushroom = {
		rotation = 0,
		scale = 1,
		moveSpeed = 0,
		occupiedRotation = false,
		oldDir = p.direction,
		turnTimer = 0,
		frame = 0
	}
end

function springMushroom.onDisable(p)	
	p.data.springMushroom = nil
	p:mem(0x154,FIELD_WORD,0) 
end

function springMushroom.onTickPowerup(p) 
	if not p.data.springMushroom then return end
	local data = p.data.springMushroom
    
   	if p.mount < 2 and not linkChars[p.character] then
        	p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then
		p:mem(0x162, FIELD_WORD, 2)
    	end

	if p:mem(0x36,FIELD_BOOL) then
		p:harm()
		return
	end

	if p.mount ~= 0 then
		p.keys.altJump = KEYS_DOWN
	end

	p.speedX = math.clamp(p.speedX, -3, 3)
	p.speedY = p.speedY - 0.15

    	if GP then
        	GP.preventPound(p)
    	end

    	if aw then
        	aw.preventWallSlide(p)
    	end

    	p:mem(0x2C, FIELD_DFLOAT, 0)
    	p:mem(0x40, FIELD_WORD, 0)
        p:mem(0x3C,FIELD_BOOL, false)
	p:mem(0x154,FIELD_WORD,-2)

	if p.forcedState ~= 0 or p.inClearPipe then data.moveSpeed = 0 end

   	if not canBounceAround(p) then return end

	p.speedX = data.moveSpeed

	if p.keys.left then
		p.direction = -1
		if data.moveSpeed > -3 then
			data.moveSpeed = data.moveSpeed - 0.05
		end
	elseif p.keys.right then
		p.direction = 1
		if data.moveSpeed < 3 then
			data.moveSpeed = data.moveSpeed + 0.05
		end
	end

	if isOnGround(p) then
		if p.keys.jump == KEYS_DOWN then
			p.speedY = -16
			p:mem(0x176,FIELD_WORD,0)
			SFX.play("powerups/bigBounce.ogg")
			data.scale = 2
			data.occupiedRotation = true
		else
			p.speedY = -8
			p:mem(0x176,FIELD_WORD,0)
			SFX.play("powerups/smallBounce.ogg")
			data.scale = 0.15
			data.occupiedRotation = true
			for k, v in Block.iterateIntersecting(p.x + 2, p.y + (p.height - 2), p.x + (p.width - 2), p.y + (p.height + 16)) do
            			if p:mem(0x48,FIELD_WORD) ~= 0 and (Block.SLOPE_MAP[v.id] and Block.config[v.id].floorslope ~= 0 and not v.isHidden and not v:mem(0x5A, FIELD_BOOL)) then
					if Block.SLOPE_LR_FLOOR_MAP[v.id] and Block.config[v.id].floorslope == -1 then
						data.moveSpeed = 3
					elseif Block.SLOPE_RL_FLOOR_MAP[v.id] and Block.config[v.id].floorslope == 1 then
						data.moveSpeed = -3
					end
            			end
        		end
		end
	end

	if p:mem(0x148, FIELD_WORD) == 2 then 
		data.moveSpeed = 3 
		p.speedY = -6
		SFX.play("powerups/smallBounce.ogg")
		data.scale = 0.15
		data.occupiedRotation = true
	end

	if p:mem(0x14C, FIELD_WORD) == 2 then 
		data.moveSpeed = -3 
		p.speedY = -6
		SFX.play("powerups/smallBounce.ogg")
		data.scale = 0.15
		data.occupiedRotation = true
	end
end

function springMushroom.onTickEndPowerup(p)
	if not p.data.springMushroom then return end	
	local data = p.data.springMushroom

	if data.occupiedRotation then
		data.rotation = data.rotation + 5 * p.direction
		if (data.rotation % 180) == 0 then
			data.occupiedRotation = false 
		end
	end

        if data.scale > 1 then 
                data.scale = data.scale - 0.05
        elseif data.scale < 1 then 
                data.scale = data.scale + 0.05
        end

	data.turnTimer = data.turnTimer - 1

	if p.direction ~= data.oldDir then
		data.turnTimer = 5
		data.oldDir = p.direction
	end

	if data.turnTimer <= 0 then
		data.frame = (p.direction == -1 and 0) or 2
	else
		data.frame = 1
	end
end

function springMushroom.onDrawPowerup(p)
	if not p.data.springMushroom then return end
	local data = p.data.springMushroom
	if p.deathTimer == 0 then 
		p:setFrame(-50 * p.direction)	
		Graphics.drawBox{
			texture = springMushroom:getAsset(p.character, springMushroom.playerImages[p.character]),
			priority = (p.forcedState == 3 and -70) or -25,
			width = 100,
			height = 100 * data.scale,
			x = p.x + (p.width * 0.5),
			y = p.y + (p.height * 0.5),
			sourceX = 0,
			sourceY = data.frame * 100,
			sourceWidth = 100,
			sourceHeight = 100,
			rotation = data.rotation,
			centered = true,
			sceneCoords = true,
        		shader = (p.hasStarman and starShader) or nil,
        		uniforms = (p.hasStarman and {time = lunatime.tick() * 2}) or nil
		}
			
	end 
end

return springMushroom