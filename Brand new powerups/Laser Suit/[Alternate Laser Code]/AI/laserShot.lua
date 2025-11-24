local easing = require("ext/easing")
local npcutils = require("npcs/npcutils")
local npcManager = require("npcManager")

local laserShot = {}

laserShot.idList = {}
laserShot.idMap = {}

local PRECISION = 0.000000001

local function roundOff(x)
	return math.floor(x/PRECISION + 0.5) * PRECISION
end

local function reflect(v, data, slopeAngle)
	local currentAngle = math.rad(data.rotation)
	local currentSpeed = data.magnitude
	local newAngle = 2 * slopeAngle - currentAngle

	local speedX = roundOff(math.cos(newAngle) * currentSpeed)

	if speedX ~= 0 then
		v.direction = math.sign(speedX)
	end

	v.speedX = speedX
	v.speedY = roundOff(math.sin(newAngle) * currentSpeed)

	data.rotation = math.deg(newAngle)
	data.dirVec = vector.right2:rotate(data.rotation)
end

-- code by 9thCore
local function handleReflection(v, data)
	local slopes = Colliders.getColliding{
		a = data.slopeCollider,
		b = Block.SLOPE,
		btype = Colliders.BLOCK,
		section = v.section
	}

	for _, slope in ipairs(slopes) do
		-- angle of a rightwards floor slope
		local rightFloorAngle = math.atan2(slope.height, slope.width)
		local slopeAngle = nil -- its possible we didnt collide

		-- test if we hit the "slope" part and set slope angle accordingly 
		local leftOfSlope = (v.x + v.width <= slope.x)
		local rightOfSlope = (v.x >= slope.x + slope.width)
		local upOfSlope = (v.y + v.height <= slope.y)
		local downOfSlope = (v.y >= slope.y + slope.height)

		-- reflect on the vertical axis
		if Block.SLOPE_LR_FLOOR_MAP[slope.id] and not rightOfSlope and not downOfSlope then
			slopeAngle = math.pi - rightFloorAngle

		elseif Block.SLOPE_RL_FLOOR_MAP[slope.id] and not leftOfSlope and not downOfSlope then
			slopeAngle = rightFloorAngle
		
		-- reflect on the horizontal axis
		elseif Block.SLOPE_LR_CEIL_MAP[slope.id] and not rightOfSlope and not upOfSlope then
			slopeAngle = -rightFloorAngle

		-- reflect a half circle
		elseif Block.SLOPE_RL_CEIL_MAP[slope.id] and not leftOfSlope and not upOfSlope then
			slopeAngle = rightFloorAngle - math.pi
		end

		-- we didn't collide with the slope part, so we can do something else instead
		if slopeAngle == nil then
			local both = true

			if leftOfSlope or rightOfSlope then
				v.speedX = -v.speedX
				both = not both
			end

			if upOfSlope or downOfSlope then
				v.speedY = -v.speedY
				both = not both
			end

			if not both then
				return true, false
			end

		-- we collided with the slope part, so reflect off it
		else
			local oldSpeedX = v.speedX
			local oldSpeedY = v.speedY
			local canKill = false

			reflect(v, data, slopeAngle)

			if oldSpeedX == -v.speedX and oldSpeedY == -v.speedY then
				canKill = true
			end

			return canKill, true
		end
	end
end

local function handleProjectile(v, data)
	for k, b in ipairs(Colliders.getColliding{a = v, b = Block.SOLID, btype = Colliders.BLOCK}) do
		v:kill(9)
		return
	end
end

local function explode(v)
	for k,n in ipairs(Colliders.getColliding{
		a = v.data.collider,
		b = NPC.HITTABLE,
		btype = Colliders.NPC,
		filter = function(w)
			if (not w.isHidden) and w:mem(0x156,FIELD_WORD) <= 0
			and w:mem(0x64, FIELD_BOOL) == false and w:mem(0x12A, FIELD_WORD) > 0 
			and w:mem(0x138, FIELD_WORD) == 0 and w:mem(0x12C, FIELD_WORD) == 0 and w.idx ~= v.idx and w.id ~= v.id then
				return true
			end
			return false
		end
	}) do
		v:kill(9)
		n:harm(HARM_TYPE_EXT_HAMMER)
		return
	end
end

function laserShot.register(id)
	npcManager.registerEvent(id, laserShot, "onTickNPC")
	npcManager.registerEvent(id, laserShot, "onDrawNPC")

	table.insert(laserShot.idList, id)
	laserShot.idMap[id] = true
end

function laserShot.onTickNPC(v)
	if Defines.levelFreeze then return end

	local data = v.data
	local config = NPC.config[v.id]

	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if not data.initialized then
		data.initialized = true
		data.collider = Colliders.Rect(0, 0, config.realWidth, config.realHeight, 0)
		data.timer = 0
		data.slopeCollider = Colliders.getAABB(v)

		data.scale = vector(1.75, 0.125)
		data.oldScale = data.scale
		data.newScale = vector(1, 1)
		data.scaleLerp = 0

		data.initialMag = data.initialMag or 0
		data.rotation = data.rotation or (90 - 90 * v.direction)
		data.magnitude = data.magnitude or 5
		data.dirVec = data.dirVec or vector.right2:rotate(data.rotation)
		data.accelLerp = 0
	end

	data.timer = data.timer + 1

	data.collider.x = v.x + v.width/2
	data.collider.y = v.y + v.height/2
	data.collider.rotation = data.rotation

	data.slopeCollider.x = v.x + v.speedX
	data.slopeCollider.y = v.y + v.speedY

	if data.scaleLerp >= 0 then
		data.scaleLerp = math.min(data.scaleLerp + 0.05, 1)
		data.scale = easing.inOutBack(data.scaleLerp, data.oldScale, data.newScale - data.oldScale, 1, 2)

		if data.scaleLerp == 1 then
			data.scaleLerp = -1
		end
	end

	if v.heldIndex ~= 0  -- Negative when held by NPCs, positive when held by players
	or v.isProjectile    -- Thrown
	or v.forcedState > 0 -- Various forced states
	then
		return
	end

	if ((config.lifetime > 0) and (data.timer >= config.lifetime)) then v:kill(9) return end

	v:mem(0x120, FIELD_BOOL, false)

	local canKill, didReflect = handleReflection(v, data)
	local collided = false

	-- check for non slope blocks
	if not didReflect then
		if v.collidesBlockBottom or v.collidesBlockUp then
			if v.speedX == 0 then
				canKill = true
			else
				reflect(v, data, math.rad(0))
				collided = true
			end
		end

		if not collided and (v.collidesBlockRight or v.collidesBlockLeft) then
			if v.speedY == 0 then
				canKill = true
			else
				reflect(v, data, math.rad(90))
				collided = true
			end
		end
	end

	if canKill then
		v:kill(9)
		return
	end

	local magnitude = data.magnitude

	if data.initialMag then
		data.accelLerp = math.min(data.accelLerp + 0.1, 4)
		magnitude = easing.inCubic(data.accelLerp, data.initialMag, data.magnitude - data.initialMag, 1)

		if data.accelLerp == 1 then
			data.accelLerp = 0
			data.initialMag = nil
		end
	else
		data.accelLerp = 0
	end

	local velocity = data.dirVec * magnitude

	if velocity.x ~= 0 and v.direction ~= math.sign(velocity.x) then
		v.direction = math.sign(velocity.x)
	end

	v.speedX = roundOff(velocity.x)
	v.speedY = roundOff(velocity.y)

	data.collider.x = v.x + v.width/2
	data.collider.y = v.y + v.height/2
	data.collider.rotation = data.rotation

	handleProjectile(v, data)
	explode(v)
end

function laserShot.onDrawNPC(v)
	if v.despawnTimer <= 0 or v.isHidden then
		return
	end

	local data = v.data
	local config = NPC.config[v.id]

	--data.collider:draw(Color.red .. 0.5)
	--data.slopeCollider:draw(Color.red .. 0.5)

	if data.initialized then
		local scaleMod = 1 + math.abs(math.sin(data.timer * 0.5) * 0.5)

		Graphics.drawBox{
			texture = Graphics.sprites.npc[v.id].img,
			x = v.x + v.width/2,
			y = v.y + v.height/2,
			width = config.gfxwidth * data.scale.x * scaleMod,
			height = config.gfxheight * data.scale.y,
			sourceX = 0,
			sourceY = v.animationFrame * config.gfxheight,
			sourceWidth = config.gfxwidth,
			sourceHeight = config.gfxheight,
			priority = -45,
			sceneCoords = true,
			centered = true,
			rotation = data.rotation or (90 * v.direction),
		}
	end

	npcutils.hideNPC(v)
end

return laserShot