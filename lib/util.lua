function param_name(osc_name)
    local id = params.lookup[osc_name]
    local param = params.params[id]
    return param.name
end