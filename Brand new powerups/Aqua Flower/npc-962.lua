
--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local bigWaterball = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local bigWaterballSettings = {
	id = npcID,

	-- ANIMATION
	--Sprite size
	gfxwidth = 32,
	gfxheight = 32,
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

	foreground = false, -- Set to true to cause built-in rendering to render the NPC to Priority -15 rather than -45

	-- LOGIC
	--Movement speed. Only affects speedX by default.
	speed = 1,
	luahandlesspeed = false, -- If set to true, the speed config can be manually re-implemented
	nowaterphysics = true,
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
	notcointransformable = false, -- Prevents turning into coins when beating the level
	nofireball = false,
	noiceball = false,
	noyoshi= false, -- If true, Yoshi, Baby Yoshi and Chain Chomp can eat this NPC

	score = 0, -- Score granted when killed
	--  1 = 10,    2 = 100,    3 = 200,  4 = 400,  5 = 800,
	--  6 = 1000,  7 = 2000,   8 = 4000, 9 = 8000, 10 = 1up,
	-- 11 = 2up,  12 = 3up,  13+ = 5-up, 0 = 0

	--Various interactions
	jumphurt = true, --If true, spiny-like (prevents regular jump bounces)
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
	-- ishot = true,
	-- iscold = true,
	-- durability = -1, -- Durability for elemental interactions like ishot and iscold. -1 = infinite durability
	-- weight = 2,
	-- isstationary = true, -- gradually slows down the NPC
	-- nogliding = true, -- The NPC ignores gliding blocks (1f0)

	--Emits light if the Darkness feature is active:
	lightradius = 48,
	lightbrightness = 1,
	--lightoffsetx = 0,
	--lightoffsety = 0,
	lightcolor = Color.fromHex(0xB8D8F8FF),

	--Define custom properties below
	smallProjectile = npcID+1,
	SPAmount = 4
}

--Applies NPC settings
npcManager.setNpcSettings(bigWaterballSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		--HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_LAVA,
		HARM_TYPE_HELD,
		--HARM_TYPE_TAIL,
		--HARM_TYPE_SPINJUMP,
		HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		--[HARM_TYPE_JUMP]=10,
		--[HARM_TYPE_FROMBELOW]=10,
		--[HARM_TYPE_NPC]=10,
		[HARM_TYPE_PROJECTILE_USED]=npcID+1,
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		[HARM_TYPE_HELD]=npcID+1,
		--[HARM_TYPE_TAIL]=10,
		--[HARM_TYPE_SPINJUMP]=10,
		[HARM_TYPE_OFFSCREEN]=npcID+1,
		--[HARM_TYPE_SWORD]=10,
	}
);

--Custom local definitions below
local function die(v, data, config)
	v:kill(HARM_TYPE_OFFSCREEN)
	SFX.play(72)
	for i=1,config.SPAmount do
		local parts = NPC.spawn(config.smallProjectile,v.x+(v.width/2),v.y+(v.height/2),v.section, false, true)
		parts.speedX = RNG.randomInt(-7,7)
		parts.speedY = RNG.randomInt(-6,6)
	end
end


--Register events
function bigWaterball.onInitAPI()
	npcManager.registerEvent(npcID, bigWaterball, "onTickEndNPC")
	registerEvent(bigWaterball,"onPostNPCKill")
end

function bigWaterball.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	if v.despawnTimer <= 0 	  --	If despawned
	or v.forcedState > 0 then --	Various forced states
		--Reset our properties, if necessary
		v.data.initialized = false
		return
	end

	local data = v.data
	local config = NPC.config[v.id]

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		v.collisionGroup = "aquaball"
		data.animationTimer = 0
		data.initialized = true
	end
	
	if v.collidesBlockBottom then
		if v.speedX == 0 then
			die(v, data, config)
			return
		else
			v.speedY = -5
		end
	end

	for k, n in ipairs(Colliders.getColliding{a = v, b = NPC.HITTABLE, btype = Colliders.NPC}) do
		if n.id ~= npcID and n.id ~= npcID + 1 then
			die(v, data, config)
			n:harm(3)
			return
		end
	end

	if v.collidesBlockLeft or v.collidesBlockRight or v.collidesBlockUp then
		die(v, data, config)
		return
	end

	data.animationTimer = data.animationTimer + 1

	if data.animationTimer % 2 == 0  then
		local e = Effect.spawn(npcID, v.x + v.width/2, v.y + v.height/2)
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2
	end

end

function bigWaterball.onPostNPCKill(v,harm)
	if harm == HARM_TYPE_OFFSCREEN or v.despawnTimer <= 0 or v.id ~= npcID then return end
	local config = NPC.config[v.id]
	for i=1,config.SPAmount do
		local parts = NPC.spawn(config.smallProjectile,v.x+(v.width/2),v.y+(v.height/2),v.section, false, true)
		parts.speedX = RNG.randomInt(-7,7)
		parts.speedY = RNG.randomInt(-6,6)
	end
end



--Gotta return the library table!
return bigWaterball