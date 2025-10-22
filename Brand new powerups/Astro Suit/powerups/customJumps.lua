
--[[
				customJumps.lua by John Nameless
				
				A customPowerups plugin that allows
			registered powerups to customize jumpheights
			
	CREDITS:
	Marioman2007 - created customPowerups framework which this script is designed for (https://www.smbxgame.com/forums/viewtopic.php?t=29435&sid=09762126985be58594941d2479968bbf)
	
	NOTE: This requires customPowerups in order to work! Get it from the link above! ^^^
]]--

local cp = require("customPowerups")

local jumper = {}

local registeredPowerups = {}
local jumpheights = {}

local wasGrounded = {}
local spikeBounced = {}
local canJump = {}

for i = 1,128 do
	wasGrounded[i] = false
	spikeBounced[i] = false
	canJump[i] = false
end

local function bouncingOnNPC(p)
	for _, n in NPC.iterateIntersecting(p.x, p.y+p.height, p.x+p.width, p.y+p.height+16+math.max(p.speedY,0)) do
		if n.isValid and not n.isHidden and not n.isGenerator and not n.friendly and n.despawnTimer > 0 
		and (NPC.config[n.id].spinjumpsafe or not NPC.config[n.id].jumphurt) 
		and not NPC.config[n.id].playerblocktop and not NPC.config[n.id].isinteractable 
		and not NPC.config[n.id].isvine then
			if Colliders.bounce(p, n) then
				local isSpiky = NPC.config[n.id].spinjumpsafe
				return true, isSpiky
			end
		end
	end
end

function jumper.registerPowerup(name,heightTable)
	if registeredPowerups[name] then return end
	registeredPowerups[name] = true
	jumpheights[name] = heightTable
end

function jumper.onInitAPI()
	registerEvent(jumper,"onTick")
end

function jumper.isOnGround(p) -- ripped straight from MrDoubleA's SMW Costume scripts
	return (
		(p.speedY == 0 and p.forcedState == 0) -- "on a block"
		or p:isGroundTouching() -- on a block (fallback if the former check fails)
		or p:isClimbing() -- on a vine
		or p:mem(0x176,FIELD_WORD) ~= 0 -- on an NPC
		or p:mem(0x48,FIELD_WORD) ~= 0 -- on a slope
		or (p.mount == MOUNT_BOOT and p:mem(0x10C, FIELD_WORD) ~= 0) -- hopping around while wearing a boot
	)
end

function jumper.onTick()
	for _,p in ipairs(Player.get()) do
		if registeredPowerups[cp.getCurrentName(p)] then
			if canJump[p.idx] then
				local finalHeight = jumpheights[cp.getCurrentName(p)][p.character]
				if finalHeight == nil then
					finalHeight = jumpheights[cp.getCurrentName(p)][1]
				end
				if p.isSpinJumping and not spikeBounced[p.idx] then
					finalHeight = finalHeight - 10
				end
				
				p:mem(0x11C,FIELD_WORD,math.max(p:mem(0x11C,FIELD_WORD),finalHeight))
				
				wasGrounded[p.idx] = false
				spikeBounced[p.idx] = false
				canJump[p.idx] = false
				return
			end

			local bouncing,isSpiky = bouncingOnNPC(p)			
			if (wasGrounded[p.idx] and p:mem(0x11C,FIELD_WORD) > 0) or bouncing then
				wasGrounded[p.idx] = false
				canJump[p.idx] = true
				if bouncing and isSpiky then
					spikeBounced[p.idx] = true
				end
			end
			
			if p:mem(0x11C,FIELD_WORD) <= 0 or jumper.isOnGround(p) then
				wasGrounded[p.idx] = true
			end
		end
	end
end

return jumper