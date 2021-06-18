local util = util

function util.param_name(osc_name)
    local id = params.lookup[osc_name]
    local param = params.params[id]
    return param.name
end

function util.params_contains_key(key)
  return pcall(function() params:get(key) end)
end

function util.load_passthrough()
  if not (util.params_contains_key("midi_interface") and
    util.params_contains_key("midi_device")) then
    print("didn't find passthrough params")
    print("initializing passthrough")
    if util.file_exists(_path.code.."passthrough") then
      local passthru = include 'passthrough/lib/passthrough'
      passthru.init()
    end
  else
    print("did find passthrough params")
    print("won't initialize passthrough")
  end
end

return util

