EnhancedReactors.ManagedItems = {}

Util.RegisterItemGroup("reactors", function (item)
    return item.GetComponentString("Reactor") ~= nil
end)

local reactors = {
    ["reactor1"] = true,
    ["outpostreactor"] = true,
    ["ekdockyard_reactorslow_small"] = true,
    ["ekdockyard_reactor_mini"] = true,
    ["ekdockyard_reactor_small"] = true
}

local fuelRods = {
    ["fuelrod"] = {
        radiationSickness = 1,
        contaminated = 1,
        radiationSounds = 3.5,
        overheating = 1
    },
    ["thoriumfuelrod"] = {
        radiationSickness = 0.5,
        contaminated = 0.5,
        radiationSounds = 2.0,
        overheating = 1.5,
    },
    ["fulguriumfuelrod"] = {
        radiationSickness = 2,
        contaminated = 2,
        radiationSounds = 4.5,
        overheating = 2,
    },
    ["fulguriumfuelrodvolatile"] = {
        radiationSickness = 3,
        contaminated = 3,
        radiationSounds = 5.5,
        overheating = 3,
    },
    ["emptyfuelrod"] = {
        radiationSickness = 0.1,
        contaminated = 0.2,
        radiationSounds = 1.5,
        overheating = 0.2,
    }
}

EnhancedReactors.ProcessItem = function (item)
    if reactors[item.Prefab.Identifier.Value] then
        item.AddTag("lua_managed")
        table.insert(EnhancedReactors.ManagedItems, item)
    end

    if fuelRods[item.Prefab.Identifier.Value] then
        item.AddTag("lua_managed")
        -- item.AddTag("fuelrod")
        table.insert(EnhancedReactors.ManagedItems, item)
    end
end

EnhancedReactors.RemoveItem = function (item)
    for i, managedItem in ipairs(EnhancedReactors.ManagedItems) do
        if managedItem == item then
            table.remove(EnhancedReactors.ManagedItems, i)
            break
        end
    end
end

EnhancedReactors.ApplyAfflictionRadius = function (item, character, maxDistance, wallPenetration, armorPenetration, afflictions)
    if Vector2.Distance(character.WorldPosition, item.WorldPosition) > maxDistance then
        return
    end

    local position = item.Position

    local factor = math.min(Explosion.GetObstacleDamageMultiplier(ConvertUnits.ToSimUnits(position), position, character.SimPosition) * wallPenetration, 1)
    factor = factor * (1 - Vector2.Distance(character.WorldPosition, item.WorldPosition) / maxDistance)

    local limb = character.AnimController.MainLimb
    local AttackResult = limb.AddDamage(limb.SimPosition, afflictions, false, factor, armorPenetration, nil)
    character.CharacterHealth.ApplyDamage(limb, AttackResult, true)
end

local overheating = AfflictionPrefab.Prefabs["overheating"]
local radiationSickness = AfflictionPrefab.Prefabs["radiationsickness"]
local contaminated = AfflictionPrefab.Prefabs["contaminated"]
local radiationSounds = AfflictionPrefab.Prefabs["radiationsounds"]
local burn = AfflictionPrefab.Prefabs["burn"]

EnhancedReactors.ProcessItemUpdate = function (item)
    local reactor = item.GetComponentString("Reactor")
    if reactor then
        if reactor.Temperature > 40 then
            for character in Character.CharacterList do
                EnhancedReactors.ApplyAfflictionRadius(item, character, 750, 1, 0, { overheating.Instantiate(0.1) })
            end
        end
    end

    if item.HasTag("fuelroditem") and item.HasTag("activefuelrod") then
        local inventory = item.ParentInventory

        local parentItem = nil
        local parentCharacter = nil

        if inventory then
            if LuaUserData.IsTargetType(inventory, "Barotrauma.ItemInventory") then
                parentItem = inventory.Owner
            else
                parentCharacter = inventory.Owner
            end
        end

        local reactor = parentItem and parentItem.GetComponentString("Reactor") or nil

        -- if not parentItem then
        --     if math.random() < 0.01 then
        --         FireSource(item.WorldPosition)
        --     end
        -- end

        if not parentItem or (not parentItem.HasTag("deepdivinglarge") and not parentItem.HasTag("containradiation")) then
            local data = fuelRods[item.Prefab.Identifier.Value]
            for character in Character.CharacterList do
                EnhancedReactors.ApplyAfflictionRadius(item, character, 750, 1, 0, {
                    radiationSickness.Instantiate(1 * data.radiationSickness),
                    contaminated.Instantiate(1 * data.contaminated),
                    radiationSounds.Instantiate(1.25 * data.radiationSounds),
                    overheating.Instantiate(0.05 * data.overheating)
            })
            end

            if parentCharacter and not item.HasTag("emptyfuelrod") then
                local slot = inventory.FindIndex(item)

                if slot == inventory.FindLimbSlot(InvSlotType.RightHand) then
                    parentCharacter.CharacterHealth.ApplyAffliction(parentCharacter.AnimController.GetLimb(InvSlotType.RightHand), burn.Instantiate(1))
                elseif slot == inventory.FindLimbSlot(InvSlotType.LeftHand) then
                    parentCharacter.CharacterHealth.ApplyAffliction(parentCharacter.AnimController.GetLimb(InvSlotType.LeftHand), burn.Instantiate(1))
                end
            end

            if parentCharacter and item.HasTag("emptyfuelrod") then
                local slot = inventory.FindIndex(item)

                if slot == inventory.FindLimbSlot(InvSlotType.RightHand) then
                    parentCharacter.CharacterHealth.ApplyAffliction(parentCharacter.AnimController.GetLimb(InvSlotType.RightHand), burn.Instantiate(0.5))
                elseif slot == inventory.FindLimbSlot(InvSlotType.LeftHand) then
                    parentCharacter.CharacterHealth.ApplyAffliction(parentCharacter.AnimController.GetLimb(InvSlotType.LeftHand), burn.Instantiate(0.5))
                end
            end
        end

        if reactor then
            if parentItem.ConditionPercentage < 75 and not parentItem.HasTag("extrashielding") then
                local data = fuelRods[item.Prefab.Identifier.Value]
                for character in Character.CharacterList do
                    EnhancedReactors.ApplyAfflictionRadius(item, character, 750, 0.6, 0, {
                        radiationSickness.Instantiate((0.45 - parentItem.ConditionPercentage * 0.006) * data.radiationSickness),
                        contaminated.Instantiate((0.45 - parentItem.ConditionPercentage * 0.006) * data.contaminated),
                        radiationSounds.Instantiate((2.9 - parentItem.ConditionPercentage * 0.038) * data.radiationSounds),
                        overheating.Instantiate((0.18 - parentItem.ConditionPercentage * 0.0024) * data.overheating)
                    })
                end
            end
        end
    end
end

local timer = 0
EnhancedReactors.Update = function ()
    if Timer.GetTime() < timer then
        return
    end

    timer = Timer.GetTime() + 0.1

    for item in EnhancedReactors.ManagedItems do
        EnhancedReactors.ProcessItemUpdate(item)
    end
end