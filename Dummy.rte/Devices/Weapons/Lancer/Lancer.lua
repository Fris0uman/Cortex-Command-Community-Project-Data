function Create(self)
	self.chargeTimer = Timer();
	self.chargeCounter = 10;

	self.maxCharge = 10;
	self.chargesPerSecond = self.RateOfFire/100;

	self.sound = false;
	self.setAngle = 0;
end
function Update(self)
	if self.FiredFrame then

		self.setAngle = self.setAngle + self.chargeCounter/(20 * (1 + self.setAngle));
		self.sound = nil;
		local actor = MovableMan:GetMOFromID(self.RootID);

		local charge = math.floor(self.chargeCounter * 0.8);
		for i = 1, charge do
			local damagePar = CreateMOPixel("Dummy Lancer Particle " .. math.ceil(i/2));
			damagePar.Pos = self.MuzzlePos + Vector(((i - 1) * 4 - charge) * self.FlipFactor, 0):RadRotate(self.RotAngle);
			damagePar.Vel = Vector((60 + 10 * charge) * self.FlipFactor, 0):RadRotate(self.RotAngle);
			damagePar.Team = self.Team;
			damagePar.IgnoresTeamHits = true;
			MovableMan:AddParticle(damagePar);
		end

		local shellPar1 = CreateMOSParticle("Tiny Smoke Ball 1 Glow Yellow")
		MovableMan:AddParticle(shellPar1);

		local highCharge = self.maxCharge * 0.7;
		local lowCharge = self.maxCharge * 0.3;
		
		for i = 1, self.chargeCounter do
			local size = i > lowCharge and (i > highCharge and "" or "Small ") or "Tiny ";
			local smokePar = CreateMOSParticle(size .. "Smoke Ball 1 Glow Yellow");
			smokePar.Pos = self.MuzzlePos;
			smokePar.Vel = Vector(math.random(5) * (charge/i) * self.FlipFactor, 0):RadRotate(self.RotAngle);
			smokePar.Team = self.Team
			smokePar.IgnoresTeamHits = true;
			MovableMan:AddParticle(smokePar);
		end
		local sound = self.chargeCounter > highCharge and "High" or (self.chargeCounter < lowCharge and "Low" or "Medium");
		AudioMan:PlaySound("Dummy.rte/Devices/Weapons/Lancer/Sounds/Fire".. sound ..".flac", self.MuzzlePos);

		self.chargeCounter = 1;
	else
		if self.chargeCounter <= self.maxCharge then
			self.chargeCounter = math.min(self.chargeCounter + ((self.chargeTimer.ElapsedSimTimeMS/1000) * self.chargesPerSecond), self.maxCharge);
			self.chargeTimer:Reset();

			if self.chargeCounter == self.maxCharge and not self.sound then
				self.sound = AudioMan:PlaySound("Dummy.rte/Devices/Weapons/Lancer/Sounds/FullChargeBleep.flac", self.Pos);
			end
		end
	end
	if self.Magazine then
		self.Magazine.RoundCount = self.chargeCounter;
	end
	if self.setAngle > 0 then
		self.setAngle = self.setAngle - (0.02 * (1 + self.setAngle));
		if self.setAngle < 0 then
			self.setAngle = 0;
		end
	end
	self.RotAngle = self.RotAngle + (self.setAngle * self.FlipFactor);
	local jointOffset = Vector(self.JointOffset.X * self.FlipFactor, self.JointOffset.Y):RadRotate(self.RotAngle);
	self.Pos = self.Pos - jointOffset + Vector(jointOffset.X, jointOffset.Y):RadRotate(-self.setAngle * self.FlipFactor);
end