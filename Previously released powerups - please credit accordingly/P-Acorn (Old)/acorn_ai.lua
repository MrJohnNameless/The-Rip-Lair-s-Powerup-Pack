local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

local acorn = {}

local function initialize(v,data)
    data.initialized = true
	data.rotation = 0
end

function acorn.register(npcID)
    npcManager.registerEvent(npcID, acorn, "onDrawNPC")
	npcManager.registerEvent(npcID, acorn, "onTickEndNPC")
end

function acorn.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	if v.despawnTimer <= 0 then
		v.data.initialized = false
		return
	end
	
	if not v.data.initialized then
		initialize(v,v.data)
	end
	
	v.data.rotation = v.data.rotation + v.speedX*360/(32*math.pi)
end


function acorn.onDrawNPC(v)
	if v.despawnTimer <= 0 or v.isHidden or v:mem(0x138, FIELD_WORD) ~= 0 then return end
	
	local data = v.data
	
	if not data.initialized then
		initialize(v,data)
	end
	
	local texture = Graphics.sprites.npc[v.id].img
	
	if data.sprite == nil or data.sprite.texture ~= texture then
        data.sprite = Sprite{texture = texture,frames = npcutils.getTotalFramesByFramestyle(v),pivot = Sprite.align.CENTRE} --European spelling, but I'm not gonna question it.
    end
	
	local config = NPC.config[v.id]
	
	data.sprite.x = v.x + v.width*0.5 + config.gfxoffsetx
    data.sprite.y = v.y + v.height - config.gfxheight*0.5 + config.gfxoffsety
	data.sprite.rotation = data.rotation % 360
	
	data.sprite:draw{frame = 1,priority = -45,sceneCoords = true}
	
	npcutils.hideNPC(v)
end

return acorn