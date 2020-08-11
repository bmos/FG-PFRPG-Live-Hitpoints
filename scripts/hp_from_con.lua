--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

function onInit()
	if User.isHost() then
		DB.addHandler(DB.getPath('charsheet.*.hp.total'), 'onUpdate', assimilateLevelHp)
		DB.addHandler(DB.getPath('charsheet.*.hp.hdhp'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('charsheet.*.hp.statused'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.score'), 'onUpdate', calculateTotalHp)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonus'), 'onUpdate', calculateTotalHp)
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
	elseif node.getChild('...').getName() == 'abilities' then
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
--	The total hitpoints are comprised of Live HP (as returned by getHpFromStat) and HD HP character sheet boxes.
--	@see getHpFromStat
--	@param node This is the databasenode passed by whichever handler which calls this function.
function calculateTotalHp(node)
	local nodeChar, rActor = handleArgs(node)
	local nHPBonus = getHpFromStat(nodeChar, rActor)
	local nHDHP = DB.getValue(nodeChar, 'hp.hdhp', 0)
	local nHPTotal = nHPBonus + nHDHP

	DB.setValue(nodeChar, 'hp.total', 'number', nHPTotal)
end

---	This function gets the ability that should be used for calculating hitpoints
--	For most characters, this is CON.
function getStatUsed(nodeChar)
	local nStatUsed = string.upper(DB.getValue(nodeChar, 'hp.statused', ''))
	local nStatNameUsed = 'constitution'

	if nStatUsed == '' then nStatUsed = 'CON' end
	if nStatUsed == 'INT' then nStatNameUsed = 'intelligence' end
	if nStatUsed == 'WIS' then nStatNameUsed = 'wisdom' end
	if nStatUsed == 'CHA' then nStatNameUsed = 'charisma' end
	if nStatUsed == 'STR' then nStatNameUsed = 'strength' end
	if nStatUsed == 'DEX' then nStatNameUsed = 'dexterity' end

	return nStatUsed, nStatNameUsed
end

---	Get the quantity of HP granted by current stat score and add extra Max HP from new effect.
--	This is calculated by adding the stat mod, scroll-entry stat mod bonus, and stat mod bonuses from effects (as returned by getStatEffects).
--	Next this number is multiplied by the character level, minus any negative levels applied by effects (as returned by EffectManager35E.getEffectsBonus)
--	Once this number is calculated, any extra HP from "MHP: N" effects are added.
--	@see getStatEffects
--	@param nodeChar This is the charsheet databasenode of the player character
--	@param rActor This is a table containing database paths and identifying data about the player character
--	@return nHPBonus This is the quantity of HP granted by current stat score plus any extra Max HP added by "MHP: N" effect.
function getHpFromStat(nodeChar, rActor)
	local nStatUsed, nStatNameUsed = getStatUsed(nodeChar)

	local nStatMod = DB.getValue(nodeChar, 'abilities.' .. nStatNameUsed .. '.bonus', 0)
	local nStatBonusMod = DB.getValue(nodeChar, 'abilities.' .. nStatNameUsed .. '.bonusmodifier', 0)
	local nStatEffectsMod = getStatEffects(nodeChar, rActor)

	local nStat = nStatMod + nStatBonusMod + nStatEffectsMod

	local nLevel = DB.getValue(nodeChar, 'level', 0)
	local nNegLevels = EffectManagerLHFC.getEffectsBonus(rActor, 'NLVL', true)

	local nMaxHPBonus = getHPEffects(nodeChar, rActor)
	
	local nFeatBonus = 0
	if DataCommon.isPFRPG() then
		if CharManager.hasFeat(nodeChar, "Toughness") then
			nFeatBonus = nFeatBonus + math.max(DB.getValue(nodeChar, 'level', 0), 3)
		end
	else
		if CharManager.hasFeat(nodeChar, "Toughness") then
			nFeatBonus = nFeatBonus + 3
		end
		if CharManager.hasFeat(nodeChar, "Improved Toughness") then
			nFeatBonus = nFeatBonus + DB.getValue(nodeChar, 'level', 0)
		end
	end

	local nHPBonus = (nStat * (nLevel - nNegLevels)) + nMaxHPBonus + nFeatBonus

	DB.setValue(nodeChar, 'hp.bonushp', 'number', nHPBonus)

	return nHPBonus
end

---	Get the bonus to the character's stat mod from effects in combat tracker
--	If not supplied with rActor, this will return 0. 
--	The total stat bonus from effects is returned by EffectManager35E.getEffectsBonus.
--	@see EffectManager35E.getEffectsBonus
--	@param nodeChar The charsheet databasenode of the player character
--	@param rActor A table containing database paths and identifying data about the player character
--	@return nStatFromEffects This is the bonus to the character's stat mod from any effects in the combat tracker
function getStatEffects(nodeChar, rActor)
	if not rActor then
		return 0, false
	end

	local nStatUsed = getStatUsed(nodeChar)

	local nStatFromEffects = math.floor(EffectManagerLHFC.getEffectsBonus(rActor, nStatUsed, true) / 2)

	return nStatFromEffects
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

---	Distributes average HP on level-up to the HD HP box without including the usual stat mod from the ruleset.
--	To do this, it take the HP total, subtracts the current stat (as returned by getHpFromStat), and overwrites HD HP.
--	This allows auto-level-up HP to function.
--	It could get funky if temporary values are entered in HD HP and then not removed before leveling up.
--	@param node The databasenode passed by the level-up handler.
function assimilateLevelHp(node)
	local nodeChar, rActor = handleArgs(node)
	local nHDHP = DB.getValue(nodeChar, 'hp.hdhp', 0)
	local nHPBonus = getHpFromStat(nodeChar, rActor)
	local nHPTotal = DB.getValue(nodeChar, 'hp.total', 0)

	if nHPTotal ~= nHDHP + nHPBonus then
		nHDHP = nHPTotal - nHPBonus
		DB.setValue(nodeChar, 'hp.hdhp', 'number', nHDHP)
	end	
end
