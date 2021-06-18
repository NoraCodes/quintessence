-- quintessence
-- outmoded cosmology in the
-- service of composition
-- v0.0.1 (alpha) @noracodes
-- llllllll.co/t/44967
--
-- --------------------------------
--
-- E1 - page
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

engine.name = 'PolyPerc'

include("lib/phys_state")
include("lib/util")
include("lib/12tet")

-- Global state
local state = {
  run = true,       -- Is the physics model progressing at the moment?
  pages = { "MODEL", "PARAM", "TRIGS", "SAMPL", "QUANT", "COMMS" },
  page = 1,         -- Start on the solar system model page
  pstate = {},      -- The physics state of the system
  midicon = {},     -- The MIDI connection in use
  send_sound = true, -- Whether or not to send sound through the PolyPerc engine
  send_midi = true, -- Whether or not to send MIDI
  page1 = {},       -- The page 1 state
  page2 = {         -- The page 2 state
    -- possible params to be edited on page 2
    params = { "radius_a",  "radius_b", "radius_c", "phase_a", "phase_b", "phase_c" },
    param_index = 1 -- Which parameter is being edited
  }
}

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

  params:set_action("radius_a", function(x) state.pstate.bodies[1].radius = x; maxradius("a", "b"); end)
  params:set_action("radius_b", function(x) state.pstate.bodies[2].radius = x; minradius("a", "b"); maxradius("b", "c"); end)
  params:set_action("radius_c", function(x) state.pstate.bodies[3].radius = x; minradius("b", "c"); end)
  params:set_action("phase_a", function(x) state.pstate.bodies[1].phase = math.rad(x); end)
  params:set_action("phase_b", function(x) state.pstate.bodies[2].phase = math.rad(x); end)
  params:set_action("phase_c", function(x) state.pstate.bodies[3].phase = math.rad(x); end)

  -- quantization parameters
  params:add_separator("quantization")
  params:add_number("output_range", "range (octaves)", 1, 10, 2)
  params:add_number("output_offset", "offset (octaves)", 0, 10, 3)

  -- communication parameters
  params:add_separator("input/output")
  params:add_option("output_send_midi", "send midi", {"yes", "no"}, 1)
  params:add_option("output_use_engine", "send sound", {"yes", "no"}, 1)
  params:add_number("output_device", "midi device", 1, 16, 1)
  params:add_number("output_channel", "midi channel", 1, 16, 1)
  params:add_option("input_accept_transport", "accept transport", {"yes", "no"}, 2)
  params:add_option("output_send_transport", "send transport", {"yes", "no"}, 2)

  params:set_action("output_device", function(device) state.midicon = midi.connect(device) end)
  params:set_action("output_send_midi", function(val) if val == 1 then state.send_midi = true else state.send_midi = false end end)
  params:set_action("output_use_engine", function(val) if val == 1 then state.send_sound = true else state.send_sound = false end end)

  state.pstate = PhysState:new()
  params:default()
  params:bang()

  -- register callbacks
  clock.transport.start = function () if params:get("input_accept_transport") == 1 then print("start"); state.run = true end end
  clock.transport.stop = function () if params:get("input_accept_transport") == 1 then print("stop"); state.run = false end end

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
      if state.run then
        state.pstate:update_computations(3/16)
      end
      redraw()
    end
  end)
  midi_clockout = clock.run(function ()
    while true do
      clock.sync(1/16)
      if state.run and state.send_midi and params:get("output_send_transport") == 1 then
        state.midicon:clock()
      end
    end
  end)
  onbeat_midi = clock.run(function()
    while true do
      clock.sync(1/4)
      if state.run then
        local close = false

        for i, distance in ipairs(state.pstate.distances) do
          if state.pstate:minmax(i) then
            close = true
          end
        end

        if close then
          local scaling_semitones = 12 * params:get("output_range")
          local offset_semitones = 12 * params:get("output_offset")
          local note = math.floor((state.pstate.area / state.pstate.max_area) * scaling_semitones + offset_semitones);
          if state.send_midi then
            state.midicon:note_on(note, 100, params:get("output_channel"))
          end
          if state.send_sound then
            engine.hz(midi_note_to_freq(note))
          end
        end 
      end
    end
  end)
end

--- state of keys at last change
local klast = {0, 0, 0}
function key(n,z)
  -- key actions: n = number, z = state
  if z == 1 and n == 2 and klast[2] == 0 then
    state.run = not state.run
    if params:get("output_send_transport") == 1 and state.send_midi then
      if state.run then
        if state.pstate.dt == 0.0 then
          state.midicon:start()
        else 
          state.midicon:continue()
        end
      else
        state.midicon:stop()
      end
    end
  end

  if z == 1 and n == 3 and klast[3] == 0 then
    state.pstate.dt = 0.0
  end

  klast[n] = z 
end

function enc(n,d)
  -- for e1, always change pages
  if n == 1 then
    state.page = get_next_page(d)
  end

  -- page 2 params are available in page 1 as well
  if state.page == 2 or state.page == 1 then
    if n == 2 then
      state.page2.param_index = get_next_param(d, state.page2.param_index, #state.page2.params)
    elseif n == 3 then
      old = params:get(state.page2.params[state.page2.param_index])
      params:set(state.page2.params[state.page2.param_index], old + d)
    end
  end
  redraw()
end

function redraw()
  screen.clear()

  screen.level(0)
  screen.stroke()

  if state.page == 1 then
    -- triangle
    for i, pair in ipairs(state.pstate.PAIRS) do
      pos1 = state.pstate:position_of(pair[1], 64, 32)
      pos2 = state.pstate:position_of(pair[2], 64, 32)
      screen.move(pos1[1], pos1[2])
      screen.line(pos2[1], pos2[2])
      if state.pstate:minmax(i) then
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

    for i, body in ipairs(state.pstate.bodies) do
      local body = state.pstate.bodies[i]
      local pos = state.pstate:position_of(i, 64, 32)

      -- the orbit
      if state.page2.param_index == i then
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
      if (state.page2.param_index - 3) == i then
        screen.fill()
      else
        screen.stroke()
      end
    end

    -- page 1 footer
    screen.level(1)
    screen.move(0, 64)
    screen.text("run")
    screen.move(25, 64)
    screen.text("rst")
  end

  if state.page == 2 then
    -- the distances
    screen.move(0, 15)
    screen.level(15)
    screen.text("DISTANCES")
    labels = {"ab", "bc", "ca"}
    for i, label in ipairs(labels) do
      if state.pstate:minmax(i) then
        screen.level(10)
      else
        screen.level(2)
      end
      screen.move(3, 6*i + 15)
      screen.text(labels[i])
      screen.move(19, 6*i + 15)
      screen.text(math.floor(state.pstate.distances[i]))
      screen.move(30, 6*i + 15)
      screen.text("/"..state.pstate.min_distances[i].."/"..state.pstate.max_distances[i])
    end
    -- the area 
    screen.move(0, 39)
    screen.level(15)
    screen.text("AREA")
    screen.level(2)
    screen.move(3, 45)
    screen.text("abc")
    screen.move(19, 45)
    screen.text(math.floor(state.pstate.area))
    screen.move(39, 45)
    screen.text("/" .. math.floor(state.pstate.max_area))

    -- the parameters
    screen.move(80, 15)
    screen.level(15)
    screen.text("PARAMETERS")
    for i, param_id in ipairs(state.page2.params) do
      if i == state.page2.param_index then
        screen.level(10)
      else
        screen.level(2)
      end
      screen.move(80, 15 + 6*i)
      screen.text(param_name(state.page2.params[i]))
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
  screen.text(state.page)

  screen.level(15)
  screen.move(5, 5)
  screen.text(state.pages[state.page])

  screen.level(1)
  screen.move(103,5)
  screen.text("page^")
end

-- produce a page change from the encoder delta
-- no matter how hard you twist the knob,
-- we move forward or back one, not wrapping.
function get_next_page(enc_delta)
  local dpage = 0
  if enc_delta > 0 then
    dpage = 1
  elseif enc_delta < 0 then
    dpage = -1
  end
  local npage = state.page + dpage
  if npage > #state.pages then
    npage = #state.pages
  end
  if npage < 1 then
    npage = 1
  end
  return npage
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
