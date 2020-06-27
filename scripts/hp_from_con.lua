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

--	Summary: Handles arguments of calculateTotalHp()
--	Argument: potentially nil node from triggering databasenode
--	Return: node of player character under charsheet and related rActor table
local function handleArgs(node)
	local nodePC
	local rActor
--	Debug.chat('Launch Node: ',node)

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

--	Debug.chat('Set Node: ', nodePC, rActor)
	return nodePC, rActor
end

--	Summary: Recomputes penalties and updates max stat and check penalty
--	Arguments: node - node of 'carried' when called from handler
function calculateTotalHp(node)
	local nodePC, rActor = handleArgs(node)
	local nConHP = getHpFromCon(nodePC, rActor)
	local nHDHP = DB.getValue(nodePC, 'hp.hdhp')
	local nHPTotal = nConHP + nHDHP

	DB.setValue(nodePC, 'hp.total', 'number', nHPTotal)
end

--	Summary: gets total HP from CON
--	Arguments: nodePC - node of player character under charsheet
function getHpFromCon(nodePC, rActor)
	local nConMod = DB.getValue(nodePC, 'abilities.constitution.bonus', 0)
	local nConBonusMod = DB.getValue(nodePC, 'abilities.constitution.bonusmodifier', 0)
	local nConEffectsMod = getConEffects(nodePC, rActor)

	local nCon = nConMod + nConBonusMod + nConEffectsMod

	local nLevel = DB.getValue(nodePC, 'level', 0)
	local nNegLevels = EffectManager35E.getEffectsBonus(rActor, 'NLVL', true)

	local nConHP = nCon * (nLevel - nNegLevels)

	DB.setValue(nodePC, 'hp.conhp', 'number', nConHP)

--	Debug.chat(nConMod..'*'..nLevel..'-'..nNegLevels)
	return nConHP
end

--	Summary: Determine the total bonus to character's CON from effects
--	Argument: rActor containing the PC's charsheet and combattracker nodes
--	Return: total bonus to CON from effects formatted as 'CON: n' in the combat tracker
function getConEffects(nodePC, rActor)
	if not rActor then
		return 0, false
	end

	local nSpeedAdjFromEffects = EffectManager35E.getEffectsBonus(rActor, 'CON', true)

	return nSpeedAdjFromEffects
end

--	Summary: Take the HP total, subtract the current CON, and overwrite HP from HD. This should allow auto-level-up HP to function.
--	Argument: node - node of 'level' when called from handler
function assimilateLevelHp(node)
	local nodePC, rActor = handleArgs(node)
	local nHDHP = DB.getValue(nodePC, 'hp.hdhp')
	local nConHP = getHpFromCon(nodePC, rActor)
	local nHPTotal = DB.getValue(nodePC, 'hp.total')

	if nHPTotal ~= nHDHP + nConHP then
		nHDHP = nHPTotal - nConHP
		DB.setValue(nodePC, 'hp.hdhp', 'number', nHDHP)
	end
end