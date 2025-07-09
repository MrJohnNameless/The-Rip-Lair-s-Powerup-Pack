--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local randomizer = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local randomizerSettings = {
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
	frames = 1,
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
	nogravity = true,
	noblockcollision = true,
	notcointransformable = true, -- Prevents turning into coins when beating the level
	nofireball = true,
	noiceball = true,
	noyoshi= true, -- If true, Yoshi, Baby Yoshi and Chain Chomp can eat this NPC
	score = 0, -- Score granted when killed
	jumphurt = true, --If true, spiny-like (prevents regular jump bounces)
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = true, --Thrown NPC hurts other NPCs if false
	nowalldeath = true, -- If true, the NPC will not die when released in a wall
}

--Applies NPC settings
npcManager.setNpcSettings(randomizerSettings)

--Custom local definitions below
local invalidNPCs = table.map{90,182,183,184,185,186,187,249,250,273,277,287,293,425,462,538,559}

local function getRandomID()
	local id = RNG.randomEntry(NPC.POWERUP)
	while invalidNPCs[id] do
		id = RNG.randomEntry(NPC.POWERUP)
	end
	return id
end

--Register events
function randomizer.onInitAPI()
	npcManager.registerEvent(npcID, randomizer, "onTickNPC")
	registerEvent(randomizer,"onTick")
	registerEvent(randomizer, "onBlockHit")
end

function randomizer.onTickNPC(v)
	--Don't act during time freeze
	v.animationFrame = 0
	v.animationTimer = 0
	--if Defines.levelFreeze then return end
	if v.despawnTimer <= 0 or v.id ~= npcID then
		return
	end
	
	if v.id == npcID then
		v:transform(getRandomID(),false)
	end
end

-- handles transforming bubbles to a powerup
function randomizer.onTick()
	for _,bubble in NPC.iterate(283) do
		if bubble.despawnTimer > 0 and bubble.ai1 == npcID then
			bubble.ai1 = getRandomID()
		end
	end
end

function randomizer.onBlockHit(token,v,upper,p)
	if v.contentID - 1000 ~= npcID then return end
	v.contentID = getRandomID() + 1000
end

--Gotta return the library table!
return randomizer