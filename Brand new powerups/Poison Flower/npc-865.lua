local npcutils = require("npcs/npcutils")
local acceleration = 0.2

--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local sampleNPC = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local sampleNPCSettings = {
	id = npcID,

	-- ANIMATION
	--Sprite size
	gfxwidth = 48,
	gfxheight = 48,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 32,
	height = 32,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 4,
	framestyle = 0,
	framespeed = 8, -- number of ticks (in-game frames) between animation frame changes

	foreground = true, -- Set to true to cause built-in rendering to render the NPC to Priority -15 rather than -45

	-- LOGIC
	--Movement speed. Only affects speedX by default.
	speed = 4,
	luahandlesspeed = true, -- If set to true, the speed config can be manually re-implemented
	nowaterphysics = true,
	cliffturn = false, -- Makes the NPC turn on ledges
	staticdirection = false, -- If set to true, built-in logic no longer changes the NPC's direction, and the direction has to be changed manually

	--Collision-related
	npcblock = false, -- The NPC has a solid block for collision handling with other NPCs.
	npcblocktop = false, -- The NPC has a semisolid block for collision handling. Overrides npcblock's side and bottom solidity if both are set.
	playerblock = false, -- The NPC prevents players from passing through.
	playerblocktop = false, -- The player can walk on the NPC.

	nohurt=true, -- Disables the NPC dealing contact damage to the player
	nogravity = true,
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
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	nowalldeath = false, -- If true, the NPC will not die when released in a wall
	useclearpipe = true,

	linkshieldable = false,
	noshieldfireeffect = false,

	grabside=false,
	grabtop=false,

	--Identity-related flags. Apply various vanilla AI based on the flag:
	--iswalker = false,
	--isbot = false,
	--isvegetable = false,
	--isshoe = false,
	--isyoshi = false,
	--isinteractable = false,
	--iscoin = false,
	--isvine = false,
	--iscollectablegoal = false,
	--isflying = false,
	--iswaternpc = false,
	--isshell = false,
	
	-- Various interactions
	-- ishot = true,
	-- iscold = true,
	-- durability = -1, -- Durability for elemental interactions like ishot and iscold. -1 = infinite durability
	-- weight = 2,
	-- isstationary = true, -- gradually slows down the NPC
	-- nogliding = true, -- The NPC ignores gliding blocks (1f0)

	--Emits light if the Darkness feature is active:
	--lightradius = 100,
	--lightbrightness = 1,
	--lightoffsetx = 0,
	--lightoffsety = 0,
	--lightcolor = Color.white,

	--Define custom properties below
	lifetime = 512
}

--Applies NPC settings
npcManager.setNpcSettings(sampleNPCSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		--HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		--HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_LAVA,
		--HARM_TYPE_HELD,
		HARM_TYPE_TAIL,
		--HARM_TYPE_SPINJUMP,
		HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		[HARM_TYPE_JUMP]=865,
		[HARM_TYPE_FROMBELOW]=865,
		[HARM_TYPE_NPC]=865,
		[HARM_TYPE_PROJECTILE_USED]=865,
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		[HARM_TYPE_HELD]=865,
		[HARM_TYPE_TAIL]=865,
		[HARM_TYPE_SPINJUMP]=865,
		[HARM_TYPE_OFFSCREEN]=865,
		[HARM_TYPE_SWORD]=865,
	}
);

--Custom local definitions below

--Register events
function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
	--npcManager.registerEvent(npcID, sampleNPC, "onTickEndNPC")
	--npcManager.registerEvent(npcID, sampleNPC, "onDrawNPC")
	--registerEvent(sampleNPC, "onNPCKill")
end

function sampleNPC.onTickNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.initialized = true
		--v.isProjectile = true
		--v.collisionGroup = "beetroot"
		data.timer = 0
		data.killCount = 0
	end

	--Depending on the NPC, these checks must be handled differently
	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then
		-- Handling of those special states. Most NPCs want to not execute their main code when held/coming out of a block/etc.
		-- If that applies to your NPC, simply return here.
		-- return
	end
	
	data.timer = data.timer + 1
	if data.timer >= NPC.config[v.id].lifetime then
		v:kill(9)
	end
	
	v.speedX = v.speedX * 0.97
	v.speedY = v.speedY * 0.97
	
	local n = npcutils.getNearestPlayer(v)
	local distance = vector(
		n.x + n.width/2 - v.x - v.width/2 + (48 * n.direction),
		n.y + n.height/2 - v.y - v.height/2 
	)
	
	if player.keys.down then
		distance = vector(
			n.x + n.width/2 - v.x - v.width/2 + (48 * n.direction),
			n.y + n.height/2 - v.y - v.height/2 + 128
		)
	elseif player.keys.up then
		distance = vector(
			n.x + n.width/2 - v.x - v.width/2 + (48 * n.direction),
			n.y + n.height/2 - v.y - v.height/2 - 128
		)
	end

	v.speedX = v.speedX + acceleration * math.sign(distance.x)
	v.speedY = v.speedY + acceleration * math.sign(distance.y)
	
	for _,n in ipairs(NPC.getIntersecting(v.x + v.speedX - 4, v.y + v.speedY, v.x + v.width + v.speedX + 4, v.y + v.height + v.speedY)) do
		if n:mem(0x12A, FIELD_WORD) > 0 and n:mem(0x138, FIELD_WORD) == 0 and v:mem(0x138, FIELD_WORD) == 0 and (not pnisHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 and n.idx ~= v.idx and v:mem(0x12C, FIELD_WORD) == 0 and NPC.HITTABLE_MAP[n.id] then
			if n.id ~= v.id then
				n:harm(3, 2)
				data.killCount = data.killCount + 1
			end
		end
	end
	for _,n in ipairs(NPC.getIntersecting(v.x + v.speedX - 4, v.y + v.speedY, v.x + v.width + v.speedX + 4, v.y + v.height + v.speedY)) do
		if NPC.COIN_MAP[n.id] or NPC.POWERUP_MAP[n.id] or n.id == 310 then
			n:collect(p)
		end
	end
	if data.killCount >= 1 then
		v:kill(9)
	end
end

--Gotta return the library table!
return sampleNPC