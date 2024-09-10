local FolderModule = {}

function FolderModule.CreateFolder(name, parent)
    return {
        Name = name,
        Parent = parent
    }
end

return FolderModule
