function Create(self)
	self:EraseFromTerrain();
	self.activity = ToGameActivity(ActivityMan:GetActivity());
	self.cost = self:GetGoldValue(0, 1, 1);
	self.text = "Open for " .. self.cost .. " gold";
	self.drop = CreateMOSRotating(self.PresetName .. " Item Spawn", "VoidWanderers.rte");
end
function OnPieMenu(self, pieActor)
	self.user = nil;
	if SceneMan:ShortestDistance(self.Pos, pieActor.Pos, SceneMan.SceneWrapsX).Magnitude < self.Radius + pieActor.IndividualRadius + 5 then
		local available = self.activity:GetTeamFunds(pieActor.Team) >= self.cost;
		if available then
			self.user = pieActor;
		end
		self.activity:AddPieMenuSlice(self.text, "VWOpenCrate", Slice.UP, available);
	end
end
function VWOpenCrate(actor)
	ToActor(actor):SetNumberValue("VWOpenCrate", 1);
	--ToGameActivity(ActivityMan:GetActivity()):RemovePieMenuSlice(self.text, "VWOpenCrate");
	--ToGameActivity(ActivityMan:GetActivity()):AddPieMenuSlice("Open Crate", "VWOpenCrate", Slice.UP, false);
end
function Update(self)
	if self.user and MovableMan:IsActor(self.user) then
		if self.user:NumberValueExists("VWOpenCrate") then
			self.user:RemoveNumberValue("VWOpenCrate");
			self.activity:SetTeamFunds(self.activity:GetTeamFunds(self.user.Team) - self.cost, self.user.Team);
			local parent = self:GetParent();
			self:GibThis();
			if parent and IsActor(parent) then
				parent.ToDelete = true;
				self.activity:ReportDeath(self.Team, -1);
			end
			if self.drop then
				self.drop.Pos = self.Pos;
				MovableMan:AddParticle(self.drop);
				self.drop = nil;
			end
		end
	else
		self.user = nil;
	end
end
function Destroy(self)
	if math.random() < 0.5 and self.drop then
		self.drop.Pos = self.Pos;
		MovableMan:AddParticle(self.drop);
		self.drop = nil;
	end
end