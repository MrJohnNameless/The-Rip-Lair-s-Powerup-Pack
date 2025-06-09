--[[
	This template can be used to make your own custom NPCs!
	Copy it over into your level or episode folder and rename it to use an ID between 751 and 1000. For example: npc-751.lua
	Please pay attention to the comments (lines with --) when making changes. They contain useful information!
	Refer to the end of onTickNPC to see how to stop the NPC talking to you.
]]


--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local astroSuit = require("powerups/astroSuit")
--Create the library table
local laser = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local laserSettings = {
	id = npcID,

	-- ANIMATION
	--Sprite size
	gfxwidth = 16,
	gfxheight = 8,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 16,
	height = 8,
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
	speed = 1,
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
	noblockcollision = true,
	notcointransformable = true, -- Prevents turning into coins when beating the level
	nofireball = true,
	noiceball = true,
	noyoshi= true, -- If true, Yoshi, Baby Yoshi and Chain Chomp can eat this NPC

	score = 1, -- Score granted when killed
	--  1 = 10,    2 = 100,    3 = 200,  4 = 400,  5 = 800,
	--  6 = 1000,  7 = 2000,   8 = 4000, 9 = 8000, 10 = 1up,
	-- 11 = 2up,  12 = 3up,  13+ = 5-up, 0 = 0

	--Various interactions
	jumphurt = false, --If true, spiny-like (prevents regular jump bounces)
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping and causes a bounce
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	nowalldeath = true, -- If true, the NPC will not die when released in a wall

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
	ishot = true,
	-- iscold = true,
	durability = 1, -- Durability for elemental interactions like ishot and iscold. -1 = infinite durability
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
}

--Applies NPC settings
npcManager.setNpcSettings(laserSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		--HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		HARM_TYPE_PROJECTILE_USED,
		--HARM_TYPE_LAVA,
		--HARM_TYPE_HELD,
		--HARM_TYPE_TAIL,
		--HARM_TYPE_SPINJUMP,
		--HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		--[HARM_TYPE_JUMP]=10,
		--[HARM_TYPE_FROMBELOW]=10,
		--[HARM_TYPE_NPC]=10,
		[HARM_TYPE_PROJECTILE_USED]=10,
		--[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_HELD]=10,
		--[HARM_TYPE_TAIL]=10,
		--[HARM_TYPE_SPINJUMP]=10,
		--[HARM_TYPE_OFFSCREEN]=10,
		--[HARM_TYPE_SWORD]=10,
	}
);

--Custom local definitions below


--Register events
function laser.onInitAPI()
	npcManager.registerEvent(npcID, laser, "onTickEndNPC")
	Misc.groupsCollide["lasers"][""] = false
	Misc.groupsCollide["lasers"]["lasers"] = false
end

function laser.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		v:kill(9)
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		v.collisionGroup = "lasers"
		data.variant = data.variant or 0
		data.totalLife = data.totalLife or 40
		data.lifetime = 0
		data.initialized = true
	end
	
	if data.variant then
		v.animationFrame = math.max(data.variant - 1, 0)
	else
		v.animationFrame = 0
	end
	
	--Depending on the NPC, these checks must be handled differently
	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then
		return
	end

	if data.totalLife ~= -1 and data.lifetime >= data.totalLife then
		v:kill(9)
		local e = Effect.spawn(10,v)
		e.x = (v.x + v.width*0.5) - e.width*0.5
		e.y = (v.y + v.height*0.5) - e.width*0.5
		return
	else
		v.despawnTimer = data.totalLife
	end
	data.lifetime = math.min(data.lifetime + 1, data.totalLife)
	
	for i,n in NPC.iterateIntersecting(v.x,v.y-2,v.x+v.width,v.y+v.height+2) do
		if (not n.friendly) and n.despawnTimer > 0 
		and (not n.isGenerator) and n.heldIndex == 0 
		and NPC.HITTABLE_MAP[n.id] and n.id ~= v.id then
			if NPC.config[n.id].nofireball then
				n:harm(3)
				SFX.play(3)
			else
				n:harm(astroSuit.settings.projectileHarmType)
			end
			n:mem(0x156,FIELD_WORD,5)
			v:kill(4)
		end
	end
	

	
	if lunatime.tick() % 3 ~= 0 then return end
	local e = Effect.spawn(80,v)
	e.x = e.x + RNG.randomInt(-8,8)
	e.y = e.y + RNG.randomInt(-4,4)
end

--Gotta return the library table!
return laser