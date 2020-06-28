--
--	Please see the license.html file included with this distribution for attribution and copyright information.
--

function onInit()
	DB.addHandler(DB.getPath('charsheet.*.hp.total'), 'onUpdate', assimilateLevelHp)
	DB.addHandler(DB.getPath('charsheet.*.hp.hdhp'), 'onUpdate', calculateTotalHp)
	DB.addHandler(DB.getPath('charsheet.*.abilities.constitution.score'), 'onUpdate', calculateTotalHp)
	DB.addHandler(DB.getPath('charsheet.*.abilities.constitution.bonus'), 'onUpdate', calculateTotalHp)
	DB.addHandler(DB.getPath('combattracker.list.*.effects'), 'onChildUpdate', calculateTotalHp)
	DB.addHandler(DB.getPath('combattracker.list'), 'onChildDeleted', calculateTotalHp)
end

---	Return a consistent value for nodePC and rActor.
--	This is accomplished by parsing node for a number of expected relationships.
--	@param node The databasenode to be queried for relationships.
local function handleArgs(node)
	local nodePC
	local rActor

	if node.getParent().getName() == 'hp' then
		nodePC = node.getChild('...')
	elseif node.getParent().getName() == 'constitution' then
		nodePC = node.getChild('....')
	elseif node.getName() == 'level' then
		nodePC = node.getParent()
	elseif node.getName() == 'effects' then
		rActor = ActorManager.getActor('ct', node.getParent())
		nodePC = DB.findNode(rActor['sCreatureNode'])
	end

	if not rActor then
		rActor = ActorManager.getActor("pc", nodePC)
	end

	return nodePC, rActor
end

---	Recompute the character's total hitpoints.
--	The total hitpoints are comprised of Live HP (as returned by getHpFromCon) and HD HP character sheet boxes.
--	@see getHpFromCon
--	@param node The databasenode passed by whichever handler which calls this function.
function calculateTotalHp(node)
	local nodePC, rActor = handleArgs(node)
	local nHPBonus = getHpFromCon(nodePC, rActor)
	local nHDHP = DB.getValue(nodePC, 'hp.hdhp', 0)
	local nHPTotal = nHPBonus + nHDHP

	DB.setValue(nodePC, 'hp.total', 'number', nHPTotal)
end

---	Get the quantity of HP granted by current CON score and add extra Max HP from new effect.
--	This is calculated by adding the CON mod, scroll-entry con mod bonus, and CON mod bonuses from effects (as returned by getConEffects).
--	Next this number is multiplied by the character level, minus any negative levels applied by effects (as returned by EffectManager35E.getEffectsBonus)
--	Once this number is calculated, any extra HP from "MHP: N" effects are added.
--	Finally, this number is returned (nHPBonus) along with the CON mod without effects (nConCombo).
--	@see getConEffects
--	@param nodePC The charsheet databasenode of the player character
--	@param rActor A table containing database paths and identifying data about the  player character
function getHpFromCon(nodePC, rActor)
	local nConMod = DB.getValue(nodePC, 'abilities.constitution.bonus', 0)
	local nConBonusMod = DB.getValue(nodePC, 'abilities.constitution.bonusmodifier', 0)
	local nConEffectsMod = getConEffects(nodePC, rActor)

	local nConCombo = nConMod + nConBonusMod
	local nCon = nConCombo + nConEffectsMod

	local nLevel = DB.getValue(nodePC, 'level', 0)
	local nNegLevels = EffectManager35E.getEffectsBonus(rActor, 'NLVL', true)

	local nMaxHPBonus = getHPEffects(nodePC, rActor)

	local nHPBonus = (nCon * (nLevel - nNegLevels)) + nMaxHPBonus

	DB.setValue(nodePC, 'hp.bonushp', 'number', nHPBonus)

	return nHPBonus, nConCombo
end

---	Get the total bonus to the character's CON mod from effects in combat tracker
--	If not supplied with rActor, this will return 0. 
--	The total CON bonus from effects is returned by EffectManager35E.getEffectsBonus.
--	@see EffectManager35E.getEffectsBonus
--	@param nodePC The charsheet databasenode of the player character
--	@param rActor A table containing database paths and identifying data about the  player character
function getConEffects(nodePC, rActor)
	if not rActor then
		return 0, false
	end

	local nConFromEffects = math.floor(EffectManager35E.getEffectsBonus(rActor, 'CON', true) / 2)

	return nConFromEffects
end

---	Get the total bonus to max hp from new effect "MHP: N" where N is a number.
--	This is useful for abilities like rage and spells that raise a character's max hp rather than granting temporary HP.
-- --	The total of any MHP effects is returned by EffectManager35E.getEffectsBonus.
--	@see EffectManager35E.getEffectsBonus
--	@param nodePC The charsheet databasenode of the player character
--	@param rActor A table containing database paths and identifying data about the  player character
function getHPEffects(nodePC, rActor)
	if not rActor then
		return 0, false
	end

	local nMaxHpFromEffects = EffectManager35E.getEffectsBonus(rActor, 'MHP', true)

	return nMaxHpFromEffects
end

---	Distributes average HP on level-up to the HD HP box without including the usual CON mod from the ruleset.
--	To do this, it take the HP total, subtracts the current CON (as returned by getHpFromCon), and overwrites HD HP.
--	This allows auto-level-up HP to function.
--	It could get funky if temporary values are entered in HD HP and then not removed before leveling up.
--	@param node The databasenode passed by the level-up handler.
function assimilateLevelHp(node)
	local nodePC, rActor = handleArgs(node)
	local nHDHP = DB.getValue(nodePC, 'hp.hdhp', 0)
	local nHPBonus, nConCombo = getHpFromCon(nodePC, rActor)
	local nHPTotal = DB.getValue(nodePC, 'hp.total', 0)

	if nHPTotal ~= nHDHP + nHPBonus then
		nHDHP = nHPTotal - nHPBonus
		DB.setValue(nodePC, 'hp.hdhp', 'number', nHDHP)
	end	
end
