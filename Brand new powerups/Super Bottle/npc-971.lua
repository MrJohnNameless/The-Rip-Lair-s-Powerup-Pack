--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
--Create the library table
local pill = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local pillSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 14,
	gfxwidth = 8,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 8,
	height = 14,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 3,
	framestyle = 0,
	framespeed = 4, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 2,
	luahandlesspeed = true,
	--Collision-related
	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.
	powerup = false,
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,
	--Various interactions
	jumphurt = true, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	useclearpipe = true,
}

--Applies NPC settings
npcManager.setNpcSettings(pillSettings)


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
		HARM_TYPE_OFFSCREEN,
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

local pillHitbox = Colliders.Box(0, 0, 0, 0)

--Register events
function pill.onInitAPI()
	npcManager.registerEvent(npcID, pill, "onTickEndNPC")
	npcManager.registerEvent(npcID, pill, "onDrawNPC")
end

local function explode(v)
	for k,n in ipairs(Colliders.getColliding{
		a = pillHitbox,
		b = NPC.HITTABLE,
		btype = Colliders.NPC,
		filter = function(w)
			if (not w.isHidden) and w:mem(0x64, FIELD_BOOL) == false and w:mem(0x12A, FIELD_WORD) > 0 and w:mem(0x138, FIELD_WORD) == 0 and w:mem(0x12C, FIELD_WORD) == 0 then
				return true
			end
			return false
		end
	}) do
	
		if v.ai1 == 0 then n:harm(HARM_TYPE_EXT_FIRE) SFX.play(3) Effect.spawn(13, v.x, v.y)
		elseif v.ai1 == 1 then n:harm(HARM_TYPE_EXT_ICE) SFX.play(3)
		elseif v.ai1 == 2 then Explosion.spawn(v.x + v.width/2, v.y + v.height/2, 3) end
		
		v:kill(9)
		SFX.play("powerups/pillhit.ogg")
		return
	end
end

function pill.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	local data = v.data
	
	pillHitbox.width = v.width + 4
	pillHitbox.height = v.height + 4
	pillHitbox.x = (v.x + v.width*0.5) - (pillHitbox.width*0.5)
	pillHitbox.y = (v.y + v.height*0.5) - (pillHitbox.height*0.5)
	

	explode(v)

	--If despawned
	if v:mem(0x12A, FIELD_WORD) <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		data.initialized = true
		v.ai1 = RNG.randomInt(0,2)
	end
	
	v.animationFrame = v.ai1
	if v.collidesBlockBottom then v.speedY = -6 end
	data.rotation = (data.rotation or 0) + 6 * v.direction
end

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

function pill.onDrawNPC(v)
	local config = NPC.config[v.id]
	local data = v.data

	if v:mem(0x12A,FIELD_WORD) <= 0 then return end

	local priority = -45
	if config.priority then
		priority = -15
	end

	drawSprite{
		texture = Graphics.sprites.npc[v.id].img,

		x = v.x+(v.width/2)+config.gfxoffsetx,y = v.y+v.height-(config.gfxheight/2)+config.gfxoffsety,
		width = config.gfxwidth,height = config.gfxheight,

		sourceX = 0,sourceY = v.animationFrame*config.gfxheight,
		sourceWidth = config.gfxwidth,sourceHeight = config.gfxheight,

		priority = priority,rotation = data.rotation,
		pivot = Sprite.align.CENTRE,sceneCoords = true,
	}

	npcutils.hideNPC(v)
end

--Gotta return the library table!
return pill