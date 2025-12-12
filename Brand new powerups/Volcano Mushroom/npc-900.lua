local npcManager = require("npcManager")
local volcanoShroom = {}
local npcID = NPC_ID

volcanoShroom.settings = {
	duration = 5,
	invulnerableWhenUsed = true,
	harmNPCs = true,

	speedAccel = 0.4,
	maxSpeed = 15,
	
	trailSpawnID = 359,
	trailSpawnInterval = 4,
	trailSpawnIsFriendly = true,

	consumeSFX = Misc.resolveSoundFile("volcanoShroom"),
	coolDownSFX = Misc.resolveSoundFile("volcanoShroomCool"),
	enflamedColour = Color.orange,
}

local settings = volcanoShroom.settings

local volcanoShroomNPCSettings = {
	id = npcID,
	gfxheight = 32,
	gfxwidth = 32,
	gfxoffsety = 2,
	width = 32,
	height = 32,
	frames = 1,
	framestyle = 0,
	framespeed = 8,
	score = 0,
	
	npcblock = false,
	npcblocktop = false,
	playerblock = false,
	playerblocktop = false,
	powerup = true,
	nohurt=true,
	nogravity = false,
	noblockcollision = false,
	nofireball = true,
	noiceball = true,
	noyoshi= false,
	nowaterphysics = false,

	jumphurt = true,
	spinjumpsafe = false,
	harmlessgrab = true,
	harmlessthrown = true,

	isinteractable = true,
	ignorethrownnpcs = true,
	notcointransformable = true,

	luahandlesspeed = true,
	ishot = true,
	durability = -1,
}

npcManager.setNpcSettings(volcanoShroomNPCSettings)
npcManager.registerHarmTypes(npcID,
	{
		HARM_TYPE_FROMBELOW,
		HARM_TYPE_LAVA,
		HARM_TYPE_TAIL,
		--HARM_TYPE_OFFSCREEN,
	}, 
	{
		[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5},
	}
);

function volcanoShroom.onInitAPI()
	npcManager.registerEvent(npcID, volcanoShroom, "onTickEndNPC")
	registerEvent(volcanoShroom, "onTick")
	registerEvent(volcanoShroom, "onDraw")
	registerEvent(volcanoShroom, "onNPCHarm")
	registerEvent(volcanoShroom, "onNPCCollect")

	Cheats.register("needavolcanomushroom",{
		isCheat = true,
		activateSFX = 12,
		aliases = {"needavolcanoshroom","superspicy","lavashroom","satanschoice"},
		onActivate = (function() 
			for i,p in ipairs(Player.get()) do
				p.reservePowerup = npcID
			end
			
			return true
		end)
	})
end

function volcanoShroom.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	if RNG.randomInt(1, 12) == 1 then
		local e = Effect.spawn(265, v.x + RNG.randomInt(0, v.width), v.y + RNG.randomInt(0, v.height))
		e.x = e.x - e.width/2
		e.y = e.y - e.height/2
		e.speedY = -1.2
	end

	if v.heldIndex ~= 0 
	or v.isProjectile   
	or v.forcedState > 0
	then return end
	
	v.speedX = 1.5 * v.direction
end

function volcanoShroom.onNPCHarm(token,v,harm,c)
	if v.id ~= npcID then return end
	
	if harm ~= HARM_TYPE_TAIL and harm ~= HARM_TYPE_FROMBELOW then return end
	v.speedY = -6
	SFX.play(2)
	token.cancelled = true
end

function volcanoShroom.onDraw()
	for k, p in ipairs(Player.get()) do
		if p.data.volcanoShroomEnflamedTimerDataValueThingy and settings.enflamedColour then
        		p:render{
            			color = settings.enflamedColour,
        		}
		end
	end
end

function volcanoShroom.onTick()
	for k, p in ipairs(Player.get()) do
		if p.data.volcanoShroomEnflamedTimerDataValueThingy then
			p.data.volcanoShroomEnflamedTimerDataValueThingy = p.data.volcanoShroomEnflamedTimerDataValueThingy - 1

			if p.direction == -1 then
				p.speedX = p.speedX - settings.speedAccel
			elseif p.direction == 1 then
				p.speedX = p.speedX + settings.speedAccel
			end
			
			p.speedX = math.clamp(p.speedX, -settings.maxSpeed, settings.maxSpeed)
	
			local excessSpeed = (math.abs(p.speedX))*math.sign(p.speedX)
  			p:mem(0x138,FIELD_FLOAT,excessSpeed)
  			p.speedX = p.speedX - excessSpeed

			if settings.invulnerableWhenUsed then
				p:mem(0x140, FIELD_WORD, 4)
				if p.forcedState == 0 and not p:mem(0x142, FIELD_BOOL) then
					p:mem(0x142, FIELD_BOOL, false)
				end
			end

			local id = (((RNG.randomInt(1, 2) == 1) and 74) or 265)

         		local e = Effect.spawn(id, p.x + RNG.random(0, p.width), p.y + RNG.random(0, p.height))
                        e.x = e.x - e.width * 0.5
                        e.y = e.y - e.height * 0.5
		        e.speedY = RNG.random(-1, -6)

			if (p.data.volcanoShroomEnflamedTimerDataValueThingy % settings.trailSpawnInterval == 0) and (settings.trailSpawnID > 0) and p:isGroundTouching() then
				local f = NPC.spawn(settings.trailSpawnID, p.x + 0.5 * p.width, p.y + p.height)
				f.x = f.x - f.width * 0.5
				f.y = f.y - f.height
				f.friendly = settings.trailSpawnIsFriendly
				f.layerName = "Spawned NPCs"
			end

			if settings.harmNPCs then
				for _, n in ipairs(NPC.getIntersecting(p.x + p.speedX, p.y, p.x + p.width + p.speedX, p.y + p.height)) do
					if n.isValid and not n.isHidden and not n.friendly and n.despawnTimer > 0 and NPC.HITTABLE_MAP[n.id] then 
						n:harm(3)
						if n.killFlag == 0 then
							p:mem(0x138,FIELD_FLOAT, -p:mem(0x138,FIELD_FLOAT)) 
							SFX.play(2)
						end
					end
				end
			end
	
			if p.data.volcanoShroomEnflamedTimerDataValueThingy <= 0 then
				p.data.volcanoShroomEnflamedTimerDataValueThingy = nil
				
				if settings.coolDownSFX then
					SFX.play(settings.coolDownSFX)
				end
				
				for i = 1, 4 do
					local e = Effect.spawn(131, p.x + p.width * 0.5, p.y + p.height * 0.5)
					e.speedX = ({-2, -2, 2, 2})[i]
					e.speedY = ({-3, 3, -3, 3})[i]
					e.x = e.x - e.width * 0.5
					e.y = e.y - e.height * 0.5
				end
			end
		end
	end
end

function volcanoShroom.onNPCCollect(eventObj, v, p)
	if v.id ~= npcID or v.isGenerator then return end

    	for i = 1, 4 do
		local e = Effect.spawn(131, v.x + v.width * 0.5, v.y + v.height * 0.5)
		e.speedX = ({-2, -2, 2, 2})[i]
		e.speedY = ({-3, 3, -3, 3})[i]
                e.x = e.x - e.width * 0.5
		e.y = e.y - e.height * 0.5
	end
	
	for j = 1, RNG.randomInt(4, 16) do
                local e = Effect.spawn(265, v.x + v.width * 0.5,v.y + v.height * 0.5)
                e.x = e.x - e.width * 0.5
                e.y = e.y - e.height * 0.5
		e.speedX = RNG.random(-4, 4)
		e.speedY = RNG.random(-4, 4)
	end  

	p.data.volcanoShroomEnflamedTimerDataValueThingy = lunatime.toTicks(settings.duration)
	
	if settings.consumeSFX then
		SFX.play(settings.consumeSFX)
	end
end

return volcanoShroom