function Create(self)
	self.number = self.Sharpness;
	self.levelUp = self.Mass > 1;
	self.Sharpness = 0;
	self.speed = self.number ~= 0 and 1/math.sqrt(math.abs(self.number + self.Mass)) or 1
	self.Lifetime = self.Lifetime * math.sqrt(self.Mass) + self.Lifetime/self.speed;
end
function Update(self)
	PrimitiveMan:DrawTextPrimitive(-1, self.Pos + Vector(0, -8), (self.number < 0 and "" or "+") .. self.number .. " xp", false, 1)
	if self.levelUp then
		PrimitiveMan:DrawTextPrimitive(-1, self.Pos + Vector(0, -16), "LEVEL UP!", false, 1)
	end
	self.Pos = self.Pos + Vector(0, -self.speed)
end