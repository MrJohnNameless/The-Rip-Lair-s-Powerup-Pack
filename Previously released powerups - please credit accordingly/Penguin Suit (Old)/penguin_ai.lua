local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

local penguin = {}

local function initialize(v,data)
    data.initialized = true
	data.rotation = 0
	data.penguinWaitTimer = 100
end

function penguin.register(npcID)
    npcManager.registerEvent(npcID, penguin, "onDrawNPC")
	npcManager.registerEvent(npcID, penguin, "onTickEndNPC")
end

function penguin.onTickEndNPC(v)
	if Defines.levelFreeze or v:mem(0x138, FIELD_WORD) ~= 0 then return end
	
	if v.despawnTimer <= 0 then
		v.data.initialized = false
		return
	end
	
	if not v.data.initialized then
		initialize(v,v.data)
	end
	
	if v.data.penguinWaitTimer >= 10 then
		v.speedX = 0
	else
		v.speedX = math.min(1,(10 - v.data.penguinWaitTimer)/10)*0.25*v.direction
	end
	v.data.rotation = v.data.rotation + 0.25
	v.data.penguinWaitTimer = v.data.penguinWaitTimer - 1
end


function penguin.onDrawNPC(v)
	if v.despawnTimer <= 0 or v.isHidden or v:mem(0x138, FIELD_WORD) ~= 0 then return end
	
	local data = v.data
	
	if not data.initialized then
		initialize(v,data)
	end
	
	local texture = Graphics.sprites.npc[v.id].img
	
	if data.sprite == nil or data.sprite.texture ~= texture then
        data.sprite = Sprite{texture = texture,frames = npcutils.getTotalFramesByFramestyle(v),width = 32,height = 32,pivot = Sprite.align.BOTTOMRIGHT}
		data.sprite2 = Sprite{texture = texture,frames = npcutils.getTotalFramesByFramestyle(v),width = 32,height = 32,pivot = Sprite.align.BOTTOMLEFT}
    end
	
	local penguinSprite, penguinOffset
	
	if math.sin(v.data.rotation*0.5) >= 0 then
		penguinSprite = data.sprite
		penguinOffset = 16
	else
		penguinSprite = data.sprite2
		penguinOffset = -16
	end
	
	local config = NPC.config[v.id]
	
	penguinSprite.rotation = 22.5*math.sin(v.data.rotation*0.5)*math.min(1,((100 - v.data.penguinWaitTimer)/100)+0.1)
	penguinSprite.x = v.x + v.width*0.5 + config.gfxoffsetx + penguinOffset
    penguinSprite.y = v.y + v.height - config.gfxheight*0.5 + config.gfxoffsety + 16
	
	--[[if data.sprite.rotation >= 0 then
		data.sprite.pivot = Sprite.align.BOTTOMRIGHT
		data.sprite.x = data.sprite.x + 16
	else
		data.sprite.pivot = Sprite.align.BOTTOMLEFT
		data.sprite.x = data.sprite.x - 16
	end]]
	
	
	penguinSprite:draw{frame = 1,priority = -45,sceneCoords = true}
	npcutils.hideNPC(v)
end

return penguin