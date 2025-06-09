--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")

--Create the library table
local sampleNPC = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

--Defines NPC config for our NPC. You can remove superfluous definitions.
local sampleNPCSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 32,
	gfxwidth = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 32,
	height = 16,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 0,
	--Frameloop-related
	frames = 1,
	framestyle = 0,
	framespeed = 8, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1,
	--Collision-related
	npcblock = false,
	npcblocktop = false, --Misnomer, affects whether thrown NPCs bounce off the NPC.
	playerblock = false,
	playerblocktop = false, --Also handles other NPCs walking atop this NPC.
	powerup = true,
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
	harmlessgrab = true, --Held NPC hurts other NPCs if false
	harmlessthrown = true, --Thrown NPC hurts other NPCs if false

	score = SCORE_1000,
	isinteractable = true,
}

--Applies NPC settings
npcManager.setNpcSettings(sampleNPCSettings)

function sampleNPC.onInitAPI()
	registerEvent(sampleNPC, "onPostNPCCollect")
end

local function spawnEffect(p)
	Animation.spawn(10,p.x+p.width*0.5-16,p.y+p.height*0.5);
end

function sampleNPC.onPostNPCCollect(v, p)
	if v.id ~= npcID then return end

	local character = p.character
	spawnEffect(p)
	p.character = 4
	p.forcedState = 1
	p:mem(0x140, FIELD_WORD, 50)
	SFX.play("sm64_star.WAV")
end

--Gotta return the library table!
return sampleNPC