local cp = require("customPowerups")

--Add your warps in this table here!
--For example, if you want the first, third warp and fourth warp to only be enterable by mini mario, do this.
--local miniWarps = {1, 3, 4}

local miniWarps = {}

function onWarpEnter(token,warp,p)
	for _,w in ipairs(miniWarps) do
		if cp.getCurrentName(p) == "Mini-Mushroom" and warp == Warp.get()[w] then
			token.cancelled = true
		end
	end
end