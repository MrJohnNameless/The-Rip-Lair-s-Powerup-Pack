
--[[
	Super Whip
				
	DIE, MONSTER!
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
				 - also made the Bubble Flower powerup script which was also used as a base here
	MrDoubleA - Provided the Uniformed Player Offsets used as a base here (https://www.smbxgame.com/forums/viewtopic.php?t=26127)
	Squishy Rex - made the sprites
	Deltomx3 - coding
	
	Version 1.0.0
	
	NOTE: This requires customPowerups in order to work! Get it from the (first) link above! ^^^
]]--

local cp = require("customPowerups")

local superWhip = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets", "cheats" and "iniFiles"
-- everything except "name" and "id" can be safely modified


superWhip.attackSound = "powerups/whip-attack.ogg"
superWhip.forcedStateType = 2 -- 0 for instant, 2 for normal/flickering, 3 for poof/raccoon
superWhip.basePowerup = PLAYER_FIREFLOWER
superWhip.cheats = {"needanotherbelmont", "ghostridesthewhip", "diemonster", "whatisaman", "johnnytest", "whipitgood"}
superWhip.settings = {
	loseSpeed = false -- If the player loses all of their speed when attacking
}

-- runs when customPowerups is done initializing the library
function superWhip.onInitPowerupLib()
	-- gets the respective spritesheets for the powerup
	superWhip.spritesheets = {
		superWhip:registerAsset(CHARACTER_MARIO, "mario-whip.png"),
		superWhip:registerAsset(CHARACTER_LUIGI, "luigi-whip.png"),
		superWhip:registerAsset(CHARACTER_PEACH, "peach-whip.png"),
		superWhip:registerAsset(CHARACTER_TOAD,  "toad-whip.png"),
		superWhip:registerAsset(CHARACTER_LINK,  "link-whip.png"),
	}
	
	-- needed to align the sprites relative to the player's hurtbox
	superWhip.iniFiles = {
		superWhip:registerAsset(CHARACTER_MARIO, "mario-whip.ini"),
		superWhip:registerAsset(CHARACTER_LUIGI, "luigi-whip.ini"),
		superWhip:registerAsset(CHARACTER_PEACH, "peach-whip.ini"),
		superWhip:registerAsset(CHARACTER_TOAD,  "toad-whip.ini"),
		superWhip:registerAsset(CHARACTER_LINK,  "link-whip.ini"),
	}
	
	--[[
	-- only uncomment the " [[ " above if you have a spritesheet for groundpounding with the template powerup
	superWhip.gpImages = {
		superWhip:registerAsset(CHARACTER_MARIO, "whip-groundPound-1.ini"),
		superWhip:registerAsset(CHARACTER_LUIGI, "whip-groundPound-2.ini"),
	}
	--]]
end


-- Peach, Toad, Megaman, Klonoa, Ninja Bomberman, Rosalina, and Ultimate-Rinka respectively
local smb2Chars = table.map{3,4,6,9,10,11,16}

-- Link, Snake, and Samus respectively
local linkChars = table.map{5,12,16}

local animFrames = {32, 32, 32, 32, 33, 33, 33, 33, 33, 33, 34, 34, 34, 34, 34, 34, 34, 34}
local duckAnimFrames = {35, 35, 35, 35, 36, 36, 36, 36, 36, 36, 37, 37, 37, 37, 37, 37, 37, 37}

-- Projectile cooldown timers for Mario, Luigi, Peach, Toad, and Link respectively
local projectileTimerMax = {55, 55, 55, 50, 45}

-- calls in Marioman2007's Ground Pound if it's in the same level folder as this customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=28456)
local GP
pcall(function() GP = require("GroundPound") end)

-- calls in Emral's anotherwalljump if it's in the same level folder as customPowerups (https://www.smbxgame.com/forums/viewtopic.php?t=24793)
local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function canPlayShootAnim(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and p.mount == 0
        and not p.climbing
        and not p.holdingNPC
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and p:mem(0x26,FIELD_WORD) <= 0 -- pulling objects from top
        and (not linkChars[p.character]) -- ducking and is not link/snake/samus
        and not p:mem(0x3C,FIELD_BOOL) -- sliding
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and p:mem(0x164,FIELD_WORD) == 0 -- tail attack
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
        and (not GP or not GP.isPounding(p))
        and (not aw or aw.isWallSliding(p) == 0)
    )
end


function superWhip.onInitAPI()
	-- register your events here!
	--registerEvent(template,"onNPCHarm")
end

-- runs once when the powerup gets activated, passes the player
function superWhip.onEnable(p)	
	p.data.superWhip = {
		projectileTimer = 0, -- don't remove this
		
		-- put your own values here!
		hitbox = Colliders.Box(p.x, p.y, 72, 24),
		atkDirection == 1,
	}
	if p.character ~= CHARACTER_MARIO and p.character ~= CHARACTER_LUIGI then
		p:harm()
	end
	-- p.data.superWhip.hitbox:Debug(true)
end

-- runs once when the powerup gets deactivated, passes the player
function superWhip.onDisable(p)	
	p.data.superWhip = nil
end

-- runs when the powerup is active, passes the player
function superWhip.onTickPowerup(p) 
	if not p.data.superWhip then return end -- check if the powerup is currenly active
	local data = p.data.superWhip
	
    data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
    
    if p.mount < 2 and not linkChars[p.character] then -- disables shooting fireballs for the original 4 characters + any X2 character that uses them as a base
        p:mem(0x160, FIELD_WORD, 2)
	elseif linkChars[p.character] then -- disables shooting fireballs if you're link, snake, or samus
		p:mem(0x162, FIELD_WORD, 2)
    end

	if data.projectileTimer > 0 or not canPlayShootAnim(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end

    if p:mem(0x50, FIELD_BOOL) and p:isOnGround() then return end -- if spinjumping while on the ground
	if p:mem(0x50, FIELD_BOOL) then return end 
	
	-- handles spawning the projectile if the player is pressing either run button, spinjumping, or at the apex(?) of link's sword slash animation respectively
    if ((p.keys.altRun == KEYS_PRESSED or p.keys.run == KEYS_PRESSED) and not linkChars[p.character]) or player:mem(0x14, FIELD_WORD) == 2 then
        data.atkDirection = p.direction
		
		-- handles projectile shooting while spinjumping
		if p:mem(0x50, FIELD_BOOL) and p.holdingNPC == nil then
			-- put your own code here!
		end

        data.projectileTimer = projectileTimerMax[p.character] -- sets the projectileTimer/cooldown upon shooting
    end
end

function superWhip.onTickEndPowerup(p)
	if not p.data.superWhip then return end -- check if the powerup is currently active
	
	local data = p.data.superWhip
	
	-- put your own code here!
	if data.projectileTimer == 44 then
		SFX.play(superWhip.attackSound, 0.8)
		for k,n in NPC.iterate() do
			if Colliders.collide(data.hitbox, n) then
				if n:mem(0x12A, FIELD_WORD) > 0 and n:mem(0x138, FIELD_WORD) == 0 and (not pnisHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 and NPC.HITTABLE_MAP[n.id] then
					n:harm(3, 2)
				end
				if NPC.COIN_MAP[n.id] or NPC.POWERUP_MAP[n.id] then
					n:collect(p)
				end
			end
		end
		for _,block in Block.iterate() do
			if Colliders.collide(data.hitbox, block) then
				-- If block is visible
				if block.isHidden == false and not block:mem(0x5A, FIELD_BOOL) then
					-- If the block should be broken, destroy it
					if Block.MEGA_SMASH_MAP[block.id] then
						if block.contentID > 0 then
							block:hit(false, p)
						else
							block:remove(true)
						end
					elseif (Block.SOLID_MAP[block.id] and not Block.SLOPE_MAP[block.id]) then
						block:hit(false, p)
						--bumpedBlock = true
					elseif Block.MEGA_STURDY_MAP[block.id] then
						block:remove(true)
					elseif Block.MEGA_HIT_MAP[block.id]then
						block:remove(true)
					end
				end
			end
		end
	end
	
	if data.projectileTimer > 35 then
		if p:isOnGround() and superWhip.settings.loseSpeed then
			p.speedX = p.speedX / 1.5
		end
		p.direction = data.atkDirection
	end
	
	if p.direction == 1 then
		data.hitbox.x = p.x + p.width
	elseif p.direction == -1 then
		data.hitbox.x = p.x - data.hitbox.width
	end
	
	if not p:mem(0x12E, FIELD_BOOL) then
		data.hitbox.y = p.y + 16
	else
		data.hitbox.y = p.y
	end
	
    local curFrame = animFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
	local curDuckFrame = duckAnimFrames[projectileTimerMax[p.character] - data.projectileTimer] -- sets the frame depending on how much the projectile timer has
    local canPlay = canPlayShootAnim(p) and not p:mem(0x50,FIELD_BOOL) and not linkChars[p.character]

    if data.projectileTimer > 0 and canPlay and curFrame then
		if p:mem(0x12E, FIELD_BOOL) then
			p:setFrame(curDuckFrame)
		else
			p:setFrame(curFrame) -- sets the frame based on the current value of "curFrame" above
		end
    end
end

function superWhip.onDrawPowerup(p)
	if not p.data.superWhip then return end -- check if the powerup is currently active
	local data = p.data.superWhip
	-- put your own code here!
	-- Text.print(data.projectileTimer, 10, 10)
end

return superWhip