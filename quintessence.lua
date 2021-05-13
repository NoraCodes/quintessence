-- quintessence
-- outmoded cosmology in the
-- service of composition
-- v0.0.1 (alpha) @noracodes
-- llllllll.co/t/xxxxxx
--
-- --------------------------------
--
-- E1 - page/mode
-- E2 - select param
-- E3 - param value
--
-- K2 - run/stop
-- K3 - reset time
-- --------------------------------
--
-- quintessence simulates a
-- set of three bodies in
-- orbit around a single
-- unmoving point,
-- in perfect circles,
-- advancing in accordance
-- with the tempo;
-- the smallest possible
-- orbit will result in
-- one half a rotation
-- in each and every beat.
--
-- melodic information is
-- derived from the relative
-- positions of these bodies.
--
-- --------------------------------
--
-- thanks to @fardles for an
-- elegant callback-based way
-- to set the limits of params
-- dynamically.

engine.name = 'PolySub'

-- Global state
RUN = true
MODE = 1 -- Start in the solar system model mode
modes = { "MODEL", "PARAM", "TRIGS", "SAMPL", "QUANT", "COMMS" }
PAGE2_PARAM_INDEX = 1
page2_params = { "radius_a",  "radius_b", "radius_c", "phase_a", "phase_b", "phase_c" }

include("lib/phys_state")
include("lib/util")

pstate = {}
midicon = {}

function init()
  obt_min = 3
  obt_max = 32

  -- physical state parameters
  params:add_separator("bodies")
  params:add_number("radius_a", "radius a", obt_min, obt_max, 10)
  params:add_number("radius_b", "radius b", obt_min, obt_max, 20)
  params:add_number("radius_c", "radius c", obt_min, obt_max, 30)
  params:add_number("phase_a", "phase a", 0, 360)
  params:add_number("phase_b", "phase b", 0, 360)
  params:add_number("phase_c", "phase c", 0, 360)
  
  params:set_action("radius_a", function(x) pstate.bodies[1].radius = x; maxradius("a", "b"); end)
  params:set_action("radius_b", function(x) pstate.bodies[2].radius = x; minradius("a", "b"); maxradius("b", "c"); end)
  params:set_action("radius_c", function(x) pstate.bodies[3].radius = x; minradius("b", "c"); end)
  params:set_action("phase_a", function(x) pstate.bodies[1].phase = math.rad(x); end)
  params:set_action("phase_b", function(x) pstate.bodies[2].phase = math.rad(x); end)
  params:set_action("phase_c", function(x) pstate.bodies[3].phase = math.rad(x); end)
  
  -- communication parameters
  params:add_separator("input/output")
  params:add_number("output_device", "midi device", 1, 16, 1)
  params:add_number("output_channel", "midi channel", 1, 16, 1)
  params:add_number("output_range", "range (octaves)", 1, 10, 2)
  params:add_number("output_offset", "offset (octaves)", 0, 10, 3)
  
  params:set_action("output_device", function(device) midicon = midi.connect(device) end)

  pstate = PhysState:new()
  params:bang()

  -- set up timing
  pmove = clock.run(function ()
    while true do
      clock.sync(1/16)
      -- the smallest orbit is 3.
      -- update_computations(1) updates orbits by 180 (pi radians) for an orbit of 1
      -- we update every 1/16th note.
      -- we want our smallest orbit to go around by half in one beat.
      -- therefore, we want 3 units of time on the simulation
      -- for each 1 unit of time in the metronome,
      -- or 3/16 units for each 1/16 unit.
      if RUN then
        pstate:update_computations(3/16)
      end
      redraw()
    end
  end)
  onbeat_midi = clock.run(function()
    while true do
      clock.sync(1/4)
      if RUN then
  
        local close = false
  
        for i, distance in ipairs(pstate.distances) do
          if pstate:minmax(i) then
            close = true
          end
        end
  
        if close then
          local scaling_semitones = 12 * params:get("output_range")
          local offset_semitones = 12 * params:get("output_offset")
          local note = math.floor((pstate.area / pstate.max_area) * scaling_semitones + offset_semitones);
          midicon:note_on(note, 100, params:get("output_channel"))
          print(note)
        end 
      end
    end
  end)
end

klast = {0, 0, 0}
function key(n,z)
  -- key actions: n = number, z = state
  if z == 1 and n == 2 and klast[2] == 0 then
    RUN = not RUN
  end
  
  if z == 1 and n == 3 and klast[3] == 0 then
    pstate.dt = 0.0
  end
  
  klast[n] = z 
end

function enc(n,d)
  -- for e1, always change modes
  if n == 1 then
    MODE = get_next_mode(d)
  end

  -- page 2 params are available in page 1 as well
  if MODE == 2 or MODE == 1 then
    if n == 2 then
      PAGE2_PARAM_INDEX = get_next_param(d, PAGE2_PARAM_INDEX, #page2_params)
    elseif n == 3 then
      old = params:get(page2_params[PAGE2_PARAM_INDEX])
      params:set(page2_params[PAGE2_PARAM_INDEX], old + d)
    end
  end
  redraw()
end

function redraw()
  screen.clear()

  screen.level(0)
  screen.stroke()

  if MODE == 1 then
    -- triangle
    for i, pair in ipairs(pstate.PAIRS) do
      pos1 = pstate:position_of(pair[1], 64, 32)
      pos2 = pstate:position_of(pair[2], 64, 32)
      screen.move(pos1[1], pos1[2])
      screen.line(pos2[1], pos2[2])
      if pstate:minmax(i) then
        screen.level(15)
      else
        screen.level(1)
      end
      screen.stroke()
    end

    -- the sun
    screen.level(15)
    screen.circle(64, 32, 2)
    screen.fill()

    for i, body in ipairs(pstate.bodies) do
      local body = pstate.bodies[i]
      local pos = pstate:position_of(i, 64, 32)

      -- the orbit
      if PAGE2_PARAM_INDEX == i then
        screen.level(3)
      else
        screen.level(1)
      end
      screen.circle(64, 32, body.radius)
      screen.stroke()

      -- the body
      screen.level(0)
      screen.circle(pos[1], pos[2], 1)
      screen.fill()
      screen.level(8)
      screen.circle(pos[1], pos[2], 2)
      -- (skip the first 3 params)
      if (PAGE2_PARAM_INDEX - 3) == i then
        screen.fill()
      else
        screen.stroke()
      end
    end
    
    -- mode 1 footer
    screen.level(1)
    screen.move(0, 64)
    screen.text("run")
    screen.move(25, 64)
    screen.text("rst")
  end

  if MODE == 2 then
    -- the distances
    screen.move(0, 15)
    screen.level(15)
    screen.text("DISTANCES")
    labels = {"ab", "bc", "ca"}
    for i, label in ipairs(labels) do
      if pstate:minmax(i) then
        screen.level(10)
      else
        screen.level(2)
      end
      screen.move(3, 6*i + 15)
      screen.text(labels[i])
      screen.move(19, 6*i + 15)
      screen.text(math.floor(pstate.distances[i]))
      screen.move(30, 6*i + 15)
      screen.text("/"..pstate.min_distances[i].."/"..pstate.max_distances[i])
    end
    -- the area 
    screen.move(0, 39)
    screen.level(15)
    screen.text("AREA")
    screen.level(2)
    screen.move(3, 45)
    screen.text("abc")
    screen.move(19, 45)
    screen.text(math.floor(pstate.area))
    screen.move(39, 45)
    screen.text("/" .. math.floor(pstate.max_area))

    -- the parameters
    screen.move(80, 15)
    screen.level(15)
    screen.text("PARAMETERS")
    for i, param_id in ipairs(page2_params) do
      if i == PAGE2_PARAM_INDEX then
        screen.level(10)
      else
        screen.level(2)
      end
      screen.move(80, 15 + 6*i)
      screen.text(param_name(page2_params[i]))
      screen.move(118, 15 + 6*i)
      screen.text(params:get(param_id))
    end

    -- the footer
    screen.move(70, 59)
    screen.level(1)
    screen.text("param   value")
  end

  redraw_header()
  screen.update()
end

function cleanup()
  -- deinitialization
  clock.cancel(onbeat_midi)
end

function redraw_header()
  screen.level(3)
  screen.move(0, 5)
  screen.text(MODE)

  screen.level(15)
  screen.move(5, 5)
  screen.text(modes[MODE])

  screen.level(1)
  screen.move(103,5)
  screen.text("mode^")
end

-- produce a mode change from the encoder delta
-- no matter how hard you twist the knob,
-- we move forward or back one, not wrapping.
function get_next_mode(enc_delta)
  local dmode = 0
  if enc_delta > 0 then
    dmode = 1
  elseif enc_delta < 0 then
    dmode = -1
  end
  local nmode = MODE + dmode
  if nmode > #modes then
    nmode = #modes
  end
  if nmode < 1 then
    nmode = 1
  end
  return nmode
end

-- produce a param change from the encoder delta
-- no matter how hard you twist the knob,
-- we move forward or back one, not wrapping.
function get_next_param(enc_delta, current, params)
  local dparam = 0
  if enc_delta > 0 then
    dparam = 1
  elseif enc_delta < 0 then
    dparam = -1
  end
  local nparam = current + dparam
  if nparam > params then
    nparam = params
  end
  if nparam < 1 then
    nparam = 1
  end
  return nparam
end
