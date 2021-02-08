--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function calculates bonus HP from feats.

--	This function accepts triggers from PCLiveHP and NPCLiveHP.
function calculateHp(nodeActor, rActor)
	if not nodeActor or not rActor then
		return nil
	end
	
	
end

---	This function checks whether an effect should trigger recalculation.
--	It does this by checking the effect text for a series of three letters followed by a colon (as used in bonuses like CON: 4).
function checkEffectRelevance(nodeEffect)
	if string.find(DB.getValue(nodeEffect, 'label', ''), '%a%a%a:') then
		return true
	end
	
	return false
end