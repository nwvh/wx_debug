local debugging = false

local function Draw3DText(pos, text, options)
    options = options or {}
    local color = options.color or { r = 255, g = 255, b = 255, a = 255 }
    local scaleOption = options.size or 0.8

    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - pos)
    local scale = (scaleOption / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scaleMultiplier = scale * fov
    SetDrawOrigin(pos.x, pos.y, pos.z, 0);
    SetTextProportional(0)
    SetTextScale(0.0 * scaleMultiplier, 0.55 * scaleMultiplier)
    SetTextColour(color.r, color.g, color.b, color.a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

---Custom function for notifications
---@param message string Message of the notification
---@param notifyType? string Type of the notification (success, error, warning, info)
wx.Notify = function(message, notifyType)
    return lib.notify(
        {
            title = "Debug",
            type = notifyType or "info",
            description = message,
            icon = "bug",
            time = 5000
        }
    )
end

local function SelectCoords()
    local selected = false
    while true do
        Wait(0)
        local hit, entity, coords = lib.raycast.cam(1|16)
        if not selected then
            selected = true
            lib.showTextUI("[E] Confirm Coords")
        end
        if hit then
            DrawSphere(coords.x, coords.y, coords.z, 0.2, 128, 128, 255, 1.0)
            Draw3DText(coords, ("%s"):format(coords))
            if IsControlJustPressed(1, 38) then
                print(coords)
                lib.hideTextUI()
                selected = false
                debugging = false
                return coords
            end
            if IsControlJustPressed(1, 26) then
                debugging = false
                return
            end
        end
    end
end

---@return number | string
function SpawnPed(model, coords, data)
    if not data then
        data = {
            freeze = false,
            reactions = true,
            god = false,
            scenario = nil
        }
    end
    if not IsModelValid(model) then -- Return an error if the vehicle model doesn't exist
        return ("[ERROR] The specified ped model - [%s] doesn't exist!"):format(model)
    end
    RequestModel(model)                            -- Request the ped model
    while not HasModelLoaded(model) do Wait(5) end -- Wait for the ped to load
    local spawnedped = CreatePed(0, model, coords, true, false)
    if data.freeze then
        FreezeEntityPosition(spawnedped, true)
    end
    if not data.reactions then
        SetBlockingOfNonTemporaryEvents(spawnedped, true)
    end
    if data.god then
        SetEntityInvincible(spawnedped, true)
    end
    if data.anim then
        RequestAnimDict(data.anim[1])
        TaskPlayAnim(spawnedped, data.anim[1], data.anim[2], 8.0, 0.0, -1, 1, 0, 0, 0, 0)
    end
    if data.scenario then
        TaskStartScenarioInPlace(spawnedped, data.scenario, 0, true)
    end
    return spawnedped
end

---comment
---@param model any
---@param coords any
---@param data any
---@return integer
function wx.SpawnVehicle(model, coords, data)
    if not data or data == nil then
        data = {
            locked = false,
            color = { 255, 255, 255 }
            ---@todo: more options
        }
    end
    if not IsModelValid(model) then -- Return an error if the vehicle model doesn't exist
        return
    end
    RequestModel(model)                                              -- Request the vehicle model
    while not HasModelLoaded(model) do Wait(5) end                   -- Wait for the vehicle to load
    local spawnedvehicle = CreateVehicle(model, coords, true, false) -- Finally spawn the vehicle
    if data.locked then
        SetVehicleDoorsLocked(spawnedvehicle, 2)
    end
    SetVehicleCustomPrimaryColour(spawnedvehicle, data.color[1], data.color[2], data.color[3])

    return spawnedvehicle
end

local entityEnumerator = {
    __gc = function(enum)
        if enum.destructor and enum.handle then
            enum.destructor(enum.handle)
        end
        enum.destructor = nil
        enum.handle = nil
    end
}

local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end

        local enum = { handle = iter, destructor = disposeFunc }
        setmetatable(enum, entityEnumerator)

        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next

        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end

function EnumerateObjects()
    return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

function EnumeratePeds()
    return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

RegisterNetEvent('wx_debug:delete:peds', function()
    for v in (EnumeratePeds()) do
        DeleteEntity(v)
    end
end)
RegisterNetEvent('wx_debug:delete:vehicles', function()
    for v in (EnumerateVehicles()) do
        DeleteEntity(v)
    end
end)
RegisterNetEvent('wx_debug:delete:objects', function()
    for v in (EnumerateObjects()) do
        DeleteEntity(v)
    end
end)

RegisterCommand(wx.Command, function()
    lib.registerContext({
        id = 'wx:debugmenu',
        title = 'WX Debug Menu',
        options = {
            {
                title = 'Precise Coords Select',
                description = "Precisely select coords using raycast",
                icon = "location-dot",
                onSelect = function()
                    if debugging then
                        return wx.Notify("You're already selecting coords", "error")
                    end
                    debugging = true
                    local selectedCoords = SelectCoords()
                    SendNUIMessage({ type = 'copy', text = tostring(selectedCoords) })
                    return wx.Notify("Selected coords copied to clipboard!", "success")
                end
            },
            {
                title = 'Spawn Ped',
                description = "Spawn a ped on the selected location",
                icon = "person",
                onSelect = function()
                    if debugging then
                        return wx.Notify("You're already selecting coords", "error")
                    end
                    debugging = true
                    local selectedCoords = SelectCoords()
                    local debugped = SpawnPed(`mp_m_boatstaff_01`, selectedCoords,
                        { freeze = false, reactions = false, god = false })
                    return wx.Notify("Ped has been spawned!", "success")
                end
            },
            {
                title = 'Spawn Vehicle',
                description = "Spawn a ped on the selected location",
                icon = "car-side",
                onSelect = function()
                    if debugging then
                        return wx.Notify("You're already selecting coords", "error")
                    end
                    debugging = true
                    local selectedCoords = SelectCoords()
                    local input = lib.inputDialog('Enter Vehicle Model', {
                        { type = 'input', label = 'Vehicle Model', icon = "car-side", description = 'Vehicle model to spawn, leave empty for a default one', required = false, min = 1, max = 32 },
                    })
                    if not IsModelAVehicle(input[1]) then
                        wx.Notify("Invalid vehicle model, using a default one", "error")
                    end
                    local veh = wx.SpawnVehicle(
                        (input[1]:gsub(" ", "") == "" or not IsModelAVehicle(input[1])) and `chino` or input[1] or
                        input[1],
                        selectedCoords)
                    SetVehicleHasBeenOwnedByPlayer(veh, false)
                    SetEntityAsMissionEntity(veh, false, false)
                    SetVehicleAsNoLongerNeeded(veh)

                    return wx.Notify("Vehicle has been spawned!", "success")
                end
            },
            {
                title = 'Delete all Peds',
                description = "Deletes every ped (npc) on the server",
                icon = "users-slash",
                onSelect = function()
                    lib.callback.await("wx_debug:delete:peds")
                    return wx.Notify("All peds has been deleted!", "success")
                end
            },
            {
                title = 'Delete all objects',
                description = "Deletes every object on the server",
                icon = "box",
                onSelect = function()
                    lib.callback.await("wx_debug:delete:objects")
                    return wx.Notify("All objects has been deleted!", "success")
                end
            },
            {
                title = 'Delete all vehicles',
                description = "Deletes every vehicle on the server",
                icon = "car",
                onSelect = function()
                    lib.callback.await("wx_debug:delete:vehicles")
                    return wx.Notify("All vehicles has been deleted!", "success")
                end
            },
        }
    })
    lib.showContext("wx:debugmenu")
end, false)
