
--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local beetroot = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local beetrootSettings = {
	id = npcID,

	-- ANIMATION
	--Sprite size
	gfxwidth = 32,
	gfxheight = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 24,
	height = 32,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 1,
	framestyle = 0,
	framespeed = 8, -- number of ticks (in-game frames) between animation frame changes

	foreground = false, -- Set to true to cause built-in rendering to render the NPC to Priority -15 rather than -45

	-- LOGIC
	--Movement speed. Only affects speedX by default.
	speed = 2,
	luahandlesspeed = true, -- If set to true, the speed config can be manually re-implemented
	nowaterphysics = false,
	cliffturn = false, -- Makes the NPC turn on ledges
	staticdirection = true, -- If set to true, built-in logic no longer changes the NPC's direction, and the direction has to be changed manually

	--Collision-related
	npcblock = false, -- The NPC has a solid block for collision handling with other NPCs.
	npcblocktop = false, -- The NPC has a semisolid block for collision handling. Overrides npcblock's side and bottom solidity if both are set.
	playerblock = false, -- The NPC prevents players from passing through.
	playerblocktop = false, -- The player can walk on the NPC.

	nohurt=true, -- Disables the NPC dealing contact damage to the player
	nogravity = false,
	noblockcollision = false,
	notcointransformable = true, -- Prevents turning into coins when beating the level
	nofireball = true,
	noiceball = true,
	noyoshi= true, -- If true, Yoshi, Baby Yoshi and Chain Chomp can eat this NPC

	score = 0, -- Score granted when killed
	--  1 = 10,    2 = 100,    3 = 200,  4 = 400,  5 = 800,
	--  6 = 1000,  7 = 2000,   8 = 4000, 9 = 8000, 10 = 1up,
	-- 11 = 2up,  12 = 3up,  13+ = 5-up, 0 = 0

	--Various interactions
	jumphurt = true, --If true, spiny-like (prevents regular jump bounces)
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping and causes a bounce
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	nowalldeath = false, -- If true, the NPC will not die when released in a wall
	useclearpipe = true,

	linkshieldable = false,
	noshieldfireeffect = false,

	grabside=false,
	grabtop=false,
	bubbleFlowerImmunity = true,
	
	totalBounces = 3,
	allowSpeedIncrement = false,
}

--Applies NPC settings
npcManager.setNpcSettings(beetrootSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_LAVA,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
	}
);

--Custom local definitions below

local function updateSpeed(v)
	local increment = 0
	if NPC.config[v.id].allowSpeedIncrement then increment = v.data.bounces / 2 end
	v.speedY = -6
	v.direction = v.direction * -1
	v.speedX = (NPC.config[v.id].speed + increment) * v.direction 
end

--Register events
function beetroot.onInitAPI()
	npcManager.registerEvent(npcID, beetroot, "onTickNPC")
	registerEvent(beetroot, "onNPCHarm")
	
	-- Done to prevent the beetroots from colliding with each other
	Misc.groupsCollide["beetroot"]["beetroot"] = false
end

function beetroot.onTickNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then data.initialized = false return end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		v.isProjectile = true
		v.collisionGroup = "beetroot"
		data.leeway = 0
		data.bounces = 0
		data.hittedNPC = false
		data.initialized = true
	end
	
	if v.heldIndex ~= 0 or v.forcedState > 0 then return end
	if data.leeway > 0 then data.leeway = data.leeway - 1 return end 
	
	if data.hittedNPC or (v.collidesBlockUp or v.collidesBlockBottom or v.collidesBlockLeft or v.collidesBlockRight)  then
		v.isProjectile = true
		
		data.leeway = 3
		data.bounces = data.bounces + 1

		local hittedBlock = false
		local hittedBrittle = false
		
		-- Yoinked from Basegame Wario/WarioRewrite's code lol
		for i,b in Block.iterateIntersecting(v.x - 2,v.y -4, v.x + v.width + 2, v.y + v.height + 4) do
			-- If block is visible
			if b.isHidden == false and b:mem(0x5A, FIELD_BOOL) == false then
				-- If the block can be broken
				if Block.MEGA_SMASH_MAP[b.id] then 
					-- don't break the brittle block if there's somehing inside it
					if b.contentID > 0 then 
						b:hitWithoutPlayer(false)
					else
					-- otherwise, break it
						b:remove(true)
						hittedBrittle = true
					end
					hittedBlock = true
				-- If the block CAN'T be broken
				elseif (Block.SOLID_MAP[b.id] or Block.PLAYERSOLID_MAP[b.id] or Block.MEGA_HIT_MAP[b.id]) then 
					b:hitWithoutPlayer(false)
					hittedBlock = true
				end
			end
		end
		
		if hittedBlock or data.hittedNPC or v.collidesBlockBottom then
			updateSpeed(v)
			if not data.hittedNPC and not hittedBrittle then
				SFX.play(39)
			end
			data.hittedNPC = false
			Effect.spawn(npcID - 1,v)
		end
		
		if data.bounces >= NPC.config[npcID].totalBounces then
			v:kill(9)
			Effect.spawn(npcID,v)
		end
		
	end
	
end

function beetroot.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "NPC" or c.id ~= npcID then return end
	c.data.hittedNPC = true
end

--Gotta return the library table!
return beetroot