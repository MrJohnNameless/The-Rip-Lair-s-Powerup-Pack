
--[[
	beeMushroom.lua by Deltomx3

	NO!!! NOT THE BEES!!!
	
	CREDITS:
	Marioman2007 - created customPowerups framework which this script uses as a base (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	SleepyVA - created all of the player sprites used for this & the power-up sprite.
	MrNameless - I used his Cloud Flower script as a base : )
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
	2ND NOTE: Not for people who are easily scared of amateur code that was put together through pure trial & error.
]]--

local cp = require("customPowerups")
local beeMushroom = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

------ SETTINGS ------

beeMushroom.settings = {
	katesWindID = 797, -- what is the current id of the SMB1-LL Wind NPC? (797 by default) (requires KateBulka's Wind NPC: https://www.smbxgame.com/forums/viewtopic.php?t=27266) 
	
	flightTime = 192, -- How long you can fly for in frames (64 FPS) (192 by default)
	upDownControl = true, -- Hold UP or DOWN to fly faster or slower respectively (true by default)
	showFlyMeter = true, -- Shows the Fly meter (doesn't disable it) (true by default)
	
	aliases = {"notthebees","itshiptobeesquare"},
}
----------------------

beeMushroom.flyMeter = Graphics.loadImageResolved("powerups/beeMushroom-flyMeter.png")

function beeMushroom.onInitPowerupLib()
	beeMushroom.spritesheets = {
		beeMushroom:registerAsset(1, "mario-beeMushroom.png"),
		beeMushroom:registerAsset(2, "luigi-beeMushroom.png"),
		beeMushroom:registerAsset(3, "peach-beeMushroom.png"), -- "ask sleepy for peach sprites, not me"	 -MrNameless
		beeMushroom:registerAsset(4, "toad-beeMushroom.png"),
	}

	beeMushroom.iniFiles = {
		beeMushroom:registerAsset(1, "mario-beeMushroom.ini"),
		beeMushroom:registerAsset(2, "luigi-beeMushroom.ini"),
		beeMushroom:registerAsset(3, "peach-beeMushroom.ini"),
		beeMushroom:registerAsset(4, "toad-beeMushroom.ini"),
	}
end

beeMushroom.basePowerup = 3
beeMushroom.items = {}
beeMushroom.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
beeMushroom.coinIDs = table.map{10,33,88,103,138,152,251,252,253,258,274,411}

local validForcedStates = table.map{0,754,755}

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p.standingNPC -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
	)
end

local function getPlayerSide(p)
	local side
	if p.data.beeMushroom.lastDirection == DIR_RIGHT then
		side = p.x -- sets the coord on the left edge of the player's hurtbox
	elseif p.data.beeMushroom.lastDirection == DIR_LEFT then 
		side = p.x + p.width -- sets the coord on the right edge of the player's hurtbox
	end

	return side
end

function beeMushroom.onInitAPI()
	registerEvent(beeMushroom,"onNPCKill")
	registerEvent(beeMushroom,"onPostNPCCollect")
end

-- runs once when the powerup gets activated, passes the player
function beeMushroom.onEnable(p)
	p:mem(0x160,FIELD_WORD, 5)
	p.data.beeMushroom = {
		animTimer = 0,
		lastDirection = p.direction,
		flightTime = beeMushroom.settings.flightTime,
		flyMeterFrame = 1,
		flyMeterFrames = 9,
		flyMeterAlpha = 0,
		flying = false,
		timer = 0,
	}
	p.data.flightTime = beeMushroom.settings.flightTime
end

-- runs once when the powerup gets deactivated, passes the player
function beeMushroom.onDisable(p)
	if not p.data.beeMushroom then return end
	Defines.player_runspeed = 6
	p.data.beeMushroom = nil
end
-- runs when the powerup is active, passes the player
function beeMushroom.onTickPowerup(p)
	if not p.data.beeMushroom then return end
	
	if p.character ~= CHARACTER_LINK then
		p:mem(0x160, FIELD_WORD, 2)
	elseif p.mount < 2 then
		p:mem(0x162, FIELD_WORD, 2)
	end
	
	if p.deathTimer ~= 0 or p.forcedState ~= 0 or p.mount ~= 0 or p:mem(0x0C, FIELD_BOOL) then p.data.beeMushroom.animTimer = 0 Defines.player_runspeed = 6 return end
	
	-- lose the powerup whenever the player touches water
	if p:mem(0x36,FIELD_BOOL) then
		cp.setPowerup(2, p, false)
		SFX.play(5)
		beeMushroom.onDisable(p)
		return
	end
	
	local data = p.data.beeMushroom	
	
	if isOnGround(p) then
		if data.flightTime >= beeMushroom.settings.flightTime then
			data.flightTime = beeMushroom.settings.flightTime
		else
			data.flightTime = data.flightTime + 3
		end
		data.flying = false
		Defines.player_runspeed = 6
		if data.flightTime ~= beeMushroom.settings.flightTime then
			if lunatime.tick() % 7 == 0 then
				data.flyMeterFrame = math.floor(math.lerp(data.flyMeterFrame, 1, 0.1))
				SFX.play(79)
			end
		end
	end
	
	if data.flightTime <= 0 then
		data.flyMeterFrame = 9
	end
	if data.flightTime >= beeMushroom.settings.flightTime then
		data.flyMeterFrame = 1
	end

	if not isOnGround(p) and p:mem(0x11C, FIELD_WORD) <= 0 and not p:mem(0x50, FIELD_BOOL) then
		p:mem(0x18, FIELD_BOOL, false)
		if p.keys.jump == KEYS_DOWN and data.flightTime > 0 then
			data.flying = true
			p.keys.down = KEYS_UP
			
			if beeMushroom.settings.upDownControl then
				if p.rawKeys.down == KEYS_DOWN then
					p.speedY = -0.2
				elseif p.keys.up == KEYS_DOWN then
					p.speedY = -2.25
				else
					p.speedY = -1.5
				end
			else
				p.speedY = -1.5
			end
			
			Defines.player_runspeed = 3
			data.flightTime = data.flightTime - 1
			data.flyMeterAlpha = math.lerp(data.flyMeterAlpha, 1, 0.2)
			
			if data.flightTime > 0 and data.flightTime % (data.flyMeterFrames * 3) == 0 then
				data.flyMeterFrame = math.floor(data.flightTime * 0.3) % (data.flyMeterFrames)
			end
			-- if data.flightTime < 96 then
				-- if lunatime.tick() % 32 == 0 then
					-- SFX.play(82)
				-- end
			-- end
			if lunatime.tick() % 24 == 0 then
				SFX.play(33)
			end
		else
			data.flying = false
		end
	end
	
	if data.flying then
		p.speedY = p.speedY - 0.2
		data.timer = 0
	else
		data.timer = data.timer + 1
		if data.timer >= 80 then
			data.flyMeterAlpha = math.lerp(data.flyMeterAlpha, 0, 0.08)
		end
	end
	
	if data.flightTime >= beeMushroom.settings.flightTime then
		data.flightTime = beeMushroom.settings.flightTime
	end
end

-- runs when the powerup is active, passes the player
function beeMushroom.onTickEndPowerup(p)
	if not p.data.beeMushroom then return end
	local data = p.data.beeMushroom
	
	-- resets or decrements the animation timer
	if p.deathTimer ~= 0 or p.mount ~= 0 or p.forcedState ~= 0 then 
		data.animTimer = 0 
	else
		if data.flying then
			data.animTimer = data.animTimer + 1
			if p.holdingNPC then
				if data.animTimer < 4 then
					p.frame = 20
				elseif data.animTimer >= 4 and data.animTimer < 8 then
					p.frame = 19
				end
			else
				if data.animTimer < 4 then
					p.frame = 11
				elseif data.animTimer >= 4 and data.animTimer < 8 then
					p.frame = 21
				end
			end
			
			if data.animTimer >= 7 then
				data.animTimer = 0
			end
		end
	end
end

-- runs when the powerup is active, passes the player
function beeMushroom.onDrawPowerup(p)
	if not p.data.beeMushroom then return end
	local data = p.data.beeMushroom
	
    data.sprite = Sprite.box{
		texture = beeMushroom.flyMeter,
		priority = -5,
		width = 26 * data.flyMeterAlpha,
		height = 26 * data.flyMeterAlpha,
		x = p.x + (p.width / 2) + 32,
		y = p.y + (p.height / 2) - 32,
		frames = data.flyMeterFrames,
		align = Sprite.align.CENTER,
	}
	
	if beeMushroom.settings.showFlyMeter then
		data.sprite:draw{priority = 5, sceneCoords = true, frame = data.flyMeterFrame, color = Color.white * data.flyMeterAlpha}
	end

	--Text.print(data.animTimer, 10, 10)
end

function beeMushroom.onPostNPCCollect(v,p)
	if not p.data.beeMushroom then return end
	local data = p.data.beeMushroom
	if beeMushroom.coinIDs[v.id] then
		data.flightTime = data.flightTime + 40
	end
end

function beeMushroom.onNPCKill(token,v,harm,c)
	for _,p in ipairs(Player.get()) do
		if p.data.beeMushroom then
		
			local data = p.data.beeMushroom
			
			if harm == 1 or harm == 8 and c == p then
				data.flightTime = beeMushroom.settings.flightTime
			end
		end
	end
end


return beeMushroom