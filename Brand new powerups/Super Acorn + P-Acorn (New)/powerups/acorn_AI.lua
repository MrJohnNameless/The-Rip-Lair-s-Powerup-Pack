--[[
	Super Acorn(s) by DeviousQuacks23 and Capt. Monochrome (v.1.0)

	CREDITS:

	Capt. Monochrome - made the original Super Acorn powerup script which was referenced for this (https://www.smbxgame.com/forums/viewtopic.php?t=27675)	
	MegaDood - ported the original script to customPowerups, and added the wall-clinging code
		
	Shikaternia - made the sprites for Squirrel Mario (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=28104)		
	Gatete - featured Squirrel Luigi sprites for Gatete Mario Engine 9 which were used here (https://github.com/GateteVerde/Gatete-Mario-Engine-9/releases)
	JR.Master - Made the glide-holding frames for Squirrel Mario & Luigi (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/63930/) & (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/96239/)

	marioBrigade2018 - Imported Squirrel Mario sprites, and made the boost frames

	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
]]--

local acornStuffs = {}

-- Settings

acornStuffs.settings = {
	-- Used to determine how quickly you fall while moving at your maximum speed. The higher it is, the faster your descent will be.
	glideConstant = 1,

	-- Used to determine how quickly you slow down while gliding. The higher it is, the quicker you'll snap to your gliding speed.
	glideRounding = 1, 

	-- Used to determine the fastest speed that you can fall at, which is equal to your terminal velocity (Defines.gravity) divided by this number. The higher it is, the slower you'll drop.
	glideFloor = 3, 

	-- Used to determine how much higher spin jumps go. The higher it is, the higher you'll spin jump!
	spinJumpConstant = 16, 

	-- Used to determine how high you'll go when you boost up.
	boostCurveX = 3,
	boostCurveY = 8,

	-- The duration of your boost.
	boostDuration = 60,

	-- Used to determine how quickly you slow down while hovering.
	hoverConstant = 5,

	-- How long you can cling onto walls before you fall down.
	clingTime = 90
}

acornStuffs.pAcornEffectTexture = Graphics.loadImageResolved("powerups/pAcornP.png")

-- List of colours that the Ps can use.
acornStuffs.pAcornEffectColours = {Color.fromHexRGB(0xF09F0E), Color.fromHexRGB(0xFF0000), Color.fromHexRGB(0x008101), Color.fromHexRGB(0x4A4385)}

local pAcornEffects = {}

-- The actual acorn code!!!

function acornStuffs.onEnableAcorn(p, dataTerm)
	p.data.dataTerm = {
		isGliding = false,
		isActuallyGliding = false,
		hasBoosted = false,
		boostTimer = 0,
		boostDir = 0,
		hoverTimer = 0,
		spinJumpLastFrame = false,
		wallClingTimer = 0,
		hasPlayedClingSFX = false
	}
end

function acornStuffs.onDisableAcorn(p, dataTerm)
	p.data.dataTerm = nil
end

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

local function canGlide(p)
    	return (
        	p.forcedState == 0
        	and p.deathTimer == 0 -- not dead
        	and p.mount == 0
        	and not p.climbing
        	and not p.inLaunchBarrel
        	and not p.inClearPipe
        	and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        	and not p.isDucking
       		and not p:mem(0x3C,FIELD_BOOL) -- sliding
        	and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        	and not p:mem(0x4A,FIELD_BOOL) -- statue
        	and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        	and not p:mem(0x0C, FIELD_BOOL) -- fairy
		and not p:mem(0x36,FIELD_BOOL) -- underwater
        	and (not GP or not GP.isPounding(p))
        	and (not aw or aw.isWallSliding(p) == 0)
		and not isOnGround(p)
    	)
end

local function spawnPParticles(p, isCheating)
	-- Spawn fancy particles, but only if you are CHEATING >:(

	if isCheating and (RNG.randomInt(1, 2) == 1) then
		table.insert(pAcornEffects, {
			x = p.x + p.width/2 + RNG.randomInt((-p.width * 0.5), (p.width * 0.5)), 
			y = p.y + p.height/2 + RNG.randomInt((-p.height * 0.5), (p.height * 0.5)),
			speedX = RNG.random(-1.5, 1.5),
			speedY = RNG.random(-1.5, 1.5),
			colour = RNG.irandomEntry(acornStuffs.pAcornEffectColours),
			scale = RNG.random(1, 1.5),
			scaleRate = RNG.random(0.05, 0.4),
			scaleTime = RNG.randomInt(8, 24),
			timer = 0,
		})    
	end         
end

local function spawnSparkles(p)
	-- Sparkles (yummy)

        if RNG.randomInt(1, 10) == 1 then
                local e = Effect.spawn(80, p.x + RNG.randomInt(0, p.width), p.y + RNG.randomInt(0, p.height))
                e.speedX = RNG.random(-2, 2)
                e.speedY = RNG.random(-2, 2)
                e.x = e.x - e.width * 0.5
                e.y = e.y - e.height * 0.5
        end
end

function acornStuffs.onTickAcorn(p, dataTerm, isCheating)
	if not p.data.dataTerm then return end

	local data = p.data.dataTerm
	local settings = acornStuffs.settings

	if isCheating then spawnSparkles(p) end -- Spawn sparkles if you have the P-Acorn

	-- GLIDING & BOOSTING

	local glideSpeed = math.min(Defines.player_walkspeed * settings.glideConstant / math.min(Defines.player_walkspeed, math.abs(p.speedX)), Defines.gravity / settings.glideFloor)
	if isOnGround(p) then data.hasBoosted = false end -- You can boost again once you've touched ground.

	if canGlide(p) then
		data.isGliding = true

		if data.boostTimer > 0 then
			p.direction = data.boostDir
			p.speedX = settings.boostCurveX * data.boostDir
			p.speedY = -data.boostTimer * settings.boostCurveY / settings.boostDuration

			-- Timer goes down
			data.boostTimer = math.max(data.boostTimer - 1, 0)

			-- Cancel the boost early if you bonk a ceiling, or you press down
			if p.keys.down == KEYS_PRESSED or p:mem(0x14A, FIELD_WORD) > 0 then data.boostTimer = 0 end

			if not isCheating then spawnSparkles(p) end
			spawnPParticles(p, isCheating)
		elseif data.hasBoosted then
			-- Hovering

			local hoverSpeed = Defines.gravity / settings.hoverConstant
			data.hoverTimer = data.hoverTimer + 1

			if data.hoverTimer % 12 == 0 then SFX.play(10) end
			if not isCheating then spawnSparkles(p) end

			p.speedX = math.clamp(p.speedX, -Defines.player_walkspeed, Defines.player_walkspeed)
			if p.speedY >= hoverSpeed then p.speedY = hoverSpeed end

			p:mem(0x50,FIELD_BOOL, false)
		else
			data.hoverTimer = 0
			data.boostTimer = 0 

			if p.keys.altJump == KEYS_PRESSED and not p:mem(0x50,FIELD_BOOL) and p.holdingNPC == nil and not data.hasBoosted then
				-- Boosting

				data.boostTimer = settings.boostDuration
				data.boostDir = p.direction

				-- Make sure that you can't boost again (unless it's a p-acorn)
				if not isCheating then data.hasBoosted = true end

				p:mem(0x11C,FIELD_WORD,0)
				SFX.play(33)

    				for i = 1, RNG.randomInt(4, 10) do
        				local e = Effect.spawn(80, p.x + p.width / 2, p.y + p.height + p.speedY)
        				e.speedX = RNG.random(-1, 2) * p.direction
        				e.speedY = RNG.random(0, 4)
        				e.x = e.x - e.width / 2
        				e.y = e.y - e.height / 2
    				end
			elseif p.keys.jump == KEYS_DOWN and p.speedY >= 0 then 
				-- Regular gliding

				p.speedY = math.max(p.speedY - settings.glideRounding, glideSpeed)
				p:mem(0x50,FIELD_BOOL, false)

				if not isCheating then spawnSparkles(p) end
				spawnPParticles(p, isCheating)

				data.isActuallyGliding = true
			else
				data.isActuallyGliding = false
			end
		end
	else
		data.isGliding = false
		data.isActuallyGliding = false
		data.boostTimer = 0
		data.hoverTimer = 0
	end     

	-- SPIN JUMPING (but higher)

	if not data.spinJumpLastFrame and p:mem(0x50,FIELD_BOOL) then
		p:mem(0x11C,FIELD_WORD, p:mem(0x11C,FIELD_WORD) + settings.spinJumpConstant)
	end

	data.spinJumpLastFrame = p:mem(0x50,FIELD_BOOL)

	-- WALL CLINGING (with a wall jump lib)

	if aw then
		if aw.isWallSliding(p) ~= 0 then
			if not data.hasPlayedClingSFX then
				data.hasPlayedClingSFX = true
				SFX.play(73)
			end

			data.wallClingTimer = data.wallClingTimer + 1

			if data.wallClingTimer <= settings.clingTime then
				if p.character ~= 2 then
					p.speedY = -Defines.player_grav
				else
					p.speedY = -Defines.player_grav + 0.04
				end

				-- This entire clusterfuck of code is here so that the dust effects won't spawn. Remove when redundant.
    				for _,e in ipairs(Effect.getIntersecting(p.x + p.width * 0.5 + p.direction * (p.width * 0.5) + 8 * ((p.direction - 1) * 0.5) - 8, p.y + 0.75 * p.height - 8,
				p.x + p.width * 0.5 + p.direction * (p.width * 0.5) + 8 * ((p.direction - 1) * 0.5) + 8, p.y + 0.75 * p.height + 8)) do
					if e.id == 74 then
    						e.animationFrame = -999
    						e.timer = 0
    						e.x = 0
    						e.y = 0
					end
				end
			end
		elseif aw.isWallSliding(p) == 0 then
			data.wallClingTimer = math.max(data.wallClingTimer - 1, 0)
			data.hasPlayedClingSFX = false
		end

		if isOnGround(p) then data.wallClingTimer = 0 end
	else
		data.wallClingTimer = 0
		data.hasPlayedClingSFX = false
	end
end

function acornStuffs.onDrawAcorn(p, dataTerm)
	if not p.data.dataTerm then return end
	local data = p.data.dataTerm

	-- Animation

	if data.isGliding and canGlide(p) then
		if data.boostTimer > 0 then
			if data.boostTimer > (acornStuffs.settings.boostDuration * 0.5) then
				p.frame = 38
			else
				p.frame = 39
			end
		elseif data.hasBoosted then
			p.frame = math.floor(data.hoverTimer / 6) % 2 + 48
		elseif data.isActuallyGliding then
			if p.holdingNPC ~= nil then
				p.frame = 47
			else
				p.frame = 37
			end
		end
	end
end

-- Those little "P" particles

function acornStuffs.onTick()
	for k = #pAcornEffects, 1, -1 do
		local v = pAcornEffects[k]

		v.timer = v.timer + 1

		v.x = v.x + v.speedX
		v.y = v.y + v.speedY

		if v.timer >= v.scaleTime then 
			v.scale = math.max(v.scale - v.scaleRate, 0) 
                end

		if v.scale <= 0 then
			table.remove(pAcornEffects, k)
		end
	end
end

function acornStuffs.onDraw()
	for k, v in ipairs(pAcornEffects) do
                local img = acornStuffs.pAcornEffectTexture

		Graphics.drawBox{
			texture = img,
			x = v.x,
			y = v.y,
			width = v.scale * img.width,
			height = v.scale * img.height,
			color = (v.colour or Color.white),
			priority = -45,
			sceneCoords = true,
			centered = true,
		}
        end
end

-- NPC stuffs

local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

acornStuffs.idMap = {}

function acornStuffs.register(npcID)
	npcManager.registerEvent(npcID, acornStuffs, "onTickEndNPC")
	npcManager.registerEvent(npcID, acornStuffs, "onDrawNPC")
        acornStuffs.idMap[npcID] = true
end

function acornStuffs.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	if v.despawnTimer <= 0 then
		v.data.initialized = false
		return
	end
	
	if not v.data.initialized then
		v.data.initialized = true

		v.data.bounceTimer = 0
		v.data.sfxTimer = 0

		v.data.rotation = 0
	end
	
	v.data.rotation = v.data.rotation + (v.speedX * 3.5)

	if v.heldIndex ~= 0 or v.forcedState > 0 then v.data.bounceTimer = 0 v.data.sfxTimer = 0 return end

	if not v.collidesBlockBottom then
		v.data.bounceTimer = v.data.bounceTimer + 1
		v.data.sfxTimer = v.data.sfxTimer + 1
	end

	if v.data.bounceTimer >= 36 and v.collidesBlockBottom then
		v.data.bounceTimer = 0
		v.speedY = -4
	end

	if v.data.sfxTimer >= 12 and v.collidesBlockBottom then
		v.data.sfxTimer = 0
		SFX.play(9, 0.5)

		local s = Effect.spawn(74, v.x + v.width * 0.5, v.y + v.height)
		s.x = s.x - s.width * 0.5
		s.y = s.y - s.height * 0.5
		s.speedX = -4	

		local s = Effect.spawn(74, v.x + v.width * 0.5, v.y + v.height)
		s.x = s.x - s.width * 0.5
		s.y = s.y - s.height * 0.5
		s.speedX = 4	
	end

	if v.isProjectile then return end
	
	v.speedX = 1.9 * v.direction
end

function acornStuffs.onDrawNPC(v)
	if v.despawnTimer <= 0 or v.isHidden or v:mem(0x138, FIELD_WORD) ~= 0 then return end
	if not v.data.rotation then return end

	local data = v.data
        local config = NPC.config[v.id]

	local img = Graphics.sprites.npc[v.id].img
	local lowPriorityStates = table.map{1,3,4}
	local priority = (lowPriorityStates[v:mem(0x138,FIELD_WORD)] and -75) or (v:mem(0x12C,FIELD_WORD) > 0 and -30) or (config.foreground and -15) or -45

	Graphics.drawBox{
		texture = img,
		x = v.x+(v.width/2)+config.gfxoffsetx,
		y = v.y+v.height-(config.gfxheight/2)+config.gfxoffsety,
		width = config.gfxwidth,
		height = config.gfxheight,
		sourceY = v.animationFrame * config.gfxheight,
		sourceHeight = config.gfxheight,
                sourceWidth = config.gfxwidth,
		sceneCoords = true,
		centered = true,
                rotation = data.rotation,
		priority = priority,
	}

	npcutils.hideNPC(v)
end

function acornStuffs.onNPCHarm(token, v, harm, c)
	if not acornStuffs.idMap[v.id] then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.direction = -v.direction
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

-- Load stuffs

function acornStuffs.onInitAPI()
        registerEvent(acornStuffs, "onTick")
        registerEvent(acornStuffs, "onDraw")
	registerEvent(acornStuffs, "onNPCHarm")
end

return acornStuffs