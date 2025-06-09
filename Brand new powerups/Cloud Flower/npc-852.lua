--[[
	This template can be used to make your own custom NPCs!
	Copy it over into your level or episode folder and rename it to use an ID between 751 and 1000. For example: npc-751.lua
	Please pay attention to the comments (lines with --) when making changes. They contain useful information!
	Refer to the end of onTickNPC to see how to stop the NPC talking to you.
]]


--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local cloudFlower = require("powerups/cloudFlower")
--Create the library table
local cloud = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID


--Defines NPC config for our NPC. You can remove superfluous definitions.
local cloudSettings = {
	id = npcID,

	-- ANIMATION
	--Sprite size
	gfxwidth = 96,
	gfxheight = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 96,
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
	luahandlesspeed = true, -- If set to true, the speed config can be manually re-implemented
	nowaterphysics = true,
	cliffturn = false, -- Makes the NPC turn on ledges
	staticdirection = true, -- If set to true, built-in logic no longer changes the NPC's direction, and the direction has to be changed manually

	--Collision-related
	npcblock = false, -- The NPC has a solid block for collision handling with other NPCs.
	npcblocktop = true, -- The NPC has a semisolid block for collision handling. Overrides npcblock's side and bottom solidity if both are set.
	playerblock = false, -- The NPC prevents players from passing through.
	playerblocktop = true, -- The player can walk on the NPC.

	nohurt=true, -- Disables the NPC dealing contact damage to the player
	nogravity = true,
	noblockcollision = true,
	notcointransformable = false, -- Prevents turning into coins when beating the level
	nofireball = true,
	noiceball = true,
	noyoshi= false, -- If true, Yoshi, Baby Yoshi and Chain Chomp can eat this NPC

	score = 0, -- Score granted when killed
	--  1 = 10,    2 = 100,    3 = 200,  4 = 400,  5 = 800,
	--  6 = 1000,  7 = 2000,   8 = 4000, 9 = 8000, 10 = 1up,
	-- 11 = 2up,  12 = 3up,  13+ = 5-up, 0 = 0

	--Various interactions
	jumphurt = false, --If true, spiny-like (prevents regular jump bounces)
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping and causes a bounce
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = true, --Thrown NPC hurts other NPCs if false
	nowalldeath = true, -- If true, the NPC will not die when released in a wall

	linkshieldable = false,
	noshieldfireeffect = false,

	grabside=false,
	grabtop=false,

	--Define custom properties below
	lifetime = 325, -- 325 frames (5 seconds) by default
}

--Applies NPC settings
npcManager.setNpcSettings(cloudSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		--HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		--HARM_TYPE_NPC,
		--HARM_TYPE_PROJECTILE_USED,
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
		--[HARM_TYPE_PROJECTILE_USED]=10,
		--[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_HELD]=10,
		--[HARM_TYPE_TAIL]=10,
		--[HARM_TYPE_SPINJUMP]=10,
		--[HARM_TYPE_OFFSCREEN]=10,
		--[HARM_TYPE_SWORD]=10,
	}
);

--Custom local definitions below

--Graphics.sprites.block[blockID].img = Graphics.loadImageResolved("stock-0.png")



--Register events
function cloud.onInitAPI()
	registerEvent(cloud, "onStart")
	npcManager.registerEvent(npcID, cloud, "onTickNPC")
	--npcManager.registerEvent(npcID, cloud, "onTickEndNPC")
	npcManager.registerEvent(npcID, cloud, "onDrawNPC")
	--registerEvent(cloud, "onNPCKill")
end

function cloud.onStart()
	Graphics.sprites.npc[npcID].img = Graphics.loadImageResolved("stock-0.png")
end



function cloud.onTickNPC(v)
	--Don't act during time freeze
	
	if Defines.levelFreeze then return end
	
	--v.speedY = v.speedY -Defines.npc_grav
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.sprite = Sprite{
			texture = Graphics.loadImageResolved("npc-"..npcID..".png"),
			x = v.x + v.width * 0.5,
			y = v.y + v.height * 0.5,
			pivot = Sprite.align.CENTER,
			texpivot = Sprite.align.CENTER
		}
		data.lifetime = 0
		data.scale = 0

		data.initialized = true
	end
	-- Put main AI below here
	data.lifetime = math.min(data.lifetime + 1, NPC.config[npcID].lifetime)
	
	for i,n in NPC.iterate(cloudFlower.settings.katesWindID) do -- for KateBulka's wind NPC
		if n.despawnTimer > 100 then	
			v.speedX = math.min(math.abs(v.speedX) + 0.1, 3) * n.direction
		end
		break
	end
	
	
	if data.lifetime <= 8 then
		data.scale = math.lerp(data.scale, 1.15, 0.5)
	elseif data.lifetime > 8 and data.lifetime < 32 then
		data.scale = math.lerp(data.scale, 1, 0.1)
	elseif data.lifetime >= 32 and data.lifetime < NPC.config[npcID].lifetime - 8 then
		data.scale = 1
	elseif data.lifetime >= NPC.config[npcID].lifetime - 8 and data.lifetime < NPC.config[npcID].lifetime then
		data.scale = math.lerp(data.scale, 0, 0.1)
		v.width = math.max(v.width - 1,0)
		--v.x = v.x + 0.5
		--v.y = v.y + 0.1
	else
		v:kill(9)
		Effect.spawn(131,v.x + v.width * 0.25,v.y)
		SFX.play(82)
	end
	

	data.sprite.x = v.x + v.width * 0.5
	data.sprite.y = v.y + v.height * 0.5
	
	
end

function cloud.onDrawNPC(v)
	if v.despawnTimer <= 0 or not v.data.initialized then return end
	local data = v.data
	data.sprite.scale = vector(data.scale,data.scale)
	
	v.animationFrame = -999
	if data.lifetime >= NPC.config[npcID].lifetime - 65 and data.lifetime % 3 == 0 then return end
	
	data.sprite:draw{
		sceneCoords = true,
		priority = -45,
	}
end

--Gotta return the library table!
return cloud