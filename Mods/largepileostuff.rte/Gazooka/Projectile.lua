function Create(self)
	self.trailRandom = Vector(self.Vel.Magnitude, 0)
		+ Vector(math.random((self.Vel.Magnitude / -3.75), (self.Vel.Magnitude / 15)), 0)
	self.trailSpread = math.random(-50, 50) / 1000
	local trail = CreateMOPixel("watthis")
	trail.Pos = self.Pos
	trail.Vel = self.trailRandom:RadRotate(self.RotAngle + self.trailSpread + math.rad(180)*math.min(0, self.FlipFactor))
	MovableMan:AddMO(trail)

	self.delay = 1

	function bloatAdd(range)
		if self.delay == 1 then
			self.delay = 0
			for actor in MovableMan.Actors do
				local distVec = SceneMan:ShortestDistance(self.Pos, actor.Pos, true)
				if
					distVec.Magnitude < range
					and actor.PresetName ~= "Reflective Robot MK-II"
					and actor:HasObjectInGroup("Craft") == false
					and SceneMan:CastStrengthRay(self.Pos, distVec, 6, Vector(0, 0), 3, 0, true) == false
				then
					actor:SetNumberValue("isBloating", 1)
				end
			end
		else
			self.delay = 1
		end
	end
end

function Update(self)
	self.trailRandom = Vector(self.Vel.Magnitude, 0)
		+ Vector(math.random((self.Vel.Magnitude / -3.75), (self.Vel.Magnitude / 15)), 0)
	self.trailSpread = math.random(-25, 25) / 1000
	local trail = CreateMOPixel("watthis")
	trail.Pos = self.Pos
	trail.Vel = self.trailRandom:RadRotate(self.RotAngle + self.trailSpread + math.rad(180)*math.min(0, self.FlipFactor))
	MovableMan:AddMO(trail)
	if self.Age > 1500 then
		self:GibThis()
	end

	bloatAdd(20)
end
