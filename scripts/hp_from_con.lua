--
--	Please see the license.html file included with this distribution for attribution and copyright information.
--

function onInit()
	DB.addHandler(DB.getPath('charsheet.*.hp.total'), 'onUpdate', calculateTotalHp)
end

--	Summary: Handles arguments of calculateTotalHp()
--	Argument: potentially nil node from triggering databasenode
--	Return: node of player character under charsheet and related rActor table
local function handlecalculateTotalHpArgs(node)
	local nodePC
	local rActor
	
--	Debug.chat('Launch Node: ',node)

	if node.getParent().getName() == 'hp' then
		nodePC = node.getChild('...')
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
	local nodePC, rActor = handlecalculateTotalHpArgs(node)
	local nConHP = getHpFromCon(nodePC)
	
	Debug.chat('nConHP', nConHP)
	DB.setValue(nodePC, 'hp.conhp', 'number', nConHP)
end

--	Summary: gets total HP from CON
--	Arguments: nodePC - node of player character under charsheet
function getHpFromCon(nodePC)
	local nCon = DB.getValue(nodePC, 'abilities.constitution.bonusmodifier', 0)
	local nLevel = DB.getValue(nodePC, 'level', 0)
	local nNegLevels = 0
--	local nNegLevels = EffectManager35E.getEffectsBonus(rActor, 'NLVL', true)
	local nConHP = nCon * (nLevel - nNegLevels)

	Debug.chat(nCon, '*', nLevel, '-', nNegLevels)
	return nConHP
end