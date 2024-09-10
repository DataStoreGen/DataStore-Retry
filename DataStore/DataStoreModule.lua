local InstanceLibrary = require(script.InstanceLibrary)
local FolderModule = require(script.Folders)
local ValueModule = require(script.Values)

local config = {
    max = 30,
    retry = 0.3,
    versionAsync = 'v1.0',
    logLevel = 'Info'
}

setmetatable(config, {
    __newindex = function(_, key, value)
        if config[key] ~= nil then
            rawset(config, key, value)
        else
            local message = `Attempting to modify a nilch config key: {key}`
            error(message)
        end
    end,
})

local asyncQueue = {}
local queueMutex = false

function logMessage(level, message)
    if level == 'Error' or config.logLevel == 'Debug' or (config.logLevel == 'Info' and level ~= 'Debug') then
        local levelMessage = string.format('[DataStoreModule] [%s] %s', level, message)
        if level == 'Error' then
            error(levelMessage)
        elseif config.logLevel == 'Debug' then
            warn(levelMessage)
        else
            print(levelMessage)
        end
    end
end

function enqueueAsync(func)
    while queueMutex do
        task.wait(0.01)
    end
    queueMutex = true
    table.insert(asyncQueue, func)
    queueMutex = false
end

local eventListen = {}

function dispatchEvent(event, ...)
    if eventListen[event] then
        for _, listener in ipairs(eventListen[event]) do
            coroutine.wrap(listener)(...)
        end
    end
end

local DataStoreModule = {}
DataStoreModule.__index = DataStoreModule

type eventName = 'dataSaved'|'dataLoaded'|'saveFailed'|'queueProcessed'|'queueError'|'AutoSave'

function DataStoreModule:on(event: eventName, listener)
    if not eventListen[event] then eventListen[event] = {} end
    table.insert(eventListen[event], listener)
end

function DataStoreModule:off(event: eventName, listener)
    if eventListen[event] then
        for i, l in ipairs(eventListen[event]) do
            if l == listener then table.remove(eventListen[event], i) break end
        end
    end
end

function processQueue()
    while true do
        if #asyncQueue > 0 then
            local func
            while queueMutex do task.wait(0.01) end
            queueMutex = true
            func = table.remove(asyncQueue, 1)
            queueMutex = false
            local success, err = pcall(func)
            if not success then
                logMessage('Error', string.format("Queuing process error: %s", err))
                dispatchEvent('queueError', err)
            else
                dispatchEvent('queueProcessed', func)
            end
        end
        task.wait(0.1)
    end
end

coroutine.wrap(processQueue)()

function retryAsync(func)
    local retries = 0
    while retries < config.max do
        local success, result = pcall(func)
        if success then return result else
            retries = retries + 1
            logMessage('Warn', string.format("Retrying ... (%d/%d) Error: %s", retries, config.max, result))
            task.wait(config.retry)
        end
    end
    error(string.format("Failed after %d retries", config.max))
end

type DSSOption = {name: string, scope: string?, options: DataStoreOptions?}

function DataStoreModule.new(configuration: DSSOption, playerData)
    local self = setmetatable({}, DataStoreModule)
    self.DataStore = game:GetService('DataStoreService'):GetDataStore(configuration.name, configuration.scope, configuration.options)
    self.PlayerData = playerData
    self.Session = require(script.Parent.Session).Session
    self.Clone = function(original)
        local copy = {}
        for key, data in pairs(original) do
            if type(data) == 'table' then copy[key] = self.Clone(data) else
                copy[key] = data
            end
        end
        return copy
    end
    return self
end

function DataStoreModule:Key(player)
    return string.format("Player_%d", player.UserId)
end

function DataStoreModule:GetLastSession(player)
    local key = self:Key(player)
    local success, data = pcall(function()
        return retryAsync(function() return self.DataStore:GetAsync(key) end)
    end)
    if not success then player:Kick(string.format(`Failed to fetch data to: {player.Name} and also retry`)) end
    return data or self.Clone(self.PlayerData)
end

function DataStoreModule:MergeToCurrent(data)
    for key, value in pairs(self.PlayerData) do
        if type(value) == 'table' then
            data[key] = data[key] or {}
            for k, v in pairs(value) do
                data[key][k] = data[key][k] or v
            end
        else
            data[key] = data[key] or value
        end
    end
    return data
end

function DataStoreModule:CreateFolder(name, player)
    local Folder = InstanceLibrary.new('Folder')
        :Name(name)
        :Parent(player)
    return Folder
end

type Val = 'Number' | 'Int' | 'String' | 'Bool'
function DataStoreModule:CreateValue(valType: Val, name: string, value: any, parent: any)
    local Value = InstanceLibrary.new(valType .. 'Value')
        :Name(name)
        :Value(value)
        :Parent(parent)
    return Value
end

function checkType(valueData)
    local valueType = typeof(valueData.Value)
    if valueType == "boolean" then return "BoolValue"
    elseif valueType == "number" then return "NumberValue"
    elseif valueType == "string" then return "StringValue"
    else
        warn(`{valueData.Name} must support {valueType}`)
        error(`Unsupported ValueType: {valueType}`)
    end
end

function DataStoreModule:AutoCreateData(foldersData, valuesData)
    local folders = {}
    local values = {}
    for _, folderData in pairs(foldersData) do
        local newFolder = Instance.new("Folder")
        newFolder.Name = folderData.Name
        newFolder.Parent = folderData.Parent
        folders[folderData.Name] = newFolder
    end
    for _, valueData in pairs(valuesData) do
        local newValueType = checkType(valueData)
        local newValueInstance = Instance.new(newValueType)
        newValueInstance.Name = valueData.Name
        newValueInstance.Value = valueData.Value
        if type(valueData.Parent) == "string" and folders[valueData.Parent] then
            newValueInstance.Parent = folders[valueData.Parent]
        elseif typeof(valueData.Parent) == "Instance" then
            newValueInstance.Parent = valueData.Parent
        else
            error("Invalid parent for value: " .. valueData.Name)
        end
        table.insert(values, newValueInstance)
    end
    return folders, values
end

function DataStoreModule:createData(player, userData)
    local ls = self:CreateFolder('leaderstats', player)
    ls:SetAttribute('Car', true)
    self:CreateValue('Number', 'Cash', userData['Cash'], ls)
    
    local keys = {
        'leaderstats'
    }
    
end

function DataStoreModule:LoadData(player)
    local data = self:GetLastSession(player)
    data = self:MergeToCurrent(data)
    local key = self:Key(player)
    self.Session[key] = data
    local user = self.Session[key]
    dispatchEvent('dataLoaded', player, data)
    self:createData(player, user)
end

function DataStoreModule:GetRequest(bug)
    local service = game:GetService('DataStoreService')
    local current = service:GetRequestBudgetForRequestType(bug)
    while current < 1 do
        task.wait(5)
        current = service:GetRequestBudgetForRequestType(bug)
    end
end

function DataStoreModule:GetData(key)
    local Session = self.Session[key]
    if not Session then return end
    return Session
end

function DataStoreModule:UpdateAsync(player, OnClose)
    local key = self:Key(player)
    local Session = self:GetData(key)

    local success, err
    repeat
        if not OnClose then self:GetRequest(Enum.DataStoreRequestType.UpdateAsync) end
        success, err = pcall(function()
            enqueueAsync(function()
                retryAsync(function() 
                    self.DataStore:UpdateAsync(key, function()
                        return Session
                    end)
                end)
            end)
        end)
    until success
    if not success then
        logMessage('Warn', string.format("Data was not saved to %s", player.Name))
        dispatchEvent('saveFailed', player, err)
    else
        dispatchEvent('dataSaved', player)
    end
end

function DataStoreModule:OnLeave(player)
    self:UpdateAsync(player)
    self.Session[self:Key(player)] = nil
end

function DataStoreModule:BindOnClose(RunService, Players)
    if RunService:IsServer() then return task.wait(2) end
    local bindableEvent = Instance.new('BindableEvent')
    local players = Players:GetPlayers()
    local remaining = #players
    for _, player in pairs(players) do
        task.spawn(function()
            self:UpdateAsync(player, true)
            remaining = remaining - 1
            if remaining <= 0 then bindableEvent:Fire() end
        end)
    end
    bindableEvent.Event:Wait()
end

function DataStoreModule:AutoSave(bool: boolean, waitTime: number)
    if waitTime < 30 then
        warn("AutoSave can't be under 30. Auto-correcting to 30")
        waitTime = 30
    elseif waitTime > 600 then
        warn("AutoSave can't go past 10 minutes or 600 seconds. Auto-correcting to 600")
        waitTime = 600
    end
    while bool and task.wait(waitTime) do
        for _, player in pairs(game.Players:GetPlayers()) do
            dispatchEvent('AutoSave', player)
            self:UpdateAsync(player)
        end
    end
end

return DataStoreModule
