--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function returns the change in maximum hitpoints from effects.
--	It checks for a hitpoint changes from "MHP: n" and reduces that by 5 for each negative level.
function getEffectHp(rActor)
	local nNegativeLevels = (EffectManager35EDS.getEffectsBonus(rActor, 'NLVL', true) * 5) or 0
	local nMhp = EffectManager35EDS.getEffectsBonus(rActor, {'MHP'}, true) or 0
	return nMhp - nNegativeLevels
end

---	This function accepts calls from PCLiveHP and NPCLiveHP.
--	It then coordinates the functions in this script to ascertain total HP.
function calculateHp(nodeActor, rActor, nAbilityBonus, nFeatBonus)
	if not nodeActor or not rActor or not nAbilityBonus or not nFeatBonus then
		return nil
	end

	local nRolledHp = DB.getValue(nodeActor, 'livehp.rolled', 0)
	local nMiscHp = DB.getValue(nodeActor, 'livehp.misc', 0)
	local nEffectHp = getEffectHp(rActor)
	local nTotalHp = nRolledHp + nAbilityBonus + nFeatBonus + nEffectHp + nMiscHp

	DB.setValue(nodeActor, 'livehp.ability', 'number', nAbilityBonus)
	DB.setValue(nodeActor, 'livehp.feats', 'number', nFeatBonus)
	DB.setValue(nodeActor, 'livehp.total', 'number', nTotalHp)

	return nTotalHp
end

---	This function checks whether an effect should trigger recalculation.
--	It does this by checking the effect text for a series of letters followed by a colon (as used in bonuses like CON: 4).
function checkEffectRelevance(nodeEffect)
	if string.find(DB.getValue(nodeEffect, 'label', ''), '%a+:') then
		return true
	end

	return false
end