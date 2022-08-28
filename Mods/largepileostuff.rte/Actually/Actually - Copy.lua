function Create(self)
	self.letterTable = {
		{ 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0 },
		{ 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 },
		{ 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 },
		{ 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0 },
	}
	self.emitterTable = {}
	self.emitterTableLength = 0

	self.lineWidth = { -2, -1, 0, -1, -2 }
	self.HStartPos = 24

	self.symbolGap = 10
	self.boomTimer = Timer()
	self.boomSound = CreateSoundContainer("Actually Sound", "largepileostuff.rte")
	self.boomSound.Pos = self.Pos
end

function Update(self)
	for i = 1, 5, 1 do
		if self.lineWidth[i] >= 0 and self.lineWidth[i] < self.HStartPos then
			for q = -1, 1, 2 do
				if self.letterTable[i][self.HStartPos + self.lineWidth[i] * q] == 1 then
					local bit = CreateAEmitter("Actually Segment", "largepileostuff.rte")
					bit.Pos = self.Pos + Vector((self.symbolGap * self.lineWidth[i] * q), self.symbolGap * (i - 3))
					MovableMan:AddMO(bit)

					self.emitterTable[self.emitterTableLength] = bit
					self.emitterTableLength = self.emitterTableLength + 1
				end

				if self.lineWidth[i] == 0 then
					break
				end
			end
		end
		self.lineWidth[i] = self.lineWidth[i] + 1
	end

	if self.boomTimer:IsPastSimMS(3000) then
		for i = 0, self.emitterTableLength - 1, 1 do
			if MovableMan:ValidMO(self.emitterTable[i]) then
				ToMOSRotating(self.emitterTable[i]):GibThis()
			end
		end

		self.Lifetime = 1
		self.boomSound:Play()
	end
end
