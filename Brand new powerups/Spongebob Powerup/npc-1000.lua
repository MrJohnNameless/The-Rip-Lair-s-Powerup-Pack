
--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local bubble = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local bubbleSettings = {
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
	frames = 2,
	framestyle = 0,
	framespeed = 12, -- number of ticks (in-game frames) between animation frame changes

	foreground = false, -- Set to true to cause built-in rendering to render the NPC to Priority -15 rather than -45

	-- LOGIC
	--Movement speed. Only affects speedX by default.
	speed = 1.5,
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
	nogravity = true,
	noblockcollision = true,
	notcointransformable = false, -- Prevents turning into coins when beating the level
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
	nowalldeath = false, -- If true, the NPC will not die when released in a wall

	linkshieldable = false,
	noshieldfireeffect = false,

	grabside=false,
	grabtop=false,
	bubbleFlowerImmunity = true,

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
	nogliding = true, -- The NPC ignores gliding blocks (1f0)

	--Emits light if the Darkness feature is active:
	--lightradius = 100,
	--lightbrightness = 1,
	--lightoffsetx = 0,
	--lightoffsety = 0,
	--lightcolor = Color.white,

	--Define custom properties below
}

--Applies NPC settings
npcManager.setNpcSettings(bubbleSettings)

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

--Register events
function bubble.onInitAPI()
	--npcManager.registerEvent(npcID, bubble, "onTickNPC")
	npcManager.registerEvent(npcID, bubble, "onTickEndNPC")
	npcManager.registerEvent(npcID, bubble, "onDrawNPC")
	--registerEvent(bubble, "onNPCKill")
	Misc.groupsCollide["bubble"][""] = false
end

function bubble.onTickEndNPC(v)
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
		v.collisionGroup = "bubble"
		data.sinTimer = 0
		
		data.frame = 1
		data.frameTimer = 0

		data.lifetime = 0
		data.hitCooldown = 0
		data.scale = data.scale or 1
		
		data.sprite = Sprite{
			texture = Graphics.sprites.npc[npcID].img,	--Graphics.loadImageResolved("npc-"..npcID..".png"),
			frames = 2,
			x = v.x + v.width * 0.5,
			y = v.y + v.height * 0.5,
			pivot = Sprite.align.CENTER,
		}
		
		data.hitsLeft = math.ceil(data.scale * 1.5)
		data.collider = Colliders.Circle(v.x,v.y,data.scale * 15)
		data.initialized = true
	end

	data.frameTimer = data.frameTimer + 1
	if data.frameTimer >= NPC.config[npcID].framespeed then
		data.frame = data.frame + 1
		if data.frame > NPC.config[npcID].frames then
			data.frame = 1
		end
		data.frameTimer = 0
	end
	
	local bubbleX = v.x + v.width * 0.5
	local bubbleY = v.y + v.height * 0.5
	data.sprite.x = bubbleX
	data.sprite.y = bubbleY
	data.collider.x = bubbleX
	data.collider.y = bubbleY
	--data.collider:Draw(Color.red .. 0.5)
	
	--Depending on the NPC, these checks must be handled differently
	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.isProjectile   --Thrown
	or v.forcedState > 0--Various forced states
	then
		return
	end
	--Text.print(data.hitsLeft,100,100)
	--Text.print(data.scale,100,100)

	-- Put main AI below here
	data.sinTimer = data.sinTimer + 1
	data.hitCooldown = math.max(data.hitCooldown - 1,0)
	v.speedY = math.sin(-data.sinTimer * 0.1) -- stole this from deltom lol

	for i,n in ipairs(Colliders.getColliding{
		a = data.collider,
		b = NPC.HITTABLE, 
		btype = Colliders.NPC,
		filter = function(o) return (
				 data.hitCooldown <= 0
				 and not o.isHidden 
				 and o.despawnTimer > 0
				 and o.id ~= npcID --Block.SLOPE_MAP[o.id]
				 ) end
		}) do
		n:harm(3)
		data.hitCooldown = 5
		data.hitsLeft = data.hitsLeft - 1
		if data.hitsLeft <= 0 then
			v:kill(9)
			SFX.play(91)
			for i = 1,math.ceil(data.scale * 1.5),1 do
				local radius = data.collider.radius * 0.5
				Effect.spawn(75,(v.x + v.width*0.5) + RNG.randomInt(-radius,radius),(v.y + v.height*0.5) + RNG.randomInt(-radius,radius))
			end
			break
		end
	end
	
	
end

function bubble.onDrawNPC(v)
	if v.despawnTimer <= 0 or not v.data.initialized then return end
	local data = v.data
	data.sprite.scale = vector(data.scale,data.scale)
	
	v.animationFrame = -999

	local priority = -45 
	if NPC.config[npcID].foreground then
		priority = -15
	end
	data.sprite:draw{
		sceneCoords = true,
		frame = data.frame,
		priority = priority - 0.01,
	}
end

--Gotta return the library table!
return bubble