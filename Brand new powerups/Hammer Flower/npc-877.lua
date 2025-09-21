
--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

--Create the library table
local hammer = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local hammerSettings = {
	id = npcID,

	gfxwidth=32,
	gfxheight=32,
	width=32,
	height=32,
	gfxoffsetx = 0,
	gfxoffsety = 0,
	frames = 1,
	framespeed = 4,
	luahandlesspeed = true, 
	noblockcollision = true,
	notcointransformable = true, 
	noiceball = true,
	noyoshi= true, 
	nohurt = true,
	jumphurt = true, 
	spinjumpsafe = false, 
	harmlessgrab = true, 
	harmlessthrown = true, 
	ignorethrownnpcs = false,
	nowalldeath = true, 

	--Define custom properties below
	rotateSprite = true, --enables sprite rotation
	newPhysics = true, --enables the new properties that I made
	doSparkleTrail = true,-- allows a 1.3 recreation of the sparkle train

	-- the configurations below will only work if newPhysics is set to true

	canComboNPCs = true, --does what it says
	canTearThruBlocks = true, --does what it says
	canTTBAfterHitting = false, --can the hammer Tear Through Blocks after hitting something?

	--weakest is f,f,f
	--strongest is t,t,f
	--realistic is f,f,t

}

--Applies NPC settings
npcManager.setNpcSettings(hammerSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_OFFSCREEN,
	},
	{
	}
);

--Custom local definitions below
local breakableBlocks = table.map{457,759}


--[[************************
Rotation code by MrDoubleA
**************************]]

local function drawSprite(args) -- handy function to draw sprites
	args = args or {}

	args.sourceWidth  = args.sourceWidth  or args.width
	args.sourceHeight = args.sourceHeight or args.height

	if sprite == nil then
		sprite = Sprite.box{texture = args.texture}
	else
		sprite.texture = args.texture
	end

	sprite.x,sprite.y = args.x,args.y
	sprite.width,sprite.height = args.width,args.height

	sprite.pivot = args.pivot or Sprite.align.TOPLEFT
	sprite.rotation = args.rotation or 0

	if args.texture ~= nil then
		sprite.texpivot = args.texpivot or sprite.pivot or Sprite.align.TOPLEFT
		sprite.texscale = args.texscale or vector(args.texture.width*(args.width/args.sourceWidth),args.texture.height*(args.height/args.sourceHeight))
		sprite.texposition = args.texposition or vector(-args.sourceX*(args.width/args.sourceWidth)+((sprite.texpivot[1]*sprite.width)*((sprite.texture.width/args.sourceWidth)-1)),-args.sourceY*(args.height/args.sourceHeight)+((sprite.texpivot[2]*sprite.height)*((sprite.texture.height/args.sourceHeight)-1)))
	end

	sprite:draw{priority = args.priority,color = args.color,sceneCoords = args.sceneCoords or args.scene}
end


--Register events
function hammer.onInitAPI()
	npcManager.registerEvent(npcID, hammer, "onTickEndNPC")
	npcManager.registerEvent(npcID, hammer, "onDrawNPC")
end

function hammer.onTickEndNPC(v)
	--Don't act during time freeze
	
	if Defines.levelFreeze then return end
	
	local data = v.data
	local config = NPC.config[v.id]
	
	--If despawned
	if v.despawnTimer <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.maxPower = true
		data.hammerCombo = 0
		data.rotation = 0
		data.CT = nil
		data.hasChecked = false
		data.timer = 0
		if config.framespeed ~= 4 then
			data.divisor = config.framespeed
		else
			data.divisor = 4
		end
		data.initialized = true
	end

	if config.rotateSprite then --rotation handling
		if v.speedX ~= 0 then
			v.data.rotation = v.data.rotation + v.speedX*360/(32*math.pi)
		else
			data.rotation = data.rotation + 36*v.direction
		end
	else
		v.data.rotation = 0
	end

	--Depending on the NPC, these checks must be handled differently
	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.forcedState > 0--Various forced states
	then
		data.timer = 0
		data.rotation = 0
	end

	v.isProjectile = false

	-- Put main AI below here
	if not data.hasChecked then
		if config.canTearThruBlocks == true then
			data.CT = true
		else
			data.CT = false
		end
		data.hasChecked = true
	end

	if config.doSparkleTrail then
		data.timer = data.timer + 1
	end
	if data.timer % data.divisor == 0 then --based off the 1.3 code for spawning the effects
		local e = Effect.spawn(80, v.x + (v.width / 2), v.y + (v.height / 2))
		e.speedX = RNG.random() * 1 - 0.5
		e.speedY = RNG.random() * 1 - 0.5
	end

	if config.newPhysics == false then return end -- for the insane folks who don't like the new behavior of the hammers

	v.friendly = true

	for _,npc in ipairs(Colliders.getColliding{a = v, atype = Colliders.NPC, b = NPC.HITTABLE}) do
		--Text.print("Colliding!",0,200) --debug
		if data.maxPower == true and not NPC.POWERUP_MAP[npc.id] then
			v.speedX = 2 * -(v.direction)
			v.speedY = -5
			local oldScore = NPC.config[npc.id].score--the next 3 lines are based off MrNameless's Blue Shell Combo handling
			NPC.config[npc.id].score = 2 + data.hammerCombo -- temporarily changes the npc's score config depending on the current combo
			npc:harm(-3)
			NPC.config[npc.id].score = oldScore -- immediately changes the npc's score config back to normal 
			data.hammerCombo = math.min(data.hammerCombo + 1, 10)
			if data.hammerCombo == 10 then data.hammerCombo = 8 end --Does weird Redigit score handing
			if config.canComboNPCs then
				data.maxPower = true
			else
				data.maxPower = false
			end
			if config.canTTBAfterHitting then
				data.CT = true
			end
		end
	end

	local list = Colliders.getColliding{a = v, btype = Colliders.BLOCK, filter = function(other)
		if other.isHidden or other:mem(0x5A, FIELD_BOOL) then
			return false
		end
		return true
	end}

	for _,block in ipairs(list) do
		if breakableBlocks[block.id] then
			--Text.print("Colliding!",0,200) --debug
			if block.id <= 638 then
				block:remove(true)
			else
				block:delete()
			end
			if data.CT == false then
				v.speedX = 2 * -(v.direction)
				v.speedY = -5
				if config.canTTBAfterHitting then
					data.CT = true
				end
			end
		end
	end
end


function hammer.onDrawNPC(v)
	local config = NPC.config[v.id]
	local data = v.data

	if v:mem(0x12A,FIELD_WORD) <= 0 or not data.rotation or data.rotation == 0 then return end

	drawSprite{
		texture = Graphics.sprites.npc[v.id].img,

		x = v.x+(v.width/2)+config.gfxoffsetx,y = v.y+v.height-(config.gfxheight/2)+config.gfxoffsety,
		width = config.gfxwidth,height = config.gfxheight,

		sourceX = 0,sourceY = v.animationFrame*config.gfxheight,
		sourceWidth = config.gfxwidth,sourceHeight = config.gfxheight,

		priority = -45,rotation = data.rotation,
		pivot = Sprite.align.CENTRE,sceneCoords = true,
	}

	npcutils.hideNPC(v)
end

--Gotta return the library table!
return hammer