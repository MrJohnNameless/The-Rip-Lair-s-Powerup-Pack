local windChargeAI = {}

local npcManager = require("npcManager")

local burstSFX = Misc.resolveFile("powerups/wind-burst.ogg")

function windChargeAI.register(npcID)
	npcManager.registerEvent(npcID, windChargeAI, "onTickEndNPC")
end

function windChargeAI.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data
	local cfg = NPC.config[v.id]
	
	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if not data.initialized then
		data.initialized = true
		data.hitbox = Colliders:Circle()
	end

	if v.heldIndex ~= 0 --Negative when held by NPCs, positive when held by players
	or v.forcedState > 0 --Various forced states
	then
		return
	end

	data.hitbox.x = v.x+v.width*0.5
	data.hitbox.y = v.y+v.height*0.5
	data.hitbox.radius = (cfg.hitboxRadius * 2)

        v.speedX = cfg.chargeSpeed * v.direction
	
	-- Put main AI below here
        if v.collidesBlockBottom or v.collidesBlockRight or v.collidesBlockUp or v.collidesBlockLeft or #Player.getIntersecting(v.x, v.y, v.x+v.width, v.y+v.height) > 0 or #Colliders.getColliding{a = v, b = NPC.HITTABLE, btype = Colliders.NPC, filter = Colliders.FILTER_COL_NPC_DEF} > 0 then

        -- knock back NPCs
        for _,n in ipairs(NPC.get()) do
		if n.idx ~= v.idx and not n.isHidden and not n.friendly and NPC.HITTABLE_MAP[n.id] and not NPC.POWERUP_MAP[n.id] then
                        if Colliders.collide(data.hitbox,n) and Misc.canCollideWith(v, n) then
			        n.speedX = (1.5 * cfg.burstStrength) * v.direction
			        n.speedY = -1.25 * cfg.burstStrength			
                                n.isProjectile = true
                        end
                end
        end

        -- collect coins
        for _,c in ipairs(NPC.get()) do
	        if NPC.COIN_MAP[c.id] and not c.isHidden then
                        if Colliders.collide(data.hitbox,c) and Misc.canCollideWith(v, c) then
	                        c:collect(p)
                        end
                end
	end

        -- knock back players
        for _,p in ipairs(Player.get()) do
                if Colliders.collide(data.hitbox,p) and Misc.canCollideWith(v, p) then
		        if p.forcedState == FORCEDSTATE_NONE and p.deathTimer == 0 then
			        local distance = vector((p.x + p.width*0.5) - (v.x + v.width*0.5),(p.y + p.height*0.5) - (v.y + v.height*0.5))
			        p.speedX = (distance.x / v.width ) * (cfg.burstStrength * 2)
			        p.speedY = (distance.y / v.height) * cfg.burstStrength
                        end
                end
        end

        -- bump nearby blocks
	for _,b in ipairs(Block.get()) do
                if Colliders.collide(data.hitbox,b) and Misc.canCollideWith(v, b) then
                        if b.isHidden == false and not b:mem(0x5A, FIELD_BOOL) then
	                        b:hitWithoutPlayer(false)
                        end
                end
	end
 
        -- do the other things
	SFX.play(burstSFX)
	Defines.earthquake = cfg.earthquake
        local e = Effect.spawn(cfg.burstEffect, v.x - cfg.effectOffset, v.y - cfg.effectOffset)
        v:kill(HARM_TYPE_OFFSCREEN)
        end
end

return windChargeAI