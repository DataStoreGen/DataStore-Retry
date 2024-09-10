local DataStoreModule = require(script.Parent.DataStoreModule)
local Players = game:GetService('Players')
local PlayersData = require(script.Parent.PlayersData)
local newStore = DataStoreModule.new({name = 'PlayerPrefs'}, PlayersData)
local RunService = game:GetService('RunService')

Players.PlayerAdded:Connect(function(player)
    newStore:LoadData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    newStore:OnLeave(player)
end)

game:BindToClose(function()
    newStore:BindOnClose(RunService, Players)
end)

newStore:AutoSave(true, 60) -- autosaves every 60 seconds
-- if under 30 seconds it will auto go back to 30 seconds
