function Create(self)
	self.Pos.Y = -30;
	self.RotAngle = 0;
end

function Update(self)
	if self.Pos.Y ~= -50 then
		self.Pos.Y = -50;
		self.RotAngle = 0;
	end
end