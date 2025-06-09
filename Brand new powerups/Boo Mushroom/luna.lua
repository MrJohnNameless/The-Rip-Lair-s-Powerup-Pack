local cp = require("customPowerups")

function onPostNPCCollect(v, p)
    if (v.id == 184 or v.id == 250 or v.id == 9 or v.id == 185) and cp.getCurrentName(p) == "Boo Mushroom" then
       cp.setPowerup(2, p, true)
    end
end