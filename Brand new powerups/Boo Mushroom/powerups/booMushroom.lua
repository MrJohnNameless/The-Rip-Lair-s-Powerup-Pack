local cp = require("customPowerups")
local boo = {}

local activePlayer

boo.basePowerup = PLAYER_BIG
boo.items = {}

boo.collectSounds = {
    upgrade = 6,
    reserve = 12,
}

local powerupRevert = require("powerups/powerupRevert")
powerupRevert.register("Boo Mushroom", 2)

boo.settings = {
	floatHeight = 256,	--How high (in pixels) can the player float? (defaults to 256)
}

boo.cheats = {"needabooshroom", "mariothefriendlyghost","ghostbusters"}
boo.blackListedBlocks = {766}

function boo.onInitPowerupLib()
	boo.spritesheets = {
		boo:registerAsset(1, "boo-mario.png"),
		boo:registerAsset(2, "boo-luigi.png"),
		boo:registerAsset(3, "boo-peach.png"),
		boo:registerAsset(4, "boo-toad.png"),
		boo:registerAsset(5, "boo-link.png"),
	}
 
	boo.iniFiles = {
		boo:registerAsset(1, "boo-mario.ini"),
		boo:registerAsset(2, "boo-luigi.ini"),
		boo:registerAsset(3, "boo-peach.ini"),
		boo:registerAsset(4, "boo-toad.ini"),
		boo:registerAsset(5, "boo-link.ini"),
	}
end

-- runs once when the powerup gets activated, passes the player
function boo.onEnable(p)	
	p.collisionGroup = "booPlayer"
	
	for _,n in ipairs(NPC.get()) do
		if n:mem(0x138, FIELD_WORD) == 0 and (not n.isHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 and NPC.HITTABLE_MAP[n.id] and not NPC.config[n.id].powerup and not NPC.config[n.id].nohurt then
			n.collisionGroup = "booNPCs"
			Misc.groupsCollide["booPlayer"]["booNPCs"] = false
		end
	end
	
	for _,block in ipairs(Block.get(boo.blackListedBlocks)) do
		block.collisionGroup = "booBlocks"
		Misc.groupsCollide["booPlayer"]["booBlocks"] = false
	end
	
	p.data.boo = {
		groundCollider = 0,
		notColliding = true,
	}
end

-- runs once when the powerup gets deactivated, passes the player
function boo.onDisable(p)
	p.data.boo = nil
	Misc.groupsCollide["booPlayer"]["booBlocks"] = true
	Misc.groupsCollide["booPlayer"]["booNPCs"] = true
	p:mem(0x154,FIELD_WORD,0) -- lets the player hold items again
end

registerEvent(boo, "onExit", "onExit")

function boo.onExit()
	if activePlayer and cp.getCurrentName(activePlayer) == "Boo Mushroom" then
		cp.setPowerup(2, activePlayer, true)
	end
end

-- runs when the powerup is active, passes the player
function boo.onTickPowerup(p)
	if cp.getCurrentPowerup(p) ~= boo or not p.data.boo then return end -- check if the powerup is currenly active
	local data = p.data.boo
	activePlayer = p
	
	data.climbOnVine = false
	
	if data.groundCollider == 0 then
		data.groundCollider = Colliders.Box(p.x, p.y, 16, boo.settings.floatHeight)
	end
	
	for _,n in ipairs(NPC.get()) do
		if n:mem(0x138, FIELD_WORD) == 0 and (not n.isHidden) and (not n.friendly) and n:mem(0x12C, FIELD_WORD) == 0 then
			if NPC.HITTABLE_MAP[n.id] and not NPC.config[n.id].powerup and not NPC.config[n.id].nohurt then
				if Colliders.collide(p, n) then p:harm() end
			end
			if NPC.config[n.id].isvine and Colliders.collide(p, n) then
				p.keys.up = KEYS_UP
				p.keys.down = KEYS_UP
				data.climbOnVine = true
			end
		end
	end
	
	p:mem(0x154,FIELD_WORD,-2)
	p:mem(0x40, FIELD_WORD, 0)
	
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
	
	local tbl2 = NPC.isValid
	collidingNPCCollider = Colliders.getColliding {
		a = data.groundCollider,
		b = tbl2,
		btype = Colliders.NPC,
		filter = function(other)
			if NPC.config[other.id].playerblocktop or NPC.config[other.id].playerblock or NPC.config[other.id].npcblocktop then
				return true
			end
			return false
		end
	}
	
	if #collidingBlocksCollider > 0 or #collidingNPCCollider > 0 or data.climbOnVine then
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
	
	p:mem(0x160, FIELD_WORD, 0)
	p:mem(0x1C, FIELD_WORD, 0)
	
	local warpTable = Warp.getIntersectingEntrance(p.x, p.y, p.x + p.width / 2, p.y + p.height / 2)
	local w = warpTable[#warpTable]
	if (w and w.isValid and not w.isHidden) and (w.warpType == 1 or w.warpType == 2) then return end
	if p:mem(0x146, FIELD_WORD) == 2 then p.speedY = -6 end
	if p:mem(0x148, FIELD_WORD) == 2 then p.speedX = 3 end
	if p:mem(0x14A, FIELD_WORD) == 2 then p.speedY = 3 end
	if p:mem(0x14C, FIELD_WORD) == 2 then p.speedX = -3 end
end

function boo.onTickEndPowerup(p)
	if cp.getCurrentPowerup(p) ~= boo or not p.data.boo then return end -- check if the powerup is currently active
	p.frame = math.floor(lunatime.tick() / 24) % 2 + 1
end

return boo