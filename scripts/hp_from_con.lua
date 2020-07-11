--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if User.isHost() then
		DB.addHandler(DB.getPath('charsheet.*.hp.total'), 'onUpdate', assimilateLevelHp)
		DB.addHandler(DB.getPath('charsheet.*.hp.hdhp'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('charsheet.*.abilities.constitution.score'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('charsheet.*.abilities.constitution.bonus'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.label'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.isactive'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('combattracker.list.*.effects'), 'onChildDeleted', calculateTotalHp)
	end
end

---	Return a consistent value for nodeChar and rActor.
--	This is accomplished by parsing node for a number of expected relationships.
--	@param node The databasenode to be queried for relationships.
--	@return nodeChar This is the charsheet databasenode of the player character
--	@return rActor This is a table containing database paths and identifying data about the player character
local function handleArgs(node)
	local nodeChar
	local rActor

	if node.getParent().getName() == 'hp' then
		nodeChar = node.getChild('...')
	elseif node.getName() == 'effects' then
		rActor = ActorManager.getActor('ct', node.getParent())
		nodeChar = DB.findNode(rActor['sCreatureNode'])
	elseif node.getParent().getName() == 'constitution' then
		nodeChar = node.getChild('....')
	elseif node.getName() == 'level' then
		nodeChar = node.getParent()
	elseif node.getChild('...').getName() == 'effects' then
		rActor = ActorManager.getActor('ct', node.getChild('....'))
		nodeChar = DB.findNode(rActor['sCreatureNode'])
	end

	if not rActor then
		rActor = ActorManager.getActor('pc', nodeChar)
	end

	return nodeChar, rActor
end

---	Recompute the character's total hitpoints.
--	The total hitpoints are comprised of Live HP (as returned by getHpFromCon) and HD HP character sheet boxes.
--	@see getHpFromCon
--	@param node This is the databasenode passed by whichever handler which calls this function.
function calculateTotalHp(node)
	local nodeChar, rActor = handleArgs(node)
	local nHPBonus = getHpFromCon(nodeChar, rActor)
	local nHDHP = DB.getValue(nodeChar, 'hp.hdhp', 0)
	local nHPTotal = nHPBonus + nHDHP

	DB.setValue(nodeChar, 'hp.total', 'number', nHPTotal)
end

---	Get the quantity of HP granted by current CON score and add extra Max HP from new effect.
--	This is calculated by adding the CON mod, scroll-entry con mod bonus, and CON mod bonuses from effects (as returned by getConEffects).
--	Next this number is multiplied by the character level, minus any negative levels applied by effects (as returned by EffectManager35E.getEffectsBonus)
--	Once this number is calculated, any extra HP from "MHP: N" effects are added.
--	@see getConEffects
--	@param nodeChar This is the charsheet databasenode of the player character
--	@param rActor This is a table containing database paths and identifying data about the player character
--	@return nHPBonus This is the quantity of HP granted by current CON score plus any extra Max HP added by "MHP: N" effect.
function getHpFromCon(nodeChar, rActor)
	local nConMod = DB.getValue(nodeChar, 'abilities.constitution.bonus', 0)
	local nConBonusMod = DB.getValue(nodeChar, 'abilities.constitution.bonusmodifier', 0)
	local nConEffectsMod = getConEffects(nodeChar, rActor)

	local nCon = nConMod + nConBonusMod + nConEffectsMod

	local nLevel = DB.getValue(nodeChar, 'level', 0)
	local nNegLevels = EffectManagerLHFC.getEffectsBonus(rActor, 'NLVL', true)

	local nMaxHPBonus = getHPEffects(nodeChar, rActor)

	local nHPBonus = (nCon * (nLevel - nNegLevels)) + nMaxHPBonus

	DB.setValue(nodeChar, 'hp.bonushp', 'number', nHPBonus)

	return nHPBonus
end

---	Get the bonus to the character's CON mod from effects in combat tracker
--	If not supplied with rActor, this will return 0. 
--	The total CON bonus from effects is returned by EffectManager35E.getEffectsBonus.
--	@see EffectManager35E.getEffectsBonus
--	@param nodeChar The charsheet databasenode of the player character
--	@param rActor A table containing database paths and identifying data about the player character
--	@return nConFromEffects This is the bonus to the character's CON mod from any effects in the combat tracker
function getConEffects(nodeChar, rActor)
	if not rActor then
		return 0, false
	end

	local nConFromEffects = math.floor(EffectManagerLHFC.getEffectsBonus(rActor, 'CON', true) / 2)

	return nConFromEffects
end

---	Get the total bonus to max hp from new effect "MHP: N" where N is a number.
--	This is useful for abilities like rage and spells that raise a character's max hp rather than granting temporary HP.
-- --	The total of any MHP effects is returned by EffectManager35E.getEffectsBonus.
--	@see EffectManager35E.getEffectsBonus
--	@param nodeChar The charsheet databasenode of the player character
--	@param rActor A table containing database paths and identifying data about the player character
--	@return nMaxHpFromEffects This is the bonus to the character's hitpoints from any instances of the new "MHP: N" effect in the combat tracker
function getHPEffects(nodeChar, rActor)
	if not rActor then
		return 0, false
	end

	local nMaxHpFromEffects = EffectManagerLHFC.getEffectsBonus(rActor, 'MHP', true)

	return nMaxHpFromEffects
end

---	Distributes average HP on level-up to the HD HP box without including the usual CON mod from the ruleset.
--	To do this, it take the HP total, subtracts the current CON (as returned by getHpFromCon), and overwrites HD HP.
--	This allows auto-level-up HP to function.
--	It could get funky if temporary values are entered in HD HP and then not removed before leveling up.
--	@param node The databasenode passed by the level-up handler.
function assimilateLevelHp(node)
	local nodeChar, rActor = handleArgs(node)
	local nHDHP = DB.getValue(nodeChar, 'hp.hdhp', 0)
	local nHPBonus = getHpFromCon(nodeChar, rActor)
	local nHPTotal = DB.getValue(nodeChar, 'hp.total', 0)

	if nHPTotal ~= nHDHP + nHPBonus then
		nHDHP = nHPTotal - nHPBonus
		DB.setValue(nodeChar, 'hp.hdhp', 'number', nHDHP)
	end	
end
