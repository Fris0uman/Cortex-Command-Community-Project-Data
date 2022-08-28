function Create(self)
	function bloatAdd(range)
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
	end
end

function Destroy(self)
	bloatAdd(100)
end
