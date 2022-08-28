function Update(self)
	local parent = self:GetParent()
	if not (parent and IsActor(parent) and ToActor(parent).Status < Actor.DYING) and self.WoundCount < self.GibWoundLimit/2 then
		local newLimb = CreateHeldDevice(string.sub(self.PresetName, 0, -4))
		newLimb.Team = self.Team
		newLimb.IgnoresTeamHits = true
		newLimb.HUDVisible = false
		newLimb.Pos = self.Pos
		newLimb.RotAngle = self.RotAngle
		newLimb.HFlipped = self.HFlipped
		newLimb.Vel = self.Vel/2
		newLimb.AngularVel = self.AngularVel/2
		MovableMan:AddItem(newLimb)
		self.ToDelete = true
	end
end