
--[[
				builderSuit.lua by MrNameless
				
			A customPowerups script that brings over the
	Super Hammer/Builder Suit from Super Mario Maker 2 into SMBX
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	C. Pariah - Provided the Builder Suit sprites for Mario & Luigi (https://www.spriters-resource.com/custom_edited/mariocustoms/sheet/131321/)
	SleepyVA - Provided the SMBX exclusive sprites for the Builder Suit sprites for Mario & Luigi
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local playerStun = require("playerstun")
local smallSwitch = require("npcs/ai/smallswitch")

local builderSuit = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

function builderSuit.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	builderSuit.spritesheets = {
		builderSuit:registerAsset(1, "mario-buildersuit.png"),
		builderSuit:registerAsset(2, "luigi-buildersuit.png"),
	}

	-- needed to align the sprites relative to the player's hurtbox
	builderSuit.iniFiles = {
		builderSuit:registerAsset(1, "mario-buildersuit.ini"),
		builderSuit:registerAsset(2, "luigi-buildersuit.ini"),
	}
end


builderSuit.projectileID = 781
builderSuit.basePowerup = PLAYER_FIREFLOWER
builderSuit.cheats = {"needabuildersuit","supersmbxmaker","wreckingcrew","canwefixit","fixitfelix","ifuckedupthecobblestonegeneratorpleaseforgiveme"}

builderSuit.alwaysSmashBlocks = table.map{89}
builderSuit.alwaysHarmNPCs = table.map{541,542,543}
builderSuit.coloredSwitches = table.map{451,452,453,454,606,607}

builderSuit.settings = {
	swingLength = 40, -- How long does the hammer swing last? (40 by default)
	crateLimit = 5, -- How many crates can a player make at a time? (5 by default)
	crateCooldown = 30, -- How long does the player have to wait before spawning another crate & being able to swing again? (30 by default)
	allowSwingStun = true, -- Should the player be able to be stunned when hitting certain hard blocks? (true by default)
	allowFowardMovement = false, -- Should the player be at least allowed to move foward while swinging? (false by default)
}

-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {37, 36, 36, 36, 36, 37, 38, 38} -- the animation frames for shooting a fireball

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as this script (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local STATE_NORMAL = 0
local STATE_SWING = 1
local STATE_STUN = 2

local function canSwing(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
		and not p:mem(0x50,FIELD_BOOL)
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not p:mem(0x12E, FIELD_BOOL) or linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
		and not linkChars[p.character]
    )
end

function builderSuit.onInitAPI()
	-- register your events here!
	registerEvent(builderSuit,"onNPCKill")
end

-- runs once when the powerup gets activated, passes the player
function builderSuit.onEnable(p)	
	p.data.builderSuit = {
		swingTimer = 0, -- don't remove this
		swingState = 0,
		crateCooldown = 0,
		hitSomething = false,
		hittedBlocks = {},
		hittedNPCs = {},
		ownedCrates = {},
	}
	p:mem(0x162,FIELD_WORD,5)
end

-- runs once when the powerup gets deactivated, passes the player
function builderSuit.onDisable(p)
	if p:mem(0x154,FIELD_WORD) <= 0 then
		p:mem(0x154,FIELD_WORD,0)
	end
	
	p.data.builderSuit = nil
end

-- runs when the powerup is active, passes the player
function builderSuit.onTickPowerup(p) 
	if not p.data.builderSuit then return end -- check if the powerup is currenly active
	local data = p.data.builderSuit
	local settings = builderSuit.settings
	
    if not p.holdingNPC or p.holdingNPC.id ~= builderSuit.projectileID  then
		data.crateCooldown = math.max(data.crateCooldown - 1, 0) -- decrement the projectile timer/cooldown
	end
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end	

	local atSwordApex = p:mem(0x14, FIELD_WORD) == 2 

	-- handles spawning crates
	if ((canSwing(p) and data.swingState == STATE_NORMAL and p.keys.altRun == KEYS_PRESSED) or (atSwordApex and p.keys.altRun)) and data.crateCooldown <= 0 then
        local v = NPC.spawn(
			builderSuit.projectileID,
			p.x + p.width/2 + (p.width/2 + 0) * p.direction + p.speedX,
			p.y + p.height/2 + p.speedY, p.section, false, true
        )
		if not linkChars[p.character] then -- makes the player hold the crate
			v.speedY = 0
			v.heldIndex = p.idx
			p:mem(0x154, FIELD_WORD, v.idx+1)
			p:mem(0x62, FIELD_WORD, 10)
			data.crateCooldown = settings.crateCooldown
			SFX.play(23)
		else -- handles shooting a projectile from link
			if p:mem(0x12E,FIELD_BOOL) then -- shoot less higher when ducking
				v.speedY = -3
				v.speedX = (2 + p.speedX/3.5) * p.direction
				v.y = v.y - 2
			else
				v.speedY = -4
				v.y = v.y - v.height*0.25
				v.speedX = (6 + p.speedX/3.5) * p.direction
			end
			v.x = v.x + (8 * p.direction)
			v:mem(0x156,FIELD_WORD,32)
			data.crateCooldown = settings.crateCooldown + 10
			SFX.play(82)
			SFX.play(90)
		end
		v.isProjectile = true
		v.data.variant = p.character -- changes the sprite variant relative to the player's character
		table.insert(data.ownedCrates,v)
		Routine.run(function()
			Routine.skip()
			local e = Effect.spawn(131,v)
		end)
		-- removes the first spawned crate if theres too many of them
		if #data.ownedCrates > builderSuit.settings.crateLimit then 
			local n = data.ownedCrates[1];
			n:kill(9)
			Effect.spawn(131,n)	
		end
		return
	end

	-- initializes swinging the hammer
	if p.keys.run == KEYS_PRESSED and canSwing(p) and data.crateCooldown <= 0 and data.swingState == STATE_NORMAL then
		p:mem(0x154,FIELD_WORD,-2) -- prevents the player from holding an item
		p:setFrame(37) 
		data.swingState = STATE_SWING
		data.swingTimer = 0
		data.hitSomething = false
		data.hittedBlocks = {}
		data.hittedNPCs = {}
		SFX.play(77)
	end
	
	if data.swingState == STATE_SWING then 
		if settings.allowFowardMovement then -- handles letting the player at least move foward when swinging
			if p.direction == -1 then
				if p.keys.right then p.speedX = p.speedX + 0.075 end
				p.keys.right = KEYS_UP
			else
				if p.keys.left then p.speedX = p.speedX - 0.075 end
				p.keys.left = KEYS_UP
			end
		else -- otherwise, take away the player's controls
			p.keys.left = KEYS_UP
			p.keys.right = KEYS_UP
		end	
		p.keys.jump = KEYS_UP
		p.keys.altJump = KEYS_UP
		p.keys.down = KEYS_UP
	end
end

-- runs when the powerup is active, passes the player
function builderSuit.onTickEndPowerup(p) 
	if not p.data.builderSuit then return end -- check if the powerup is currenly active
	local data = p.data.builderSuit
	local settings = builderSuit.settings

	if data.swingState == STATE_NORMAL then return end -- prevents the rest of the code below from activating if not swinging
	
	data.swingTimer = math.min(data.swingTimer + 1,  settings.swingLength)
	
	if not canSwing(p) or data.swingTimer >= settings.swingLength then -- resets the player's hammer properties
		p:mem(0x154,FIELD_WORD,0) -- allows the player to hold an item again
		data.swingState = STATE_NORMAL
		data.swingTimer = 0
		data.hitSomething = false
		data.hittedBlocks = {}
		data.hittedNPCs = {}
		return
	end
	
	if data.swingState == STATE_SWING then 
		local left = 0; local right = 0
		local top = p.y
		local bottom = p.y + p.height - 2
		if p.direction == -1 then
			right = p.x
			left = (right - 30) 
		else
			left = p.x + p.width
			right = (left + 30)
		end
		if data.swingTimer >= 10 and data.swingTimer <= math.floor(settings.swingLength/1.5) then
			local hittedSomething = false
			local bumpedBlock = false
			-- handles hitting blocks
			for _,block in Block.iterateIntersecting(left, top, right, bottom) do 
			-- If the block should be broken, destroy it
				if not data.hittedBlocks[block.idx] and not Block.LAVA_MAP[block.id] and not Block.PLAYER_MAP[block.id] and not Block.SEMISOLID_MAP[block.id] then
					if Block.MEGA_SMASH_MAP[block.id] or builderSuit.alwaysSmashBlocks[block.id] or block.contentID > 0 then
						if (block.contentID > 0) and not builderSuit.alwaysSmashBlocks[block.id] then
							block:hit(false, p)
						else
							block:remove(true)
						end
					elseif Block.MEGA_HIT_MAP[block.id] or (Block.SOLID_MAP[block.id] and not Block.SLOPE_MAP[block.id]) then
						block:hit(false, p)
						bumpedBlock = true
					end
					data.hittedBlocks[block.idx] = true -- makes it so the block is only hit once.
					hittedSomething = true
				end
			end
			
			 -- handles hitting NPCs
			local hittedNPC = false
			for _, npc in NPC.iterateIntersecting(left, top, right, bottom) do
				if bumpedBlock then break end -- skip hitting npcs if the player also hitted a solid block beforehand
				if (not npc.friendly) and npc.despawnTimer > 0 and (not npc.isGenerator) and npc.forcedState == 0 and npc.heldIndex == 0 and not data.hittedNPCs[npc.idx] then
					if npc.id == builderSuit.projectileID then -- allows the hammer swing to destroy crates
						npc:kill(9)
						Effect.spawn(1,npc)
						SFX.play(4)
					elseif NPC.SWITCH_MAP[npc.id] then
						if builderSuit.coloredSwitches[npc.id] then -- presses the SMBX2 lua-based switches
							smallSwitch.press(npc)
						else -- presses the 1.3 switches
							npc:harm(1)
						end
					elseif NPC.COLLECTIBLE_MAP[npc.id] and not NPC.POWERUP_MAP[npc.id] and npc:mem(0x14E,FIELD_WORD) == 0 then -- lets the hammer collect coins
						npc:collect(p)
					elseif NPC.HITTABLE_MAP[npc.id] or builderSuit.alwaysHarmNPCs[npc.id] then
						npc:harm(3)
					end
					data.hittedNPCs[npc.idx] = true -- makes it so the npc is only hit once.
					hittedSomething = true
				end
			end
		
			-- stuns the player whenever they hit a solid block
			if bumpedBlock and data.swingTimer <= 14 and settings.allowSwingStun then
				data.swingState = STATE_STUN
				playerStun.stunPlayer(p.idx, settings.swingLength - data.swingTimer)
				SFX.play(35)
			end
			-- play the block hit SFX only once if the player hitted anything
			if not data.hitSomething and (p:isGroundTouching() or hittedSomething) then 
				SFX.play(3) 
				data.hitSomething = true
			end
		end
	elseif data.swingState == STATE_STUN then
		p.speedX = -1 * p.direction -- gives the player recoil when stunned
	end

	for i = #data.ownedCrates,1,-1 do
		local n = data.ownedCrates[i];
		if (n.isValid) then
			n.despawnTimer = 180 -- prevents player-owned crates from ever despawning
		end
	end	
end

function builderSuit.onDrawPowerup(p)
	if not p.data.builderSuit then return end -- check if the powerup is currently active
	local data = p.data.builderSuit

    local curFrame = animFrames[math.min(math.floor(data.swingTimer * 0.7), #animFrames)] -- sets the frame depending on how much the projectile timer has
    local canPlay = canSwing(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.swingTimer <= 0 then return end
	
	if data.swingState == STATE_SWING and canPlay and curFrame then
        p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
	elseif data.swingState == STATE_STUN then
		p:setFrame(36) -- locks the frame to the raised hammer one when stunned
	end
end

function builderSuit.onNPCKill(token,v,harm)
	for _,p in ipairs(Player.get()) do
		if p.data.builderSuit then
			local data = p.data.builderSuit	
			for i,n in ipairs(data.ownedCrates) do
				if n.isValid and n == v then
					table.remove(data.ownedCrates, i)
					break
				end
			end
		end
	end
end

return builderSuit