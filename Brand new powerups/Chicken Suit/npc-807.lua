
--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local egg = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

Explosion.register(
	--ID of the explosion to be
	npcID, 
	--Radius
	40, 
	--Effect to display
	133, 
	--Sound effect
	22,
	--Is strong
	true,
	--Is friendly
	true
)

--Defines NPC config for our NPC. You can remove superfluous definitions.
local eggSettings = {
	id = npcID,
	-- ANIMATION
	--Sprite size
	gfxwidth = 18,
	gfxheight = 20,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 24,
	height = 24,
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
	speed = 2.5,
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
	
	totalBounces = 2,
	bounceSFX = Misc.resolveSoundFile("sound/extended/bowlingball.ogg"),
}

--Applies NPC settings
npcManager.setNpcSettings(eggSettings)

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
	v.speedY = -6
	v.direction = v.direction * -1
	v.speedX = NPC.config[v.id].speed * v.direction 
end

local function kablooey(v)
	v:kill(9)
	local boom = Explosion.spawn(v.x + 0.5 * v.width, v.y + 0.5 * v.height, npcID)
	Effect.spawn(npcID,boom.x,boom.y)
end

--Register events
function egg.onInitAPI()
	npcManager.registerEvent(npcID, egg, "onTickNPC")
	npcManager.registerEvent(npcID, egg, "onDrawNPC")
	registerEvent(egg, "onNPCHarm")
end

function egg.onTickNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v.despawnTimer <= 0 then data.initialized = false return end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		v.isProjectile = true
		data.leeway = 0
		data.bounces = data.bounces or NPC.config[npcID].totalBounces
		data.rotation = 0
		data.hittedNPC = false
		data.initialized = true
	end
	
	local speed = v.speedX
	if speed == 0 then
		speed = v.speedY * v.direction
	end
	
	if v.forcedState == 0 and v.heldIndex == 0 then
		data.rotation = data.rotation + speed*360/(32*math.pi)
	end
	
	if v.heldIndex ~= 0 or v.forcedState > 0 then return end
	if data.leeway > 0 then data.leeway = data.leeway - 1 return end 
	
	-- hitting the ceiling or a wall
	if v.collidesBlockUp or v.collidesBlockLeft or v.collidesBlockRight then
		kablooey(v)
		return
	end
	
	-- hitting the floor
	if data.hittedNPC or (v.collidesBlockBottom) then
		v.isProjectile = true
		
		data.leeway = 3
		data.bounces = data.bounces - 1

		local hittedBlock = false
		local hittedBrittle = false
	
		-- Yoinked from Basegame Wario/WarioRewrite's code lol
		for i,b in Block.iterateIntersecting(v.x - 2,v.y -4, v.x + v.width + 2, v.y + v.height + 4) do
			-- If block is visible
			if b.isHidden == false and b:mem(0x5A, FIELD_BOOL) == false then
				if (Block.MEGA_SMASH_MAP[b.id] or Block.SOLID_MAP[b.id] or Block.PLAYER_MAP[b.id] or Block.MEGA_HIT_MAP[b.id]) 
				or (Block.SEMISOLID_MAP[b.id] and v.y+v.height-2 <= b.y) then 
					b:hitWithoutPlayer(false)
					hittedBlock = true
				end
			end
		end
		
		if data.bounces <= 0 then
			kablooey(v)
			return
		end
		
		if hittedBlock then
			updateSpeed(v)
			if not data.hittedNPC and not hittedBrittle then
				SFX.play(NPC.config[npcID].bounceSFX)
			end
			data.hittedNPC = false
		end
	end
end

function egg.onDrawNPC(v)
	if v.despawnTimer <= 0 or not v.data.initialized then return end
	if Misc.isPaused() then v.animationFrame = 0 return end
	local data = v.data
	local config = NPC.config[v.id]
    local img = Graphics.sprites.npc[v.id].img

    Graphics.drawBox{
        texture = img,
        x = v.x + v.width/2,
        y = v.y + v.height/2,
		width = config.gfxwidth,
		height = config.gfxheight,
        sourceY = v.animationFrame * config.gfxheight,
        sourceHeight = config.gfxheight,
        sourceWidth = config.gfxwidth,
        sceneCoords = true,
        centered = true,
        priority = -45,
        rotation = data.rotation,
    }
	
	v.animationFrame = -999
	v.animationTimer = 0
end


function egg.onNPCHarm(token,v,harm,c)
	if not c or type(c) ~= "NPC" or c.id ~= npcID then return end
	if v.id == npcID or v.despawnTimer <= 0 then return end
	Routine.run(function()
		Routine.skip()
		kablooey(c)
	end)
end

--Gotta return the library table!
return egg