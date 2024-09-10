local InstanceType = {}
InstanceType.__index = InstanceType

export type Ins<Creation> = typeof(
    setmetatable(
        {}:: {
            InstanceNew: Creation,
        },
        {}:: {
            __index: {
                Parent: (self: Ins<Creation>, parent: any) -> Ins<Creation>,
                Name: (self: Ins<Creation>, name: string) -> Ins<Creation>,
                Value: (self: Ins<Creation>, value: any) -> Ins<Creation>,
                OnChanged: (self: Ins<Creation>, callBack: (property: string) -> (any)) -> Ins<Creation>,
                ChangeName: (self: Ins<Creation>, newName: string) -> Ins<Creation>,
                Destroy: (self: Ins<Creation>) -> Ins<Creation>,
                SetAttribute: (self: Ins<Creation>, Name: string, Value: any) -> Ins<Creation>,
                ValueChange: (self: Ins<Creation>, newValue: any) -> Ins<Creation>,
                ChangeAttribute: (self: Ins<Creation>, newName: string, newValue: any) -> Ins<Creation>
            }
        }
    )
)

local insMeta = {
    __index = function(self, key)
        local cacheMethod = rawget(self, '_methodCache')[key]
        if cacheMethod then
            return cacheMethod
        end
        if InstanceType[key] then
            local method = function(...)
                return InstanceType[key](...)
            end
            rawget(self, '_methodCache')[key] = method
            return method
        else
            return self.Ins[key]
        end
    end,
    __newindex = function(self, key, value)
        if self.Ins[key] ~= nil then
            self.Ins[key] = value
        else
            error(string.format(`Property, '%s' does not exist on instance of type '%s`, key, tostring(self.InstanceNew)))
        end
    end,
    __metatable = 'Locked MetaTable'
}

function InstanceType.new<Creation>(InstanceNew: Creation): Ins<Creation>
    local self = {
        InstanceNew = InstanceNew,
        Ins = Instance.new(InstanceNew),
        _methodCache = {}
    }
    setmetatable(self, insMeta)
    return self
end

function InstanceType:Parent(parent): Ins
    if type(parent) == "table" and parent.Ins then
        self.Ins.Parent = parent.Ins
    else
        self.Ins.Parent = parent
    end
    return self
end

function InstanceType:Name(name): Ins
    self.Ins.Name = name
    return self
end

function InstanceType:Value(value): Ins
    self.Ins.Value = value
    return self
end

function InstanceType:OnChanged(callback: (property: string) -> ()): Ins
    return self.Ins.Changed:Connect(callback)
end

function InstanceType:ChangeName(newName: string): Ins
    self.Ins.Name = newName
    return self
end

function InstanceType:Destroy(): Ins
    return self.Ins:Destroy()
end

function InstanceType:SetAttribute(Name, Value): Ins<Creation>
    self.Ins:SetAttribute(Name, Value)
    return self
end

function InstanceType:ValueChange(newValue): Ins<Creation>
    self.Ins.Value = newValue
    return self
end

function InstanceType:ChangeAttribute(Name, Value): Ins<Creation>
    self.Ins:SetAttribute(Name, Value)
    return self
end

return InstanceType
