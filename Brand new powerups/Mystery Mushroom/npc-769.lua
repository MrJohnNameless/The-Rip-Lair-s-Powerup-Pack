--NPCManager is required for setting basic NPC properties
local npcManager = require("npcManager")
local playerManager = require("playerManager")
local oldCostume = {}
local costumes = {}

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
npcManager.setNpcSettings(sampleNPCSettings)

function sampleNPC.onInitAPI()
	registerEvent(sampleNPC, "onPostNPCCollect")
end

local function spawnEffect(p)
	Animation.spawn(10,p.x+p.width*0.5-16,p.y+p.height*0.5);
	SFX.play(34)
end

function sampleNPC.onPostNPCCollect(v, p)
	if v.id ~= npcID then return end

	local character = p.character

	if (costumes[character] == nil) then
		costumes[character] = playerManager.getCostumes(character);
	end

	--If costume is default then find which one we are using, or if we can't assume 0 (default).
	if oldCostume[character] == nil then
		local current = playerManager.getCostume(character);
		oldCostume[character] = 0
		if(current ~= nil) then
			for k,c in ipairs(costumes[character]) do
				if(c == current) then
					oldCostume[character] = k;
					break;
				end
			end
		end
	end
	
	local newCostume = (oldCostume[character]+1) % (#costumes[character] + 1);
	playerManager.setCostume(character,costumes[character][newCostume])
	oldCostume[character] = newCostume
	spawnEffect(p)
end

--Gotta return the library table!
return sampleNPC