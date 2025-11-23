local flyingStar = {}

-- reserved variable names are "name", "items", "id", "collectSounds", "basePowerup", "spritesheets" and "iniFiles"
-- everything except "name" and "id" can be safely modified

local afterImages = {}
local afterImagesShader = Shader.fromFile(nil, "afterimages_shader.frag")

function flyingStar.onInitPowerupLib()
	flyingStar.spritesheets = {
		flyingStar:registerAsset(1, "flying-mario.png"),
		flyingStar:registerAsset(2, "flying-luigi.png"),
		flyingStar:registerAsset(3, "flying-peach.png"),
		flyingStar:registerAsset(4, "flying-toad.png"),
		flyingStar:registerAsset(5, "flying-link.png"),
	}

	flyingStar.iniFiles = {
		flyingStar:registerAsset(1, "flying-mario.ini"),
		flyingStar:registerAsset(2, "flying-luigi.ini"),
		flyingStar:registerAsset(3, "flying-peach.ini"),
		flyingStar:registerAsset(4, "flying-toad.ini"),
		flyingStar:registerAsset(5, "flying-link.ini"),
	}

	flyingStar.flyingSprites = {
		flyingStar:registerAsset(1, "mario-flyingSprite.png"),
		flyingStar:registerAsset(2, "luigi-flyingSprite.png"),
		flyingStar:registerAsset(3, "peach-flyingSprite.png"),
		flyingStar:registerAsset(4, "toad-flyingSprite.png"),
		flyingStar:registerAsset(5, "link-flyingSprite.png"),
	}
end

flyingStar.playerColors = {
	[CHARACTER_MARIO] = Color.fromHexRGB(0xF82038),
	[CHARACTER_LUIGI] = Color.fromHexRGB(0xA0D800),
	[CHARACTER_PEACH] = Color.fromHexRGB(0xF85090),
	[CHARACTER_TOAD] = Color.fromHexRGB(0x2078F8),
	[CHARACTER_LINK] = Color.fromHexRGB(0xA0D800),
}

flyingStar.basePowerup = PLAYER_FIREFLOWER

local aw
pcall(function() aw = require("anotherwalljump") end)
pcall(function() aw = aw or require("aw") end)

local function createAfterImage(p, args)
    args = args or {}

    local t = {
        fadeWhilePaused = args.fadeWhilePaused,
        opacity = args.opacity or 1,
        color = args.color or Color.white,
        fadeSpeed = args.fadeSpeed or 0.075,

		direction = p.direction,
		x = p.x + p.width/2,
		y = p.y + p.height/2,

		texture = args.texture,
		rotation = args.rotation,
		priority = args.priority,
    }

    table.insert(afterImages, t)
    return t
end

registerEvent(flyingStar, "onDraw")

function flyingStar.onDraw()
	for k = #afterImages, 1, -1 do
        local obj = afterImages[k]

        if not Misc.isPaused() or obj.fadeWhilePaused then
            obj.opacity = math.max(obj.opacity - obj.fadeSpeed, 0)
        end

        Graphics.drawBox{
			texture = obj.texture,
			x = obj.x,
			y = obj.y,
			width = obj.texture.width * obj.direction,
			height = obj.texture.height,
			rotation = obj.rotation,
			priority = obj.priority,
			centered = true,
			sceneCoords = true,

			shader = afterImagesShader,
			uniforms = {
				iCol = obj.color,
				iAlpha = obj.opacity,
			}
		}

        if obj.opacity == 0 then
            table.remove(afterImages, k)
        end
    end
end

function flyingStar.onEnable(p)
   if p.data.flyingStar then return end
	p.data.flyingStar = {
		maxSpeed = false,
		maxSpeedTimer = 0,
		isFlying = false,
		flyTimer = 0,
		canFly = true,
		
		
		--****************************************
		--Configs here, change what you want
		--Set flyDuration to 0 for infinite flight
		--****************************************
		
		flyDuration = 256,
	}
end

function flyingStar.onDisable(p)
    p.data.flyingStar = nil
	p:mem(0x164, FIELD_WORD, 0)
end

function flyingStar.onTickPowerup(p)
	if not p.data.flyingStar then return end -- check if the powerup is currenly active
	local data = p.data.flyingStar
	
	if p.character ~= CHARACTER_LINK then
		p:mem(0x160, FIELD_WORD, 2)
	elseif p.mount < 2 then
		p:mem(0x162, FIELD_WORD, 2)
	end
	
	--Check the player's speed is at their max
	if (math.abs(p.speedX) >= Defines.player_runspeed and p.character ~= 3) or (math.abs(p.speedX) >= Defines.player_runspeed - 1 and p.character == 3) then
		data.maxSpeed = true
		if not p:isOnGround() and p.keys.altRun == KEYS_PRESSED and data.canFly and not data.isFlying and p.mount == 0 and not p:mem(0x0C, FIELD_BOOL) and not p:mem(0x50, FIELD_BOOL) then
			data.isFlying = true
			SFX.play(34)
			p:mem(0x164, FIELD_WORD, -1)
		end
		if p:isOnGround() then data.canFly = true end
	else
		data.maxSpeed = false
	end
end

function flyingStar.onTickEndPowerup(p)
	if not p.data.flyingStar then return end -- check if the powerup is currenly active
	local data = p.data.flyingStar
	
	if not data.isFlying then
		data.flyTimer = 0
		if data.maxSpeed then
			data.maxSpeedTimer = data.maxSpeedTimer + 1
			--Animation for when the player can fly
			if p.mount == 0 and p.holdingNPC == nil and not p:mem(0x12E, FIELD_BOOL) and not p:mem(0x50, FIELD_BOOL) and not p:mem(0x4A, FIELD_BOOL) and not p:mem(0x44, FIELD_BOOL) and not p:mem(0x3C, FIELD_BOOL) and not p:mem(0x36, FIELD_BOOL) then
				if p:isOnGround() then
					p.frame = math.floor(data.maxSpeedTimer / 4) % 3 + 16
				else
					p.frame = 19
				end
			else
				data.maxSpeedTimer = 0
			end
		else
			data.maxSpeedTimer = 0
		end
	else
	
		data.flyTimer = data.flyTimer + 1
		data.maxSpeed = false
		
		--When flying, hide the player and draw an image instead
		p:setFrame(50)

		--Disables walljumping
		if aw then aw.preventWallSlide(p) end
		--Flying code here
		
		if p.keys.right then
			p.speedX = math.min(p.speedX+1.5,6)
		elseif p.keys.left then
			p.speedX = math.max(p.speedX-1.5,-6)
		elseif p.keys.up or p.keys.down then
			if p.speedX > 0 then
				p.speedX = math.max(0, p.speedX-1.5)
			else
				p.speedX = math.min(0, p.speedX+1.5)
			end
		elseif p.speedX > 0 then
			p.speedX = math.max(0, p.speedX-0.125)
		else
			p.speedX = math.min(0, p.speedX+0.125)
		end
		
		if p.keys.up and p:mem(0x14A, FIELD_WORD) == 0 then
			p.speedY = math.max(p.speedY-1.5,-6)
		elseif p.keys.down then
			p.speedY = math.min(p.speedY+1.5,6)
		elseif p.keys.right or p.keys.left then
			if p.speedY > 0 then
				p.speedY = math.max(0, p.speedY-1.5)
			else
				p.speedY = math.min(0, p.speedY+1.5)
			end
		elseif p.speedY > 0 then
			p.speedY = math.max(0, p.speedY-0.125)
		else
			p.speedY = math.min(0, p.speedY+0.125)
		end
	
		if not p.keys.left and not p.keys.right and not p.keys.up and not p.keys.down then
			p.speedY = -Defines.npc_grav
		else
			p.speedY = p.speedY-(Defines.player_grav/10)
		end
		
		p:mem(0x40, FIELD_WORD, 0)
		
		if p:isOnGround() or (data.flyDuration ~= 0 and data.flyTimer >= data.flyDuration) or p:mem(0x34, FIELD_WORD) == 2 then
			data.flyTimer = 0
			data.isFlying = false
			data.canFly = false
			p:mem(0x164, FIELD_WORD, 0)
		end
	end
end

local goalTape = require("npcs/AI/goalTape")

local function getPriority(p)
        local priority
        local info = goalTape.playerInfo[p.idx]

        if info and info.darkness > 0 then
          	priority = (info.pausesGame and 0.5) or -6
        elseif p.forcedState == 3 then
            	priority = -70	
	else
		priority = -25
        end

	return priority
end

function flyingStar.onDrawPowerup(p)
	
	if not p.data.flyingStar then return end -- check if the powerup is currenly active
	local data = p.data.flyingStar
	if not data.isFlying then return end

    local ps = p:getCurrentPlayerSetting()
	
	local slideTexture = flyingStar:getAsset(p.character, flyingStar.flyingSprites[p.character])

	Graphics.drawBox{
		texture = slideTexture,
		x = p.x + p.width/2,
		y = p.y + p.height/2,
		width = slideTexture.width * p.direction,
		height = slideTexture.height,
		sourceX = 0,
		sourceY = 0,
		sourceWidth = slideTexture.width,
		sourceHeight = slideTexture.height,
		sceneCoords = true,
		centered = true,
		priority = getPriority(p),
		rotation = (p.speedY * 4) * p.direction,
	}

	if not Misc.isPaused() and p.frame >= 0 and p.frame <= 10 then
		createAfterImage(p, {
			priority = -49,
			color = flyingStar.playerColors[p.character],
			rotation = (p.speedY * 4) * p.direction,
			texture = slideTexture,
			opacity = 0.4,
			fadeSpeed = 0.025,
		})
	end
end

return flyingStar