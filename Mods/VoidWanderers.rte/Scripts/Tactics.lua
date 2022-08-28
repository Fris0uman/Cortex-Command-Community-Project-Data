-----------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
-- Start Activity
-----------------------------------------------------------------------------------------
function VoidWanderers:StartActivity()
	print ("VoidWanderers:Tactics:StartActivity");

	-- Disable string rendering optimizations because letters start to fall down )))
	CF_FrameCounter = 0

	if self.IsInitialized == nil then
		self.IsInitialized = false
	end
	
	self.BuyMenuEnabled = false

	if self.IsInitialized then
		return
	end
		
	self.IsInitialized = true
	self.ShopsCreated = false
	
	self.LastMusicType = -1
	self.LastMusicTrack = -1
	
	self.GS = {};
	--self.ModuleName = "VoidWanderers.rte";
	
	self.TickTimer = Timer();
	self.TickTimer:Reset();
	self.TickInterval = CF_TickInterval;
	
	self.TeleportEffectTimer = Timer()
	self.TeleportEffectTimer:Reset()

	self.HoldTimer = Timer()
	self.HoldTimer:Reset()	
	
	self.RandomEncounterDelayTimer = nil
	
	self.FlightTimer = Timer()
	self.FlightTimer:Reset()
	self.LastTrigger = 0

	-- All items in this queue will be removed
	self.ItemRemoveQueue = {}
	
	-- Factions are already initialized by strategic part
	self:LoadCurrentGameState();
	
	CF_GS = self.GS

	self.RandomEncounterID = nil
	self.Ship = nil
	self.EngineEmitters = nil
	
	self.PlayerFaction = self.GS["Player0Faction"]
	
	-- If activity was reset during mission switch back to mission mode
	if self.GS["WasReset"] == "True" then
		self.GS["Mode"] = "Vessel"
		self.GS["SceneType"] = "Vessel"
		self.GS["WasReset"] = nil
	end

	self.AlliedUnits = nil
	-- Artificial Gravity System
	self.AGS = Vector(0, rte.PxTravelledPerFrame/(1 + SceneMan.Scene.GlobalAcc.Y));
	local setAIDifficulty = math.floor((50 + CF_Difficulty) * 0.5)
	
	-- Adjust Fog of War based on map size
	if SceneMan.Scene then
		CF_FogOfWarResolution = 48 * math.ceil(math.sqrt(SceneMan.Scene.Width^2 + SceneMan.Scene.Height^2)/1500)
	end
	
	-- Read brain location data
	if self.GS["SceneType"] == "Vessel" then
		-- Load vessel level data
		self.LS = CF_ReadSceneConfigFile(self.ModuleName , SceneMan.Scene.PresetName.."_deploy.dat");

		self.BrainPos = {}
		for i = 1, 4 do
			local x,y;
			
			x = tonumber(self.LS["BrainSpawn"..i.."X"])
			y = tonumber(self.LS["BrainSpawn"..i.."Y"])
			self.BrainPos[i] = Vector(x,y)
		end

		self.EnginePos = {}
		for i = 1, 10 do
			local x,y;
			
			x = tonumber(self.LS["Engine"..i.."X"])
			y = tonumber(self.LS["Engine"..i.."Y"])
			if x and y then
				self.EnginePos[i] = Vector(x,y)
			else
				break
			end
		end

		self.AwayTeamPos = {}
		
		for i = 1, 16 do
			local x,y;
			
			x = tonumber(self.LS["AwayTeamSpawn"..i.."X"])
			y = tonumber(self.LS["AwayTeamSpawn"..i.."Y"])
			
			if x and y then
				self.AwayTeamPos[i] = Vector(x,y)
			else
				break
			end
		end
		
		self.CreatedBrains = {}
		
		-- Create brains
		--print ("Create brains")
		for player = 0, self.PlayerCount - 1 do
			if self.GS["Brain"..player.."Detached"] ~= "True" then
				local a = CreateActor("Brain Case", "Base.rte")
				if a then
					a.Team = CF_PlayerTeam;
					a.Pos = self.BrainPos[player + 1];
					MovableMan:AddActor(a)
					self.CreatedBrains[player] = a
				end
			end
		end
		
		self.Ship = SceneMan.Scene:GetArea("Vessel")
		
		local spawnedactors = 1
		local dest = 1

		-- Spawn previously saved actors
		for i = 1, CF_MaxSavedActors do
			if self.GS["Actor"..i.."Preset"] then
				local limbData = {};
				for j = 1, #CF_LimbID do
					limbData[j] = self.GS["Actor"..i..CF_LimbID[j]];
				end
				local actor = CF_MakeActor(self.GS["Actor"..i.."Preset"], self.GS["Actor"..i.."Class"], self.GS["Actor"..i.."Module"], self.GS["Actor"..i.."XP"], self.GS["Actor"..i.."Identity"], self.GS["Actor"..i.."Prestige"], self.GS["Actor"..i.."Name"], limbData)
				if actor then
					actor.AIMode = Actor.AIMODE_SENTRY;
					actor:ClearAIWaypoints();
					
					actor.Team = CF_PlayerTeam
					for j = 1, CF_MaxSavedItemsPerActor do
						--print(self.GS["Actor"..i.."Item"..j.."Preset"])
						if self.GS["Actor"..i.."Item"..j.."Preset"] then
							local itm = CF_MakeItem(self.GS["Actor"..i.."Item"..j.."Preset"], self.GS["Actor"..i.."Item"..j.."Class"], self.GS["Actor"..i.."Item"..j.."Module"])
							if itm then
								actor:AddInventoryItem(itm)
							end
						else
							break
						end
					end
					local x = self.GS["Actor"..i.."X"]
					local y = self.GS["Actor"..i.."Y"]
					
					if x and y then
						actor.Pos = Vector(tonumber(x), tonumber(y))
					else
						actor.Pos = self.AwayTeamPos[dest]
						dest = dest + 1
						
						if dest > #self.AwayTeamPos then
							dest = 1
						end
					end
					MovableMan:AddActor(actor)
					self:AddPreEquippedItemsToRemovalQueue(actor)

					spawnedactors = spawnedactors + 1
				end
			else
				break
			end
		end
		
		-- Spawn previously deployed actors
		if self.DeployedActors then
			local dest = 1;
			
			-- Not only we need to spawn deployed actors but we also need to save them to config
			-- if we don't do that once player will restart the game after mission away-team actors will disappear
			for i = 1, #self.DeployedActors do
				local limbData = {}
				--Move this?
				for j = 1, #CF_LimbID do
					limbData[j] = self.DeployedActors[i][CF_LimbID[j]];
				end
				local actor = CF_MakeActor(self.DeployedActors[i]["Preset"], self.DeployedActors[i]["Class"], self.DeployedActors[i]["Module"], self.DeployedActors[i]["XP"], self.DeployedActors[i]["Identity"], self.DeployedActors[i]["Prestige"], self.DeployedActors[i]["Name"], limbData)
				if actor then
					actor.AIMode = Actor.AIMODE_SENTRY;
					actor:ClearAIWaypoints();
				
					actor.Team = CF_PlayerTeam
					
					self.GS["Actor"..spawnedactors.."Preset"] = actor.PresetName
					self.GS["Actor"..spawnedactors.."Class"] = actor.ClassName
					self.GS["Actor"..spawnedactors.."Module"] = actor.ModuleName
					self.GS["Actor"..spawnedactors.."X"] = math.ceil(actor.Pos.X)
					self.GS["Actor"..spawnedactors.."Y"] = math.ceil(actor.Pos.Y)
					self.GS["Actor"..spawnedactors.."XP"] = actor:GetNumberValue("VW_XP")
					self.GS["Actor"..spawnedactors.."Identity"] = actor:GetNumberValue("Identity")
					self.GS["Actor"..spawnedactors.."Prestige"] = actor:GetNumberValue("VW_Prestige")
					self.GS["Actor"..spawnedactors.."Name"] = actor:GetNumberValue("VW_Name")
					for j = 1, #CF_LimbID do
						self.GS["Actor"..spawnedactors..CF_LimbID[j]] = limbData[j]
					end
					
					--print (#self.DeployedActors[i]["InventoryPresets"])
					
					for j = 1, #self.DeployedActors[i]["InventoryPresets"] do
						local itm = CF_MakeItem(self.DeployedActors[i]["InventoryPresets"][j], self.DeployedActors[i]["InventoryClasses"][j], self.DeployedActors[i]["InventoryModules"][j])
						if itm then
							actor:AddInventoryItem(itm)
							
							self.GS["Actor"..spawnedactors.."Item"..j.."Preset"] = self.DeployedActors[i]["InventoryPresets"][j]
							self.GS["Actor"..spawnedactors.."Item"..j.."Class"] = self.DeployedActors[i]["InventoryClasses"][j]
							self.GS["Actor"..spawnedactors.."Item"..j.."Module"] = self.DeployedActors[i]["InventoryModules"][j]
						end
					end
					actor.Pos = self.AwayTeamPos[dest]
					MovableMan:AddActor(actor)
					self:AddPreEquippedItemsToRemovalQueue(actor)
					
					spawnedactors = spawnedactors + 1
				end
			
				dest = dest + 1
				if dest > #self.AwayTeamPos then
					dest = 1
				end
			end
		end
		
		-- If we'er on temp-location then cancel this location
		if CF_IsLocationHasAttribute(self.GS["Location"], CF_LocationAttributeTypes.TEMPLOCATION) then
			self.GS["Location"] = nil
		end
		
		self.DeployedActors = nil
		self:SaveCurrentGameState()
	else
		-- Load generic level data
		self.LS = CF_ReadSceneConfigFile(self.ModuleName , SceneMan.Scene.PresetName..".dat");
	end

	-- Spawn away-team objects
	if self.GS["Mode"] == "Mission" then
		self:StartMusic(CF_MusicTypes.MISSION_CALM)
	
		self.GS["WasReset"] = "True"
	
		-- All mission related final message will be accumulated in mission report list
		self.MissionDeployedTroops = #self.DeployedActors
		
		self.AlliedUnits = {}
	
		local scene = SceneMan.Scene.PresetName

		self.Pts =  CF_ReadPtsData(scene, self.LS)
		self.MissionDeploySet = CF_GetRandomMissionPointsSet(self.Pts, "Deploy")
		
		-- Convert non-CPU doors
		if CF_LocationRemoveDoors[self.GS["Location"]] then
			for actor in MovableMan.Actors do
				if actor.ClassName == "ADoor" then
					actor.Team = CF_CPUTeam
				end
			end
		end
	
		-- Find suitable LZ's
		local lzs = CF_GetPointsArray(self.Pts, "Deploy", self.MissionDeploySet, "PlayerLZ")
		self.LZControlPanelPos  = CF_SelectRandomPoints(lzs, self.PlayerCount)
		
		-- Init LZ's
		self:InitLZControlPanelUI()
		
		local dest = 1;
		local dsts = CF_GetPointsArray(self.Pts, "Deploy", self.MissionDeploySet, "PlayerUnit")
		
		-- Spawn player troops
		for i = 1, #self.DeployedActors do
			local limbData = {};
			for j = 1, #CF_LimbID do
				limbData[j] = self.DeployedActors[i][CF_LimbID[j]];
			end
			local actor = CF_MakeActor(self.DeployedActors[i]["Preset"], self.DeployedActors[i]["Class"], self.DeployedActors[i]["Module"], self.DeployedActors[i]["XP"], self.DeployedActors[i]["Identity"], self.DeployedActors[i]["Prestige"], self.DeployedActors[i]["Name"], limbData)
			if actor then
				actor.Team = CF_PlayerTeam
				actor.AIMode = Actor.AIMODE_SENTRY
				actor:ClearAIWaypoints();
				for j = 1, #self.DeployedActors[i]["InventoryPresets"] do
					local itm = CF_MakeItem(self.DeployedActors[i]["InventoryPresets"][j], self.DeployedActors[i]["InventoryClasses"][j], self.DeployedActors[i]["InventoryModules"][j])
					if itm then
						actor:AddInventoryItem(itm)
					end
				end
				actor.Pos = dsts[dest]
				MovableMan:AddActor(actor)
				self:AddPreEquippedItemsToRemovalQueue(actor)
			end
		
			dest = dest + 1
			if dest > #dsts then
				dest = 1
			end
		end
		self.DeployedActors = nil
		
		-- Spawn crates
		local randomLocationsRate = 0.25
		local crts = CF_GetPointsArray(self.Pts, "Deploy", self.MissionDeploySet, "Crates")
		local amount = math.ceil(CF_CratesRate * #crts)
		--print ("Crates: "..amount)
		local crtspos = CF_SelectRandomPoints(crts, amount)
		
		for i = 1, #crtspos do
			local crt = math.random() < CF_ActorCratesRate and CreateMOSRotating("Crate", self.ModuleName) or (math.random() < 0.01 and CreateAHuman("Case", self.ModuleName) or CreateAttachable("Case", self.ModuleName))

			if crt then
				crt.Pos = crtspos[i]
				if math.random() < randomLocationsRate then
					-- Try to spawn a crate at a totally random location
					local materialThreshold = 200;	-- The average strength of the terrain surrounding the crate has to be below this
					local surroundingStrength = 0;
					local checkPos = Vector((SceneMan.SceneWrapsX and math.random(SceneMan.SceneWidth) or math.random(50, SceneMan.SceneWidth - 50)), math.random(SceneMan.SceneHeight * 0.5, SceneMan.SceneHeight - 50));
					local terrCheck = SceneMan:GetTerrMatter(checkPos.X, checkPos.Y);
					if terrCheck ~= rte.airID then
						surroundingStrength = surroundingStrength + SceneMan:GetMaterialFromID(terrCheck).StructuralIntegrity;
						local dots = 5;
						local radius = crt.Radius;
						for i = 1, dots do
							local checkPos2 = checkPos + Vector(radius, 0):RadRotate(math.pi * 2 * i/dots);
							local terrCheck2 = SceneMan:GetTerrMatter(checkPos2.X, checkPos2.Y);
							surroundingStrength = surroundingStrength + (terrCheck2 ~= rte.airID and SceneMan:GetMaterialFromID(terrCheck2).StructuralIntegrity or materialThreshold * 2);
						end
						if surroundingStrength < materialThreshold * (1 + dots) then
							crt.Pos = checkPos
						end
					end
				end
				crt.PinStrength = crt.GibImpulseLimit * 0.8
				MovableMan:AddMO(crt)
			end
		end
		
		--	Prepare for mission, load scripts
		self.MissionAvailable = false
		local missionscript
		local ambientscript
		
		self.MissionStatus = nil
		
		-- Set generic mission difficulty based on location security
		local diff = CF_GetLocationDifficulty(self.GS, self.GS["Location"])
		self.MissionDifficulty = diff
		-- Set enemy AI skill based on location difficulty
		setAIDifficulty = math.floor(CF_Difficulty + (CF_Difficulty * 0.5 * diff/CF_MaxDifficulty))
		
		-- Find available mission
		for m = 1, CF_MaxMissions do
			if self.GS["Location"] == self.GS["Mission"..m.."Location"] then -- GAMEPLAY
				self.MissionAvailable = true
				
				self.MissionNumber = m
				self.MissionType = self.GS["Mission"..m.."Type"]
				self.MissionDifficulty = CF_GetFullMissionDifficulty(self.GS, self.GS["Location"], m)--tonumber(self.GS["Mission"..m.."Difficulty"])
				self.MissionSourcePlayer = tonumber(self.GS["Mission"..m.."SourcePlayer"])
				self.MissionTargetPlayer = tonumber(self.GS["Mission"..m.."TargetPlayer"])

				-- DEBUG
				--self.MissionDifficulty = CF_MaxDifficulty -- DEBUG
				--self.MissionType = "Assault" -- DEBUG
				--self.MissionType = "Assassinate" -- DEBUG
				--self.MissionType = "Dropships" -- DEBUG
				--self.MissionType = "Mine" -- DEBUG
				--self.MissionType = "Zombies" -- DEBUG
				--self.MissionType = "Defend" -- DEBUG
				--self.MissionType = "Destroy" -- DEBUG
				--self.MissionType = "Squad" -- DEBUG
				
				self.MissionScript = CF_MissionScript[ self.MissionType ]
				self.MissionGoldReward = CF_CalculateReward(CF_MissionGoldRewardPerDifficulty[ self.MissionType ] , self.MissionDifficulty)
				self.MissionReputationReward = CF_CalculateReward(CF_MissionReputationRewardPerDifficulty[ self.MissionType ] , self.MissionDifficulty)
				
				self.MissionStatus = "" -- Will be updated by mission script

				-- Create unit presets
				CF_CreateAIUnitPresets(self.GS, self.MissionSourcePlayer , CF_GetTechLevelFromDifficulty(self.GS, self.MissionSourcePlayer, self.MissionDifficulty, CF_MaxDifficulty))
				CF_CreateAIUnitPresets(self.GS, self.MissionTargetPlayer , CF_GetTechLevelFromDifficulty(self.GS, self.MissionTargetPlayer, self.MissionDifficulty, CF_MaxDifficulty))
				
				break
			end -- GAMEPLAY
		end
		
		if self.MissionAvailable then
			-- Increase location security every time mission started
			local sec = CF_GetLocationSecurity(self.GS, self.GS["Location"])
			sec = sec + CF_SecurityIncrementPerMission
			CF_SetLocationSecurity(self.GS, self.GS["Location"], sec)
		
			missionscript = self.MissionScript
			ambientscript = CF_LocationAmbientScript[ self.GS["Location"] ]
		else
			-- Slightly increase location security every time deplyment happens
			local sec = CF_GetLocationSecurity(self.GS, self.GS["Location"])
			sec = sec + CF_SecurityIncrementPerDeployment
			CF_SetLocationSecurity(self.GS, self.GS["Location"], sec)

			if CF_LocationScript[ self.GS["Location"] ] then
				local r = math.random(#CF_LocationScript[ self.GS["Location"] ])
				missionscript = CF_LocationScript[ self.GS["Location"] ][r]
			end
			
			ambientscript = CF_LocationAmbientScript[ self.GS["Location"] ]
		end
		
		self.MissionReport = {}
		
		if missionscript == nil then
			missionscript = "VoidWanderers.rte/Scripts/Mission_Generic.lua"
		end
		
		if ambientscript == nil then
			ambientscript = "VoidWanderers.rte/Scripts/Ambient_Generic.lua"
		end
		
		self.MissionStartTime = tonumber(self.GS["Time"])
		self.MissionEndMusicPlayed = false
		
		self.SpawnTable = {}
		
		-- Clear previous script functions
		self.MissionCreate = nil
		self.MissionUpdate = nil
		self.MissionDestroy = nil

		self.AmbientCreate = nil
		self.AmbientUpdate = nil
		self.AmbientDestroy = nil
		
		dofile(missionscript)
		dofile(ambientscript)
		
		self:MissionCreate()
		self:AmbientCreate()
		
		-- Set unseen
		if self.GS["FogOfWar"] and self.GS["FogOfWar"] == "true" then
			SceneMan:MakeAllUnseen(Vector(CF_FogOfWarResolution, CF_FogOfWarResolution), CF_PlayerTeam);
			
			-- Reveal previously saved fog of war
			-- But do not reveal on vessel maps
			if not CF_IsLocationHasAttribute(self.GS["Location"], CF_LocationAttributeTypes.ALWAYSUNSEEN) then
				local wx = math.ceil(SceneMan.Scene.Width / CF_FogOfWarResolution);
				local wy = math.ceil(SceneMan.Scene.Height / CF_FogOfWarResolution);
				local str = "";
				
				for y = 0, wy do
					str = self.GS[self.GS["Location"].."-Fog"..tostring(y)];
					-- print (str);
					if str then
						for x = 0, wx do
							-- print(string.sub(str, x + 1 , x + 1))
							if string.sub(str, x + 1, x + 1) == "1" then
								SceneMan:RevealUnseen(x * CF_FogOfWarResolution , y * CF_FogOfWarResolution , CF_PlayerTeam);
							end
						end
					end
				end
			end
		end
		
		-- Set unseen for AI (maybe some day it will matter ))))
		for p = Activity.PLAYER_2, Activity.PLAYER_4 do
			SceneMan:MakeAllUnseen(Vector(CF_FogOfWarResolution, CF_FogOfWarResolution), p);
		end
	else
		self:StartMusic(CF_MusicTypes.SHIP_CALM)
	end
	
	self:SetTeamAISkill(CF_CPUTeam, setAIDifficulty)
	print("Enemy AI skill is set at " .. setAIDifficulty)
	
	-- Load pre-spawned enemy locations. These locations also used during assaults to place teleported units
	self.EnemySpawn = {}
	for i = 1, 32 do
		local x,y;
		
		x = tonumber(self.LS["EnemySpawn"..i.."X"])
		y = tonumber(self.LS["EnemySpawn"..i.."Y"])
		if x and y then
			self.EnemySpawn[i] = Vector(x,y)
		else
			break
		end
	end
	
	self.GenericTimer = Timer();
	self.GenericTimer:Reset();

	self.AISpawnTimer = Timer();
	self.AISpawnTimer:Reset();
	
	self.IsInitialized = true

	self.HumanPlayer = 0

	for player = 0, self.PlayerCount - 1 do
		self:SetPlayerBrain(nil, player);
	end	
	-- Display gold like normal since the buy menu is disabled
	self:SetTeamFunds(CF_GetPlayerGold(self.GS, CF_PlayerTeam), CF_PlayerTeam);

	self:SaveCurrentGameState();
	
	-- Init consoles if in Vessel mode
	if self.GS["Mode"] == "Vessel" and self.GS["SceneType"] == "Vessel" then
		self:InitConsoles()
		if self.GS["Location"] ~= "Station Ypsilon-2" then
			local newLoc = Vector(48, 48):DegRotate(tonumber(self.GS["Time"]) * 0.1);
			newLoc = Vector(math.floor(newLoc.X), math.floor(newLoc.Y));
			CF_LocationPos["Station Ypsilon-2"] = newLoc;
		end
	end
	
	self.gravityPerFrame = SceneMan.Scene.GlobalAcc * TimerMan.DeltaTimeSecs;

	self.AssaultTime = -100
	
	self.BrainSwitchTimer = Timer()
	self.BrainSwitchTimer:Reset()
	
	self:DoBrainSelection()
	self.EnableBrainSelection = true

	-- Init icon display data
	self.Icon = CreateMOSRotating("Icon_Generic", self.ModuleName)
	self.IconFrame = {}

	--self.Icon[0] = ALLY_ICON
	self.IconFrame[1] = {findByName = {"Heavy Digger", "Remote Explosive", "Timed Explosive"}}
	self.IconFrame[2] = {findByGroup = {"Tools - Diggers"}}
	self.IconFrame[3] = {findByGroup = {"Weapons - Explosive"}}
	self.IconFrame[4] = {findByName = {"Medikit", "Medical Dart Gun", "First Aid Kit", "Medical Healer Mk3"}}
	self.IconFrame[5] = {findByName = {"Light Scanner", "Medium Scanner", "Heavy Scanner"}}
	self.IconFrame[6] = {findByGroup = {"Weapons - Sniper"}}
	--self.IconFrame[agile] = {findByName = {"Grapple Gun", "Warp Grenade", "Dov Translocator", "Feather"}}

	self.RankIcon = CreateMOSRotating("Icon_Rank", self.ModuleName)
	self.PrestigeIcon = CreateMOSRotating("Icon_Prestige", self.ModuleName)
	self.xpSound = CreateSoundContainer("Geiger Click", "Base.rte");
	self.levelUpSound = CreateSoundContainer("Confirm", "Base.rte");
	-- Typing
	CF_TypingActor = nil;
	self.nameString = {};
	self.key = {A = 1, B = 2, C = 3, D = 4, E = 5, F = 6, G = 7, 
				H = 8, I = 9, J = 10, K = 11, L = 12, M = 13, N = 14, O = 15, P = 16, 
				Q = 17, R = 18, S = 19, T = 20, U = 21, V = 22, 
				W = 23, X = 24, Y = 25, Z = 26, 
				num0 = 27, num1 = 28, num2 = 29, num3 = 30, num4 = 31, 
				num5 = 32, num6 = 33, num7 = 34, num8 = 35, num9 = 36, 
				numpad0 = 37, numpad1 = 38, numpad2 = 39, numpad3 = 40, numpad4 = 41, 
				numpad5 = 42, numpad6 = 43, numpad7 = 44, numpad8 = 45, numpad9 = 46, 
				---------------------------------------------------------------------
				backspace = 63, enter = 67, 
				---------------------------------------------------------------------
				spacebar = 75, insert = 76, delete = 77, pageup = 80, pagedown = 81};
	
	self.keyString = {"A", "B", "C", "D", "E", "F", "G", 
				"H", "I", "J", "K", "L", "M", "N", "O", "P", 
				"Q", "R", "S", "T", "U", "V", 
				"W", "X", "Y", "Z", 
				"0", "1", "2", "3", "4", 
				"5", "6", "7", "8", "9", 
				"0", "1", "2", "3", "4", 
				"5", "6", "7", "8", "9", 
				"", "", "", "", "", "", "", "", "", "", "", "", "", "`", "-", "=", "ERASE", "\n", "[", "]", 
				---------------------------------------------------------------------
				"CONFIRM",
				"68", "'", "\\", "\\", ",", ".", "/", 
				---------------------------------------------------------------------
				" ", "", "CLEAR", "", ""};
				
	self.keyStringShift = {
				[28] = "!", [29] = '@', [30] = "#", [31] = "$", [32] = "%", 
				[33] = "^", [34] = "&", [35] = "*", [36] = "(", [27] = ")",
				---------------------------------------------------------------------
				[60] = "~", [61] = "_", [62] = "+", [65] = "{", [66] = "}", 
				[69] = '"', [70] = '|', [71] = "|", [72] = "<", [73] = ">", [74] = "?"};

	self.actorList = {}
	self.killClaimRange = 50 + (FrameMan.PlayerScreenWidth + FrameMan.PlayerScreenHeight) * 0.3
	
	print ("VoidWanderers:Tactics:StartActivity - End");
end
-----------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------
function VoidWanderers:InitConsoles()
	self:InitShipControlPanelUI()
	self:InitStorageControlPanelUI()
	self:InitClonesControlPanelUI()
	self:InitBeamControlPanelUI()
	self:InitTurretsControlPanelUI()
end
-----------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------
function VoidWanderers:DestroyConsoles()
	self:DestroyShipControlPanelUI()
	self:DestroyStorageControlPanelUI()
	self:DestroyClonesControlPanelUI()
	self:DestroyBeamControlPanelUI()
	
	self:DestroyItemShopControlPanelUI()
	self:DestroyCloneShopControlPanelUI()
	
	self:DestroyTurretsControlPanelUI()
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:DrawIcon(preset, pos)
	if preset then
		for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
			PrimitiveMan:DrawBitmapPrimitive(self:ScreenOfPlayer(player), pos, self.Icon, 0, preset);
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:DrawRankIcon(preset, pos, prestige)
	if preset then
		for player = Activity.PLAYER_1, Activity.MAXPLAYERCOUNT - 1 do
			local screen = self:ScreenOfPlayer(player);
			PrimitiveMan:DrawBitmapPrimitive(player, pos, (prestige ~= 0 and self.PrestigeIcon or self.RankIcon), 0, preset);
			if prestige > 1 then
				PrimitiveMan:DrawTextPrimitive(player, pos, "x" .. prestige, true, 0);
			end
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:GiveXP(actor, xp)
	if actor then
		xp = math.floor(xp/math.sqrt(1 + actor:GetNumberValue("VW_Prestige")) + 0.5)
		local levelUp, nextRank
		if xp > 0 then
			self.xpSound:Play(actor.Pos);
			local newXP = actor:GetNumberValue("VW_XP") + xp
			actor:SetNumberValue("VW_XP", newXP)
			
			nextRank = CF_Ranks[actor:GetNumberValue("VW_Rank") + 1]
			levelUp = nextRank and newXP >= nextRank;
		end

		if not SceneMan:IsUnseen(actor.Pos.X, actor.Pos.Y, CF_PlayerTeam) then
			local effect = CreateMOPixel("XP Effect", self.ModuleName)
			if actor:IsPlayerControlled() and SceneMan:ShortestDistance(actor.EyePos, actor.ViewPoint, SceneMan.SceneWrapsX).Magnitude > math.min(FrameMan.PlayerScreenWidth, FrameMan.PlayerScreenHeight) * 0.5 - 25 then
				effect.Pos = actor.ViewPoint + Vector(0, -math.random(5))
			else
				effect.Pos = actor.AboveHUDPos + Vector(math.random(-5, 5), -math.random(5))
			end
			effect.Sharpness = xp
			if levelUp then
				effect.Mass = nextRank + 1;
			end
			MovableMan:AddParticle(effect)
		end
		
		if levelUp then
			actor:SetNumberValue("VW_Rank", actor:GetNumberValue("VW_Rank") + 1);
			actor:FlashWhite(50);
			if not self.levelUpSound:IsBeingPlayed() then
				self.levelUpSound:Play(actor.Pos);
			end
		end
		--print(actor.PresetName .. (xp < 0 and " lost " or " gained ") .. xp .. " XP!")
	end
end
-----------------------------------------------------------------------------------------
-- WIP
-----------------------------------------------------------------------------------------
function VoidWanderers:OnPieMenu(pieActor)
	local xp = pieActor:GetNumberValue("VW_XP")
	if xp > CF_Ranks[#CF_Ranks - 1] then
		local yaGottaPrestigeNow = xp >= CF_Ranks[#CF_Ranks];
--		if yaGottaPrestigeNow and CF_Difficulty > 50 then
--			self:RemovePieMenuSlice("Brain Hunt AI Mode", "");
--			self:RemovePieMenuSlice("Patrol AI Mode", "");
--			self:RemovePieMenuSlice("Gold Dig AI Mode", "");
--			self:RemovePieMenuSlice("Go-To AI Mode", "");
--			self:RemovePieMenuSlice("Sentry AI Mode", "");
--		end
		self:AddPieMenuSlice("Claim Prestige", "VoidWanderersPrestige", Slice.UP, yaGottaPrestigeNow);
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderersPrestige(pieActor)
	if IsAHuman(pieActor) then
		pieActor = ToAHuman(pieActor);
		pieActor:RemoveWounds(pieActor.WoundCount);
		pieActor.Health = pieActor.MaxHealth;
		
		CF_UnBuffActor(ToAHuman(pieActor), pieActor:GetNumberValue("VW_Rank"), pieActor:GetNumberValue("VW_Prestige"))
		pieActor:RemoveNumberValue("VW_XP")
		pieActor:RemoveNumberValue("VW_Rank")
		pieActor:SetNumberValue("VW_Prestige", pieActor:GetNumberValue("VW_Prestige") + 1)
		pieActor:SetStringValue("VW_Name", "");
		CF_TypingActor = pieActor;
	end
end
-----------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------
function VoidWanderers:PutGlow(preset, pos)
	local glow = CreateMOPixel(preset, self.ModuleName);
	if glow then
		glow.Pos = pos
		MovableMan:AddParticle(glow);	
	end
end
-----------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------
function VoidWanderers:PutGlowWithModule(preset, pos, module)
	local glow = CreateMOPixel(preset, module);
	if glow then
		glow.Pos = pos
		MovableMan:AddParticle(glow);	
	end
end
-----------------------------------------------------------------------------------------
-- Removes specified item from actor's inventory, returns number of removed items
-----------------------------------------------------------------------------------------
function VoidWanderers:RemoveInventoryItem(actor , itempreset, maxcount)
	local count = 0;
	local toabort = 0
	
	--print ("Remove "..itempreset)
	
	if MovableMan:IsActor(actor) and actor.ClassName == "AHuman" then
		if actor:HasObject(itempreset) then
			local human = ToAHuman(actor);
		
			if human.EquippedItem then
				if human.EquippedItem.PresetName == itempreset then
					human.EquippedItem.ToDelete = true;
					count = 1;
				end
			end
			
			human:UnequipBGArm()

			if not actor:IsInventoryEmpty() then
				actor:AddInventoryItem(CreateTDExplosive("VoidWanderersInventoryMarker" , self.ModuleName));
				
				local enough = false;
				while not enough do
					local weap = actor:Inventory();
					
					--print (weap.PresetName)
					
					if weap.PresetName == itempreset then
						if count < maxcount then
							weap = actor:SwapNextInventory(nil, true);
							count = count + 1;
						else
							weap = actor:SwapNextInventory(weap, true);
						end
					else
						if weap.PresetName == "VoidWanderersInventoryMarker" then
							enough = true;
							actor:SwapNextInventory(nil, true);
						else
							weap = actor:SwapNextInventory(weap, true);
						end
					end
					
					toabort = toabort + 1
					if toabort == 20 then
						enough = true;
					end
				end
			end
		end
	end
	
	-- print (tostring(count).." items removed")
	return count;
end
-----------------------------------------------------------------------------------------
-- Save fog of war
-----------------------------------------------------------------------------------------
function VoidWanderers:SaveFogOfWarState(config)
	-- Save fog of war status
	-- Since if we disable fog of war all map will be revealed we don't
	-- need to save fog of war state at all
	local tiles = 0
	local revealed = 0
	
	if config["FogOfWar"] and config["FogOfWar"] == "true" then
		local wx = SceneMan.Scene.Width / CF_FogOfWarResolution;
		local wy = SceneMan.Scene.Height / CF_FogOfWarResolution;
		local str = "";
		
		for y = 0, wy do
			str = "";
			for x = 0, wx do
				tiles = tiles + 1
				if SceneMan:IsUnseen(x * CF_FogOfWarResolution, y * CF_FogOfWarResolution, CF_PlayerTeam) then
					str = str.."0";
				else
					str = str.."1";
					revealed = revealed + 1
				end
			end
			
			config[self.GS["Location"].."-Fog"..tostring(y)] = str;
			config[self.GS["Location"].."-FogRevealPercentage"] = math.floor(revealed / tiles * 100);
		end
	end
end
-----------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------
function VoidWanderers:TriggerShipAssault()
	if not CF_EnableAssaults then
		return
	end
	
	local toassault = false
	
	-- First select random assault player
	-- Select angry CPU's
	local angry = {}
	
	for i = 1, tonumber(self.GS["ActiveCPUs"]) do
		local rep = tonumber(self.GS["Player"..i.."Reputation"])
		if rep <= CF_ReputationHuntThreshold then
			angry[#angry + 1] = i
		end
	end
	
	
	if #angry > 0 then
		local rangedangry = {}
		-- Range angry CPU based on their 
		for i = 1, #angry do
			--print ("- "..CF_GetPlayerFaction(self.GS, angry[i]))
			local anger = math.floor(math.abs(tonumber(self.GS["Player"..angry[i].."Reputation"]) / CF_ReputationPerDifficulty))
			
			if anger <= 0 then
				anger = 1
			end
			
			if anger > CF_MaxDifficulty then
				anger = CF_MaxDifficulty
			end			
			
			for j = 1, anger do
				rangedangry[#rangedangry + 1] = angry[i]
				--print (CF_GetPlayerFaction(self.GS, angry[i]))
			end
		end
		
		angry = rangedangry

		self.AssaultEnemyPlayer = angry[math.random(#angry)]
		
		local rep = tonumber(self.GS["Player"..self.AssaultEnemyPlayer.."Reputation"])
		
		self.AssaultDifficulty = math.min(math.max(math.floor(math.abs(rep / CF_ReputationPerDifficulty)), 1), CF_MaxDifficulty)
		
		local r = math.random(CF_MaxDifficulty * 45)
		local tgt = (self.AssaultDifficulty * 5) + 10
		
		--print (CF_GetPlayerFaction(self.GS, self.AssaultEnemyPlayer).." D - "..self.AssaultDifficulty.." R - "..r.." TGT - "..tgt)
		
		if r < tgt then
			toassault = true
		end
	end
	
	--toassault = false -- DEBUG
	--toassault = true -- DEBUG

	if toassault then
		self.AssaultTime = self.Time + CF_ShipAssaultDelay
		self.AssaultEnemiesToSpawn = CF_AssaultDifficultyUnitCount[self.AssaultDifficulty]
		self.AssaultNextSpawnTime = self.AssaultTime + CF_AssaultDifficultySpawnInterval[self.AssaultDifficulty] + 1
		self.AssaultNextSpawnPos = self.EnemySpawn[math.random(#self.EnemySpawn)]	
		self.AssaultWarningTime = 6

		--self.AssaultEnemiesToSpawn = 1 -- DEBUG
		--self.AssaultTime = self.Time + 3 -- DEBUG

		-- Create attacker's unit presets
		CF_CreateAIUnitPresets(self.GS, self.AssaultEnemyPlayer, CF_GetTechLevelFromDifficulty(self.GS, self.AssaultEnemyPlayer, self.AssaultDifficulty, CF_MaxDifficulty))	
		
		-- Remove some panel actors
		self.ShipControlPanelActor.ToDelete = true
		self.BeamControlPanelActor.ToDelete = true
	else
		-- Trigger random encounter
		if math.random() < CF_RandomEncounterProbability and #CF_RandomEncounters > 0 then
			-- Find suitable random event
			local r 
			local id
			local found = false
			local brk = 1
			
			while not found do
				r = math.random(#CF_RandomEncounters)
				id = CF_RandomEncounters[r]
				
				if CF_RandomEncountersOneTime[id] == true then
					if self.GS["Encounter"..id.."Happened"] == nil then
						found = true
					end
				else
					found = true
				end
				
				brk = brk + 1
				if brk > 30 then
					--error("Endless loop in random encounter selector")
					break
				end
			end
			
			--id = "PIRATE_GENERIC" -- DEBUG
			--id = "ABANDONED_VESSEL_GENERIC"  -- DEBUG
			--id = "HOSTILE_DRONE" -- DEBUG
			--id = "REAVERS" -- DEBUG
			
			-- Launch encounter
			if found and id ~= nil then
				-- Increase probability of reavers a bit
				if CF_RandomEncounters["REAVERS"] and id ~= "REAVERS" then
					local maxGold = 25000;
					if math.random() < math.min(CF_GetPlayerGold(self.GS, CF_PlayerTeam), maxGold)/(maxGold * 2) then
						id = "REAVERS"
					end
				end
			
				self.RandomEncounterID = id
				self.RandomEncounterVariant = 0
				
				self.RandomEncounterDelayTimer = Timer()
				
				self.RandomEncounterText = CF_RandomEncountersInitialTexts[id]
				self.RandomEncounterVariants = CF_RandomEncountersInitialVariants[id]
				self.RandomEncounterVariantsInterval = CF_RandomEncountersVariantsInterval[id]
				self.RandomEncounterChosenVariant = 0
				self.RandomEncounterIsInitialized = false
				self.ShipControlSelectedEncounterVariant = 1
				
				-- Switch to ship panel
				local bridgeempty = true
				local plrtoswitch = -1
				
				for plr = 0, self.PlayerCount - 1 do
					local act = self:GetControlledActor(plr);
					
					if act and MovableMan:IsActor(act) then
						if act.PresetName ~= "Ship Control Panel" and plrtoswitch == -1 then
							plrtoswitch = plr
						end
						
						if act.PresetName == "Ship Control Panel" then
							bridgeempty = false
						end
					end
				end
					
				if plrtoswitch > -1 and bridgeempty and MovableMan:IsActor(self.ShipControlPanelActor) then
					self:SwitchToActor(self.ShipControlPanelActor, plrtoswitch, CF_PlayerTeam);
				end
				self.ShipControlMode = self.ShipControlPanelModes.REPORT
				
				self:StartMusic(CF_MusicTypes.SHIP_INTENSE)
				--]]--
			end
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:SpawnFromTable()
	if #self.SpawnTable > 0 then
		if MovableMan:GetMOIDCount() < CF_MOIDLimit then
			local nm = self.SpawnTable[1]
		
			local actor = CF_SpawnAIUnitWithPreset(self.GS, nm["Player"], nm["Team"], nm["Pos"], nm["AIMode"], nm["Preset"])
			if actor then
				if nm["Name"] and not actor:StringValueExists("VW_Name") then
					actor:SetStringValue("VW_Name", nm["Name"])
				end
				-- Give diggers of required
				if nm["Digger"] then
					local diggers = CF_MakeListOfMostPowerfulWeapons(self.GS, nm["Player"], CF_WeaponTypes.DIGGER, 10000)
					if diggers ~= nil then
						local r = math.random(#diggers)
						local itm = diggers[r]["Item"]
						local fct = diggers[r]["Faction"]
						
						local pre = CF_ItmPresets[fct][itm]
						local cls = CF_ItmClasses[fct][itm]
						local mdl = CF_ItmModules[fct][itm]
						
						local newitem = CF_MakeItem(pre, cls, mdl)
						if newitem then
							actor:AddInventoryItem(newitem)
						end
					end
				end
				if nm["RenamePreset"] ~= nil then
					actor.PresetName = nm["RenamePreset"]..actor.PresetName
				end
				actor.HFlipped = math.random() < 0.5;
				MovableMan:AddActor(actor)
			end
			table.remove(self.SpawnTable, 1)
		else
			print ("MOID LIMIT REACHED!!!")
			self.SpawnTable = nil
		end
	else
		self.SpawnTable = nil
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:ClearActors()
	for i = 1, CF_MaxSavedActors do
		self.GS["Actor"..i.."Preset"] = nil
		self.GS["Actor"..i.."Class"] = nil
		self.GS["Actor"..i.."Module"] = nil
		self.GS["Actor"..i.."X"] = nil
		self.GS["Actor"..i.."Y"] = nil
		self.GS["Actor"..i.."XP"] = nil
		self.GS["Actor"..i.."Identity"] = nil
		self.GS["Actor"..i.."Prestige"] = nil
		self.GS["Actor"..i.."Name"] = nil
		for j = 1, #CF_LimbID do
			self.GS["Actor"..i..CF_LimbID[j]] = nil
		end
		for j = 1, CF_MaxSavedItemsPerActor do
			self.GS["Actor"..i.."Item"..j.."Preset"] = nil
			self.GS["Actor"..i.."Item"..j.."Class"] = nil
			self.GS["Actor"..i.."Item"..j.."Module"] = nil
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:SaveActors(clearpos)
	self:ClearActors()

	local savedactor = 1
	local totalpenalty = 0

	for actor in MovableMan.Actors do
		if actor.PresetName ~= "Brain Case" and (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") then
			local pre, cls, mdl = CF_GetInventory(actor)
		
			-- Save actors to config
			self.GS["Actor"..savedactor.."Preset"] = actor.PresetName
			self.GS["Actor"..savedactor.."Class"] = actor.ClassName
			self.GS["Actor"..savedactor.."Module"] = actor.ModuleName
			-- Give a slight XP penalty for each save to discourage save scum?
			local xp = actor:GetNumberValue("VW_XP")
--			local penalty = math.max(math.floor(xp * CF_SaveGameXPPenaltyRatio + 0.5 - CF_SaveGameXPPenaltyIncrement), 0)
			local penalty = math.max(math.floor(xp * CF_SaveGameXPPenaltyRatio + 0 - CF_SaveGameXPPenaltyIncrement), 0)
			self.GS["Actor"..savedactor.."XP"] = xp - penalty
			totalpenalty = totalpenalty + penalty
			self.GS["Actor"..savedactor.."Identity"] = actor:GetNumberValue("Identity")
			self.GS["Actor"..savedactor.."Prestige"] = actor:GetNumberValue("VW_Prestige")
			self.GS["Actor"..savedactor.."Name"] = actor:GetStringValue("VW_Name")
			for j = 1, #CF_LimbID do
				self.GS["Actor"..savedactor..CF_LimbID[j]] = CF_GetLimbName(actor, j)
			end

			if clearpos then
				self.GS["Actor"..savedactor.."X"] = nil
				self.GS["Actor"..savedactor.."Y"] = nil
			else
				self.GS["Actor"..savedactor.."X"] = math.floor(actor.Pos.X)
				self.GS["Actor"..savedactor.."Y"] = math.floor(actor.Pos.Y)
			end
			
			for j = 1, #pre do
				self.GS["Actor"..savedactor.."Item"..j.."Preset"] = pre[j]
				self.GS["Actor"..savedactor.."Item"..j.."Class"] = cls[j]
				self.GS["Actor"..savedactor.."Item"..j.."Module"] = mdl[j]
			end

			savedactor = savedactor + 1
		end
	end
	print("Total XP save penalty: " .. totalpenalty)
end
-----------------------------------------------------------------------------------------
-- Update Activity
-----------------------------------------------------------------------------------------
function VoidWanderers:UpdateActivity()
	-- Just check for intialization flags in update loop to avoid unnecessary function calls during all the mission
	if self.IsInitialized == nil then
		self.IsInitialized = false
	end
	
	if not self.IsInitialized then
		--Init mission if we're still not
		self:StartActivity()
	end

	self:ClearObjectivePoints();
	
	--if true then
	--	return
	--end
	
	-- Add any gold gained in-game
	local realGold = self:GetTeamFunds(CF_PlayerTeam);
	if realGold ~= CF_GetPlayerGold(self.GS, CF_PlayerTeam) then
		CF_SetPlayerGold(self.GS, CF_PlayerTeam, realGold);
	end

	if self.GenericTimer:IsPastSimMS(25) then
		for i = 1, #self.actorList do
			local victim = self.actorList[i];
			if victim and not MovableMan:IsActor(victim.Pointer) then
				--print(victim.Value .. " of value dead at (" .. math.floor(victim.ViewPoint.X + 0.5) .. ", " .. math.floor(victim.ViewPoint.Y + 0.5) .. ")!");
				local dist = Vector()
				local gain = victim.Team == -1 and 0 or 1
				-- Give automatic reward to the first actor up-close to the enemy
				local killer = MovableMan:GetClosestEnemyActor(victim.Team, victim.ViewPoint, 50, dist)
				if killer and self:IsPlayerUnit(killer) then
					gain = gain + victim.Value/(1 + math.abs(killer:GetGoldValue(0, 0.3, 0.3))) * (3 - math.min(killer.Health/killer.MaxHealth + dist.Magnitude/self.killClaimRange, 2))
					self:GiveXP(killer, gain)
				else
					-- Share XP between nearby actors
					local killerCandidates = {}
					for actor in MovableMan.Actors do
						if self:IsPlayerUnit(actor) then
							dist = SceneMan:ShortestDistance(actor.ViewPoint, victim.ViewPoint, SceneMan.SceneWrapsX)
							if dist.Magnitude < self.killClaimRange then
								-- Check for some possible terrain obstructances that will diminish the probability of claiming a kill
								local obstructionTotal = 0
								if dist.Magnitude > actor.Radius then
									local checkPos = {actor.ViewPoint + dist * 0.2, victim.ViewPoint - dist * 0.2}
									for i = 1, #checkPos do
										obstructionTotal = obstructionTotal + math.floor(SceneMan:GetMaterialFromID(SceneMan:GetTerrMatter(checkPos[i].X, checkPos[i].Y)).StructuralIntegrity^0.5)
									end
								end
								table.insert(killerCandidates, {killer = actor, dist = dist.Magnitude + obstructionTotal})
							end
						end
					end
					for _, actor in pairs(killerCandidates) do
						local sharedGain = gain + (victim.Value/(1 + math.abs(actor.killer:GetGoldValue(0, 0.4, 0.4))) * (3 - math.min(actor.killer.Health/actor.killer.MaxHealth + actor.dist/self.killClaimRange, 2)))/#killerCandidates;
						self:GiveXP(actor.killer, sharedGain)
					end
				end
			end
			self.actorList[i] = nil
		end
		for actor in MovableMan.Actors do
			local isFriendly = actor.Team == CF_PlayerTeam
			if not isFriendly and actor.Pos.Y > 0 then
				-- Save enemy actors in an external table to track their disappearance
				if not actor:NumberValueExists("VW_FragValue") then
					local fragValue = math.abs(actor:GetGoldValue(0, 1, 1));
					if IsAHuman(actor) and ToAHuman(actor).EquippedItem then
						fragValue = fragValue + ToAHuman(actor).EquippedItem:GetGoldValue(0, 0.5, 0.5);
					end
					actor:SetNumberValue("VW_FragValue", fragValue * (1 + actor:GetNumberValue("VW_Rank") * 0.1));
				end
				self.actorList[#self.actorList + 1] = {Pointer = actor, Team = actor.Team, Value = actor:GetNumberValue("VW_FragValue"), ViewPoint = Vector(actor.ViewPoint.X, actor.ViewPoint.Y)};
			end
			-- Display icons
			if CF_EnableIcons then
				if actor.HUDVisible and (isFriendly or SettingsMan.ShowEnemyHUD) and not SceneMan:IsUnseen(actor.Pos.X, actor.Pos.Y, CF_PlayerTeam) then
					local cont, pieMenuOpen
					local prestige = actor:GetNumberValue("VW_Prestige")
					local velOffset = actor.Vel * rte.PxTravelledPerFrame;
					
					local offsetY = (actor:IsPlayerControlled() and actor.ItemInReach) and -8 or -1;
					local name = actor:GetStringValue("VW_Name");
					if name and name ~= "" then
						PrimitiveMan:DrawTextPrimitive(actor.AboveHUDPos + velOffset + Vector(1, offsetY - 7), name, false, 1);
					elseif isFriendly then
						cont = actor:GetController()
						pieMenuOpen = cont:IsState(Controller.PIE_MENU_ACTIVE)
						local icons = {}
						if self:IsAlly(actor) and not pieMenuOpen then
							self:DrawIcon(0, actor.Pos + velOffset + Vector(-8, -actor.Height * 0.5 + 8))
						end

						for i = 1, #self.IconFrame do
							if self.IconFrame[i].findByGroup then
								for _, group in pairs(self.IconFrame[i].findByGroup) do
									if actor:HasObjectInGroup(group) then
										icons[#icons + 1] = i
										break
									end
								end
							elseif self.IconFrame[i].findByName then
								for _, name in pairs(self.IconFrame[i].findByName) do
									if actor:HasObject(name) then
										icons[#icons + 1] = i
										break
									end
								end
							end
						end

						if #icons > 0 then
							local pos = actor.AboveHUDPos + velOffset + Vector(-(13 * #icons * 0.5) + 7, offsetY)
							for _, frame in pairs(icons) do
								self:DrawIcon(frame, pos)
								pos = pos + Vector(13, 0)
							end
						end
					end
					local rank = actor:GetNumberValue("VW_Rank")
					if rank > 0 or prestige ~= 0 then
						local pos = actor.Pos + velOffset + Vector(-20, 8 - actor.Height * 0.5);
						
						self:DrawRankIcon(rank, pos, prestige)
						local progress = CF_Ranks[rank + 1] and actor:GetNumberValue("VW_XP") .. "/" .. CF_Ranks[rank + 1] or CF_Ranks[rank] .. "/" .. CF_Ranks[rank];
						if pieMenuOpen then
							PrimitiveMan:DrawTextPrimitive(cont.Player, pos + Vector(0, 5), progress, true, 1)
						end
					end
				end
			end
		end
	end
	
	-- Process UI's and other vessel mode features
	if self.GS["Mode"] == "Vessel" then
		if self:GetPlayerBrain(Activity.PLAYER_1) then
			self:GetBanner(GUIBanner.RED, Activity.PLAYER_1):ClearText();
		end
		
		self:ProcessClonesControlPanelUI()
		self:ProcessStorageControlPanelUI()
		self:ProcessBrainControlPanelUI()
		self:ProcessTurretsControlPanelUI()
		
		-- Auto heal all actors when not in combat or random encounter
		if not self.OverCrowded then
			if self.RandomEncounterID == nil then
				for actor in MovableMan.Actors do
					if actor.Health > 0 and actor.Health < actor.MaxHealth and actor.Team == CF_PlayerTeam and self.Ship:IsInside(actor.Pos) then
						actor.Health = math.min(actor.Health + 1, actor.MaxHealth)
					end
				end
			end
		else
			local count = CF_CountActors(CF_PlayerTeam) - tonumber(self.GS["Player0VesselLifeSupport"])
			local s = count == 1 and "BODY" or "BODIES"
		
			FrameMan:ClearScreenText(0);
			FrameMan:SetScreenText("LIFE SUPPORT OVERLOADED\nSTORE OR DUMP "..CF_CountActors(CF_PlayerTeam) - tonumber(self.GS["Player0VesselLifeSupport"]) .." "..s, 0, 0, 1000, true);
		end
		
		-- Show assault warning
		if self.AssaultTime > self.Time then
			FrameMan:ClearScreenText(0);
			FrameMan:SetScreenText(CF_GetPlayerFaction(self.GS, tonumber(self.AssaultEnemyPlayer)).." "..CF_AssaultDifficultyTexts[self.AssaultDifficulty].." approaching in T-"..self.AssaultTime - self.Time.."\nBATTLE STATIONS!", 0, 0, 1000, true);
		else
			-- Process some control panels only when ship is not boarded
			self:ProcessShipControlPanelUI()
			self:ProcessBeamControlPanelUI()
			self:ProcessItemShopControlPanelUI()
			self:ProcessCloneShopControlPanelUI()
		end
		
		-- Launch defense activity
		if self.AssaultTime == self.Time then
			self.GS["Mode"] = "Assault"
			
			self:DeployTurrets()
			
			-- Remove control actors
			self:DestroyStorageControlPanelUI()
			self:DestroyClonesControlPanelUI()
			self:DestroyBeamControlPanelUI()
			self:DestroyItemShopControlPanelUI()
			self:DestroyCloneShopControlPanelUI()
			self:DestroyTurretsControlPanelUI()
			
			self:StartMusic(CF_MusicTypes.SHIP_INTENSE)
		end
		
		-- Process random encounter function
		if self.RandomEncounterID ~= nil then
			CF_RandomEncountersFunctions[self.RandomEncounterID](self, self.RandomEncounterChosenVariant)
			-- If incounter was finished then remove turrets
			if self.RandomEncounterID == nil then
				self.RandomEncounterDelayTimer = nil
				self:RemoveDeployedTurrets()
			end
		end
	end--]]--

	local engineBurst = false
	local engineBoost = self.EngineEmitters and tonumber(self.GS["Player0VesselSpeed"]) * 0.005 or nil
				
	if self.GS["Mode"] == "Vessel" and self.FlightTimer:IsPastSimMS(CF_FlightTickInterval) then
		self.FlightTimer:Reset()
		-- Fly to new location
		if self.GS["Destination"] ~= nil and self.GS["Location"] == nil and self.Time > self.AssaultTime and self.RandomEncounterID == nil then

			-- Move ship
			local dx = tonumber(self.GS["DestX"])
			local dy = tonumber(self.GS["DestY"])
			
			local sx = tonumber(self.GS["ShipX"])
			local sy = tonumber(self.GS["ShipY"])
			
			local d = CF_Dist(Vector(sx,sy), Vector(dx,dy))
			
			if (d < 0.5) then
				self.GS["Location"] = self.GS["Destination"]
				self.GS["Destination"] = nil

				local locpos = CF_LocationPos[ self.GS["Location"] ]
				if locpos == nil then
					locpos = Vector()
				end
				
				self.GS["ShipX"] = locpos.X
				self.GS["ShipY"] = locpos.Y
				
				-- Delete emitters
				if self.EngineEmitters then
					for i = 1, #self.EngineEmitters do
						self.EngineEmitters[i].ToDelete = true
					end
					self.EngineEmitters = nil
					engineBoost = engineBoost * (-2)
				end
			else
				self.GS["Distance"] = d
				
				local ax = (dx - sx) / d * (tonumber(self.GS["Player0VesselSpeed"]) / CF_KmPerPixel)
				local ay = (dy - sy) / d * (tonumber(self.GS["Player0VesselSpeed"]) / CF_KmPerPixel)
				
				sx = sx + ax
				sy = sy + ay
				
				self.GS["ShipX"] = sx
				self.GS["ShipY"] = sy
				
				self.LastTrigger = self.GS["DistanceTraveled"]
				
				if self.LastTrigger == nil then
					self.LastTrigger = 0
				else
					self.LastTrigger = tonumber(self.LastTrigger)
				end
				
				self.LastTrigger = self.LastTrigger + 1
				
				if self.LastTrigger > CF_DistanceToAttemptEvent then
					self.LastTrigger = 0
					self:TriggerShipAssault()
				end

				self.GS["DistanceTraveled"] = self.LastTrigger
				
				-- Create emitters if nessesary
				if self.EngineEmitters == nil then
					self.EngineEmitters = {}
					
					for i = 1, #self.EnginePos do
						local em = CreateAEmitter("Vessel Main Thruster")
						if em then
							em.Pos = self.EnginePos[i] + Vector(2, 0)
							self.EngineEmitters[i] = em
 							MovableMan:AddParticle(em)
							em:EnableEmission(true)
						end
					end
					engineBurst = true
					engineBoost = tonumber(self.GS["Player0VesselSpeed"]) * 0.5
				end
			end
		end
		
		-- Create or delete shops if we arrived/departed to/from Star base
		if CF_IsLocationHasAttribute(self.GS["Location"], CF_LocationAttributeTypes.TRADESTAR) or CF_IsLocationHasAttribute(self.GS["Location"], CF_LocationAttributeTypes.BLACKMARKET) then
			if not self.ShopsCreated then
				-- Destroy any previously created item shops and create a new one
				self:DestroyItemShopControlPanelUI()
				self:InitItemShopControlPanelUI()
				self:DestroyCloneShopControlPanelUI()
				self:InitCloneShopControlPanelUI()
				self.ShopsCreated = true
			end
		else
			if self.ShopsCreated then
				self:DestroyItemShopControlPanelUI()
				self:DestroyCloneShopControlPanelUI()
				self.ShopsCreated = false
			end
		end
	end--]]--

	-- Remove pre-eqipped items from inventories
	if #self.ItemRemoveQueue > 0 then
		for i = 1, #self.ItemRemoveQueue do
			if MovableMan:IsActor(self.ItemRemoveQueue[i]["Actor"]) then
				self:RemoveInventoryItem(self.ItemRemoveQueue[i]["Actor"], self.ItemRemoveQueue[i]["Preset"], 1)
				table.remove(self.ItemRemoveQueue, i)
				--print ("Removed")
				break;
			else
				table.remove(self.ItemRemoveQueue, i)
				break;
			end
		end		
	end--]]--

	-- Generate artificial gravity inside the ship
	if self.Ship then
		-- God forbid you exit the ship when the engines are on
		if engineBoost then
			for id = 1, MovableMan:GetMOIDCount() - 1 do
				local mo = MovableMan:GetMOFromID(id);
				if mo and mo.PinStrength == 0 and mo.ID == mo.RootID then
					if not self.AGS and engineBurst then
						mo.Vel = mo.Vel + Vector(engineBoost, 0);
						if IsMOSRotating(mo) then
							ToMOSRotating(mo).AngularVel = ToMOSRotating(mo).AngularVel + math.random(-0.5, 0.5) * engineBoost;
						end
					elseif not self.Ship:IsInside(mo.Pos) then
						mo.Vel = mo.Vel + Vector(engineBoost, 0);
					end
				end
			end
		end

		local coll = {MovableMan.Actors, MovableMan.Items};
		for i = 1, #coll do
			for mo in coll[i] do
				if mo.PinStrength == 0 then
					mo.Vel = mo.Vel - self.gravityPerFrame;
					if engineBoost and mo.ID == rte.NoMOID then	-- Apply the same as above for items with no MOID
						if not self.AGS and engineBurst then
							mo.Vel = mo.Vel + Vector(engineBoost, 0);
							if IsMOSRotating(mo) then
								ToMOSRotating(mo).AngularVel = ToMOSRotating(mo).AngularVel + math.random(-0.5, 0.5) * engineBoost;
							end
						elseif not self.Ship:IsInside(mo.Pos) then
							mo.Vel = mo.Vel + Vector(engineBoost, 0);
						end
					end
					if self.AGS and self.Ship:IsInside(mo.Pos) then
						mo.Vel = mo.Vel + self.AGS;
					else
						if IsAHuman(mo) then
							local actor = ToAHuman(mo);
							local stillness = 1/(1 + (actor.Vel.Magnitude + math.abs(actor.AngularVel) * 0.1) * 0.1);
							if actor.Team ~= CF_PlayerTeam then
								actor.Vel = actor.Vel + Vector(0, 0.1 * stillness);
							elseif actor.Status < Actor.INACTIVE and actor.Radius < 1000 and actor.Mass > 0 then
			
								local controller = actor:GetController();
								local aimAngle = actor:GetAimAngle(false);
								local playerControlled = actor:IsPlayerControlled();
								actor.Status = Actor.UNSTABLE;

								local targetAngle = 0;
								local moveSpeed = 0.001;
	
								if playerControlled then
											
									if actor.FGArm then
										local moID = SceneMan:CastMORay(actor.FGArm.Pos, Vector(actor.FGArm.MaxLength * actor.FlipFactor * math.random(), 0):RadRotate(aimAngle + RangeRand(-0.5, 0.5)), actor.ID, Activity.NOTEAM, rte.grassID, true, 3);
										if moID == rte.NoMOID then
											moID = actor.HitWhatMOID;
										end
										if moID ~= rte.NoMOID then
											local item = MovableMan:GetMOFromID(moID);
											if item and IsMOSRotating(item) then
												item = ToMOSRotating(item):GetRootParent();
												if IsHeldDevice(item) then
													actor.ItemInReach = ToHeldDevice(item);
												end
											end
										end
									end
									local limbs = {actor.FGArm, actor.BGArm, actor.FGFoot, actor.BGFoot};
									for _, limb in pairs(limbs) do
										if limb then
											local checkPos = limb.HandPos or limb.Pos;
											if checkPos then
												checkPos = checkPos + Vector(0, 1) + SceneMan:ShortestDistance(actor.Pos, checkPos, SceneMan.SceneWrapsX):SetMagnitude(1);
												local terrCheck = SceneMan:GetTerrMatter(checkPos.X, checkPos.Y);
												if terrCheck ~= rte.airID then
													moveSpeed = math.min(SceneMan:GetMaterialFromID(terrCheck).Friction * 0.1, 1);
													break;
												end
											end
										end
									end
									moveSpeed = moveSpeed * stillness;
									
									if actor.Status == Actor.UNSTABLE then
										targetAngle = math.pi * 0.5;-- + (actor.Jetpack and (actor.Jetpack.EmitAngle - math.pi * 1.5) or 0);
									end
									--actor.Status = math.abs(aimAngle) > 1 and Actor.UNSTABLE or actor.Status;
				
									if controller:IsState(Controller.BODY_JUMP) then
										--controller:SetState(Controller.BODY_JUMP, false);
										actor.Vel = actor.Vel + Vector(0, -moveSpeed * 0.5) + Vector(moveSpeed * 0.5, 0):RadRotate(actor:GetAimAngle(true));
									elseif controller:IsState(Controller.BODY_CROUCH) then
										--controller:SetState(Controller.BODY_CROUCH, false);	-- Avoid flinging yourself forwards?
										actor.Vel = actor.Vel + Vector(0, moveSpeed * 0.5) - Vector(moveSpeed * 0.5, 0):RadRotate(actor:GetAimAngle(true));
									elseif controller:IsState(Controller.AIM_UP) or controller:IsState(Controller.AIM_DOWN) then
										actor.Vel = actor.Vel + Vector(0, -moveSpeed * math.sin(aimAngle));
									else
										if controller:IsState(Controller.MOVE_RIGHT) then
											actor.Vel = actor.Vel + Vector(moveSpeed * 0.5, 0) + Vector(moveSpeed * 0.5, 0):RadRotate(actor:GetAimAngle(true));
										end
										if controller:IsState(Controller.MOVE_LEFT) then
											actor.Vel = actor.Vel + Vector(-moveSpeed * 0.5, 0) + Vector(moveSpeed * 0.5, 0):RadRotate(actor:GetAimAngle(true));
										end
									end
								end
								--actor.Status = stillness < 0.66 and Actor.UNSTABLE or actor.Status;
								actor.AngularVel = actor.AngularVel * (1 - stillness) - (actor.RotAngle - (aimAngle - targetAngle) * actor.FlipFactor)/(1 + actor.TravelImpulse.Magnitude/actor.Mass) * 4 * stillness;
							end
						end
					end
				end
			end
		end
	end
	-- Tick timer
	--if self.TickTimer:IsPastSimMS(self.TickInterval) then
	if self.TickTimer:IsPastRealMS(self.TickInterval) then
		self.Time = self.Time + 1
		self.TickTimer:Reset();

		-- Reputation erosion
		if self.Time % CF_ReputationErosionInterval	== 0 then
			for i = 1, tonumber(self.GS["ActiveCPUs"]) do
				local rep =  tonumber(self.GS["Player"..i.."Reputation"]) 
				
				if rep > 0 then 
					rep = rep - 1
				elseif rep < 0 then
					rep = rep + 1
				end
				
				self.GS["Player"..i.."Reputation"] = rep
			end
		end

		-- Give passive experience points for non-brain actors
		for actor in MovableMan.Actors do

			if self:IsPlayerUnit(actor) then
				--actor = IsAHuman(actor) and ToAHuman(actor) or actor
				--[[local engagedAtDist = 0
				-- Arbitrary calculations for whether actors are engaging the enemy?
				if actor:GetController():IsState(Controller.WEAPON_FIRE) and actor.EquippedItem and IsHDFirearm(actor.EquippedItem) then
					local gun = ToHDFirearm(actor.EquippedItem)
					local dots = math.sqrt(math.abs(gun.SharpLength))
					local checkPos = gun.MuzzlePos
					for i = 1, dots do
						local gap = i^2
						local checkPos = checkPos + Vector(gap - math.random(gap), 0):RadRotate(actor:GetAimAngle(true))
						local moCheck = SceneMan:GetMOIDPixel(checkPos.X, checkPos.Y)
						PrimitiveMan:DrawCircleFillPrimitive(checkPos, 1, 13)
						if moCheck ~= rte.NoMOID then
							local mo = MovableMan:GetMOFromID(moCheck)
							if mo and mo.Team ~= -1 and mo.Team ~= CF_PlayerTeam then
								engagedAtDist = math.sqrt(i)
								actor:SetNumberValue("VW_EngageCounter", 100/engagedAtDist)
								break
							end
						elseif SceneMan:GetTerrMatter(checkPos.X, checkPos.Y) ~= rte.airID then
							break
						end
					end
				end
				local engageCounter = actor:GetNumberValue("VW_EngageCounter");
				]]--
			
				local damage = (actor.PrevHealth - actor.Health)/actor.MaxHealth;
				
				local gains = damage * math.sqrt(25 + actor.Vel.Magnitude);
				if gains >= 1 then
					self:GiveXP(actor, gains)
				end
			end
		end
		
		if self.AssaultTime > self.Time then
			if self.Time % 2 == 0 then
				self:MakeAlertSound()
			end
		end
		
		if self.GS["Mode"] == "Vessel" then
			local count = 0 
		
			-- Count actors except turrets
			for actor in MovableMan.Actors do
				if actor.Team == CF_PlayerTeam and (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") and not actor:IsInGroup("Brains") then
					local isturret = false
				
					if self.TurretsDeployedActors ~= nil then
						local count = tonumber(self.GS["Player0VesselTurrets"])

						for turr = 1, count do
							if MovableMan:IsActor(self.TurretsDeployedActors[turr]) then
								if actor.ID == self.TurretsDeployedActors[turr].ID then
									isturret = true
								end
							end
						end
					end
					
					if not isturret then
						count = count + 1
					end
				end
			end
		
			if count > tonumber(self.GS["Player0VesselLifeSupport"]) then
				self.OverCrowded = true
				
				if self.Time % 3 == 0 then
					for actor in MovableMan.Actors do
						if (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") and not actor:IsInGroup("Brains") then
							actor.Health = actor.Health - math.ceil(50/math.sqrt(1 + math.abs(actor.Mass + actor.Material.StructuralIntegrity)));
						end
					end
				end
				
				if self.Time % 2 == 0 then
					self:MakeAlertSound()
				end
			else
				self.OverCrowded = false
			end
			
			if self.RandomEncounterID ~= nil then
				if self.Time % 2 == 0 then
					self:MakeAlertSound()
				end
			end
			
			-- When on vessel always 
		end
		
		-- Kill all actors outside the ship
		if self.Ship then
			for actor in MovableMan.Actors do
				if (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") and not self.Ship:IsInside(actor.Pos) and not actor:IsInGroup("Brains") then
					actor.Health = actor.Health - math.ceil(50/math.sqrt(1 + math.abs(actor.Mass + actor.Material.StructuralIntegrity)));
					-- Push actor outwards from the ship?
					--actor.Vel = actor.Vel + SceneMan:ShortestDistance(Vector(SceneMan.SceneWidth * 0.5, SceneMan.SceneHeight * 0.5), actor.Pos, SceneMan.SceneWrapsX) * 0.001;
				end
			end
		end
		
		-- Process enemy spawn during assaults
		if self.GS["Mode"] == "Assault" then
			if self.Time % 2 == 0 then
				self:MakeAlertSound()
			end
		
			-- Spawn enemies
			if self.AssaultNextSpawnTime == self.Time then
				-- Check end of assault conditions
				if CF_CountActors(CF_CPUTeam) == 0 and self.AssaultEnemiesToSpawn == 0 then
					-- End of assault
					self.GS["Mode"] = "Vessel"
					
					-- Give some exp
					if 	self.MissionReport == nil then
						self.MissionReport = {}
					end
					self.MissionReport[#self.MissionReport + 1] = "We survived this assault."
					self:GiveRandomExperienceReward(self.AssaultDifficulty)
					
					-- Remove turrets
					self:RemoveDeployedTurrets()

					-- Re-init consoles back
					self:InitConsoles()
					
					-- Launch ship assault encounter
					local id = "COUNTERATTACK"
					self.RandomEncounterID = id
					self.RandomEncounterVariant = 0
					
					self.RandomEncounterDelayTimer = Timer()
					self.RandomEncounterText = ""
					self.RandomEncounterVariants = {"Blood for Ba'al!!", "Let them leave."}
					self.RandomEncounterVariantsInterval = 12
					self.RandomEncounterChosenVariant = 0
					self.RandomEncounterIsInitialized = false
					self.ShipControlSelectedEncounterVariant = 1
					
					-- Switch to ship panel
					local bridgeempty = true
					local plrtoswitch = -1
					
					for plr = 0 , self.PlayerCount - 1 do
						local act = self:GetControlledActor(plr);
						
						if act and MovableMan:IsActor(act) then
							if act.PresetName ~= "Ship Control Panel" and plrtoswitch == -1 then
								plrtoswitch = plr
							end
							
							if act.PresetName == "Ship Control Panel" then
								bridgeempty = false
							end
						end
					end
						
					if plrtoswitch > -1 and bridgeempty and MovableMan:IsActor(self.ShipControlPanelActor) then
						self:SwitchToActor(self.ShipControlPanelActor, plrtoswitch, CF_PlayerTeam);
					end
					self.ShipControlMode = self.ShipControlPanelModes.REPORT					
				end

				--print ("Spawn")
				self.AssaultNextSpawnTime = self.Time + CF_AssaultDifficultySpawnInterval[self.AssaultDifficulty]
				
				local cnt = math.random(math.ceil(CF_AssaultDifficultySpawnBurst[self.AssaultDifficulty] * 0.5), CF_AssaultDifficultySpawnBurst[self.AssaultDifficulty])
				local engineer = false
				for j = 1, cnt do
					if self.AssaultEnemiesToSpawn > 0 then
						local act = CF_SpawnAIUnitWithPreset(self.GS, self.AssaultEnemyPlayer, CF_CPUTeam, self.AssaultNextSpawnPos, Actor.AIMODE_BRAINHUNT, math.random(CF_PresetTypes.INFANTRY1))
						
						if act then
							self.AssaultEnemiesToSpawn = self.AssaultEnemiesToSpawn - 1
							if not engineer and math.random() < 0.5 * j/cnt then
								act:AddInventoryItem((math.random() < 0.5 and CreateHDFirearm("Heavy Digger", "Base.rte") or CreateTDExplosive("Timed Explosive", "Coalition.rte")))
								engineer = true
							end
							MovableMan:AddActor(act)
							local fxb = CreateAEmitter("Teleporter Effect A");
							fxb.Pos = act.Pos;
							MovableMan:AddParticle(fxb);
							
							act:FlashWhite(math.random(400, 600));
						end
					end
				end
				self.AssaultWarningTime = math.random(5, 7)
				self.AssaultNextSpawnPos = self.EnemySpawn[math.random(#self.EnemySpawn)]
			end
		end
	end
	
	if self.GS["Mode"] == "Assault" then
		-- Show enemies count
		if self.Time % 10 == 0 and self.AssaultEnemiesToSpawn > 0 then
			FrameMan:SetScreenText("Remaining assault bots: "..self.AssaultEnemiesToSpawn, 0, 0, 1500, true);
		end
		
		-- Create teleportation effect
		--print ("-")
		--print (AssaultEnemiesToSpawn)
		--print (self.AssaultNextSpawnTime)
		
		if self.AssaultEnemiesToSpawn > 0 and self.AssaultNextSpawnTime - self.Time < self.AssaultWarningTime then
			self:AddObjectivePoint("INTRUDER\nALERT", self.AssaultNextSpawnPos , CF_PlayerTeam, GameActivity.ARROWDOWN);
		
			if self.TeleportEffectTimer:IsPastSimMS(50) then
				-- Create particle
				local p = CreateMOSParticle("Tiny Blue Glow", self.ModuleName)
				p.Pos = self.AssaultNextSpawnPos + Vector(-20 + math.random(40), 30 - math.random(20))
				p.Vel = Vector(0,-2)
				MovableMan:AddParticle(p)
				self.TeleportEffectTimer:Reset()
			end
		end
	end
	
	-- DEBUG
	-- Debug-print unit orders
	--local arr = {}
	--arr[Actor.AIMODE_BRAINHUNT] = "Brainhunt"
	--arr[Actor.AIMODE_SENTRY] = "Sentry"
	--arr[Actor.AIMODE_GOLDDIG] = "Gold dig"
	--arr[Actor.AIMODE_GOTO] = "Goto"
	--
	--for actor in MovableMan.Actors do
	--	if actor.ClassName == "AHuman" or actor.ClassName == "ACrab" then
	--		local s = arr[actor.AIMode]
	--		
	--		if s ~= nil then
	--			CF_DrawString(s, actor.Pos + Vector(-20,30), 100, 100)
	--		end
	--	end
	--end

	-- Deploy turrets when key pressed
	--if UInputMan:KeyPressed(75) then
	--	if self.TurretsDeployedActors == nil then
	--		self:DeployTurrets()
	--	else
	--		self:RemoveDeployedTurrets()
	--	end
	--end
	
	if self.GS["Mode"] == "Mission" then
		self:ProcessLZControlPanelUI()
		
		-- Spawn units from table while it have some left
		if self.SpawnTable ~= nil then
			self:SpawnFromTable()
		end
		
		if self.AmbientUpdate ~= nil then
			self:AmbientUpdate()
		end
		
		if self.MissionUpdate ~= nil then
			self:MissionUpdate()
		end
		
		-- Make actors glitch if there are too many of them
		local count = 0;
		local braincount = 0;
		for actor in MovableMan.Actors do
			if actor.Team == CF_PlayerTeam and actor.ClassName ~= "Actor" and actor.ClassName ~= "ADoor" and not self:IsAlly(actor) then
				count = count + 1

				if self.Time % 4 == 0 and count > tonumber(self.GS["Player0VesselCommunication"]) and self.GS["BrainsOnMission"] ~= "True" then
					local cont = actor:GetController();
					if cont then
						if math.random() < 0.1 then
							if cont:IsState(Controller.WEAPON_FIRE) then
								cont:SetState(Controller.WEAPON_FIRE, false)
							else
								cont:SetState(Controller.WEAPON_FIRE, true)
							end
						end
						if cont:IsState(Controller.BODY_JUMP) then
						
							cont:SetState(Controller.BODY_JUMP, false)
							cont:SetState(Controller.BODY_JUMPSTART, false)
							cont:SetState(Controller.BODY_CROUCH, true)
							
						elseif cont:IsState(Controller.BODY_CROUCH) then
						
							cont:SetState(Controller.BODY_JUMP, true)
							cont:SetState(Controller.BODY_CROUCH, false)
						end
						if cont:IsState(Controller.MOVE_LEFT) then
						
							cont:SetState(Controller.MOVE_LEFT, false)
							cont:SetState(Controller.MOVE_RIGHT, true)
							
						elseif cont:IsState(Controller.MOVE_RIGHT) then
						
							cont:SetState(Controller.MOVE_RIGHT, false)
							cont:SetState(Controller.MOVE_LEFT, true)
						end
					end
					
					self:AddObjectivePoint("CONNECTION LOST", actor.AboveHUDPos , CF_PlayerTeam, GameActivity.ARROWUP);
				end
				if actor:IsInGroup("Brains") or actor:HasObjectInGroup("Brains") then
					braincount  = braincount + 1;
				end
			end
			
			-- Add allied units to array when they are actually spawned
			if actor.Team == CF_PlayerTeam and (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") then
				if string.find(actor.PresetName , "-") == 1 then
					local nw = #self.AlliedUnits + 1
					self.AlliedUnits[nw] = actor
					actor.PresetName = string.sub(actor.PresetName , 2 , string.len(actor.PresetName))
				end
			end
		end
		
		-- Check losing conditions
		if self.GS["BrainsOnMission"] ~= "False" and self.ActivityState ~= Activity.OVER then
			if braincount < self.PlayerCount and self.EnableBrainSelection and self.Time > self.MissionStartTime + 1 then
				self.WinnerTeam = CF_CPUTeam;
				ActivityMan:EndActivity();
				self:StartMusic(CF_MusicTypes.DEFEAT)
			end
		end
	end
	if CF_TypingActor and MovableMan:IsActor(CF_TypingActor) then
		local screen = self:ScreenOfPlayer(Activity.PLAYER_1);
		SceneMan:SetScrollTarget(CF_TypingActor.AboveHUDPos + CF_TypingActor.Vel * rte.PxTravelledPerFrame + Vector(1, 22), 1, false, screen);
		local controlledActor = self:GetControlledActor(Activity.PLAYER_1);
		local controller = controlledActor:GetController();
		if controlledActor.UniqueID ~= CF_TypingActor.UniqueID then
			self:SwitchToActor(CF_TypingActor, controller.Player, controlledActor.Team);
		else
			for i = 0, 29 do	--Go through and disable the gameplay-related controller states
				controller:SetState(i, false);
			end
			if UInputMan:AnyPress() then
				for i = 1, #self.keyString do
					local keyString = self.keyString[i];
					if (i == self.key.delete) and UInputMan:KeyPressed(i) then
						self.nameString = {};
					elseif (i == self.key.backspace) and UInputMan:KeyPressed(i) then
						self.nameString[#self.nameString] = nil;
					elseif (i == self.key.enter) and UInputMan:KeyPressed(i) then
						if self.nameString == nil or #self.nameString == 0 or self.nameString[#self.nameString] == "" then
							CF_TypingActor:RemoveStringValue("VW_Name");
						else
							CF_TypingActor:SetStringValue("VW_Name", self.nameString[#self.nameString]);
						end
						CF_TypingActor:FlashWhite(100);
						CF_TypingActor = nil;
						self.nameString = {};
					elseif keyString ~= "" and UInputMan:KeyPressed(i) then
						self.nameString[#self.nameString + 1] = (self.nameString[#self.nameString] or "") .. (UInputMan.FlagShiftState and (self.keyStringShift[i] or keyString) or string.lower(keyString));
					end
				end
			end
			--if #self.nameString ~= 0 then
				--PrimitiveMan:DrawTextPrimitive(screen, controlledActor.AboveHUDPos + Vector(1, -6), self.nameString[#self.nameString], false, 1);
			--end
		end
		local nameString = #self.nameString ~= 0 and self.nameString[#self.nameString] or ""
		FrameMan:SetScreenText("> NAME YOUR UNIT <\n" .. nameString, screen, 0, 1, true);
	else
		CF_TypingActor = nil;
		self.nameString = {};
	end

	if self.EnableBrainSelection then
		self:DoBrainSelection()
	end
	self:CheckWinningConditions();
	self:YSortObjectivePoints();
	--]]--
	
end
-----------------------------------------------------------------------------------------
-- Brain selection and gameover conditions check
-----------------------------------------------------------------------------------------
function VoidWanderers:CheckWinningConditions()
	if self.ActivityState ~= Activity.OVER then
	end
end
-----------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------
function VoidWanderers:GetItemPrice(itmpreset, itmclass)
	local price = 0;

	for f = 1, #CF_Factions do
		local ff = CF_Factions[f]
		for i = 1, #CF_ItmNames[ff] do
			local class = CF_ItmClasses[ff][i]
			if class == nil then
				class = "HDFirearm"
			end

			if itmclass == class and itmpreset == CF_ItmPresets[ff][i] then
				return CF_ItmPrices[ff][i]
			end
		end
	end
	
	return price;
end
-----------------------------------------------------------------------------------------
-- Brain selection and gameover conditions check
-----------------------------------------------------------------------------------------
function VoidWanderers:DoBrainSelection()
	if self.ActivityState ~= Activity.OVER then
		for player = 0, self.PlayerCount - 1 do
			local team = self:GetTeamOfPlayer(player);
			local brain = self:GetPlayerBrain(player);

			if not brain or not MovableMan:IsActor(brain) or not brain:HasObjectInGroup("Brains") then
				if team == CF_PlayerTeam then
					self.PlayerBrainDead = true
				end

				self:SetPlayerBrain(nil, player);
				local newBrain = MovableMan:GetUnassignedBrain(team);
				if newBrain then
					self:SetPlayerBrain(newBrain, player);
					self:SwitchToActor(newBrain, player, team);
					-- Looks like a brain actor can't become a brain actor if it can't hit MO's
					-- so we'll define LZ actors as hittable but then change this once our brains are assigned to cheat
					if newBrain.PresetName == "LZ Control Panel" then
						newBrain.HitsMOs = false
						newBrain.GetsHitByMOs = false
					end
					if team == CF_PlayerTeam then
						self.PlayerBrainDead = false
						self:GetBanner(GUIBanner.RED, Activity.PLAYER_1):ClearText();
					end
				else
					for actor in MovableMan.Actors do
						if actor.Team == team and actor:HasObjectInGroup("Brains") then
							self:SetPlayerBrain(actor, player);
							self:SwitchToActor(actor, player, team);
							if team == CF_PlayerTeam then
								self.PlayerBrainDead = false
							end
							self:GetBanner(GUIBanner.RED, Activity.PLAYER_1):ClearText();
						end
					end
				end
			else
				self:SetObservationTarget(brain.Pos, player)
			end
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:DrawDottedLine(x1,y1,x2,y2,dot,interval)
	local d = CF_Dist(Vector(x1,y1), Vector(x2,y2))
		
	local ax = (x2 - x1) / d * interval
	local ay = (y2 - y1) / d * interval
	
	local x = x1
	local y = y1
	
	d = math.floor(d)
	
	for i = 1, d, interval do
		self:PutGlowWithModule(dot, Vector(x,y), self.ModuleName)
		
		x = x + ax
		y = y + ay
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:DeployGenericMissionEnemies(setnumber, setname, plr, team, spawnrate)
	-- Define spawn queue
	local dq = {}
	-- Defenders aka turrets if any
	dq[1] = {}
	dq[1]["Preset"] = CF_PresetTypes.DEFENDER
	dq[1]["PointName"] = "Defender"
	
	-- Snipers
	dq[2] = {}
	dq[2]["Preset"] = CF_PresetTypes.SNIPER
	dq[2]["PointName"] = "Sniper"
	
	--Heavies
	dq[3] = {}
	if math.random(10) < 5 then
		dq[3]["Preset"] = CF_PresetTypes.HEAVY1
	else
		dq[3]["Preset"] = CF_PresetTypes.HEAVY2
	end
	dq[3]["PointName"] = "Heavy"
	
	--Shotguns
	dq[4] = {}
	dq[4]["Preset"] = CF_PresetTypes.SHOTGUN
	dq[4]["PointName"] = "Shotgun"
	
	-- Armored
	dq[5] = {}
	if math.random(10) < 5 then
		dq[5]["Preset"] = CF_PresetTypes.ARMOR1
	else
		dq[5]["Preset"] = CF_PresetTypes.ARMOR2
	end
	dq[5]["PointName"] = "Armor"

	-- Riflemen
	dq[6] = {}
	if math.random(10) < 5 then
		dq[6]["Preset"] = CF_PresetTypes.INFANTRY1
	else
		dq[6]["Preset"] = CF_PresetTypes.INFANTRY2
	end
	dq[6]["PointName"] = "Rifle"

	-- Random
	dq[7] = {}
	dq[7]["Preset"] = nil
	dq[7]["PointName"] = "Any"--]]--
	
	-- Spawn everything
	for d = 1, #dq do
		local fullenmpos = CF_GetPointsArray(self.Pts, setname, setnumber, dq[d]["PointName"])
		local count = math.floor(spawnrate * #fullenmpos)
		-- Guarantee that at least one unit is awlays spawned
		if count < 1 then
			count = 1
		end
		
		local enmpos = CF_SelectRandomPoints(fullenmpos, count)
		
		--print (dq[d]["PointName"].." - "..#enmpos.." / ".. #fullenmpos .." - "..spawnrate)
		
		for i = 1, #enmpos do
			local nw = {}
			if dq[d]["Preset"] == nil then
				nw["Preset"] = math.random(CF_PresetTypes.ARMOR2)
			else
				nw["Preset"] = dq[d]["Preset"]
			end
			nw["Team"] = team
			nw["Player"] = plr
			nw["AIMode"] = Actor.AIMODE_SENTRY
			nw["Pos"] = enmpos[i]
			
			-- If spawning as player's team then they are allies
			if team == CF_PlayerTeam then
				nw["RenamePreset"] = "-"
			end
			
			table.insert(self.SpawnTable, nw)
		end
	end
	
	-- Get LZs
	self.MissionLZs = CF_GetPointsArray(self.Pts, setname, setnumber, "LZ")
	
	-- Get base box
	local bp = CF_GetPointsArray(self.Pts, setname, setnumber, "Base")
	self.MissionBase = {}
	
	for i = 1, #bp, 2 do
		if bp[i + 1] == nil then
			print ("OUT OF BOUNDS WHEN BUILDING BASE BOX")
			break
		end
		
		-- Split the box if we're crossing the seam
		if bp[i].X > bp[i + 1].X then
			local nxt = #self.MissionBase + 1
			-- Box(x1,y1, x2, y2)
			self.MissionBase[nxt] = Box(bp[i].X, bp[i].Y, SceneMan.Scene.Width, bp[i + 1].Y)

			local nxt = #self.MissionBase + 1
			self.MissionBase[nxt] = Box(0, bp[i].Y, bp[i + 1].X, bp[i + 1].Y)
		else
			local nxt = #self.MissionBase + 1
			self.MissionBase[nxt] = Box(bp[i].X, bp[i].Y, bp[i + 1].X, bp[i + 1].Y)
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:GiveMissionRewards(disablepenalties)
	print ("MISSION COMPLETED")
	self.GS["Player"..self.MissionSourcePlayer.."Reputation"] = tonumber(self.GS["Player"..self.MissionSourcePlayer.."Reputation"]) + self.MissionReputationReward
	if not disablepenalties then
		self.GS["Player"..self.MissionTargetPlayer.."Reputation"] = tonumber(self.GS["Player"..self.MissionTargetPlayer.."Reputation"]) - math.ceil(self.MissionReputationReward * CF_ReputationPenaltyRatio)
	end
	CF_SetPlayerGold(self.GS, 0, CF_GetPlayerGold(self.GS, 0) + self.MissionGoldReward)

	-- speed up black market refreshal
	if self.GS["BlackMarket".."Station Ypsilon-2".."ItemsLastRefresh"] ~= nil then
		local last = tonumber(self.GS["BlackMarket".."Station Ypsilon-2".."ItemsLastRefresh"])
		if (last + CF_BlackMarketRefreshInterval) * RangeRand(0.5, 0.75) < tonumber(self.GS["Time"]) then
			self.GS["BlackMarket".."Station Ypsilon-2".."ItemsLastRefresh"] = nil
		end
	end
	if self.GS["BlackMarket".."Station Ypsilon-2".."ActorsLastRefresh"] ~= nil then
		local last = tonumber(self.GS["BlackMarket".."Station Ypsilon-2".."ActorsLastRefresh"])
		if (last + CF_BlackMarketRefreshInterval) * RangeRand(0.5, 0.75) < tonumber(self.GS["Time"]) then
			self.GS["BlackMarket".."Station Ypsilon-2".."ActorsLastRefresh"] = nil
		end
	end
	
	self.MissionReport[#self.MissionReport + 1] = "MISSION COMPLETED"
	if self.MissionGoldReward > 0 then
		self.MissionReport[#self.MissionReport + 1] = tostring(self.MissionGoldReward).."oz of gold received"
	end
	
	local exppts = math.floor((self.MissionReputationReward + self.MissionGoldReward) / 8)
	print("exppts " .. exppts)
	
	local levelup = false;

	if self.GS["BrainsOnMission"] == "True" then
		levelup = CF_GiveExp(self.GS, exppts)
		
		self.MissionReport[#self.MissionReport + 1] = tostring(exppts).." exp received"
		if levelup then
			local s = ""
			if self.PlayerCount > 1 then
				s = "s"
			end
		
			self.MissionReport[#self.MissionReport + 1] = "Brain"..s.." leveled up!"
		end
	end
	
	local actors = {};
	for actor in MovableMan.Actors do
		if actor.Team == CF_PlayerTeam and not actor:HasObjectInGroup("Brains") and (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") then
			table.insert(actors, actor)
		end
	end
	if #actors > 0 then
		local gains = 1 + (exppts * 0.1)/#actors
		for _, actor in pairs(actors) do
			self:GiveXP(actor, gains)
		end
	end

	if self.MissionReputationReward > 0 then
		self.MissionReport[#self.MissionReport + 1] = "+"..self.MissionReputationReward.." "..CF_FactionNames[ CF_GetPlayerFaction(self.GS, self.MissionSourcePlayer) ].." reputation"
		if not disablepenalties then
			self.MissionReport[#self.MissionReport + 1] = "-"..math.ceil(self.MissionReputationReward * CF_ReputationPenaltyRatio).." "..CF_FactionNames[ CF_GetPlayerFaction(self.GS, self.MissionTargetPlayer) ].." reputation"
		end
	end

	self.MissionFailed = false
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:GiveMissionPenalties()
	print ("MISSION FAILED")
	self.GS["Player"..self.MissionSourcePlayer.."Reputation"] = tonumber(self.GS["Player"..self.MissionSourcePlayer.."Reputation"]) - math.ceil(self.MissionReputationReward * CF_MissionFailedReputationPenaltyRatio)
	self.GS["Player"..self.MissionTargetPlayer.."Reputation"] = tonumber(self.GS["Player"..self.MissionTargetPlayer.."Reputation"]) - math.ceil(self.MissionReputationReward * CF_MissionFailedReputationPenaltyRatio)
	
	self.MissionReport[#self.MissionReport + 1] = "MISSION FAILED"
	
	local loss = math.floor((self.MissionReputationReward + self.MissionGoldReward) * 0.005)
	for actor in MovableMan.Actors do
		if actor.Team == CF_PlayerTeam and not actor:HasObjectInGroup("Brains") and (actor.ClassName == "AHuman" or actor.ClassName == "ACrab") then
			self:GiveXP(actor, -(loss + actor:GetNumberValue("VW_XP") * 0.1))
		end
	end
	if self.MissionReputationReward > 0 then
		self.MissionReport[#self.MissionReport + 1] = "-"..math.ceil(self.MissionReputationReward * CF_MissionFailedReputationPenaltyRatio).." "..CF_FactionNames[ CF_GetPlayerFaction(self.GS, self.MissionSourcePlayer) ].." reputation"
		self.MissionReport[#self.MissionReport + 1] = "-"..math.ceil(self.MissionReputationReward * CF_MissionFailedReputationPenaltyRatio).." "..CF_FactionNames[ CF_GetPlayerFaction(self.GS, self.MissionTargetPlayer) ].." reputation"
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:IsAlly(actor)
	--return actor:NumberValueExists("VW_Ally")
	if self.AlliedUnits ~= nil then
		local l = #self.AlliedUnits
		for i = 1, l do
			if self.AlliedUnits[i] ~= nil and MovableMan:IsActor(self.AlliedUnits[i]) then
				if self.AlliedUnits[i].ID == actor.ID then
					return true
				end
			else
				self.AlliedUnits[i] = nil
			end
		end
	end
	return false
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:IsPlayerUnit(actor)
	return (IsAHuman(actor) or IsACrab(actor)) and actor.Team == CF_PlayerTeam and not (actor:HasObjectInGroup("Brains") or self:IsAlly(actor))
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:AddPreEquippedItemsToRemovalQueue(a)
	-- Mark actor's pre-equipped items for deletion
	if CF_ItemsToRemove[a.PresetName] then
		for i = 1, #CF_ItemsToRemove[a.PresetName] do
			local nw = #self.ItemRemoveQueue + 1
			self.ItemRemoveQueue[nw] = {}
			self.ItemRemoveQueue[nw]["Preset"] = CF_ItemsToRemove[a.PresetName][i]
			self.ItemRemoveQueue[nw]["Actor"] = a
		end
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:InitExplorationPoints()
	local set = CF_GetRandomMissionPointsSet(self.Pts, "Exploration")

	local pts = CF_GetPointsArray(self.Pts, "Exploration", set, "Explore")
	self.MissionExplorationPoint = pts[math.random(#pts)]
	self.MissionExplorationRecovered = false
	
	self.MissionExplorationHologram = "Holo" .. math.random(CF_MaxHolograms)
	
	self.MissionExplorationText = {}
	self.MissionExplorationTextStart = -100
	
	--print (self.MissionExplorationPoint)
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:ProcessExplorationPoints()
	if self.MissionExplorationPoint ~= nil then
		if not self.MissionExplorationRecovered then
			if math.random(10) < 7 then
				self:PutGlow(self.MissionExplorationHologram, self.MissionExplorationPoint)
			end
			
			-- Send all units to brainhunt
			for actor in MovableMan.Actors do
				if actor.Team == CF_PlayerTeam and CF_Dist(actor.Pos, self.MissionExplorationPoint) < 25 then
					if actor:IsInGroup("Brains") then
						self.MissionExplorationText = self:GiveRandomExplorationReward()
						self.MissionExplorationRecovered = true
						--self.MissionExplorationPoint = nil
						
						self.MissionExplorationTextStart = self.Time
						
						for a in MovableMan.Actors do
							if a.Team ~= CF_PlayerTeam then
								CF_HuntForActors(a, CF_PlayerTeam)
							end
						end
						
						break
					else
						self:AddObjectivePoint("Only brain can decrypt this holorecord", self.MissionExplorationPoint + Vector(0,-30) , CF_PlayerTeam, GameActivity.ARROWDOWN);
					end
				end
			end
		end
	end
	
	if self.Time > self.MissionExplorationTextStart and self.Time < self.MissionExplorationTextStart + 10 then
		local txt = ""
		for i = 1, #self.MissionExplorationText do
			txt = self.MissionExplorationText[i] .."\n"
		end
		
		self:AddObjectivePoint(txt, self.MissionExplorationPoint + Vector(0,-30) , CF_PlayerTeam, GameActivity.ARROWDOWN);
	end
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:GiveRandomExplorationReward()
	local rewards = {gold = 1, experience = 2, reputation = 3, blueprints = 4, nothing = 5}
	local text = {"Nothing of value was found."}
	
	local r = math.random(#rewards)
	
	if r == rewards.gold then
		local amount = math.floor(math.random(self.MissionDifficulty * 250, self.MissionDifficulty * 500))
		
		CF_SetPlayerGold(self.GS, 0, CF_GetPlayerGold(self.GS, 0) + amount)
		text = {}
		text[1] = "Bank account access codes found.\n"..tostring(amount).."oz of gold received."
	elseif r == rewards.experience then
		local exppts = math.floor(math.random(self.MissionDifficulty * 75, self.MissionDifficulty * 150))
		levelup = CF_GiveExp(self.GS, exppts)
		
		text = {}
		text[1] = "Captain's log found. "..exppts.." exp gained."
		
		if levelup then
			local s = ""
			if self.PlayerCount > 1 then
				s = "s"
			end
		
			text[1] = text[1].."\nBrain"..s.." leveled up!"
		end
	elseif r == rewards.reputation then
		local amount = math.floor(math.random(self.MissionDifficulty * 75, self.MissionDifficulty * 150))
		local plr = math.random(tonumber(self.GS["ActiveCPUs"]))
		
		local rep = tonumber(self.GS["Player"..plr.."Reputation"])
		self.GS["Player"..plr.."Reputation"] = rep + amount
		
		text = {}
		text[1] = "Intelligence data found.\n+"..amount.." "..CF_GetPlayerFaction(self.GS, plr).." reputation."
	elseif r == rewards.blueprints then
		local id = CF_UnlockRandomQuantumItem(self.GS)
		
		text = {CF_QuantumItmPresets[id].." quantum scheme found."}
	end
	
	if self.MissionReport == nil then
		self.MissionReport = {}
	end
	for i = 1, #text do
		self.MissionReport[#self.MissionReport + 1]	= text[i]
	end
	CF_SaveMissionReport(self.GS, self.MissionReport)
	
	return text;
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:GiveRandomExperienceReward(diff)
	local exppts = 150 + math.random(350)
	
	if diff ~= nil then
		exppts = CF_CalculateReward(diff , 250)
	end
	
	levelup = CF_GiveExp(self.GS, exppts)
	
	text = {}
	text[1] = tostring(exppts).." exp gained."
	
	if levelup then
		local s = ""
		if self.PlayerCount > 1 then
			s = "s"
		end
	
		text[2] = "Brain"..s.." leveled up!"
	end

	if 	self.MissionReport == nil then
		self.MissionReport = {}
	end
	for i = 1, #text do
		self.MissionReport[#self.MissionReport + 1]	= text[i]
	end
	CF_SaveMissionReport(self.GS, self.MissionReport)
end-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:MakeAlertSound()
	local pos = self.BrainPos[1];
	local actor = self:GetControlledActor(Activity.PLAYER_1);
	if actor and MovableMan:IsActor(actor) then
		pos = actor.Pos;
	end

	local fxb = CreateAEmitter("Alarm Effect");
	fxb.Pos = pos;
	MovableMan:AddParticle(fxb);				
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:StartMusic(musictype)
	print ("VoidWanderers:StartMusic")
	local ok = false
	local counter = 0
	local track = -1
	local queue = false
	
	-- Queue defeat or victory loops
	if musictype == CF_MusicTypes.VICTORY then
		AudioMan:PlayMusic("Base.rte/Music/dBSoundworks/uwinfinal.ogg", 1, -1);
		queue = true
		print ("MUSIC: Play victory")
	end
	
	if musictype == CF_MusicTypes.DEFEAT then
		AudioMan:PlayMusic("Base.rte/Music/dBSoundworks/udiedfinal.ogg", 1, -1);
		queue = true
		print ("MUSIC: Play defeat")
	end
	
	-- Select calm music to queue after victory or defeat
	if self.LastMusicType ~= -1 and queue then
		if self.LastMusicType == CF_MusicTypes.SHIP_CALM or self.LastMusicType == CF_MusicTypes.SHIP_INTENSE then
			musictype = CF_MusicTypes.SHIP_CALM
		end
	
		if self.LastMusicType == CF_MusicTypes.MISSION_CALM or self.LastMusicType == CF_MusicTypes.MISSION_INTENSE then
			musictype = CF_MusicTypes.MISSION_CALM
		end
	end
	
	while (not ok) do
		ok = true
		if CF_Music and CF_Music[musictype] then
			track = math.random(1, #CF_Music[musictype])
				
			if musictype ~= self.LastMusicType and #CF_Music[musictype] > 1 then
				if track == self.LastMusicTrack then
					ok = false
				end
			end
			--print (track)
			--print (CF_Music[musictype][track])
		end

		counter = counter + 1
		if counter > 5 then
			print ("BREAK")
			break
		end
	end
	
	-- If we're playing intense music, then just queue it once and play ambient all the other times
	if ok then
		if musictype == CF_MusicTypes.SHIP_INTENSE or musictype == CF_MusicTypes.MISSION_INTENSE then
			self:PlayMusicFile(CF_Music[musictype][track], false, 1)
			print ("MUSIC: Queue intense")
		else
			self:PlayMusicFile(CF_Music[musictype][track], queue, -1)
			if queue then
				print("MUSIC: Queue calm")
			else
				print("MUSIC: Play calm")
			end
		end
	end

	-- Then add a calm music after an intense
	if musictype == CF_MusicTypes.SHIP_INTENSE or musictype == CF_MusicTypes.MISSION_INTENSE then
		if musictype == CF_MusicTypes.SHIP_INTENSE then
			musictype = CF_MusicTypes.SHIP_CALM
		end
	
		if musictype == CF_MusicTypes.MISSION_INTENSE then
			musictype = CF_MusicTypes.MISSION_CALM
		end

		local ok = false
		local counter = 0

		while (not ok) do
			ok = true

			track = math.random(#CF_Music[musictype])
			
			if musictype ~= self.LastMusicType and #CF_Music[musictype] > 1 then
				if track == self.LastMusicTrack then
					ok = false
				end
			end
			
			counter = counter + 1
			if counter > 5 then
				print ("BREAK")
				break
			end
		end
		if ok then
			self:PlayMusicFile(CF_Music[musictype][track], true, -1)
			print("MUSIC: Queue calm")
		end
	end
	
	self.LastMusicType = musictype
	self.LastMusicTrack = track
--]]--
end
-----------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------
function VoidWanderers:PlayMusicFile(path , queue, count)
	if CF_IsFilePathExists(path) then
		if queue then
			AudioMan:QueueMusicStream(path)
		else
			AudioMan:ClearMusicQueue();
			AudioMan:PlayMusic(path, count, -1);
		end
		return true
	else
		print ("ERR: Can't find music: "..path);
		return false
	end	
end
-----------------------------------------------------------------------------------------
-- That's all folks!!!
-----------------------------------------------------------------------------------------
