--[[
	Fire and Ice Mushroom, by AlanLive, Sleepy Dee, and DeviousQuacks23
]]--

local fireIceShroom = {}

function fireIceShroom.onInitAPI()
        registerEvent(fireIceShroom, "onTick")
        registerEvent(fireIceShroom, "onDraw")
end

local mask = Shader()
mask:compileFromFile(nil, "shaders/effects/mask.frag")

fireIceShroom.bounceTexture = Graphics.loadImageResolved("powerups/shroomBoom.png")
fireIceShroom.ringTexture = Graphics.loadImageResolved("powerups/shroomBoomRing.png")

local bounceEffects = {}
local ringEffects = {}

fireIceShroom.pulseTimerMax = {60, 65, 70, 55, 55}

function fireIceShroom.pulseThePlayer(p, isIceShroom)
	if isOverworld then return end
	if lunatime.tick() <= 1 then return end

	Defines.earthquake = 5
	SFX.play(Misc.resolveFile("powerups/player-pulse.ogg"))
	for j = 1, RNG.randomInt(8, 24) do
                local e = Effect.spawn(((isIceShroom and 80) or 265), p.x + p.width * 0.5, p.y + p.height * 0.5)
                e.x = e.x - e.width * 0.5
                e.y = e.y - e.height * 0.5
		e.speedX = RNG.random(-8, 8)
		e.speedY = RNG.random(-8, 8)
	end  
	table.insert(bounceEffects, {
		x = p.x + p.width/2, 
		y = p.y + p.height/2,
		colour = ((isIceShroom and Color.lightblue) or Color.red),
		scale = 1,
		timer = 0,
		opacityMod = 1,
	})                        
	table.insert(ringEffects, {
		x = p.x + p.width/2, 
		y = p.y + p.height/2,
		colour = ((isIceShroom and Color.lightblue) or Color.red),
		scale = 0,
		timer = 0,
		opacityMod = 1,
        })    

        local circ = Colliders.Circle(p.x + 0.5 * p.width, p.y + 0.5 * p.height, 96)
        for k,n in ipairs(Colliders.getColliding{
        	atype = Colliders.NPC,
                b = circ,
                filter = function(o)
                	if NPC.HITTABLE_MAP[o.id] and not o.friendly and not o.isHidden then
                        	return true
                    	end
                end
	}) do
		if isIceShroom then
			n:harm(HARM_TYPE_EXT_ICE)
		else
        		n:harm(HARM_TYPE_EXT_FIRE)
		end
	end                    
end

local function canPulse(p)
    return (
        p.forcedState == 0
        and p.deathTimer == 0 -- not dead
        and not p.inLaunchBarrel
        and not p.inClearPipe
        and not p:mem(0x44,FIELD_BOOL) -- shell surfing
        and not p:mem(0x4A,FIELD_BOOL) -- statue
        and not p:mem(0x0C, FIELD_BOOL) -- fairy
    )
end

function fireIceShroom.onTickShroom(p, data, isIceShroom)
    	data.projectileTimer = math.max(data.projectileTimer - 1, 0) -- decrement the projectile timer/cooldown
   	if data.projectileTimer > 0 or not canPulse(p) or Level.endState() ~= LEVEL_WIN_TYPE_NONE then return end

    	if p.keys.altRun == KEYS_PRESSED then
		fireIceShroom.pulseThePlayer(p, isIceShroom)
		data.projectileTimer = fireIceShroom.pulseTimerMax[p.character] 
	end
end

function fireIceShroom.onDrawShroom(p, data, isIceShroom)
	p:render{
		x = p.x,
		y = p.y,
		shader = mask,
		color = ((isIceShroom and Color.lightblue) or Color.red) .. math.lerp(0, 1, data.projectileTimer / fireIceShroom.pulseTimerMax[p.character]),
	}
end

function fireIceShroom.onTick()
	for k = #bounceEffects, 1, -1 do
		local v = bounceEffects[k]

		v.timer = v.timer + 1
                v.scale = v.scale + 0.15

		if v.timer >= 8 then 
                        v.opacityMod = math.max(v.opacityMod - 0.05, 0) 
                end

		if v.opacityMod <= 0 then
			table.remove(bounceEffects, k)
		end
	end

	for k = #ringEffects, 1, -1 do
		local v = ringEffects[k]

		v.timer = v.timer + 1
                v.scale = v.scale + 0.35

		if v.timer >= 10 then 
                        v.opacityMod = math.max(v.opacityMod - 0.1, 0) 
                end

		if v.opacityMod <= 0 then
			table.remove(ringEffects, k)
		end
	end
end

function fireIceShroom.onDraw()
	for k, v in ipairs(bounceEffects) do
                local img = fireIceShroom.bounceTexture
		Graphics.drawBox{
			texture = img,
			x = v.x,
			y = v.y,
			width = v.scale * img.width,
			height = v.scale * img.height,
			color = (v.colour or Color.white) .. v.opacityMod,
			priority = -45,
			sceneCoords = true,
			centered = true,
		}
        end

	for k, v in ipairs(ringEffects) do
                local img = fireIceShroom.ringTexture
		Graphics.drawBox{
			texture = img,
			x = v.x,
			y = v.y,
			width = v.scale * img.width,
			height = v.scale * img.height,
			color = (v.colour or Color.white) .. v.opacityMod,
			priority = -45,
			sceneCoords = true,
			centered = true,
		}
        end
end

return fireIceShroom