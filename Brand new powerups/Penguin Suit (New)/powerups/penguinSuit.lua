--[[
			 penguinSuit.lua by John Nameless
		A remake of Capt.Monochrome's original Penguin Suit
			script made for anotherpowerup.lua
			
	CREDITS:
	Capt.Monochrome - made the original Penguin Suit powerup script which was occasionally referenced for this (https://www.smbxgame.com/forums/viewtopic.php?t=27675)
					- also made the behavior for the powerup NPC of the penguin suit used here.
					
	Shikaternia - made the sprites for Penguin Mario (https://mfgg.net/index.php?act=resdb&param=02&c=1&id=23949)
				- made the sprites for Penguin Luigi
				
	Gatete - featured Penguin Luigi sprites for Gatete Mario Engine 9 which were used here (https://github.com/GateteVerde/Gatete-Mario-Engine-9/releases)
	
	Legend-Tony980 - made the sprites for Penguin Toad (https://www.deviantart.com/legend-tony980/art/SMBX-Toad-s-sprites-Fourth-Update-724628909)
	
	Emral & Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
						 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)

	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--


local bumper = require("npcs/ai/bumper")
local springs = require("npcs/ai/springs")

local penguinSuit = {}

local defaultAnimations = {
	["swimIdle"] = 		 {frames = {40,41}, framespeed = 24},
	["swimUp"] = 		 {frames = {47,48,47,46,46,46}, framespeed = 8},
	["swimDown"] = 		 {frames = {37,38,37,36,36,36}, framespeed = 8},
	["swimHorizontal"] = {frames = {42,43,42,44,44,44}, framespeed = 8},
	["swimItemHold"] = 	 {frames = {20,21}, framespeed = 24},
	["sliding"] = {frames = {14,39,49}, framespeed = 4, loops = false},
}

penguinSuit.projectileID = 265
penguinSuit.forcedStateType = 1 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
penguinSuit.basePowerup = PLAYER_ICE
penguinSuit.cheats = {"needapenguinsuit","pingu","flightlessbird","slipandslide","linux","dropthebabypenguin"}
penguinSuit.collectSounds = {
    upgrade = 6,
    reserve = 12,
}
penguinSuit.settings = {
	slideMinimumSpeed = 3.25, -- What's the minimum horizontal speed required to start sliding on a flat surface? (3.25 by default)
	slideSpeedcap = 11, -- What's the maximum horizontal speed obtainable while sliding? (11 by default)
	slideComboTime = 130, -- When sliding, how much time does the player have to hit a NPC before their slide combo resets? (130 by default)
	animations = {
		[CHARACTER_MARIO] = defaultAnimations,
		[CHARACTER_LUIGI] = defaultAnimations,
		[CHARACTER_PEACH] = defaultAnimations,
		[CHARACTER_TOAD]  = defaultAnimations,
		[CHARACTER_LINK]  = defaultAnimations,
	},
}

penguinSuit.alwaysHarmNPCs = table.map{12,37,180,179,295,432,435,437,589,590,641,643}

-- runs when customPowerups is done initializing the library
function penguinSuit.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	penguinSuit.spritesheets = {
		penguinSuit:registerAsset(CHARACTER_MARIO, "mario-penguin.png"),
		penguinSuit:registerAsset(CHARACTER_LUIGI, "luigi-penguin.png"),
		penguinSuit:registerAsset(CHARACTER_PEACH, "peach-penguin.png"),
		penguinSuit:registerAsset(CHARACTER_TOAD,  "toad-penguin.png"),
		penguinSuit:registerAsset(CHARACTER_LINK,  "link-penguin.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	penguinSuit.iniFiles = {
		penguinSuit:registerAsset(CHARACTER_MARIO, "mario-penguin.ini"),
		penguinSuit:registerAsset(CHARACTER_LUIGI, "luigi-penguin.ini"),
		penguinSuit:registerAsset(CHARACTER_PEACH, "peach-penguin.ini"),
		penguinSuit:registerAsset(CHARACTER_TOAD,  "toad-penguin.ini"),
		penguinSuit:registerAsset(CHARACTER_LINK,  "link-penguin.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the template powerup
	penguinSuit.gpImages = {
		penguinSuit:registerAsset(CHARACTER_MARIO, "penguin-groundPound-1.png"),
		penguinSuit:registerAsset(CHARACTER_LUIGI, "penguin-groundPound-2.png"),
	}
	--]]
end

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
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
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function isUnoccupied(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and p:mem(0x06,FIELD_WORD) <= 0 -- in quicksand
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end

local function inWater(p)
	return (
		p:isUnderwater()
		and p:mem(0x06,FIELD_WORD) <= 0
	)
end

local function stopSlide(p)
	if not p.data.penguinSuit then return end
	local data = p.data.penguinSuit
	data.isSliding = false
	data.wasGoingUphill = false
	data.slideRotation = 0
	data.slideCombo = 0 
	data.comboTimer = 0
	data.stuckTimer = 3
	if not inWater(p) then
		p:mem(0x12E,FIELD_WORD,0)
		p:mem(0x160, FIELD_WORD,math.max(p:mem(0x160, FIELD_WORD),2))
	end
end

local STATE_NORMAL = 0
local STATE_SLIDE = 1
local STATE_SWIM = 2

function penguinSuit.onInitAPI()
	-- register your events here!
	--registerEvent(penguinSuit,"onNPCHarm")
end
	
-- runs once when the powerup gets activated, passes the player
function penguinSuit.onEnable(p)	
	p.data.penguinSuit = {
		wasUnderwater = p:isUnderwater(),
		slidingOnWater = false,
		isSliding = false,
		wasGoingUphill = false,
		slideSpeedX = p.speedX,
		lastX = p.x,
		stuckTimer = 3,
		slideCombo = 0,
		comboTimer = 0,
		slideRotation = 0,
		slopeSize = 0,
		animTimer = 0,
		curAnim = "swimIdle",
		playerBuffer = Graphics.CaptureBuffer(100, 100)
	}
end

-- runs once when the powerup gets deactivated, passes the player
function penguinSuit.onDisable(p)	
	p.data.penguinSuit = nil
	p:mem(0x12E,FIELD_WORD,0)
end

-- runs when the powerup is active, passes the player
function penguinSuit.onTickPowerup(p) 
	if not p.data.penguinSuit then return end
	local data = p.data.penguinSuit
	
	p:mem(0x0A,FIELD_BOOL,false)
	
	if not isUnoccupied(p) then 
		data.animTimer = 0,
		stopSlide(p)
		return 	
	end
	
	------------ SWIMMING HANDLING ------------
	if inWater(p) then
		if not data.wasUnderwater then
			for _,l in ipairs(Liquid.getIntersecting(p.x,p.y,p.x+p.width,p.y+p.height)) do
				if p.y + p.height > l.y+l.height then
					p.y = p.y - (p.height*0.5)
					break
				end
			end
			data.wasUnderwater = true
		end
		if data.isSliding then
			stopSlide(p)
		end
		p:mem(0x12E,FIELD_WORD,1)
		-- handles shooting iceballs when swimming
		if p:mem(0x160, FIELD_WORD) <= 0 and (p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED) and not linkChars[p.character] then
			local dir = p.direction
			local v = NPC.spawn(
				265, p.x + p.width/2 + (p.width/2 + 0) * dir + p.speedX,
				p.y + p.height/2 + p.speedY, p.section, false, true
			)
			local speedX = (4 + p.speedX/3.5) * dir
			if p.keys.altRun and smb2Chars[p.character] and p.holdingNPC == nil then
				v.speedY = 0
				v.heldIndex = p.idx
				p:mem(0x154, FIELD_WORD, v.idx+1)
				SFX.play(18)
			else
				local speedYMod = p.speedY * 0.1
				if p.standingNPC then
					speedYMod = p.standingNPC.speedY * 0.1
				end
				if p.keys.up then -- sets the projectile upwards if you're holding up while shooting
					v.speedY = -8 + speedYMod
				else
					v.speedY = 5 + speedYMod
				end
				v.direction = dir
				v.speedX = speedX
				SFX.play(18)
			end
			p:mem(0x160, FIELD_WORD,30)
		end

		local isMoving = false
		local speedcap = Defines.player_runspeed - 4
		local horizontalSpeed = 4
		local verticalSpeed = 2
		-- doubles the swimspeed if holding run
		if p.keys.run then
			speedcap = speedcap + 2
			horizontalSpeed = horizontalSpeed * 4
			verticalSpeed = verticalSpeed * 4
		end
		-- handles swimming up or down
		if p.keys.up then
			if p:mem(0x14A,FIELD_WORD) == 0 then
				p.speedY = -verticalSpeed
			end
			data.curAnim = "swimUp"
			isMoving = true
		elseif p.keys.down then
			p.speedY = verticalSpeed
			data.curAnim = "swimDown"
			isMoving = true
		else
			if math.abs(p.speedY) < 0.45 then
				p.speedY = -Defines.player_grav/10
			else
				p.speedY = p.speedY * 0.9
			end
		end
		-- handles swimming left or right
		if (p.keys.left and p.direction == -1) or (p.keys.right and p.direction == 1) then
			p.speedX = horizontalSpeed * p.direction
			p.speedX = math.clamp(p.speedX,-speedcap,speedcap)
			p:mem(0x138, FIELD_FLOAT, p.speedX)
			p.speedX = 0
			data.curAnim = "swimHorizontal"
			isMoving = true
		else
			p.speedX = p.speedX * 0.85
		end
		
		if isMoving then 
			local rate = 54
			if p.keys.run then rate = 22 end
			if data.animTimer % rate == 0 then
				SFX.play(72)
			end
			data.animTimer = data.animTimer + 1
		else
			data.curAnim = "swimIdle"
			data.animTimer = data.animTimer + 1
		end
		
		if p.holdingNPC then
			data.curAnim = "swimItemHold"
		end
		return
	end
	------------ END OF SWIMMING HANDLING ------------

	-- handles starting up the slide
	if not data.isSliding and p.keys.down and isOnGround(p) and not p.holdingNPC
	and (math.abs(p.speedX) > penguinSuit.settings.slideMinimumSpeed 
	or p:mem(0x48,FIELD_WORD) ~= 0) then
		data.isSliding = true
		p.keys.down = KEYS_UP
		p:mem(0x12E,FIELD_WORD,1)
		p:mem(0x3C,FIELD_BOOL,false)
		data.curAnim = "sliding"
	elseif data.isSliding then -- handles preventing specific keys & actions being done while sliding
		p.keys.down = KEYS_UP
		p.keys.run = KEYS_UP
		p.keys.altRun = KEYS_UP
		data.animTimer = data.animTimer + 1
		if p.keys.altJump == KEYS_PRESSED or p.keys.up then
			if p.keys.altJump then
				p.keys.jump = KEYS_PRESSED
				p:mem(0x120,FIELD_BOOL,false)
				if data.slidingOnWater then
					data.slidingOnWater = false
					p.speedY = 0
					p:mem(0x11E,FIELD_BOOL,true)
				end
			end
			stopSlide(p)
			data.animTimer = 0
			return
		end
	end

end

function penguinSuit.onTickEndPowerup(p)
	if not p.data.penguinSuit then return end
	if not isUnoccupied(p) then 
		p:mem(0x12E,FIELD_WORD,0)
		return 
	end
	local data = p.data.penguinSuit
	local settings = penguinSuit.settings

	-- handles setting the player's held NPC to be aligned with the smaller hitbox when swimming
	if inWater(p) then
		p:mem(0x38,FIELD_WORD,2)
		if p.holdingNPC and p.holdingNPC.isValid then
			local n = p.holdingNPC
			if smb2Chars[p.character] then
				local playerHalf = p.width * 0.5
				if p.direction == - 1 then
					n.x = p.x - n.width + 6
				elseif p.direction == 1 then
					n.x = p.x + p.width - 6
				end
			end
			n.y = (p.y + p.height*0.5) - (n.height*0.5) - 2			
		end
		return
	elseif data.wasUnderwater then -- handles escaping the water
		p:mem(0x12E,FIELD_WORD,0)
		data.wasUnderwater = false
		data.animTimer = 0
		if p.speedY > Defines.player_grav then
			p.y = p.y + p.height
		elseif p.speedY < 0 then
			p.y = p.y - 2
			p.speedY = p.speedY + Defines.jumpspeed
		end
		p.speedY = math.clamp(p.speedY,-9,3)
	end

	------------ SLIDING HANDLING ------------
	if data.isSliding then
		local fastEnough = math.abs(data.slideSpeedX) > settings.slideMinimumSpeed
		local holdingForward = (p.keys.left and math.sign(data.slideSpeedX) == -1) or (p.keys.right and math.sign(data.slideSpeedX) == 1)
		local goingUphill = false
		local goingDownhill = false
		p:mem(0x3C,FIELD_BOOL,false) 
		if isOnGround(p) and lunatime.tick() % 2 == 0 then
			Effect.spawn(
				74, 
				(p.x + p.width*0.5), 
				p.y + p.height - 4
			) 
		end
		if p:mem(0x48,FIELD_WORD) ~= 0 then
			p:mem(0x3A,FIELD_WORD,2) -- disable gravity to let players slide up slopes a bit more smoothly & make it less likely to get stuck in them
			local slope = Block(p:mem(0x48,FIELD_WORD))
			local slopeDirection = Block.config[slope.id].floorslope
			goingUphill = math.sign(data.slideSpeedX) ~= slopeDirection
			goingDownhill = math.sign(data.slideSpeedX) == slopeDirection
			if not goingUphill or not holdingForward or data.slideSpeedX == 0 then
				data.slideSpeedX = data.slideSpeedX + (0.1 * slopeDirection)
			end
			fastEnough = math.abs(data.slideSpeedX) > settings.slideMinimumSpeed
			data.slopeSize = slope.height/slope.width
			data.slideRotation = math.deg(math.atan(slope.height/slope.width)*math.sign(slopeDirection))
		elseif data.wasGoingUphill then
			Routine.run(function()
				Routine.loop(12,function()
					p:mem(0x3A,FIELD_WORD,2) -- replicates temporary no gravity for 12 frames as similar to the vanilla slide
				end)
			end)
			if fastEnough then
				p.speedY = -math.abs(data.slideSpeedX) * data.slopeSize
			end
			data.wasGoingUphill = false
		else
			if data.slideRotation < 0 then
				data.slideRotation = math.min(data.slideRotation + 7,0)
			elseif data.slideRotation > 0 then
				data.slideRotation = math.max(data.slideRotation - 7,0)
			end
		end
		data.slideSpeedX = math.clamp(data.slideSpeedX,-settings.slideSpeedcap,settings.slideSpeedcap)
		p.direction = math.sign(data.slideSpeedX)
		p.speedX = data.slideSpeedX
		
		if p.x == data.lastX and math.abs(data.slideSpeedX) > 0.25 and not goingDownhill then
			data.stuckTimer = data.stuckTimer - 1
			p.y = p.y - 2
		else
			data.stuckTimer = 3
		end
		data.lastX = p.x
		data.comboTimer = math.max(data.comboTimer - 1,0)
		if data.comboTimer <= 0 then 
			data.slideCombo = 0 
		end
		
		local left = p.x - 2 
		local right = p.x + p.width + 2
		local top = p.y + 2 + math.min(p.speedY,0)
		local bottom = p.y + p.height
		
		if goingDownhill then
			bottom = bottom + 4
			p:mem(0x3A,FIELD_WORD,0) -- renable gravity to prevent players from flying off when trying to slide downhill
			data.wasGoingUphill = false
		elseif goingUphill then
			top = top - 4
			data.wasGoingUphill = true
		end
		if p.direction == -1 then
			left = left + (p.speedX*0.75)
		else
			right = right + (p.speedX*0.75)
		end
		
		local bumpedBlock = false
		local bumpedNPC = false
		-- Hit/Destroy objects if the player's sliding fast enough or sliding down a hill
		if fastEnough or goingDownhill then
			for _,block in Block.iterateIntersecting(left, top, right, bottom) do -- handles hitting blocks
				-- If block is visible
				if block.isValid and block.isHidden == false and not block:mem(0x5A, FIELD_BOOL) then
					-- If the block should be broken, destroy it
					if Block.MEGA_SMASH_MAP[block.id] then
						if block.contentID > 0 or block.id == 457 then
							block:hit(false, p)
							bumpedBlock = true
						else
							SFX.play(3)
							block:remove(true)
						end
					elseif Block.config[block.id].smashable == 1 then
						block:hit(false, p)
						bumpedBlock = true
					end
				end
			end
		end
		for _, npc in NPC.iterateIntersecting(left, top - 16, right, bottom + 16) do -- handles hitting NPCs
			if npc.isValid and (not npc.friendly) and npc.despawnTimer > 0 
			and (not npc.isGenerator) and npc.forcedState == 0 and npc.heldIndex == 0 then
				if NPC.HITTABLE_MAP[npc.id] and (fastEnough or goingDownhill) -- handles hitting npcs that are part of HITTABLE_MAP
				and not penguinSuit.alwaysHarmNPCs[npc.id] then
					local oldScore = NPC.config[npc.id].score
					NPC.config[npc.id].score = 2 + data.slideCombo -- temporarily changes the npc's score config depending on the current slide combo
					npc:harm(3)
					NPC.config[npc.id].score = oldScore -- immediately changes the npc's score config back to normal 
					if NPC.MULTIHIT_MAP[npc.id] then
						bumpedNPC = true
					else
						-- increments the player's slide combo
						data.comboTimer = settings.slideComboTime 
						data.slideCombo = data.slideCombo + 1
						if data.slideCombo > 9 then
							data.slideCombo = 8
						end
					end
				elseif (springs.ids[npc.id] == springs.TYPE.SIDE and p:collide(npc)) -- handles changing direction upon hitting a bumper or a sideway spring
				or (bumper.ids[npc.id] and NPC.config[npc.id].bounceplayer and p:collide(npc.data._basegame.hitbox) 
				and (p.y+p.height > npc.y+10 and p.y < npc.y + npc.height-10)) then
					if type(npc.data._basegame.hitbox) == "BoxCollider" then
						SFX.play(Misc.resolveSoundFile("bumper")) 
					end
					data.slideSpeedX = math.max(math.abs(data.slideSpeedX),math.floor(settings.slideMinimumSpeed*3)) * math.sign(-data.slideSpeedX)
					p.speedX = data.slideSpeedX
					break
				end
			end
		end
		
		-- stops sliding if the player bumped into a wall/NPC
		if data.stuckTimer <= 0 or bumpedBlock or bumpedNPC then
			if fastEnough or bumpedBlock or bumpedNPC then
				if (data.stuckTimer <= 0 or bumpedBlock) then
					SFX.play(37)
				end
				p:mem(0x3C,FIELD_BOOL,true)
				p.speedX = -3 * p.direction
				p.speedY = -5
			end
			stopSlide(p)
			data.animTimer = 0
			return
		end

		if linkChars[p.character] then -- fix to prevent SMBX's hardcoded speedcap specific to link from slowing him down
			p.keys.left = KEYS_UP
			p.keys.right = KEYS_UP
			p:mem(0x138, FIELD_FLOAT, p.speedX)
			p.speedX = 0
		end
		
		-- handles water RUNNING
		if not fastEnough then return end
		for k, l in ipairs(Liquid.getIntersecting(p.x,p.y,p.x+p.width,p.y+p.height + 4 + p.speedY)) do 
			if not p:mem(0x36,FIELD_BOOL) and p.mount == 0 
			and p:mem(0x11C,FIELD_WORD) <= 0 
			and p.y + p.height < l.y + 2 then
				p:mem(0x50,FIELD_BOOL, false)
				p.y = l.y - 2 - p.height
				p.speedY = -Defines.player_grav
				data.slidingOnWater = true
				if p.keys.jump == KEYS_PRESSED then
					p.speedY = Defines.jumpspeed
					p:mem(0x11C,FIELD_WORD,Defines.jumpheight)
					data.slidingOnWater = false
					SFX.play(1)
				end
				if lunatime.tick() % 12 == 0 and not l.isQuicksand then -- spawn a water splashing effect every 12 frames
					local e = Effect.spawn(114, (p.x + p.width*0.5), l.y) 
					e.xAlign = 0.5
					e.x = (e.x - (e.width * 0.5)) - (p.width * p.direction)
					e.y = l.y - (e.height)
				elseif l.isQuicksand and lunatime.tick() % 2 == 0 then -- or spawn a skidding effect when sliding on quicksand
					Effect.spawn(
						74, 
						(p.x + p.width*0.5), 
						p.y + p.height - 4
					) 
				end
				break
			end
		end		
	else
		data.slideSpeedX = p.speedX
	end
	------------ END OF SLIDING HANDLING ------------
end

function penguinSuit.onDrawPowerup(p)
	if not p.data.penguinSuit then return end
	local data = p.data.penguinSuit
	local settings = penguinSuit.settings

	data.playerBuffer:clear(-100)
	
	if settings.animations[p.character] == nil then
		settings.animations[p.character] = defaultAnimations
	end
	
	if not inWater(p) and not data.isSliding then return end
	
	local animation = settings.animations[p.character][data.curAnim] or defaultAnimations[data.curAnim]
	local framespeed = animation.framespeed
	
	if inWater(p) and p.keys.run then
		framespeed = framespeed/2
	end
	
	local curFrame
	if animation.loops == false then
		curFrame = animation.frames[math.min(1 + math.floor(data.animTimer / framespeed),#animation.frames)]
	else
		curFrame = animation.frames[1 + math.floor(data.animTimer / framespeed) % #animation.frames]
	end
	local canPlay = isUnoccupied(p) and p.mount == 0 and not p:mem(0x50,FIELD_BOOL)

	if not canPlay or not curFrame then return end
	if data.isSliding then	
		-- hides the player & override it with a sprite replica that allows rotation
		p:setFrame(-50 * p.direction * p.direction) 
		p:render{
			frame = curFrame,
			target = data.playerBuffer,
			x = 50 - p.width/2,
			y = 50 - p.height/2,
			mount = p.mount,
			sceneCoords = false,
		}
		-- redraws the player & rotates them according to the direction of the slope they're sliding on
		Graphics.drawBox{ 
			texture = data.playerBuffer,
			x = p.x + p.width/2,
			y = p.y + p.height/2,
			sceneCoords = true,
			centered = true,
			rotation = data.slideRotation,
			priority = -25
		}
	else
		p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
	end
		
end

-- handles drawing the powerup when the player is in the overworld
function penguinSuit.onDrawPowerupOverworld(p)
	-- put your own code here!
end

return penguinSuit
