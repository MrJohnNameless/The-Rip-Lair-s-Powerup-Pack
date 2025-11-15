local cp = require("customPowerups")
local dkg = {}

dkg.basePowerup = PLAYER_FIREFLOWER
dkg.items = {}

dkg.collectSounds = {
    upgrade = ("powerups/Hey I can fly.wav"),
    reserve = 12,
}

local powerupRevert = require("powerups/powerupRevert")
powerupRevert.register(dkg, 2)

dkg.cheats = {"needadonkeygoomba"}
dkg.blackListedBlocks = {766}

function dkg.onInitPowerupLib()
	dkg.spritesheets = {
		dkg:registerAsset(1, "DKG-mario.png"),
		dkg:registerAsset(2, "DKG-luigi.png"),
	}
 
	dkg.iniFiles = {
		dkg:registerAsset(1, "DKG-mario.ini"),
		dkg:registerAsset(2, "DKG-luigi.ini"),
	}
end

-- runs once when the powerup gets activated, passes the player
function dkg.onEnable(p)	
	p.collisionGroup = "dkgPlayer"
	
	for _,n in ipairs(NPC.get()) do
		if n:mem(0x138, FIELD_WORD) == 0 and (not n.isHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 and NPC.HITTABLE_MAP[n.id] then
			n.collisionGroup = "dkgNPCs"
			Misc.groupsCollide["dkgPlayer"]["dkgNPCs"] = false
		end
	end
	
	p.data.dkg = {
		groundCollider = 0,
		notColliding = true,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function dkg.onDisable(p)
	p.data.dkg = nil
	Misc.groupsCollide["dkgPlayer"]["dkgNPCs"] = true
	p:mem(0x154,FIELD_WORD,0) -- lets the player hold items again
end

dkg.ignore = {};
dkg.ignore[108] = true;

local function starmanFilter(v)
	return Colliders.FILTER_COL_NPC_DEF(v) and not dkg.ignore[v.id];
end

-- runs when the powerup is active, passes the player
function dkg.onTickPowerup(p)
	if cp.getCurrentPowerup(p) ~= dkg or not p.data.dkg then return end -- check if the powerup is currenly active
	local data = p.data.dkg
	
	if data.groundCollider == 0 then
		data.groundCollider = Colliders.Box(p.x, p.y, 16, 256)
	end
	
	p:mem(0x140, FIELD_WORD, 2);
	p:mem(0x142, FIELD_WORD, 0);
	
	for _,n in ipairs(NPC.get()) do
		if n:mem(0x138, FIELD_WORD) == 0 and (not n.isHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 and NPC.HITTABLE_MAP[n.id] then
			if Colliders.collide(p, n) then n:harm(HARM_TYPE_EXT_HAMMER); end
		end
	end
	
	p:mem(0x154,FIELD_WORD,-2)
	p:mem(0x40, FIELD_WORD, 0)
	
	p:mem(0x160, FIELD_WORD, 0)
	
	-- lose the powerup whenever the player touches water
	-- bit of code by MrNameless
	if p:mem(0x36,FIELD_BOOL) then
		p:harm()
		return
	end
	
	data.groundCollider.x = p.x
	data.groundCollider.y = p.y
	
	local tbl = Block.SOLID .. Block.PLAYER .. Block.SEMISOLID .. Block.SIZEABLE
	collidingBlocksCollider = Colliders.getColliding {
		a = data.groundCollider,
		b = tbl,
		btype = Colliders.BLOCK
	}
	
	if #collidingBlocksCollider > 0 then
		if (p.keys.jump or p.keys.altJump) then
			if p.speedY > -4 then p.speedY = p.speedY - 0.5 end
			data.notColliding = false
		else
			data.notColliding = true
		end
	else
		data.notColliding = true
	end
	
	if data.notColliding then
		if not p.keys.down then
			p.speedY = math.min(p.speedY, 1.5)
		else
			p.speedY = math.min(p.speedY, 3.5)
		end
	end
	
	if p:mem(0x146, FIELD_WORD) == 2 then p.speedY = -6 end
	if p:mem(0x148, FIELD_WORD) == 2 then p.speedX = 3 end
	if p:mem(0x14A, FIELD_WORD) == 2 then p.speedY = 3 end
	if p:mem(0x14C, FIELD_WORD) == 2 then p.speedX = -3 end
end

function dkg.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= dkg or not p.data.dkg then return end -- check if the powerup is currently active
	p.frame = math.floor(lunatime.tick() / 24) % 2 + 1
end

return dkg