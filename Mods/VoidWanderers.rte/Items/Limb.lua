function Create(self)
	self.isArm = string.find(self.PresetName, " Arm");
	--self.isLeg = string.find(self.PresetName, " Leg");
	self.origStanceOffset = Vector(self.StanceOffset.X, self.StanceOffset.Y);
	self.attachSound = CreateSoundContainer(self:StringValueExists("AttachSound") and self:GetStringValue("AttachSound") or "Robot Stride");
	self.errorSound = CreateSoundContainer("Error");
	self.limbName = self:StringValueExists("LimbName") and self:GetStringValue("LimbName") or self.PresetName;
end
function Update(self)
	if self:IsActivated() then
		local parent = self:GetRootParent();
		if IsActor(parent) and not self.wasActivated then
			local j = 0;
			parent = ToActor(parent);
			local actor = MovableMan:GetClosestActor(self.Pos, self.Diameter, Vector(), parent) or parent;
			if actor and IsAHuman(actor) then
				actor = ToAHuman(actor);
				if (self.isArm) then
					j = not actor.FGArm and 1 or (not actor.BGArm and 2 or j);
				else--if (self.isLeg) then
					j = not actor.FGLeg and 3 or (not actor.BGLeg and 4 or j);
				end
				if j ~= 0 then
					local reference = CreateAHuman(actor:GetModuleAndPresetName());
					local referenceLimb = j == 1 and reference.FGArm or (j == 2 and reference.BGArm or (j == 3 and reference.FGLeg or reference.BGLeg));
					local newLimb = self.isArm and CreateArm(self.limbName .. (j == 1 and " FG" or " BG")) or CreateLeg(self.limbName .. (j == 3 and " FG" or " BG"));
					if referenceLimb then
						newLimb.ParentOffset = referenceLimb.ParentOffset;
						local woundName = referenceLimb:GetEntryWoundPresetName();
						if woundName ~= "" then newLimb.ParentBreakWound = CreateAEmitter(woundName); end
					end
					--Can't use a temp pointer to set limbs... refer to the ID
					if 		j == 1 then actor.FGArm = newLimb;
					elseif 	j == 2 then actor.BGArm = newLimb;
					elseif 	j == 3 then actor.FGLeg = newLimb;
					elseif 	j == 4 then actor.BGLeg = newLimb;
					end
					for wound in actor.Wounds do
						if math.floor(wound.ParentOffset.X - newLimb.ParentOffset.X + 0.5) == 0 and math.floor(wound.ParentOffset.Y - newLimb.ParentOffset.Y + 0.5) == 0 then
							for em in wound.Emissions do
								em.ParticlesPerMinute = 0;
							end
							wound.Scale = wound.Scale * 0.7;
						end
					end
					DeleteEntity(reference);
				end
			end
			if j == 0 then
				self.errorSound:Play(self.Pos);
			else
				actor:FlashWhite(50);
				self.attachSound:Play(self.Pos);
				self.ToDelete = true;
			end
		end
		self.wasActivated = true;
		self:Deactivate();
	else
		self.wasActivated = false;
	end
end