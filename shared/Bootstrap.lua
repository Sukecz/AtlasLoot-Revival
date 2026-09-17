local addonName, ns = ...

ns.name = addonName
ns.modules = {}
ns.Data = {}

function ns:RegisterModule(name, module)
    assert(type(name) == "string" and name ~= "", "module name is required")
    assert(type(module) == "table", "module must be a table")
    assert(self.modules[name] == nil, "module already registered: " .. name)

    self.modules[name] = module
    return module
end
