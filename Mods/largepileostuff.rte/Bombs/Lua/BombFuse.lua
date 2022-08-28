function Create(self)
	self.active = false
	self.fuse = CreateAEmitter(self.PresetName .. " Fuse")
	self.fuse.Pos = self.Pos
	self:AddEmitter(self.fuse)

	function lightFuse()
		if not self:IsActivated() and not self:GetParent() then
			self:Activate()
		end
	end

	lightFuse()
end

function Update(self)
	lightFuse()

	if not self.active and self:IsActivated() then
		if not self.fuse:IsEmitting() then
			self.fuse:EnableEmission(true)
		end
		self.active = true
	end
end

function Destroy(self)
	self.fuse.Lifetime = 1
end
