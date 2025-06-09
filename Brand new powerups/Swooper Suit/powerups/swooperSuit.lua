local cp = require("customPowerups")
local swooper = {}

function swooper.onInitPowerupLib()
	swooper.spritesheets = {
		swooper:registerAsset(1, "swooper-mario.png"),
		swooper:registerAsset(2, "swooper-luigi.png"),
	}

	swooper.iniFiles = {
		swooper:registerAsset(1, "swooper-mario.ini"),
		swooper:registerAsset(2, "swooper-luigi.ini"),
	}
end

swooper.basePowerup = PLAYER_FIREFLOWER
swooper.items = {}
swooper.forcedStateType = 2

swooper.collectSounds = {
    upgrade = 34,
    reserve = 12,
}

local swooper_flap = Misc.resolveSoundFile("swooperflap")

-- runs once when the powerup gets activated, passes the player
function swooper.onEnable(p)	
	p.data.swooper = {
		isFlying = false,
		flyTimer = 0,
		flapSpeed = 6,
		canFly = 0,
		slowPlayer = 4,
		
		
		--*******************
		--Custom configs here
		--*******************
		
		
		--Set this to be whatever you want, flight time
		flightTime = 128,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function swooper.onDisable(p)	
	p.data.swooper = nil
end

local activePlayer

registerEvent(swooper, "onExit", "onExit")

function swooper.onExit()
	if activePlayer and cp.getCurrentPowerup(activePlayer) == swooper then
		activePlayer.data.swooper.isFlying = false
		activePlayer.data.swooper.flyTimer = 0
		activePlayer.data.swooper.canFly = 0
		activePlayer.data.swooper.flapSpeed = 6
		activePlayer.data.swooper.slowPlayer = 4
	end
end

-- runs when the powerup is active, passes the player
function swooper.onTickPowerup(p)
	if cp.getCurrentPowerup(p) ~= swooper or not p.data.swooper or p:mem(0x0C, FIELD_BOOL) then return end -- check if the powerup is currenly active
	local data = p.data.swooper
	activePlayer = p
	
	if p.character ~= 5 then
		p:mem(0x160, FIELD_WORD, 2)
	end

	if not data.isFlying then
		if not p:isOnGround() and p.keys.jump == KEYS_PRESSED and (p:mem(0x34, FIELD_WORD) == 0 and not p:isClimbing() and p.mount == 0) then
			data.isFlying = true
		end
		if p:isOnGround() then
			data.canFly = 0
			data.flapSpeed = 6
			data.slowPlayer = 4
			data.flyTimer = 0
		end
	else
		if p.character ~= 2 then
			p.speedY = (-Defines.player_grav - 0.000000000001) + data.canFly
		else
			p.speedY = ((-Defines.player_grav + 0.04) - 0.000000000001) + data.canFly
		end
		p.speedX = math.clamp(p.speedX, -data.slowPlayer, data.slowPlayer)
		if data.flyTimer % 24 == 7 then
			SFX.play(swooper_flap)
		end
		if p.keys.jump == KEYS_PRESSED or p:isOnGround() or p:isClimbing() or p.mount ~= 0 or p:mem(0x34, FIELD_WORD) ~= 0 or (p.forcedState ~= 0 and p.forcedState ~= 7) then
			data.isFlying = false
		end
		if data.flyTimer == data.flightTime then
			data.flapSpeed = 4
			data.slowPlayer = 2.5
			SFX.play(49)
		end
		if data.flyTimer >= data.flightTime + 64 then
			data.canFly = 2
		end
		p.keys.down = KEYS_UP
	end
	
	if p:isClimbing() or p:mem(0x34, FIELD_WORD) == 2 then
		data.isFlying = false
		data.canFly = 0
		data.flapSpeed = 6
		data.slowPlayer = 4
		data.flyTimer = 0
	end
end

function swooper.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= swooper or not p.data.swooper then return end -- check if the powerup is currently active
	local data = p.data.swooper
	if data.isFlying then
		p.frame = 1
		if p.forcedState ~= 7 then data.flyTimer = data.flyTimer + 1 end
		p.frame = math.floor(data.flyTimer / data.flapSpeed) % 4 + 32
	end	
end

return swooper