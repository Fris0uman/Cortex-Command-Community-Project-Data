--[[
	Miranda Zone Reavers by Major
	Supported out of the box
]]--

local id = "REAVERS";
CF_RandomEncounters[#CF_RandomEncounters + 1] = id
CF_RandomEncountersInitialTexts[id] = ""
CF_RandomEncountersInitialVariants[id] = {"Fight the bastards!", "Stay low", "RUN!!!"}
CF_RandomEncountersVariantsInterval[id] = 24
CF_RandomEncountersOneTime[id] = false
CF_RandomEncountersFunctions[id] = 

function (self, variant)
	if not self.RandomEncounterIsInitialized then
		self.RandomEncounterReavers = {}

		self.RandomEncounterReaversAct = 	{"Reaver", "Bone Reaver"}
		self.RandomEncounterReaversActMod = {"VoidWanderers.rte", "VoidWanderers.rte"}

		self.RandomEncounterReaversLight = 	{"JPL 10 Auto", "K-LDP 7.7mm"}
		self.RandomEncounterReaversLightMod = 	{"VoidWanderers.rte", "VoidWanderers.rte"}

		self.RandomEncounterReaversHeavy = 	{"K-HAR 10mm", "Shrike Mdl.G", "PBL Maw"}
		self.RandomEncounterReaversHeavyMod = 	{"VoidWanderers.rte", "VoidWanderers.rte", "VoidWanderers.rte"}
		
		self.RandomEncounterReaversThrown = {"M67 Grenade", "M24 Potato Masher", "Molotov Cocktail", "Scrambler"};
		self.RandomEncounterReaversThrownMod = 	{"Ronin.rte", "Ronin.rte", "Ronin.rte", "Ronin.rte"};
		
		self.RandomEncounterReaversInterval = 8
		
		local id = CF_Vessel[ math.random(#CF_Vessel) ]
		
		self.RandomEncounterShipId = id
		self.RandomEncounterSpeed = math.random(CF_VesselStartSpeed[id], CF_VesselMaxSpeed[id]) + 1

		self.RandomEncounterDistance = math.random(300, 400) - self.RandomEncounterSpeed
		self.RandomEncounterMaxDistance = math.random(400, 500)
		-- Eat the rich!
		self.RandomEncounterPlayerGoldScalar = math.sqrt(1 + CF_GetPlayerGold(self.GS, 0) * 0.001)
		local maxCapacity = math.ceil(CF_VesselMaxClonesCapacity[id] * 0.5)
		local minCapacity = math.ceil(math.max(maxCapacity * 0.5, CF_VesselStartClonesCapacity[id] * 0.5))
		self.RandomEncounterReaversUnitCount =  math.random(minCapacity, maxCapacity)
		self.RandomEncounterDifficulty = math.min(math.max(math.floor(self.RandomEncounterReaversUnitCount * 0.2), 0), CF_MaxDifficulty)
		
		self.RandomEncounterText = "An unknown ".. CF_VesselName[id].." class ship detected, it must be Reavers!!! If we hide everything and stay low, they might think it's a dead ship."
		
		self.RandomEncounterScanTimeMax = math.ceil(math.random(20, 25)/math.sqrt(self.RandomEncounterDifficulty))
		self.RandomEncounterScanTime = math.random(math.min(CF_CountActors(CF_PlayerTeam) * 5 + 10, self.RandomEncounterScanTimeMax - 1), self.RandomEncounterScanTimeMax)

		self.RandomEncounterDir = -1
		if SceneMan.Scene:HasArea("LeftGates") then
			if SceneMan.Scene:HasArea("RightGates") and math.random() < 0.5 then
				self.RandomEncounterGates = SceneMan.Scene:GetArea("RightGates")
				self.RandomEncounterDir = 1
			else
				self.RandomEncounterGates = SceneMan.Scene:GetArea("LeftGates")
			end
		elseif SceneMan.Scene:HasArea("RightGates") then
			self.RandomEncounterGates = SceneMan.Scene:GetArea("RightGates")
			self.RandomEncounterDir = 1
		end
		self.RandomEncounterShotCount = 0
		local centerGates = self.RandomEncounterGates:GetCenterPoint()
		if self.RandomEncounterGates then
			for actor in MovableMan.Actors do
				if actor.ClassName == "ADoor" and SceneMan:ShortestDistance(actor.Pos, centerGates, false).Magnitude < actor.Radius and math.random() < 1/(1 + self.RandomEncounterShotCount) then
					self.RandomEncounterShotCount = self.RandomEncounterShotCount + 1
				end
			end
		end
		self.RandomEncounterGatesDistance = SceneMan:ShortestDistance(centerGates, Vector(self.RandomEncounterDir == 1 and SceneMan.SceneWidth or 0, centerGates.Y), false).Magnitude

		self.RandomEncounterAttackLaunched = false
		self.RandomEncounterScanLaunched = false
		self.RandomEncounterRunLaunched = false
		self.RandomEncounterFightSelected = false
		self.RandomEncounterAbortChase = false
		self.RandomEncounterIsInitialized = true
	end

	if variant == 1 then
		self.RandomEncounterText = "BATTLE STATIONS!!!"
		self.RandomEncounterVariants = {}
		self.RandomEncounterChosenVariant = 0
		self.RandomEncounterRunLaunched = true
		self.RandomEncounterRunStarted = self.Time
		self.RandomEncounterFightSelected = true
		self.RandomEncounterChaseTimer = Timer()
	end
	
	if variant == 2 then
		self.RandomEncounterText = "They are scanning us..."
		self.RandomEncounterVariants = {}
		self.RandomEncounterChosenVariant = 0
		self.RandomEncounterScanLaunched = true
		self.RandomEncounterScanStarted = self.Time
	end	

	if variant == 3 then
		self.RandomEncounterText = "Let's pray we're faster..."
		self.RandomEncounterVariants = {}
		self.RandomEncounterChosenVariant = 0
		self.RandomEncounterRunLaunched = true
		self.RandomEncounterBoostTriggered = false
		self.RandomEncounterRunStarted = self.Time
		self.RandomEncounterChaseTimer = Timer()
	end	
	
	if self.RandomEncounterScanLaunched == true then
		local act = CF_CountActors(CF_PlayerTeam)
		local prob = math.min(math.floor(act * 5 * self.RandomEncounterPlayerGoldScalar), 100)
		
		local progress = self.Time - self.RandomEncounterScanStarted
	
		FrameMan:SetScreenText("Scan progress "..math.floor(progress / self.RandomEncounterScanTimeMax * 100).."%\nProbability to detect life signs: "..prob.."%", 0, 0, 1500, true);
		
		if self.Time >= self.RandomEncounterScanStarted + self.RandomEncounterScanTime then

			if math.random(100) < prob then
				self.RandomEncounterText = "BATTLE STATIONS!!!"
				self.RandomEncounterVariants = {}
				self.RandomEncounterChosenVariant = 0
				self.RandomEncounterRunLaunched = true
				self.RandomEncounterScanLaunched = false
				self.RandomEncounterRunStarted = self.Time
				self.RandomEncounterFightSelected = true
				self.RandomEncounterChaseTimer = Timer()
			else
				self.MissionReport = {}
				self.MissionReport[#self.MissionReport + 1] = prob > 90 and "They must be blind..." or "We tricked them. Lucky we are."
				CF_SaveMissionReport(self.GS, self.MissionReport)
				
				self.RandomEncounterText = ""
				
				-- Finish encounter
				self.RandomEncounterID = nil			
			end
		end
	end

	if self.RandomEncounterRunLaunched == true then
		FrameMan:SetScreenText("\nDistance: "..self.RandomEncounterDistance.."km", 0, 0, 1500, true)
	
		if self.RandomEncounterChaseTimer:IsPastSimMS(350) then
			if self.RandomEncounterFightSelected then
				self.RandomEncounterDistance = self.RandomEncounterDistance - self.RandomEncounterSpeed
			else
				self.RandomEncounterDistance = self.RandomEncounterDistance - self.RandomEncounterSpeed + tonumber(self.GS["Player0VesselSpeed"])
			end
			self.RandomEncounterChaseTimer:Reset()
			
			-- Boost reavers if they're too far
			if not self.RandomEncounterBoostTriggered then
				if self.RandomEncounterDistance > self.RandomEncounterMaxDistance or self.RandomEncounterSpeed == tonumber(self.GS["Player0VesselSpeed"]) then
					self.RandomEncounterBoostTriggered = true
					self.RandomEncounterSpeed = self.RandomEncounterSpeed + math.floor(math.random(4) * self.RandomEncounterPlayerGoldScalar)
					self.RandomEncounterText = (math.random() < 0.5 and "Oh crap" or "O kurwa")..", they overloaded their reactor to boost the engines!!!"
					
					if self.RandomEncounterSpeed <= tonumber(self.GS["Player0VesselSpeed"]) then
						self.RandomEncounterAbortChase = true
					end
				end
			end
			
			-- Stop chasing if it's too long
			if not self.RandomEncounterFightSelected then
				if (self.Time > self.RandomEncounterRunStarted + 40 and self.RandomEncounterDistance > 150) or self.RandomEncounterDistance > self.RandomEncounterMaxDistance + 100 or self.RandomEncounterAbortChase then
					self.MissionReport = {}
					self.MissionReport[#self.MissionReport + 1] = "They stopped chasing us. Lucky we are."
					CF_SaveMissionReport(self.GS, self.MissionReport)
					
					self.RandomEncounterText = ""
					
					-- Finish encounter
					self.RandomEncounterID = nil
				end
			end
			
			if self.RandomEncounterDistance <= 0 then
				self.RandomEncounterAttackLaunched = true
				self.RandomEncounterRunLaunched = false
				self.RandomEncounterNextAttackTime = self.Time

				--Deploy turrets
				self:DeployTurrets()
				
				-- Disable consoles
				self:DestroyStorageControlPanelUI()
				self:DestroyClonesControlPanelUI()
				self:DestroyBeamControlPanelUI()
				self:DestroyTurretsControlPanelUI()
			end
		end
	end
	
	if self.RandomEncounterAttackLaunched then
		if self.Time % 10 == 0 and self.RandomEncounterReaversUnitCount > 0 then
			FrameMan:SetScreenText("Remaining Reavers: "..self.RandomEncounterReaversUnitCount, 0, 0, 1500, true)
		end
		local centerGates = self.RandomEncounterGates:GetCenterPoint()
		if self.Time >= self.RandomEncounterNextAttackTime then
			self.RandomEncounterNextAttackTime = self.Time + self.RandomEncounterReaversInterval
			
			-- Create assault bot
			if MovableMan:GetMOIDCount() < CF_MOIDLimit and self.RandomEncounterReaversUnitCount > 0 then
				
				local rocket = CreateACRocket("Reaver Rocklet")
				if rocket then
					rocket.HFlipped = rocket.RandomEncounterDir == 1;
					rocket.Pos = Vector((self.RandomEncounterDir == 1 and SceneMan.SceneWidth + 1 or -1), centerGates.Y + math.random(rocket.Radius * RangeRand(-1, 1)))
					rocket.Vel = Vector(-10 * self.RandomEncounterDir, 0)
					rocket.RotAngle = math.pi * 0.49 * self.RandomEncounterDir

					rocket.Team = CF_CPUTeam
					rocket.AIMode = Actor.AIMODE_DELIVER
					rocket.Health = math.random(40, 60)
					
					for i = 1, 2 do
						if self.RandomEncounterReaversUnitCount > 0 then
							local r1 = math.random(#self.RandomEncounterReaversAct)
							local r2 = math.random(#self.RandomEncounterReaversLight)
							local r3 = math.random(#self.RandomEncounterReaversHeavy)
							local r4 = math.random(#self.RandomEncounterReaversThrown)
						
							local actor = CreateAHuman(self.RandomEncounterReaversAct[r1], self.RandomEncounterReaversActMod[r1])
							if actor then
								actor.Team = CF_CPUTeam
								actor.RotAngle = rocket.RotAngle
								actor.HFlipped = rocket.HFlipped
								actor.JetTimeTotal = actor.JetTimeTotal * 3
								
								if math.random() < 0.3 then
									if math.random() < 0.5 then
										local arm = CreateArm("Prosthetic Arm FG")
										arm:AddScript("VoidWanderers.rte/Items/Salvage.lua");
										actor.FGArm = arm;
									else
										local arm = CreateArm("Prosthetic Arm BG")
										arm:AddScript("VoidWanderers.rte/Items/Salvage.lua");
										actor.BGArm = arm;
									end
								end
								if math.random() < 0.3 then
									if math.random() < 0.5 then
										local leg = CreateLeg("Prosthetic Leg FG")
										leg:AddScript("VoidWanderers.rte/Items/Salvage.lua");
										actor.FGLeg = leg;
									else
										local leg = CreateLeg("Prosthetic Leg BG")
										leg:AddScript("VoidWanderers.rte/Items/Salvage.lua");
										actor.BGLeg = leg;
									end
								end
								
								local itm = CreateHDFirearm(self.RandomEncounterReaversHeavy[r3], self.RandomEncounterReaversHeavyMod[r3])
								if itm then
									actor:AddInventoryItem(itm)
								end

								local itm = CreateHDFirearm(self.RandomEncounterReaversLight[r2], self.RandomEncounterReaversLightMod[r2])
								if itm then
									actor:AddInventoryItem(itm)
								end
								local itm = math.random() < 0.1 and CreateTDExplosive("Timed Explosive", "Coalition.rte") or CreateTDExplosive(self.RandomEncounterReaversThrown[r4], self.RandomEncounterReaversThrownMod[r4])
								if itm then
									actor:AddInventoryItem(itm)
								end

								rocket:AddInventoryItem(actor)
								self.RandomEncounterReaversUnitCount = self.RandomEncounterReaversUnitCount - 1
							end
						end
					end
					
					MovableMan:AddActor(rocket)
					if self.RandomEncounterShotCount > 0 then
						self.RandomEncounterShotCount = self.RandomEncounterShotCount - 1
						local expl = CreateAEmitter("Reaver RPG")
						expl.Team = CF_CPUTeam
						local randNum = rocket.Radius * (math.random() < 0.5 and -1 or 1)
						expl.Pos = rocket.Pos + Vector(0, randNum)
						expl.LifeTime = self.RandomEncounterGatesDistance;
						expl.Vel = Vector(-math.random(40, 45) * self.RandomEncounterDir, -randNum * 0.05)
						expl.RotAngle = expl.Vel.AbsRadAngle
						MovableMan:AddParticle(expl)
					end
				
					self.RandomEncounterRocket = rocket
				end
			end
		end
		
		if self.RandomEncounterRocket then
			if MovableMan:IsActor(self.RandomEncounterRocket) then
			
				local rocket = ToACRocket(self.RandomEncounterRocket)
				local empty = rocket:IsInventoryEmpty()
				local boundsDist = self.RandomEncounterGatesDistance * 0.8 - 150
				if (self.Ship:IsInside(rocket.Pos) or not (rocket.Pos.X > SceneMan.SceneWidth - boundsDist or rocket.Pos.X < boundsDist)) and not empty then
					rocket:OpenHatch()
				end
				--if rocket.MainEngine then rocket.MainEngine:EnableEmission(true) end
				local cont = rocket:GetController()
				
				cont:SetState(Controller.MOVE_DOWN, empty or rocket.Vel.X * -self.RandomEncounterDir > 20)
				cont:SetState(Controller.MOVE_UP, not empty and rocket.Vel.X * -self.RandomEncounterDir < 10)
				cont:SetState(Controller.MOVE_RIGHT, false)
					
				local healthFactor = 1 - math.max(rocket.Health/rocket.MaxHealth, 0) * 0.5
				if empty then
					cont:SetState(Controller.MOVE_LEFT, true)
				else
					rocket.Vel = Vector(rocket.Vel.X, rocket.Vel.Y * healthFactor)
					rocket.AngularVel = rocket.AngularVel * healthFactor;
					
					cont:SetState(Controller.MOVE_LEFT, false)
				end
				
				if self.RandomEncounterGates and self.RandomEncounterGates:IsInside(rocket.Pos) then
					rocket.Vel.X = rocket.Vel.X * 0.3
					rocket:GibThis()
					rocket = nil
				end
				local futurePos = rocket.Pos + rocket.Vel * rte.PxTravelledPerFrame
				if not SceneMan:IsWithinBounds(futurePos.X, futurePos.Y, 100) and math.random() > healthFactor then
					-- The rocket made it to safety, add an extra Reaver
					self.RandomEncounterReaversUnitCount = self.RandomEncounterReaversUnitCount + 1
					rocket.ToDelete = true
				end
			else
				self.RandomEncounterRocket = nil
			end
		end
		
		-- Check wining conditions
		if self.RandomEncounterReaversUnitCount <= 0 and self.RandomEncounterRocket == nil and CF_CountActors(CF_CPUTeam) == 0 then
			self.MissionReport = {}
			self.MissionReport[#self.MissionReport + 1] = "Those were the last of them."

			self:GiveRandomExperienceReward(self.RandomEncounterDifficulty)
			
			-- Finish encounter
			self.RandomEncounterID = nil
			CF_SaveMissionReport(self.GS, self.MissionReport)
			-- Rebuild destroyed consoles
			self:InitStorageControlPanelUI()
			self:InitClonesControlPanelUI()
			self:InitBeamControlPanelUI()		
			self:InitTurretsControlPanelUI()		
		else
			for actor in MovableMan.Actors do
				local boundsDist = self.RandomEncounterGatesDistance - actor.IndividualRadius
				--Reavers in danger of flying out of bounds
				if actor.Team == CF_CPUTeam and IsAHuman(actor) and not self.Ship:IsInside(actor.Pos) then --(actor.Pos.X > SceneMan.SceneWidth - boundsDist or actor.Pos.X < boundsDist) then
					local active = actor.Status < Actor.INACTIVE
					if active then
						actor.Status = Actor.UNSTABLE
					end
					if active and actor.Age < 6000 then
						actor.Status = Actor.UNSTABLE
						actor.HFlipped = self.RandomEncounterDir == 1
						actor.AngularVel = actor.AngularVel + math.sin(actor.RotAngle - math.pi * 0.5 * actor.FlipFactor)
						if (actor.Vel.X + actor.PrevVel.X) * actor.FlipFactor < 5 then
							actor:GetController():SetState(Controller.BODY_JUMP, true)
							actor.Vel.Y = actor.Vel.Y + (centerGates.Y - actor.Pos.Y)/(250 + actor.Vel.Magnitude * 25)
						end
						boundsDist = boundsDist * 0.5
						if (actor.Pos.X > SceneMan.SceneWidth - boundsDist or actor.Pos.X < boundsDist or actor.Age > 1500) and not actor:NumberValueExists("GrapplingReaver") then
							local grapple = CreateMOSRotating("Reaver Grapple Hook")
							grapple.Pos = actor.Pos
							grapple.Sharpness = actor.ID
							grapple.Team = actor.Team
							grapple.Vel = actor.Vel * 0.5 + SceneMan:ShortestDistance(actor.Pos, centerGates, SceneMan.SceneWrapsX):RadRotate(RangeRand(-0.2, 0.2)):SetMagnitude(30)
							grapple.RotAngle = grapple.Vel.AbsRadAngle
							MovableMan:AddParticle(grapple)
							actor:SetNumberValue("GrapplingReaver", 1)
				
							actor.Vel.Y = actor.Vel.Y * 0.5
							actor.AngularVel = actor.AngularVel * 0.5
							actor.HFlipped = self.RandomEncounterDir == 1
							actor.AIMode = Actor.AIMODE_GOTO
							actor:AddAIMOWaypoint(self:GetPlayerBrain(Activity.PLAYER_1) or self:GetPlayerBrain(Activity.PLAYER_2))
						end
					else
						actor.AngularVel = actor.AngularVel - self.RandomEncounterDir/(1 + math.abs(actor.AngularVel)/(1 + actor.Vel.Magnitude));
					end
				end
			end
		end
	end
end
-------------------------------------------------------------------------------

