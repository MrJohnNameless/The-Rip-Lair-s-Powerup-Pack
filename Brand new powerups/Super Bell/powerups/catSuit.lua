
--[[
					catSuit.lua by MrNameless
				
			A customPowerups script that brings over the
		Super Bell/Cat Suit from Super Mario 3D World into SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	
	JR.Master - Created most of the original Cat Mario & Luigi sprites used here 
				Mario: (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/63930/)
				Luigi: (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/96239/)
				
	SleepyVA -	Imported over the Cat Suit sprites for luigi
			 -	Also created Yoshi-Riding & Normal Swimming Sprites for Cat Mario & Luigi
	
	Master of Diaster - Created the Swiping Effect for the Cat Suit
	
	AmarLthePlumber - Made the original skidding sprites for Cat Mario & Luigi
	Jacc Jorep - Made the original ducking sprites for Cat Mario & Luigi (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/144445/)
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")
local smallSwitch = require("npcs/ai/smallswitch")

local catSuit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified

catSuit.effectID = 831
catSuit.forcedStateType = 1 -- 0 for instant, 1 for normal/flickering, 2 for poof/raccoon
catSuit.basePowerup = PLAYER_FIREFLOWER
catSuit.cheats = {"needasuperbell","needacatsuit","herekittykitty","ohheytacobell","thecatsmeow","garfieldyoufatcat","yarnaddiction","micetastenice","hairball","valorantplayers","sorrymdaandstarshi"}
catSuit.settings = { 
	swipeSFX = Misc.resolveSoundFile("powerups/catsuit_swipe.ogg"), -- what is the SFX played when attacking/swiping with the cat suit?
	diveSFX = Misc.resolveSoundFile("sound/character/ub_lunge.wav"), -- what is the SFX played when diving with the cat suit?
	canDive = true, -- is the player able to dive while using the cat suit? (true by default)
	canSlide = true, -- is the player able to slide while using the cat suit? (true by default)
	canWallClimb = true, -- is the player allowed to wall-climb while using the cat suit? (true by default)
	wallClimbLength = 260 -- how many ticks/frames is the player able to wall-climb for? (260 by default)
}

-- runs when customPowerups is done initializing the library
function catSuit.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	catSuit.spritesheets = {
		catSuit:registerAsset(CHARACTER_MARIO, "mario-catsuit.png"),
		catSuit:registerAsset(CHARACTER_LUIGI, "luigi-catsuit.png"),
		--catSuit:registerAsset(CHARACTER_PEACH, "peach-catsuit.png"),
		--catSuit:registerAsset(CHARACTER_TOAD, "toad-catsuit.png"),
		--catSuit:registerAsset(CHARACTER_LINK, "link-catsuit.png"),
	}

	-- needed to align the sprites relative to the player's hurtbox
	catSuit.iniFiles = {
		catSuit:registerAsset(CHARACTER_MARIO, "mario-catsuit.ini"),
		catSuit:registerAsset(CHARACTER_LUIGI, "luigi-catsuit.ini"),
		--catSuit:registerAsset(CHARACTER_PEACH, "peach-catsuit.ini"),
		--catSuit:registerAsset(CHARACTER_TOAD, "toad-catsuit.ini"),
		--catSuit:registerAsset(CHARACTER_LINK, "link-catsuit.ini"),
	}

	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the catSuit powerup
	catSuit.gpImages = {
		catSuit:registerAsset(CHARACTER_MARIO, "catsuit-groundPound-1.png"),
		catSuit:registerAsset(CHARACTER_LUIGI, "catsuit-groundPound-2.png"),
	}
	--]]
end


catSuit.coloredSwitches = table.map{451,452,453,454,606,607}

local playerBuffer = Graphics.CaptureBuffer(100, 100)

local STATE_NORMAL = 0
local STATE_SWIPE = 1
local STATE_DIVE = 2
local STATE_SLIDE = 3
local STATE_WALLCLIMB = 4

local smwCostumes = table.map{"SMW-MARIO","SMW-LUIGI","SMW-TOAD","SMW-WARIO","SMM2-MARIO","SMM2-LUIGI","SMM2-TOAD","SMM2-TOADETTE",} -- ,"SMW-TODD?"}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local swipeAnim = {36, 36, 37, 37, 37, 37, 38, 38} -- the animation frames for swiping

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {55, 55, 55, 50, 45}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function onSand(p) -- fix for not being able to pull on pullable sand BLOCKS with the slide enabled because there are two diggable sands for some reason
	local onSand = false
	for i,sand in Block.iterateIntersecting(p.x,p.y + p.height - 2,p.x + p.width,p.y + p.height + 2) do
		if sand.id == 370 and (not sand.isHidden and not sand:mem(0x5A, FIELD_BOOL)) then
			onSand = true
			break
			SFX.play(12)
		end
	end
	return onSand
end

local function isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		p:isGroundTouching() -- on a block
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

local function unOccupied(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and not p:mem(0x50,FIELD_BOOL) -- not spinjumping
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

local function isTouchingWall(p)
	local touched = false
	local offset = 0
	if p.direction == -1 then
		offset = offset - 1
	else
		offset = offset + 1
	end
	for i,b in Block.iterateIntersecting((p.x + offset),p.y,(p.x + p.width + offset),p.y + p.height - 4) do
		if (not b.isHidden and not b:mem(0x5A, FIELD_BOOL)) and Block.SOLID_MAP[b.id] and not Block.SLOPE_MAP[b.id] and not Block.SEMISOLID_MAP[b.id]
		and not Block.LAVA_MAP[b.id] and not Block.PLAYER_MAP[b.id] then
			touched = true
			break
		end
	end
	return touched
end

local function canWallClimb(p)
	return (
		catSuit.settings.canWallClimb
		and unOccupied(p)
		and isTouchingWall(p)
		and (p:mem(0x11C, FIELD_WORD) <= 0 or p.speedY > 0)
		and not p:mem(0x36,FIELD_BOOL) -- not underwater
		and not p:mem(0x12E,FIELD_BOOL)
		and (p:mem(0x48,FIELD_WORD) ~= 0 or not isOnGround(p))
		and p.data.catSuit.wallCooldown <= 0
	)
end

local function handleSwiping(p,left,right,top,bottom,hitboxWidth,canCombo) -- handles breaking blocks & harming npcs when doing specific actions in the cat suit
	if not p.data.catSuit then return end
	local data = p.data.catSuit

	if p.direction == -1 then
		left = left - hitboxWidth + math.min(p.speedX,0)
	else
		right = right + hitboxWidth + math.max(p.speedX,0)
	end
	
	p.keys.jump = KEYS_UP
	p.keys.altJump = KEYS_UP
	p.keys.down = KEYS_UP
	
	local hittedSomething = false
	-- handles hitting blocks
	for _,block in Block.iterateIntersecting(left, top, right, bottom) do 
	-- If the block should be broken, destroy it
		if (not block.isHidden and not block:mem(0x5A, FIELD_BOOL)) and not data.hittedBlocks[block.idx] and not Block.LAVA_MAP[block.id] and not Block.PLAYER_MAP[block.id] and not Block.SEMISOLID_MAP[block.id] then
			if Block.MEGA_SMASH_MAP[block.id] then
				if block.contentID > 0 then
					block:hit(false, p)
				else
					block:remove(true)
				end
				hittedSomething = true
			elseif Block.MEGA_HIT_MAP[block.id] or (Block.SOLID_MAP[block.id] and not Block.SLOPE_MAP[block.id]) then
				block:hit(false, p)
				hittedSomething = true
			end
			data.hittedBlocks[block.idx] = true -- makes it so the block is only hit once.
		end
	end
	
	-- handles hitting NPCs
	local hittedNPC = false
	for _, npc in NPC.iterateIntersecting(left, top, right, bottom) do
		if (not npc.friendly) and npc.despawnTimer > 0 and (not npc.isGenerator) and npc.forcedState == 0 and npc.heldIndex == 0 and not data.hittedNPCs[npc.idx] then
			if NPC.SWITCH_MAP[npc.id] then
				if catSuit.coloredSwitches[npc.id] then -- presses the SMBX2 lua-based switches
					smallSwitch.press(npc)
				else -- presses the 1.3 switches
					npc:harm(1)
				end
			elseif NPC.COLLECTIBLE_MAP[npc.id] and not NPC.POWERUP_MAP[npc.id] and npc:mem(0x14E,FIELD_WORD) == 0 then -- lets the hammer collect coins
				npc:collect(p)
			elseif NPC.HITTABLE_MAP[npc.id] then
				if canCombo then -- handles incrementing the combo score
					local oldScore = NPC.config[npc.id].score
					NPC.config[npc.id].score = 2 + data.diveCombo
					npc:harm(3)
					NPC.config[npc.id].score = oldScore
					data.diveCombo = math.min(data.diveCombo + 1, 8)
				else
					npc:harm(3)
				end
			end
			data.hittedNPCs[npc.idx] = true -- makes it so the npc is only hit once.
			hittedSomething = true
		end
	end
	-- play the block hit SFX only once if the player hitted anything
	if not data.hitSomething and hittedSomething then 
		SFX.play(3) 
		data.hitSomething = true
	end
end
local function spawnWallSkid(p)
	local e = Effect.spawn(74,p.x+p.width/2,p.y)
	e.x = e.x - e.width/2
	e.x = (e.x + (16 * p.direction))
	e.y = (p.y+p.height*0.5) + RNG.randomInt(-16,16)
	return e
end

function catSuit.onInitAPI()
	registerEvent(catSuit,"onPlayerHarm")
end

-- runs once when the powerup gets activated, passes the player
function catSuit.onEnable(p)
	p:setFrame(3)
	p.data.catSuit = {
		state = STATE_NORMAL,
		swipeEffect = nil,
		canDive = true,
		canFloat = false,
		hitSomething = false,
		hittedBlocks = {},
		hittedNPCs = {},
		swipeTimer = 0,
		swipeCooldown = 0,
		diveCombo = 0,
		wallTimer = 0,
		wallDuration = 0,
		wallJumpLeeway = 0,
		wallCooldown = 0,
		wallDirection = p.direction,
		slideDirection = p.direction
	}
end

-- runs once when the powerup gets deactivated, passes the player
function catSuit.onDisable(p)
	p:mem(0x154,FIELD_WORD,math.max(p:mem(0x154,FIELD_WORD), 0)) -- allows the player to hold an item again
	p:mem(0x12E,FIELD_WORD,0) -- allows the player to freely duck & unduck again
	p.data.catSuit = nil
end

-- runs when the powerup is active, passes the player
function catSuit.onTickPowerup(p) 
	if not p.data.catSuit then return end
	local data = p.data.catSuit
	local settings = catSuit.settings
    if aw then aw.preventWallSlide(p) end
	
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end

    if p:mem(0x50, FIELD_BOOL) and isOnGround(p) then return end -- if spinjumping while on the ground
	
	-- refreshes diving & wall-climbing duration
	if isOnGround(p) or p:mem(0x36,FIELD_BOOL) then
		data.canDive = true
		data.wallDuration = settings.wallClimbLength
	end
	
	-- if the player's busy doing/being something else, bring the player's state back to normal
	if not unOccupied(p) and data.state ~= STATE_NORMAL then 
		data.state = STATE_NORMAL
		p:mem(0x12E,FIELD_WORD,0) -- allows the player to freely duck & unduck again
		p:mem(0x154,FIELD_WORD,math.max(p:mem(0x154,FIELD_WORD), 0)) -- allows the player to hold an item again
		return
	end
		
	if unOccupied(p) and (p.keys.run == KEYS_PRESSED or p.keys.altRun == KEYS_PRESSED) and data.state == STATE_NORMAL and Level.endState() == 0 then
		-- initiates sliding
		if settings.canSlide and not onSand(p) and (p:mem(0x12E, FIELD_BOOL) or p.keys.down) 
		and p.rawKeys.altJump ~= KEYS_DOWN and not p:mem(0x36,FIELD_BOOL) and p:mem(0x176,FIELD_WORD) == 0 then
			p.speedX = 8 * p.direction
			p.keys.run = KEYS_UP
			p.keys.altRun = KEYS_UP
			p:mem(0x12E,FIELD_WORD,1)
			data.state = STATE_SLIDE
			data.slideDirection = p.direction
			data.hitSomething = false
			handleSwiping(
				p, -- player
				p.x, -- left
				p.x + p.width, -- right
				p.y - 2, -- top 
				p.y + p.height + 4 + math.max(p.speedY,0), -- bottom
				12 + math.abs(p.speedX), -- hitbox width
				true -- allows comboing
			)
			SFX.play(catSuit.settings.swipeSFX) 
			Effect.spawn(10,p)
		-- initiates swiping
		elseif ((p:mem(0x176,FIELD_WORD) == 0 and not onSand(p)) or not p.keys.down) then
			p:setFrame(swipeAnim[1])
			p:mem(0x154,FIELD_WORD,-2) -- prevents the player from holding an item
			data.state = STATE_SWIPE
			data.swipeEffect = Effect.spawn(catSuit.effectID,p.x+p.width/2,p.y)
			data.swipeEffect.direction = p.direction
			SFX.play(catSuit.settings.swipeSFX) 
		end
	end
		
	-- handles wall-jumping
	if data.wallJumpLeeway > 0 and (p.keys.jump == KEYS_PRESSED or p.keys.altJump == KEYS_PRESSED) then
		data.canFloat = p:mem(0x18,FIELD_BOOL) -- stores peach's spinjump if she hasn't used it before wall-running
		p:mem(0x18,FIELD_BOOL,false) -- stops peach from being able to float
		p:mem(0x50,FIELD_BOOL,false) -- stops spinjumping
		p.direction = -data.wallDirection
		p.speedX = -8 * data.wallDirection
		p.speedY = -10
		p.keys.left = KEYS_UP
		p.keys.right = KEYS_UP
		data.wallJumpLeeway = 0
		data.wallCooldown = 8
		Routine.run(function() -- delays jump handling check by 2 frames/ticks
			Routine.skip()
			Routine.skip()
			if p.keys.altJump then
				p:mem(0x50,FIELD_BOOL, true)
				SFX.play(33)
			else
				SFX.play(1)
			end
		end)
		p:mem(0x18,FIELD_BOOL, data.canFloat) -- gives peach back her float if she didn't use it before wall-running
	end
		
	-- initiates wall climbing
	if canWallClimb(p) and data.state == STATE_NORMAL and p.speedY > Defines.player_grav then		
		p.speedX = 0
		p.speedY = -Defines.player_grav
		data.state = STATE_WALLCLIMB
		data.canFloat = p:mem(0x18,FIELD_BOOL) -- stores peach's spinjump if she hasn't used it before wall-running
		data.wallDirection = p.direction
		data.wallJumpLeeway = 8
	end
	
	data.wallCooldown = math.max(data.wallCooldown - 1, 0)
	
	-- prevents the rest of the code below from activating when not doing any action
	if data.state == STATE_NORMAL then 
		data.wallJumpLeeway = math.max(data.wallJumpLeeway - 1, 0)
		data.diveCombo = 0
		data.swipeTimer = 0
		data.wallTimer = 0
		p:mem(0x154,FIELD_WORD,math.max(p:mem(0x154,FIELD_WORD), 0)) -- allows the player to hold an item again
		return 
	end
	
	if data.state == STATE_SWIPE then
		-- prevent the player from jumping
		p.keys.jump = KEYS_UP
		p.keys.altJump = KEYS_UP
		p.keys.down = KEYS_UP
	end
	
	------------ DIVE HANDLING ------------
	if data.state == STATE_DIVE and (p.keys.run or p.keys.altRun) and p.speedX ~= 0 and not isOnGround(p) then
		p.keys.left = KEYS_UP
		p.keys.right = KEYS_UP
		p.keys.down = KEYS_UP
		p.keys.run = KEYS_UP
		p.keys.altRun = KEYS_UP
		p.speedX = 8 * p.direction
		p.speedY = 8
		if lunatime.tick() % 6 == 0 then Effect.spawn(10,p) end
	elseif data.state == STATE_DIVE then
		p:mem(0x154,FIELD_WORD,0) -- allows the player to hold an item again
		data.state = STATE_NORMAL
		data.diveCombo = 0
	end
	------------ END OF DIVE HANDLING ------------
	
	------------ SLIDE HANDLING ------------
	if data.state == STATE_SLIDE then
		data.wallCooldown = 32
		if math.abs(p.speedX) <= 0.5 or canWallClimb(p) or p:mem(0x36,FIELD_BOOL) or (isOnGround(p) and (p.keys.jump or p.keys.altJump)) then
			p.keys.jump = KEYS_UP
			p.keys.altJump = KEYS_UP
			p:mem(0x12E,FIELD_WORD,0)
			p:mem(0x12E,FIELD_BOOL,true)
			data.state = STATE_NORMAL
			return
		end
		local goingUphill = false
		if p:mem(0x48,FIELD_WORD) ~= 0 then
			local slope = Block(p:mem(0x48,FIELD_WORD))
			if (Block.SLOPE_LR_FLOOR_MAP[slope.id] and p.speedX > 0) or (Block.SLOPE_RL_FLOOR_MAP[slope.id] and p.speedX < 0) then
				goingUphill = true
			elseif (Block.SLOPE_RL_FLOOR_MAP[slope.id] and p.speedX > 0) or (Block.SLOPE_LR_FLOOR_MAP[slope.id] and p.speedX < 0) then
				p.speedX = p.speedX + (0.3 * p.direction) -- speeds the player up when going downhill
			end
		end
		if not goingUphill then
			local modifier = 0.05
			if isOnGround(p) then modifier = -0.01 end
			p.speedX = p.speedX + (modifier * p.direction) -- lessens the player's friction if not going uphill
		else
			p:mem(0x3A,FIELD_WORD,5)
		end
		if isOnGround(p) then
			local e = spawnWallSkid(p)
			e.x = e.x - (RNG.randomInt(1,4) * p.direction)
			e.y = p.y + p.height
		end
		p.keys.run = KEYS_UP
		p.keys.altRun = KEYS_UP
		p.keys.down = KEYS_UP
	end
	------------ END OF SLIDE HANDLING ------------
	
	------------ WALL-CLIMB HANDLING ------------
	if data.state == STATE_WALLCLIMB and canWallClimb(p) then
		data.wallDuration = math.max(data.wallDuration - 1, 0)
		data.wallJumpLeeway = 8
		if p.keys.up and data.wallDuration > 0 then
			-- lets the player climb upwards, speed depends on how much climbing duration they have left
			if data.wallDuration > 65 then
				p.speedY = math.max(p.speedY - (Defines.player_grav + 0.5),-4)
			else
				p.speedY = math.min(p.speedY - (Defines.player_grav - 0.1), 3)
				data.wallTimer = data.wallTimer - 1
			end
			data.wallTimer = data.wallTimer - 1
			spawnWallSkid(p)
		elseif p.keys.down or data.wallDuration <= 65 then
			p.speedY = math.min(p.speedY - (Defines.player_grav - 0.5),4)
			data.wallTimer = data.wallTimer - 1
			p.keys.down = KEYS_UP
			spawnWallSkid(p)
		else
			p.speedY = -Defines.player_grav 
			data.wallTimer = 0
		end
	elseif data.state == STATE_WALLCLIMB then
		data.wallCooldown = 32
		data.wallTimer = 0
		data.state = STATE_NORMAL
	end
	------------ END OF WALL-CLIMB HANDLING ------------
end

function catSuit.onTickEndPowerup(p)
	if not p.data.catSuit then return end
	
	local data = p.data.catSuit
	local settings = catSuit.settings
	
	------------ SWIPE HANDLING ------------
	if data.state == STATE_SWIPE then
		data.swipeTimer = data.swipeTimer + 1
		-- lets the player levitate when they're able to dive
		if data.canDive and p.speedY >= Defines.player_grav and not p:isUnderwater() then
			p.speedY = -Defines.player_grav + 0.01
		end
		if data.swipeTimer >= 4 and data.swipeTimer < 20 then
			handleSwiping(
				p, -- player
				p.x, -- left
				p.x + p.width, -- right
				p.y, -- top 
				p.y + p.height - 2, -- botton
				30 -- hitbox width
			)
		end
		-- handles making the swipe effect follow the player
		data.swipeEffect.x = (p.x + p.width/2) + p.speedX
		data.swipeEffect.y = (p.y + p.height/2) + p.speedY
		
		-- handles ending the swipe & transitioning to either diving or wall climbing depending on the situation
		if data.swipeTimer >= 20 then
			data.state = STATE_NORMAL
			data.swipeTimer = 0
			data.wallTimer = 0
			data.wallJumpLeeway = 0
			
			data.hitSomething = false
			data.hittedBlocks = {}
			data.hittedNPCs = {}
			
			if settings.canDive and p.keys.run == KEYS_DOWN and not p.keys.altRun and not isOnGround(p) 
			and not p:mem(0x36,FIELD_BOOL) and data.canDive and not canWallClimb(p) then
				data.state = STATE_DIVE
				data.wallDuration = math.max(data.wallDuration,settings.wallClimbLength/2) -- makes it so you only regain a bit of your wall climb duration back & not all of it
				p.speedX = Defines.player_runspeed * p.direction
				SFX.play(settings.diveSFX, 0.75) 
			else
				p:mem(0x154,FIELD_WORD,0) -- allows the player to hold an item again
			end
			if not canWallClimb(p) then data.canDive = false end
		else
			return
		end
	end
	------------ END OF SWIPE HANDLING ------------
	

	if data.state == STATE_DIVE then
		p:setFrame(39)
		data.hittedNPCs = {}
		handleSwiping(
			p, -- player
			p.x, -- left
			p.x + p.width, -- right
			p.y, -- top 
			p.y + p.height + 4 + math.max(p.speedY,0), -- bottom
			8, -- hitbox width
			true -- allows comboing
		)
	end
	
	if data.state == STATE_SLIDE then
		p:setFrame(11)
		handleSwiping(
			p, -- player
			p.x, -- left
			p.x + p.width, -- right
			p.y - 2, -- top 
			p.y + p.height + 4 + math.max(p.speedY,0), -- bottom
			12 + math.abs(p.speedX), -- hitbox width
			true -- allows comboing
		)
		p.direction = data.slideDirection
	end	
end

function catSuit.onDrawPowerup(p)
	if not p.data.catSuit then return end -- check if the powerup is currently active
	local data = p.data.catSuit
	
    local curFrame = swipeAnim[math.min(math.floor(data.swipeTimer * 0.7), #swipeAnim)] -- sets the frame depending on how much the projectile timer has
    local canPlay = unOccupied(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.swipeTimer > 0 and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
    end
	
	-- forces the player's idle frame to be the standing variant for spinjumps
	if p:mem(0x50,FIELD_BOOL) and p.frame == 1 then
		p.frame = 12
	end
	
	if data.state == STATE_WALLCLIMB then
		playerBuffer:clear(-100)
		local wallAnim = {1,2,3,2} -- the animation frames for wall climbing
		if smwCostumes[Player.getCostume(p.character)] then
			wallAnim = {3,2,1}
		end
		local frame = wallAnim[1 + math.floor(data.wallTimer * 0.3) % #wallAnim] -- sets the animation frame depending on the wallTimer
		if data.wallDuration <= 0 then 
			frame = wallAnim[1] -- force the frame to be the idle climbing animation if the player can't climb any longer
		end
		-- hides the player & override it with a sprite replica that allows rotation
		p:setFrame(-50 * p.direction) 
		p:render{
			frame = frame,
			target = playerBuffer,
			x = 50 - p.width/2,
			y = 50 - p.height/2,
			mount = p.mount,
			sceneCoords = false,
		}
		-- redraws the player & rotates them according to the direction of the wall they're climbing on
		Graphics.drawBox{ 
			texture = playerBuffer,
			x = (p.x + p.width/2) - ((p.width/3 - 2) * p.direction), 
			y = p.y + p.height/2, -- tweaks needed
			sceneCoords = true,
			centered = true,
			rotation = (90 * -p.direction)
		}
	end
	--[[
	-- shows the player's hitbox (for debug purposes only)
	local c = Colliders.Box(p.x, p.y, p.width, p.height) 
	c:Draw(Color.red .. 0.5)
	--]]
end

-- fallback if the player got harmed while diving/sliding into a hittable npc
function catSuit.onPlayerHarm(token,p)
	if cp.getCurrentPowerup(p) ~= catSuit or not p.data.catSuit then return end
	if p.data.catSuit.state ~= STATE_DIVE and p.data.catSuit.state ~= STATE_SLIDE then return end
	for _,v in NPC.iterateIntersecting(p.x,p.y,p.x + p.width,p.y + p.height) do
		if (not v.friendly) and v.despawnTimer > 0 
		and (not v.isGenerator) and v.heldIndex == 0 -- and not catSuit.alwaysHarmNPCs[v.id]
		and NPC.HITTABLE_MAP[v.id] and not NPC.MULTIHIT_MAP[v.id] then -- prevents the player from getting hurt if the npc can be hit by the player
			v:harm(3)
			token.cancelled = true
			break
		end
	end
end

return catSuit