include("lib/body")

PhysState = {
  dt = 0.0,
  bodies = {},
  positions = {},
  distances = {},
  min_distances = {},
  max_distances = {},
  max_simultaneous_distances = {},
  area = 0.0,
  max_area = 0.0,
  -- defined order for pairs
  PAIRS = {{1, 2}, {2, 3}, {3, 1}}
}

PhysState.__index = PhysState

function PhysState:new ()
  local ps = {}
  setmetatable(ps, PhysState)
  ps.bodies = {
    Body:new(params:get("radius_a"), 0.0),
    Body:new(params:get("radius_b"), 0.0),
    Body:new(params:get("radius_c"), 0.0)
  }
  ps:update_computations(0)
  return ps
end

function PhysState:update_computations(dt)
  self.dt = self.dt + dt
  for i, pair in ipairs(self.PAIRS) do
    self.distances[i] = self.bodies[pair[1]]:distance_to(self.dt, self.bodies[pair[2]])
    -- TODO split out all this stuff, run only on radius updates!
    self.min_distances[i] = math.abs(
      self.bodies[pair[1]].radius - self.bodies[pair[2]].radius
    )
    self.max_distances[i] = math.abs(
      self.bodies[pair[1]].radius + self.bodies[pair[2]].radius
    )
    local third_rad = (2*math.pi)/3
    local hypothetical_phases = {{0, third_rad}, {third_rad, 2*third_rad}, {2*third_rad, 0}}
    local hypothetical_body_1 = Body:new(self.bodies[pair[1]].radius, hypothetical_phases[i][1])
    local hypothetical_body_2 = Body:new(self.bodies[pair[2]].radius, hypothetical_phases[i][2])
    self.max_simultaneous_distances[i] = hypothetical_body_1:distance_to(0, hypothetical_body_2)
  end

  self.area = area_of(self.distances[1], self.distances[2], self.distances[3])
  self.max_area = area_of(self.max_simultaneous_distances[1], self.max_simultaneous_distances[2], self.max_simultaneous_distances[3])
end

function PhysState:position_of(body, offset_x, offset_y)
  local x = self.bodies[body]:pos_x(self.dt, offset_x)
  local y = self.bodies[body]:pos_y(self.dt, offset_y)
  return {x,y}
end

function PhysState:minmax(i)
  return math.abs(self.distances[i] - self.min_distances[i]) < 0.1 or math.abs(self.distances[i]- self.max_distances[i]) < 0.1
end

function area_of(a, b, c)
  s = (a + b + c) / 2
  return math.sqrt(s * math.abs(s - a) * math.abs(s - b) * math.abs(s - c))
end

-- function for minimum radius, takes letters for bodies
function minradius(smaller,larger)
	local smaller_id = "radius_"..smaller
	local larger_id = "radius_"..larger
	if params:get(larger_id) < params:get(smaller_id) + 1
		then params:set(larger_id, params:get(smaller_id)+1)
	end
end

-- function for maximum radius, takes letters for bodies
function maxradius(smaller,larger)
	local smaller_id = "radius_"..smaller
	local larger_id = "radius_"..larger
	if params:get(smaller_id) > params:get(larger_id) - 1
		then params:set(smaller_id, params:get(larger_id)-1)
	end
end

return PhysState
