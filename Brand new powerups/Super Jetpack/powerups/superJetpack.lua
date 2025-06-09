
--[[
						Super Jetpack by MrNameless
						
					A customPowerups script that brings over
					the Jetpack from Super Mario Dimensions 2 
				(& sort of also the Rocket Boots from Terraria) into SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	LangtonLion64 - Made the original Jetpack powerup & made all the original Jetpack assets (Powerup sprite,Jetpack SFX,Player sprites, etc.)
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local jetpack = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

jetpack.powerupID = 786
jetpack.forcedStateType = 1 -- 0 for instant, 2 for normal/flickering, 3 for poof/raccoon
jetpack.basePowerup = PLAYER_FIREFLOWER
jetpack.flyingSFX = Misc.resolveFile("powerups/jetpack-fly.ogg")
jetpack.cheats = {"needasuperjetpack","needajetpack","gottablast","youreonblast","barrysteakfries","jetpackjoyride","noiwillnotaddrocketboots"}
jetpack.settings = {
	showMeter = true, -- can the jetpack's fuel meter be shown? (true by default)
	miniMeter = false, -- should a smaller version of the jetpack's fuel meter be shown instead? (false by default)
	accelMultiplier = 2.25, -- what's the speed multiplier for acclerating upwards with the jetpack? (2.25 by default)
	upwardSpeedcap = Defines.jumpspeed, -- what is the maximum upwards speed the jetpack can fly up to? (Defines.jumpspeed/-5.7 by default)
	depletionRate = 0.0085, -- From 1 to 0, how much fuel is lost between those numbers per tick/frame when using the jetpack? (0.0085 by default)
	recoveryRate = 0.01, -- From 0 to 1, how much fuel is recovered between those numbers per tick/frame? (0.01 by default)
	recoveryOnStomp = 0.2, -- From 0 to 1, how much fuel is recovered between those numbers upon stomping on a NPC? (0.2 by default)
}

-- runs when customPowerups is done initializing the library
function jetpack.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	jetpack.spritesheets = {
		jetpack:registerAsset(CHARACTER_MARIO, "mario-jetpack.png"),
		jetpack:registerAsset(CHARACTER_LUIGI, "luigi-jetpack.png"),
		--jetpack:registerAsset(CHARACTER_PEACH, "peach-jetpack.png"),
		jetpack:registerAsset(CHARACTER_TOAD,  "toad-jetpack.png"),
		--jetpack:registerAsset(CHARACTER_LINK,  "link-jetpack.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	jetpack.iniFiles = {
		jetpack:registerAsset(CHARACTER_MARIO, "mario-jetpack.ini"),
		jetpack:registerAsset(CHARACTER_LUIGI, "luigi-jetpack.ini"),
		--jetpack:registerAsset(CHARACTER_PEACH, "peach-jetpack.ini"),
		jetpack:registerAsset(CHARACTER_TOAD,  "toad-jetpack.ini"),
		--jetpack:registerAsset(CHARACTER_LINK,  "link-jetpack.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the jetpack powerup
	jetpack.gpImages = {
		jetpack:registerAsset(CHARACTER_MARIO, "jetpack-groundPound-1.ini"),
		jetpack:registerAsset(CHARACTER_LUIGI, "jetpack-groundPound-2.ini"),
	}
	--]]
end

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function isntOccupied(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount ~= MOUNT_CLOWNCAR
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
		and not p:mem(0x36,FIELD_BOOL) -- underwater
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p.speedY == 0 -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p.standingNPC -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or p:mem(0x36,FIELD_BOOL) -- is underwater
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function stopSFX(sfx)
	if not sfx then return end
	if not sfx.isValid or not sfx:isplaying() then return end
	sfx:stop()
end

local function initJetpackMeter(p)
	if not p.data.superJetpack then return end
	local data = p.data.superJetpack
	local properties = {
		meterTexture = Graphics.loadImageResolved("powerups/jetpack-meter.png"),
		barTexture = Graphics.loadImageResolved("powerups/jetpack-bar.png"),
		barPivot = Sprite.align.LEFT,
		barScale = Sprite.barscale.HORIZONTAL,
		targetX = p.x + p.width * 0.5,
		targetY = p.y + p.height * 0.5,
	}
	if jetpack.settings.miniMeter then
		properties = {
			meterTexture = Graphics.loadImageResolved("powerups/jetpack-meterMINI.png"),
			barTexture = Graphics.loadImageResolved("powerups/jetpack-barMINI.png"),
			barPivot = Sprite.align.BOTTOM,
			barScale = Sprite.barscale.VERTICAL,
			targetX = p.x + p.width + 16,
			targetY = p.y + p.height * 0.15,
		}
	end
	data.meter = Sprite.box{
			texture = properties.meterTexture,
			pivot = Sprite.align.CENTER,
			x = properties.targetX,
			y = properties.targetY,
	}
	data.bar = Sprite.bar{
		texture = properties.barTexture,
		pivot = Sprite.align.CENTER,
		barpivot = properties.barPivot,
		scaletype = properties.barScale,
		bgtexture = Graphics.loadImageResolved("stock-0.png"),
		value = 1,
		width = properties.barTexture.width,
		height = properties.barTexture.height,
		x = properties.targetX,
		y = properties.targetY,
	}
	data.meter:addChild(data.bar.transform)
	data.usingMiniMeter = jetpack.settings.miniMeter
end


function jetpack.onInitAPI()
	--register your events here!
	registerEvent(jetpack,"onNPCHarm")
	registerEvent(jetpack,"onNPCTransform")
end

-- runs once when the powerup gets activated, passes the player
function jetpack.onEnable(p)
	--local img = Graphics.loadImageResolved("powerups/jetpack-bar.png")	
	p.data.superJetpack = {
		duration = 80,
		barTimer = 0,
		usingMiniMeter = jetpack.settings.miniMeter,
		flyingSFX = SFX.play(jetpack.flyingSFX,1,0)
	}
	stopSFX(p.data.superJetpack.flyingSFX)
	initJetpackMeter(p)
end

-- runs once when the powerup gets deactivated, passes the player
function jetpack.onDisable(p)
	stopSFX(p.data.superJetpack.flyingSFX)
	p.data.superJetpack = nil
end

-- runs when the powerup is active, passes the player
function jetpack.onTickPowerup(p) 
	if not p.data.superJetpack then return end -- check if the powerup is currenly active
	local data = p.data.superJetpack
	
	if data.usingMiniMeter ~= jetpack.settings.miniMeter then
		initJetpackMeter(p)
	end
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end
end

function jetpack.onTickEndPowerup(p)
	if not p.data.superJetpack then return end -- check if the powerup is currently active
	local data = p.data.superJetpack
	local settings = jetpack.settings
	
	local unduckHeight = p:getCurrentPlayerSetting().hitboxHeight
	local targetX = (p.x + p.width * 0.5)
	local targetY = ((p.y + p.height) - unduckHeight) - unduckHeight * 0.35
	if settings.miniMeter then
		targetX = p.x + p.width + 24
		targetY = ((p.y + p.height) - unduckHeight)
	end
	
	data.meter.x = targetX
	data.meter.y = targetY

	data.barTimer = (math.max(data.barTimer - 1,0))	
	
	if (p.keys.jump or p.keys.altJump) and not isOnGround(p)
	and p:mem(0x11C, FIELD_WORD) <= 0 and isntOccupied(p)
	and data.bar.value > 0 then 
		if p:mem(0x14A,FIELD_WORD) <= 0 then
			p.speedY = math.min(p.speedY,2)
			p.speedY = math.max(p.speedY - (Defines.player_grav * settings.accelMultiplier), settings.upwardSpeedcap)
		end
		if not data.flyingSFX:isplaying() then
			data.flyingSFX = SFX.play(jetpack.flyingSFX,1,0)
		end
		if lunatime.tick() % 2 == 0 then
			local e = Effect.spawn(jetpack.powerupID,p)
			e.y = (p.y + p.height) - e.height * 0.5
			e.speedY = RNG.random(2,4)
			e.animationFrame = RNG.randomInt(0,1)
		end
		data.barTimer = 52
		data.bar.value = (math.max(data.bar.value - settings.depletionRate,0))
	elseif data.bar.value < 1 then
		data.barTimer = 52
		stopSFX(data.flyingSFX)
		if isOnGround(p) then
			data.bar.value = (math.min(data.bar.value + settings.recoveryRate,1))	
		end
	end
end

function jetpack.onDrawPowerup(p)
	if not jetpack.settings.showMeter then return end
	if not p.data.superJetpack then return end -- check if the powerup is currently active
	local data = p.data.superJetpack
	if data.barTimer <= 0 then return end
	data.meter:draw{
		sceneCoords = true,
	}
	data.bar:draw{
		sceneCoords = true,
	}
end

function jetpack.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "Player" or c.idx == 0 then return end
	if harm ~= 1 and harm ~= 8 then return end
	if cp.getCurrentPowerup(c) ~= jetpack or not c.data.superJetpack then return end 	
	local bar = c.data.superJetpack.bar.value
	c.data.superJetpack.bar.value = (math.min(bar + jetpack.settings.recoveryOnStomp,1))	
end

-- check if a player was right above the NPC whenever it was transformed by a jump harmtype
function jetpack.onNPCTransform(v,oldID,harm)
	if harm ~= 1 and harm ~= 8 then return end
	for _,p in ipairs(Player.getIntersecting(v.x - 2,v.y - 4,v.x + v.width + 2,v.y + v.height)) do 
		if cp.getCurrentPowerup(p) == jetpack and p.data.superJetpack then
			local bar = p.data.superJetpack.bar.value
			p.data.superJetpack.bar.value = (math.min(bar + jetpack.settings.recoveryOnStomp,1))	
		end
	end
end

return jetpack