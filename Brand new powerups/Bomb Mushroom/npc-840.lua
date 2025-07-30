--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local powerup = require("powerups/bombShroom")

--Create the library table
local shroom = {}
--NPC_ID is dynamic based on the name of the library file
local npcID = NPC_ID

local cp = require("customPowerups")
local bombShroom = cp.addPowerup("Bomb Mushroom", "powerups/bombShroom", npcID)
cp.transformWhenSmall(npcID, 9)
Explosion.register(-npcID-1, 112, npcID+1, 22)

--Defines NPC config for our NPC. You can remove superfluous definitions.
local shroomSettings = {
	id = npcID,
	--Sprite size
	gfxheight = 42,
	gfxwidth = 32,
	--Hitbox size. Bottom-center-bound to sprite size.
	width = 32,
	height = 32,
	--Sprite offset from hitbox for adjusting hitbox anchor on sprite.
	gfxoffsetx = 0,
	gfxoffsety = 2,
	--Frameloop-related
	frames = 1,
	framestyle = 0,
	framespeed = 8, --# frames between frame change
	--Movement speed. Only affects speedX by default.
	speed = 1.5,
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
	iswalker = true,
}

--Applies NPC settings
npcManager.setNpcSettings(shroomSettings)

--Register the vulnerable harm types for this NPC. The first table defines the harm types the NPC should be affected by, while the second maps an effect to each, if desired.
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_LAVA,
		HARM_TYPE_TAIL,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
		--[HARM_TYPE_OFFSCREEN]=10,
	}
);

function shroom.onInitAPI()
	registerEvent(shroom, "onNPCHarm")
end

function shroom.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(9)
	token.cancelled = true
end

--Gotta return the library table!
return shroom