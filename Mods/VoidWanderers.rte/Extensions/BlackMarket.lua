-- Black Market exclusives
CF_FactionNames["Black Market"] = "Black Market"
local id = #CF_BlackMarketItmPresets

id = id + 1
CF_BlackMarketItmPresets[id] = "Prosthetic Arm"
CF_BlackMarketItmModules[id] = CF_ModuleName
CF_BlackMarketItmClasses[id] = "HeldDevice"
CF_BlackMarketItmPrices[id] = 25
CF_BlackMarketItmDescriptions[id] = "Need a hand?"

id = id + 1
CF_BlackMarketItmPresets[id] = "Prosthetic Leg"
CF_BlackMarketItmModules[id] = CF_ModuleName
CF_BlackMarketItmClasses[id] = "HeldDevice"
CF_BlackMarketItmPrices[id] = 25
CF_BlackMarketItmDescriptions[id] = "Break a leg!"

id = id + 1
CF_BlackMarketItmPresets[id] = "YAK-4700"
CF_BlackMarketItmModules[id] = CF_ModuleName
CF_BlackMarketItmClasses[id] = "HDFirearm"
CF_BlackMarketItmPrices[id] = 200
CF_BlackMarketItmDescriptions[id] = "Someone's tampered with this gun, I can tell..."

if PresetMan:GetModuleID("MyMod.rte") ~= -1 then
	id = id + 1
	CF_BlackMarketItmPresets[id] = "My Gun"
	CF_BlackMarketItmModules[id] = "MyMod.rte"
	CF_BlackMarketItmClasses[id] = "HDFirearm"
	CF_BlackMarketItmPrices[id] = 100
	CF_BlackMarketItmDescriptions[id] = "It's my gun!"
end

--[[
id = id + 1
CF_BlackMarketItmPresets[id] = "Uber Grenade Launcher"
CF_BlackMarketItmModules[id] = CF_ModuleName
CF_BlackMarketItmClasses[id] = "HDFirearm"
CF_BlackMarketItmPrices[id] = 700

id = id + 1
CF_BlackMarketItmPresets[id] = "Frag Nailer Machinegun"
CF_BlackMarketItmModules[id] = CF_ModuleName
CF_BlackMarketItmClasses[id] = "HDFirearm"
CF_BlackMarketItmPrices[id] = 500

id = id + 1
CF_BlackMarketItmPresets[id] = "Big Iron"
CF_BlackMarketItmModules[id] = CF_ModuleName
CF_BlackMarketItmClasses[id] = "HDFirearm"
CF_BlackMarketItmPrices[id] = 250
]]--