package.path = package.path .. string.format(";largepileostuff.rte/?.lua");
require "MegaGib";

function Create(self)
	self.skipFrames = 2
	self.frameTimer = 0
	self.bloatFrames = 300
	self.bloatFactor = 1.5
	self.bloatIncrement = self.bloatFactor / (self.bloatFrames / (self.skipFrames + 1))

	function bloatCheck()
		for actor in MovableMan.Actors do
			if
				actor:GetNumberValue("isBloating") == 1
				and actor.PresetName ~= "Reflective Robot MK-II"
				and actor:HasObjectInGroup("Craft") == false
			then
				if actor.Scale < self.bloatFactor then
					for mo in actor.Attachables do
						mo.ParentOffset = Vector(mo.ParentOffset.X, mo.ParentOffset.Y):SetMagnitude(
							(mo.ParentOffset.Magnitude / mo.Scale) * (mo.Scale + self.bloatIncrement)
						)
						mo.Scale = mo.Scale + self.bloatIncrement
					end
					actor.Scale = actor.Scale + self.bloatIncrement
				elseif actor.Scale >= self.bloatFactor then
					self.deathPuff = CreateAEmitter("Bloating Gas Puff")
					self.deathPuff.Pos = actor.Pos
					MovableMan:AddParticle(self.deathPuff)
					absolutelyFuckingGib(actor, Vector(0, 0))
				end
			end
		end
	end

	bloatCheck()
end

function Update(self)
	self.Age = 1
	self.Mass = self.Mass + 0.000001
	for particle in MovableMan.Particles do
		if particle.PresetName == "Scripty Particle Bloat" then
			if particle.Mass < self.Mass then
				particle.ToDelete = true
			elseif particle.Mass == self.Mass and self.ID > particle.ID then
				particle.ToDelete = true
			end
		end
	end

	if self.frameTimer >= self.skipFrames then
		bloatCheck()
		self.frameTimer = 0
	else
		self.frameTimer = self.frameTimer + 1
	end
end
