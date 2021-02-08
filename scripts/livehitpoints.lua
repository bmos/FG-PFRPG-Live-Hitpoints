--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

--	This function accepts triggers from PCLiveHP and NPCLiveHP.
function calculateHp(nodeActor, rActor)
	if not nodeActor or not rActor then
		return nil
	end
	
	Debug.chat(nodeActor, rActor)
end

---	This function accepts triggers from PCLiveHP and NPCLiveHP.
--	To reduce wasted calculation, it first checks whether the effect should trigger recalculation.
function checkEffectRelevance(nodeActor, rActor, nodeEffect)
	local isRelevant = false
	local sEffect = DB.getValue(nodeEffect, '.', ''):lower
	
	if sEffect:find('str') or sEffect:find('dex') or sEffect:find('con') or sEffect:find('int') or sEffect:find('wis') or sEffect:find('cha') then
		isRelevant = true
		Debug.chat('isRelevant' isRelevant)
	end
	
	if isRelevant then
		calculateHp(nodeActor, rActor)
	end
end