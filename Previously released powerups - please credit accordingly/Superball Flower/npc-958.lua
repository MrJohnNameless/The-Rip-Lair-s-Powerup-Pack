local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")
local remoteCC = require("remoteCC")
local ball = {}

ball.collectibleItems = {10, 33, 88, 103, 138, 152, 251, 252, 253, 258, 274, 310, 378} --some imporant coins
ball.lifetime = 280

--[[
	***************************************
	 Uses removeCC.lua, made by Novarender
	***************************************
	]]
	

local npcID = NPC_ID

local ballSettings = {
	id = npcID,
	
	gfxheight = 20,
	gfxwidth = 20,
	
	width = 20,
	height = 20,
	
	gfxoffsetx = 0,
	gfxoffsety = 0,
	
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	
	speed = 1,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,

	
	nohurt=true,
	nogravity = true,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = true,
	
	jumphurt = false,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,
	SMLDamageSystem = true,


}

npcManager.setNpcSettings(ballSettings)
npcManager.registerHarmTypes(npcID,{HARM_TYPE_OFFSCREEN},{})

function ball.onInitAPI()
	npcManager.registerEvent(npcID, ball, "onTickNPC")
end

local function getDirection(v) --get the direction for eject the ball
	local data = v.data
	local dir = v.data.dir

	local p = data.owner or player

	if p.keys.up and not v.data.firstFrame then
		dir.y = -1
	end
	
	data.ballCollider = data.ballCollider or Colliders.Box(v.x - 4, v.y + 4, v.width + 4, v.height + 4);
	data.ballCollider.x = v.x
	data.ballCollider.y = v.y

	--Thing that makes it work with slopes I guess lol
	local slopes = Colliders.getColliding{
	a = data.ballCollider, 
	btype = Colliders.BLOCK, 
	filter = function(other)
	if other.isHidden or other:mem(0x5A, FIELD_BOOL) then
		return false
	end
	return true
	end}
	
	for _,b in ipairs(slopes) do
		if Block.config[b.id].floorslope ~= 0 or Block.config[b.id].ceilingslope ~= 0 then
			dir.x = -dir.x
			dir.y = -dir.y
		end
	end
		
	if v.collidesBlockBottom then
		dir.y = -1
	elseif v.collidesBlockUp then
        dir.y = 1
	end

	if not v.collidesBlockUp then
		if v.collidesBlockLeft then
		 dir.x = 1
	   elseif v.collidesBlockRight then
		 dir.x = -1
	  end
	end

	return dir * 4 --final direction

end


local function spuff(v)
	Animation.spawn(10,v.x,v.y)
	v:kill(HARM_TYPE_OFFSCREEN)
end


function ball.onTickNPC(v)
	if Defines.levelFreeze then return end


	
	local config = NPC.config[v.id]
	local data = v.data

	if data.lifetime and data.lifetime >= ball.lifetime then
		spuff(v)
	end
	
	if v:mem(0x12A, FIELD_WORD) <= 0 then
		return
	end

	local p = data.owner or player

	if not data.init then
		data.dir = vector.v2(p.direction,1)
		data.init = true
	end

	data.lifetime = data.lifetime or 0

	


	local dir_final = getDirection(v) * 1.5
	
    v:mem(0x120,FIELD_BOOL,false)
	v.speedX,v.speedY = dir_final.x,dir_final.y



	v.friendly = true

	-- AI for coins and starcoins. Uses remoteCC.lua by Novarender

	for _,c in NPC.iterate(ball.collectibleItems) do
		
		if v:collide(c) then
			if not NPC.config[c.id].iscoin then
				c.x = p.x
				c.y = p.y
			else
				remoteCC.collect(c)
			end
		end
	end

	for k,npc in ipairs(Colliders.getColliding{a = v, atype = Colliders.NPC, b = NPC.HITTABLE}) do
		if not (NPC.config[npc.id].nofireball and not npc.friendly and not npc.isHidden and not npc.isinteractable and not npc.iscoin and not NPC.POWERUP_MAP[npc.id]) and npc:mem(0x138, FIELD_WORD) == 0 then
			npc:harm(HARM_TYPE_EXT_FIRE)
			spuff(v)
		else
			spuff(v)
		end
	end
	
	data.firstFrame = true
	data.lifetime = data.lifetime + 1
	
end

return ball