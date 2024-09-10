--[[
how to make ur own Store to able create secure game data

local QueueStore = require(script.Parent.QueueStore)
local PlayerData = require(script.Parent.PlayerData)
local newStore = QueueStore.new({ Name = 'PlayerPrefs', Scope = 'PlayerData' }, PlayerData) --[
    the first arg is 
    {name: string, scope: string, options: DataStoreOptions}
]

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

newStore:on('dataLoaded', function(player, data)
    local message = `Successfully reloaded data to: {player.Name}`
    print(message)
end)

Players.PlayerAdded:Connect(function(player)
    newStore:LoadData(player) -- [
    loads example  {Cash = 0} if new data adds {Cash = 0, Rebirth = 0} and so on
    ]
end)

Players.PlayerRemoving:Connect(function(player)
    newStore:OnLeave(player) --[
    sets the self.Session to nil so it does not leave behind 100+ sessions running in the background
    ]
end)

game:BindToClose(function()
    newStore:BindToClose(RunService, Players) --able to update UpdateAsync to save Data properly
end)

newStore:of('dataLoaded', function(player, data) end)


newStore:AutoSave(true, 30) -- if u try to put anything under it will automatcially correct to 30

--Store Creation aka Data
PlayerData.lua
local module = {
    Cash = 0,
    Rebirth = 0
}
return Module

QueueStore.lua
function DataStoreModule:createData(player, userData)
--option 1 auto setup everything fast
    self:AutoCreateData(
        {
            FolderModule.CreateFolder('leaderstats', player)
        },
        {
            ValueModule.CreateValues('Cash', userData['Cash', 'leaderstats')
        }
    )
    
--option 2 slow and make each one manually but has a Library to create its other functions
    local ls = self:CreateFolder('leaderstats', player)
    local Cash = self:CreateValue('Cash', userData['Cash'], ls)
        :OnChanged(function(property)
            print('Cash has changed to:', property)
        end)
        :SetAttribute('Upgrades', 0)
end

-- to turn on Debug
from newStore at line 6 in Read-Only
newStore:on('dataLoaded', function(player, data)
    warn('Data loaded to:', player.Name)
end)
-- to turn it off
newStore:off('dataLoaded', function(player, data) end) -- this is how to turn it off

]]
