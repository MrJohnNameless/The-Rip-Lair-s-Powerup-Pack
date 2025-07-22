--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
--Create the library table
local bomb = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local bombSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 22,
	gfxwidth = 16,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 16,
	height = 16,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 4,
	framestyle = 0,
	framespeed = 4, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1,
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
	ignorethrownnpcs = true,
	nofireball = true,
	noiceball = true,
	noyoshi= true,
	nowaterphysics = true,
	--Various interactions
	jumphurt = true, --If true, spiny-like
	spinjumpsafe = false, --If true, prevents player hurt when spinjumping
	harmlessgrab = false, --Held NPC hurts other NPCs if false
	harmlessthrown = false, --Thrown NPC hurts other NPCs if false
	useclearpipe = true,
	
	explodeTime = 256,
	normalAnimation = {0,1},
	alertAnimation = {0,3,2,1},
	allowAlert = true,
}

--Applies NPC settings
npcManager.setNpcSettings(bombSettings)

--Register events
function bomb.onInitAPI()
	npcManager.registerEvent(npcID, bomb, "onTickEndNPC")
end

function bomb.onTickEndNPC(v)
	--Don't act during time freeze
	if Defines.levelFreeze then return end
	local data = v.data

	--If despawned
	if v:mem(0x12A, FIELD_WORD) <= 0 then
		--Reset our properties, if necessary
		data.initialized = false
		return
	end

	local config = NPC.config[npcID]

	--Initialize
	if not data.initialized then
		--Initialize necessary data.
		v.ai1 = 0
		data.animation = config.normalAnimation
		data.initialized = true
	end
	
	if v.collidesBlockBottom then
		v.speedX = 0
	end
	
	if v.ai1 > 1 then
		if v.collidesBlockLeft or v.collidesBlockRight then
			v.speedX = v.speedX / 5
		end
	end
	
	v.ai1 = v.ai1 + 1
	if v.ai1 >= config.explodeTime then
		Explosion.spawn(v.x + 8, v.y + 16, -841)
		v:kill(9)
	elseif v.ai1 == config.explodeTime - 72 and config.allowAlert then
		data.animation = config.alertAnimation
	end
	
	for _,p in ipairs(NPC.getIntersecting(v.x - 2, v.y - 2, v.x + v.width + 2, v.y + v.height + 2)) do
		if p:mem(0x12A, FIELD_WORD) > 0 and p:mem(0x138, FIELD_WORD) == 0 and v:mem(0x138, FIELD_WORD) == 0 
		and (not p.isHidden) and (not p.friendly) and p:mem(0x12C, FIELD_WORD) == 0 and p.idx ~= v.idx 
		and v:mem(0x12C, FIELD_WORD) == 0 and (not NPC.config[p.id].powerup) and NPC.HITTABLE_MAP[p.id] then
			Explosion.spawn(v.x + 8, v.y + 16, -841)
			v:kill(9)
		end
	end

	v.animationFrame = data.animation[1 + math.floor(v.ai1 / config.framespeed) % #data.animation] -- updates the animation manually
end

--Gotta return the library table!
return bomb