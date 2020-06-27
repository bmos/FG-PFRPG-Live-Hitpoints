--
--	Please see the license.html file included with this distribution for attribution and copyright information.
--

function onInit()
	DB.addHandler(DB.getPath('charsheet.*.hp.*.total'), 'onUpdate', applyPenalties)
end

--	Summary: Handles arguments of getHpFromCon()
--	Argument: potentially nil node from triggering databasenode
--	Return: databasenode of PC and related rActor table
local function handleGetHpFromConArgs(node)
	local nodePC
	local rActor
	
	Debug.chat('Launch Node: ',node)

	if nodeField.getParent().getName() == 'charsheet' then
		nodePC = nodeField
	elseif nodeField.getName() == 'inventorylist' then
		nodePC = nodeField.getParent()
	elseif nodeField.getName() == 'hp' then
		nodePC = nodeField.getParent()
	elseif nodeField.getParent().getName() == 'inventorylist' then
		nodePC = nodeField.getChild( '...' )
	elseif nodeField.getName() == 'carried' then
		nodePC = nodeField.getChild( '....' )
	elseif nodeField.getName() == 'effects' then
		rActor = ActorManager.getActor('ct', nodeField.getParent())
		nodePC = DB.findNode(rActor['sCreatureNode'])
	end

	if not rActor then
		rActor = ActorManager.getActor("pc", nodePC)
	end

	return nodePC, rActor
end

--	Summary: Recomputes penalties and updates max stat and check penalty
--	Arguments: nodeField - node of 'carried' when called from handler
function getHpFromCon(node)
	local nodePC, rActor = handleGetHpFromConArgs(node)
	local nCon = DB.getValue(nodePC, 'abilities.constitution.bonusmodifier', 0)
	local nLevel = DB.getValue(nodePC, 'level', 0)
	local nNegLevels = 0
--	local nNegLevels = EffectManager35E.getEffectsBonus(rActor, 'NLVL', true)
	local nConHP = nCon * (nLevel - nNegLevels)
	Debug.chat(nCon, nLevel)
end