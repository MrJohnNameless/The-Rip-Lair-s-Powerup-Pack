
--[[
				cloudFlower.lua by MrNameless & SleepyVA
				
				A customPowerups script that brings over
			the Cloud Flower from Super Mario Galaxy 2 to SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script uses as a base (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	SleepyVA - created all of the player sprites used for this.
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--



local cp = require("customPowerups")
local cloudFlower = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified


------ SETTINGS ------
cloudFlower.settings = {
	katesWindID = 797, -- what is the current id of the SMB1-LL Wind NPC? (797 by default) (requires KateBulka's Wind NPC: https://www.smbxgame.com/forums/viewtopic.php?t=27266) 
	
	initialLimit = 3,
	slowFall = true, -- should the player be able to fall slowly when using the cloud flower? (true by default)
	autoReplenish = true, -- should the player be able to replenish clouds automatically without needing to pick up another cloud flower? (false by default)
	replenishAnywhere = false, -- should the player be able to replenish clouds anywhere, regardles if they're airborne or not? (false by default)
}
----------------------

function cloudFlower.onInitPowerupLib()
	cloudFlower.spritesheets = {
		cloudFlower:registerAsset(1, "mario-cloudFlower.png"),
		cloudFlower:registerAsset(2, "luigi-cloudFlower.png"),
		cloudFlower:registerAsset(3, "peach-cloudFlower.png"), -- "ask sleepy for peach sprites, not me"	 -MrNameless
		cloudFlower:registerAsset(4, "toad-cloudFlower.png"),
	}

	cloudFlower.iniFiles = {
		cloudFlower:registerAsset(1, "mario-cloudFlower.ini"),
		cloudFlower:registerAsset(2, "luigi-cloudFlower.ini"),
		cloudFlower:registerAsset(3, "peach-cloudFlower.ini"),
		cloudFlower:registerAsset(4, "toad-cloudFlower.ini"),
	}
end

cloudFlower.basePowerup = 2
cloudFlower.items = {}
cloudFlower.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
cloudFlower.cheats = {"needacloudflower","imcloudnine"}

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
	if p.data.cloudFlower.lastDirection == DIR_RIGHT then
		side = p.x -- sets the coord on the left edge of the player's hurtbox
	elseif p.data.cloudFlower.lastDirection == DIR_LEFT then 
		side = p.x + p.width -- sets the coord on the right edge of the player's hurtbox
	end

	return side
end

local function initFollower(p,follower,i)
	--intiallizes a cloud follower if there isn't one in the current index
	follower = {
		canShow = true,
		warpDelay = 0,
		sprite = Sprite{
			texture = Graphics.loadImageResolved("powerups/cloudFlower-follower.png"),
			pivot = Sprite.align.CENTER,
			x = getPlayerSide(p) - ((16 * i)*p.direction),
			y = p.y + p.height * 0.5,
		},
	}
	Effect.spawn(131,follower.sprite.x - follower.sprite.width*0.5,follower.sprite.y - follower.sprite.height * 0.5)
	SFX.play(82)
	
	return follower
end

function cloudFlower.onInitAPI()
	registerEvent(cloudFlower,"onNPCKill")
end

-- runs once when the powerup gets activated, passes the player
function cloudFlower.onEnable(p)
	p:mem(0x160,FIELD_WORD, 5)
	p.data.cloudFlower = {
		animTimer = 0,
		limit = cloudFlower.settings.initialLimit,
		lastDirection = p.direction,
		canSummon = true,
		clouds = {},
		followers = {},
	}
end

-- runs once when the powerup gets deactivated, passes the player
function cloudFlower.onDisable(p)
	if not p.data.cloudFlower then return end
	for i = #p.data.cloudFlower.followers,1,-1 do
		local current = p.data.cloudFlower.followers[i]
		local sprite = current.sprite
		if current.canShow then Effect.spawn(131,sprite.x - sprite.width*0.5,sprite.y - sprite.height * 0.5) end
		current.canShow = false
	end
	p.data.cloudFlower = nil
end
-- runs when the powerup is active, passes the player
function cloudFlower.onTickPowerup(p)
	if not p.data.cloudFlower then return end
	
	if p.deathTimer ~= 0 or p.forcedState ~= 0 then p.data.cloudFlower.animTimer = 0 return end
	
	-- lose the powerup whenever the player touches water
	if p:mem(0x36,FIELD_BOOL) then
		cp.setPowerup(2, p, false)
		SFX.play(5)
		cloudFlower.onDisable(p)
		return
	end
	
	local data = p.data.cloudFlower	
	
	-- replicates slow-falling from SMG2
	if cloudFlower.settings.slowFall and p.speedY > 0 then
		p.speedY = math.min(p.speedY ,4.5)
	end
	
	-- allows the player to summon another cloud if they're grounded
	if isOnGround(p) then
		data.canSummon = true
	end

	for i = #data.clouds,1,-1 do
		local n = data.clouds[i];
		-- replenish a cloud when touching on a floor that isn't a cloud platform OR if the replenishOnClouds settings is true
		if ((isOnGround(p) and (not p.standingNPC or p.standingNPC.id ~= 852)) or cloudFlower.settings.replenishAnywhere) and n.canBeRemoved then 
			table.remove(data.clouds, i)
		end
	end
	
	-- needed to prevent the cloud followers from constantly switching sides when spinjumping
	if not p:mem(0x50, FIELD_BOOL) then
		data.lastDirection = p.direction
	end
	
	if data.animTimer > 0 then
		p.keys.down = KEYS_UNPRESSED
		p:mem(0x12E, FIELD_BOOL, false)
	end
	
	if (not data.canSummon) or #data.clouds >= data.limit then return end
	
	-- spawns the cloud platform
	if p.keys.altJump == KEYS_PRESSED and not isOnGround(p) and p.mount == 0 then
		p.speedY = -4
		data.animTimer = 20
		data.canSummon = false

		-- spawns & makes the cloud platform "owned" by the player via inserting to the player's clouds table
		n = NPC.spawn(852, p.x + p.width*0.5 ,p.y + p:getCurrentPlayerSetting().hitboxHeight + 16,p.section,false,true)
		n.speedX = 0
		table.insert(data.clouds,n)
		Effect.spawn(131,p.x,n.y)
		SFX.play(82)
		SFX.play(35)
	end
	

end



-- runs when the powerup is active, passes the player
function cloudFlower.onTickEndPowerup(p)
	if not p.data.cloudFlower then return end
	local data = p.data.cloudFlower
	
	for i = data.limit,1,-1 do
		
		if data.followers[i] == nil then -- initialize cloud follower if data.limit was increased/decreased
			data.followers[i] = initFollower(p,data.followers[i],i)
		end
		
		local current = data.followers[i]
		local sprite = current.sprite
		
		local targetX = getPlayerSide(p) - ((32 * (i-0.75))*data.lastDirection)
		local targetY = (p.y + p.height * 0.5)
	
		
		if p.forcedState == FORCEDSTATE_PIPE or p.forcedState == FORCEDSTATE_DOOR then -- if warping via pipe or door
			current.warpDelay = 2
		end
		
		-- if warping via a pipe or door, then bring the cloud immediately to the target position
		if current.warpDelay > 0 then
			sprite.x = targetX
			sprite.y = targetY
			current.warpDelay = current.warpDelay - 1
		else
		-- otherwise, make the cloud follow the target position slowly & smoothly
			sprite.x = math.lerp(sprite.x, targetX, 0.15 + (0.02 * (data.limit - 3)) - (i * 0.02))
			sprite.y = math.lerp(sprite.y, targetY, 0.1 + (0.02 * (data.limit - 3)) - (i * 0.02))
		end
			
		-- makes the cloud follower appear
		if validForcedStates[p.forcedState] and data.limit - i >= #data.clouds and not current.canShow then 
			Effect.spawn(131,sprite.x - sprite.width*0.5,sprite.y - sprite.height * 0.5)
			current.canShow = true
		elseif (data.limit - i < #data.clouds or not validForcedStates[p.forcedState]) and current.canShow then 
		-- hide the cloud follower if the current cloud's index is currently being ""used"" or if the player's in a forced state
			Effect.spawn(131,sprite.x - sprite.width*0.5,sprite.y - sprite.height * 0.5)
			current.canShow = false
		end
	end
	
	-- resets or decrements the animation timer
	if p.deathTimer ~= 0 or p.mount ~= 0 or p.forcedState ~= 0 or p.holdingNPC then 
		data.animTimer = 0 
	else
		data.animTimer = math.max(data.animTimer - 1, 0)
	end
	
end

-- runs when the powerup is active, passes the player
function cloudFlower.onDrawPowerup(p)
	if not p.data.cloudFlower then return end
	local data = p.data.cloudFlower
	
	if data.animTimer > 0 then -- handles	
		p.frame = 12 + math.floor(data.animTimer * 0.3) % 4
	end
	
	for i = #data.followers,1,-1 do
		if i <= data.limit then -- draws the cloud follower if it's index is not above the limit
			local current = data.followers[i]
			if current.canShow then
				current.sprite:draw{
					sceneCoords = true,
					priority = -45,
				}
			end
		else -- otherwise, remove the cloud from the player's follower table
			Effect.spawn(131,data.followers[i].sprite.x - data.followers[i].sprite.width*0.5,data.followers[i].sprite.y - data.followers[i].sprite.height * 0.5)
			data.followers[i] = nil
			table.remove(data.followers,i)
		end
	end
end

function cloudFlower.onNPCKill(token,v,harm,c)
	if not cloudFlower.settings.autoReplenish then return end
	for _,p in ipairs(Player.get()) do
		if p.data.cloudFlower then
		
			local data = p.data.cloudFlower
			
			if harm == 1 or harm == 8 and c == p then
				data.canSummon = true
			end
			
			for i = #data.clouds,1,-1 do
				local n = data.clouds[i];
				if (n.isValid) and n == v then
					n.canBeRemoved = true -- allows the cloud to be removed
				end
			end
			
		end
	end
end


return cloudFlower