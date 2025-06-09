--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local particles = require('particles')
local folderpath = "AI/plasma shell/"
--local plasmatrail = particles.Emitter(0,0,Misc.resolveFile('particles-plasmaShell.ini'))
local explosions = Particles.Emitter(0, 0, Misc.resolveFile("particles-shinyExplosion.ini"))

--Create the library table
local sampleNPC = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID


-- This npc is adapted from Emral's Gold Fireball from anotherpowerup.lua. Am too lazy to rework it to be completely original

--Defines NPC config for our NPC. You can remove superfluous definitions.
local sampleNPCSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 32,
	gfxwidth = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 32,
	height = 32,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 4,
	framestyle = 0,
	framespeed = 4, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1.3,
	--Collision-related
	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.
	powerup = false,
	projectile = true,
	nohurt= true,
	nogravity = false,
	noblockcollision = false,
	nofireball = false,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,
	--Various interactions
	jumphurt = false, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	useclearpipe = true,
	
	score = 0,
	thrownspeed = 8,
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
	isshell = false,
	isfireball = true,

	--Emits light if the Darkness feature is active:
	lightradius = 100,
	lightbrightness = 0.5,
	lightoffsetx = 0,
	lightoffsety = 0,
	lightcolor = ffffff,

	--Define custom properties below
}

--Applies NPC settings
npcManager.setNpcSettings(sampleNPCSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_JUMP,
		--HARM_TYPE_FROMBELOW,
		HARM_TYPE_NPC,
		HARM_TYPE_PROJECTILE_USED,
		HARM_TYPE_LAVA,
		HARM_TYPE_HELD,
		--HARM_TYPE_TAIL,
		--HARM_TYPE_SPINJUMP,
		HARM_TYPE_OFFSCREEN,
		--HARM_TYPE_SWORD
	}, 
	{
		[HARM_TYPE_JUMP]=78,
		--[HARM_TYPE_FROMBELOW]=78,
		[HARM_TYPE_NPC]=78,
		[HARM_TYPE_PROJECTILE_USED]=78,
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		[HARM_TYPE_HELD]=78,
		--[HARM_TYPE_TAIL]=78,
		--[HARM_TYPE_SPINJUMP]=78,
		[HARM_TYPE_OFFSCREEN]=78,
		--[HARM_TYPE_SWORD]=78,
	}
);

--Custom local definitions below


--Register events
function sampleNPC.onInitAPI()
	npcManager.registerEvent(npcID, sampleNPC, "onTickNPC")
	--npcManager.registerEvent(npcID, sampleNPC, "onTickEndNPC")
	npcManager.registerEvent(npcID, sampleNPC, "onDrawNPC")
	registerEvent(sampleNPC, "onPostNPCKill")
	registerEvent(sampleNPC, "onDraw")
	
end


local function explode(v)
	v:kill(9)
	explosions.x = v.x + v.width * 0.5
	explosions.y = v.y + v.height * 0.5
	explosions:Emit(1)
	SFX.play(folderpath .. "explode.ogg")
	local circ = Colliders.Circle(v.x + 0.5 * v.width, v.y + 0.5 * v.height, 64)
	-- harm npcs that are in it's path
	for k,n in ipairs(Colliders.getColliding{atype = Colliders.NPC,b = circ, filter = function(o) 
			if NPC.HITTABLE_MAP[o.id] and not o.friendly and not o.isHidden then return true end end }) do
		n:harm(3)
	end
	
	-- hit blocks that can't be broken
	for k,n in ipairs(Colliders.getColliding{
		atype = Colliders.BLOCK,
		b = circ,
		filter = function(o)
			if not o.isHidden then
				return true
			end
		end
	}) do
		n:hit(2)
	end
	
	-- destroy blocks that can be broken (and don't contain something)
	for k,n in ipairs(Colliders.getColliding{
		atype = Colliders.BLOCK,
		b = circ,
		filter = function(o)
			if Block.MEGA_SMASH_MAP[o.id] and not o.isHidden and o.contentID == 0 then
				return true
			end
		end
	}) do
		n:remove(3)
		
	end
end

function sampleNPC.onHarm(harmEvent)
    if( (harmEvent.reason_code ~= BaseNPC.DAMAGE_LAVABURN) and (harmEvent.reason_code ~= BaseNPC.DAMAGE_BY_KICK) )then
        harmEvent.cancel=true
        harmEvent.damage=0
        if (harmEvent.killed_by == NpcHarmEvent.player) then
            self.npc_obj.direction = harmEvent.killer_p.direction
			explode(v)
        end
    end
end

function sampleNPC.onPostNPCKill(v, rsn)
	if v.id == npcID and rsn ~= 9 then
		explode(v)
	end
end

function sampleNPC.onTickNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	
	local data = v.data
	
	--If despawned
	if v:mem(0x12A, FIELD_WORD) <= 0 then
		--Reset our properties, if necessary
		data.plasmatrail:Destroy()
		data.initialized = false
		return
	end
	

	--Initialize
	if not data.initialized then
		-- initiate necessary data
		data.priority = -44
		data.plasmatrail = particles.Emitter(0,0,Misc.resolveFile('particles-plasmaShell.ini'))
		
		if v.ai1 == 1 then		-- assigns colours to the different playable characters. v.ai1 is set to the player id when thrown
			data.colour = Color(1,0.1,0.1) -- red
		elseif v.ai1 == 2 then
  		   data.colour = Color.green
		elseif v.ai1 == 3 then
  		   data.colour = Color(1, 0.1 ,0.5)
		elseif v.ai1 == 4 then
  		   data.colour = Color(0.2,0.2,1)
		else
 		   data.colour = Color.white	-- default colour is white
		end
		data.plasmatrail:setParam("col",data.colour .. 0.4)
		
		if v.lightSource then
			v.lightSource.colour = data.colour
		end
		
		data.plasmatrail:Attach(v)			--now it attaches the plasmatrail to the plasmashell
		data.initialized = true
	end

	-- Handle priority
	data.priority = -44
	if v:mem(0x12C, FIELD_WORD) > 0 then	-- if grabbed
		v.animationTimer = 0
		v.animationFrame = 0
		if player.character == CHARACTER_TOAD or player.character == CHARACTER_PEACH then
			data.priority = -14
		else
			data.priority = -29
		end
	end


	v:mem(0x136, FIELD_BOOL, true)	-- always be in projectile mode
	v:mem(0x120, FIELD_BOOL, false)	-- do not turn around grrr
	
	data.speedX = data.speedX or v.speedX
	if not v.collidesBlockBottom then
		v.speedY = v.speedY + (Defines.player_grav - Defines.npc_grav)	-- gives the shells the player's gravity
	end
	
	if v.collidesBlockLeft or v.collidesBlockRight or v.collidesBlockUp or (v.speedX == 0 and v.collidesBlockBottom) then
		-- explode when colliding with a wall or having no speed (while on ground and not held)
		explode(v)
	end

	for k,n in ipairs(Colliders.getColliding{atype = Colliders.NPC, b = v, filter = function(o) if NPC.HITTABLE_MAP[o.id] and not o.friendly and not o.isHidden then return true end end}) do
		-- when colliding with an npc, explode
		explode(v)
	end
end

function sampleNPC.onDraw()
	explosions:Draw(-5)
end

function sampleNPC.onDrawNPC(v)		-- handle particles
	if v.isHidden or not v.data.colour or not v.isValid then return end
	local data = v.data
	--plasmatrail:Draw(-80)
	
	if data.plasmatrail then
	  data.plasmatrail:Draw(-80)
	end
	
	local sprite = Graphics.loadImageResolved(folderpath .. "shellOverlay.png")

	Graphics.drawBox{			-- draw the overlay of the shell, coloured depending on the player!
		texture      = sprite,
		sceneCoords  = true,
		x            = v.x,
		y            = v.y,
		width        = v.width,
		height       = v.height,
		sourceX      = 0,
		sourceY      = v.animationFrame * 32,
		sourceWidth  = v.width,
		sourceHeight = v.height,
		centered     = false,
		priority     = data.priority,
		color        = data.colour .. 1,--playerOpacity,
		rotation     = 0,
	}
end
--Gotta return the library table!
return sampleNPC