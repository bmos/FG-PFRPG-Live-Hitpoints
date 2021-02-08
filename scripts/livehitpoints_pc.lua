--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function is called when effect components are changed.
--	First, it checks if the triggering actor is a PC and whether the effect is relevant to this extension.
--	Then, it calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectChanged(node)
	local rActor = ActorManager.resolveActor(node.getChild('....'))
	if ActorManager.isPC(rActor) and LiveHP.checkEffectRelevance(node.getChild('..')) then
		LiveHP.calculateHp(node.getChild('....'), rActor)
	end
end

---	This function is called when effects are removed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onEffectRemoved(node)
	local rActor = ActorManager.resolveActor(node.getChild('..'))
	if ActorManager.isPC(rActor) then
		LiveHP.calculateHp(ActorManager.getCreatureNode(rActor), rActor)
	end
end

---	This function is called when ability score components are changed.
--	It calls the calculateHp function in LiveHP and provides it with nodeActor and rActor.
local function onAbilityChanged(node)
	LiveHP.calculateHp(node.getChild('....'), ActorManager.resolveActor(node.getChild('....')))
end

---	This function watches for changes in the database and triggers various functions.
--	It only runs on the host machine.
function onInit()
	if Session.IsHost then
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonus'), 'onUpdate', onAbilityChanged)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.bonusmodifier'), 'onUpdate', onAbilityChanged)
		DB.addHandler(DB.getPath('charsheet.*.abilities.*.damage'), 'onUpdate', onAbilityChanged)

		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects'), 'onChildDeleted', onEffectRemoved)
	end
end
