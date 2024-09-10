local ValueModule = {}

function ValueModule.CreateValues(name, value, parent)
    return {
        Name = name,
        Value = value,
        Parent = parent
    }
end

return ValueModule
