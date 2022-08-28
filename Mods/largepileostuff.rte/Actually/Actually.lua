function Create(self)
	self.letterTable = {
		{ 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1 },
		{ 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0 },
		{ 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 },
		{ 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 },
		{ 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0 },

		--		@EVERYONE
		--		{0,1,1,1,0,0,1,1,1,1,1,0,1,0,0,0,1,0,1,1,1,1,1,0,1,1,1,1,0,0,1,0,0,0,1,0,0,1,1,1,0,0,1,0,0,0,1,0,1,1,1,1,1},
		--		{1,0,1,0,1,0,1,0,0,0,0,0,1,0,0,0,1,0,1,0,0,0,0,0,1,0,0,0,1,0,0,1,0,1,0,0,1,0,0,0,1,0,1,1,0,0,1,0,1,0,0,0,0},
		--		{1,0,1,1,1,0,1,1,1,1,0,0,0,1,0,1,0,0,1,1,1,1,0,0,1,1,1,1,0,0,0,0,1,0,0,0,1,0,0,0,1,0,1,0,1,0,1,0,1,1,1,1,0},
		--		{1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,1,0,0,1,0,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0,1,0,0,1,1,0,1,0,0,0,0},
		--		{0,1,1,1,1,0,1,1,1,1,1,0,0,0,1,0,0,0,1,1,1,1,1,0,1,0,0,0,1,0,0,0,1,0,0,0,0,1,1,1,0,0,1,0,0,0,1,0,1,1,1,1,1}
	}
	self.emitterTable = {}
	self.emitterTableLength = 0

	self.HStartPos = math.ceil(#self.letterTable[3] / 2)

	self.symbolGap = 10
	self.boomTimer = Timer()
	self.boomSound = CreateSoundContainer("Actually Sound", "largepileostuff.rte")
	self.boomSound.Pos = self.Pos

	for i = 1, 5, 1 do
		for bits = 0, self.HStartPos, 1 do
			for q = -1, 1, 2 do
				if self.letterTable[i][self.HStartPos + bits * q] == 1 then
					local bit = CreateAEmitter("Actually Segment", "largepileostuff.rte")
					local vPos = self.Pos + Vector((self.symbolGap * bits * q), self.symbolGap * (i - 3))
					bit.Pos = self.Pos
					bit.Vel = SceneMan:ShortestDistance(self.Pos, vPos, true) * 0.15
					MovableMan:AddMO(bit)

					self.emitterTable[self.emitterTableLength] = bit
					self.emitterTableLength = self.emitterTableLength + 1
				end

				if bits == 0 then
					break
				end
			end
		end
	end
end

function Update(self)
	if self.boomTimer:IsPastSimMS(2000) then
		for i = 0, self.emitterTableLength - 1, 1 do
			if MovableMan:ValidMO(self.emitterTable[i]) then
				ToMOSRotating(self.emitterTable[i]):GibThis()
			end
		end

		self.Lifetime = 1
		self.boomSound:Play()
		self.boomTimer:Reset()
	end
end
