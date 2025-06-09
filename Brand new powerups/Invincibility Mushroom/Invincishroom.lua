local npcManager = require("npcManager")
local Invincishroom = {}

SaveData[Level.filename()] = SaveData[Level.filename()] or {}
SaveData[Level.filename()].invinci_deaths = SaveData[Level.filename()].invinci_deaths or 0

if SaveData.invinciDeaths == nil then
	SaveData.invinciDeaths = {}
end

if SaveData.invinciDeaths[Level.filename()] == nil then
	SaveData.invinciDeaths[Level.filename()] = 0
end

Invincishroom.enabled = true
Invincishroom.collected = false
Invincishroom.particleEffects = true
Invincishroom.deathsRequired = 5
Invincishroom.npcID = 997

local deathCount = SaveData.invinciDeaths[Level.filename()]
local sparkle = Particles.Emitter(0, 0, Misc.resolveFile("particles/p_starman_sparkle.ini"))

registerEvent(Invincishroom, "onStart")
registerEvent(Invincishroom, "onTick")
registerEvent(Invincishroom, "onDraw")
registerEvent(Invincishroom, "onPostNPCKill")
registerEvent(Invincishroom, "onPostPlayerKill")
registerEvent(Invincishroom, "onExitLevel")

function Invincishroom.onStart()
	sparkle:Attach(player)

	if deathCount == Invincishroom.deathsRequired then
		local spawnedNPC = NPC.spawn(Invincishroom.npcID, player.x+player.width/2, player.y - NPC.config[Invincishroom.npcID].height/2, player.section, false, true)
		spawnedNPC.speedY = -7
	end
end

function Invincishroom.onTick()
end

function Invincishroom.onDraw()
	if deathCount > Invincishroom.deathsRequired then
		deathCount = Invincishroom.deathsRequired
	end

	if Invincishroom.collected and player.deathTimer == 0 then
		local priority = -25
		local wid = "-".. (player.width*0.5)..":"..(player.width*0.5)
		local hei = "-"..(player.height*0.5)..":"..(player.height*0.5)

		if (player.forcedState == 3) then
			priority = -70
		else
			priority = -25
		end

		player:mem(0x140, FIELD_WORD, 2)
		player:mem(0x142, FIELD_WORD, 0);
		sparkle:setParam("xOffset",wid)
		sparkle:setParam("yOffset",hei)
		sparkle:Draw(priority)
	end
end

function Invincishroom.onPostNPCKill(v, reason)
	if v.id ~= Invincishroom.npcID then return end

    if npcManager.collected(v, reason) then
		Invincishroom.collected = true
		SFX.play("invincishroom.ogg")
    end
end

function Invincishroom.onPostPlayerKill(p)
	deathCount = deathCount + 1
end

function Invincishroom.onExitLevel(win)
	Invincishroom.collected = false
	if win > 0 then
		deathCount = 0
	end
end

return Invincishroom