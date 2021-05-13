Body = { radius = 0, phase = 0.0 }
Body.__index = Body

function Body:new (radius, phase)
    local body = {}
    setmetatable(body, Body)
    body.radius = radius
    body.phase = phase
    return body 
end

function Body:theta(dt)
    return self.phase + (math.pi * dt) / self.radius
end

function Body:pos_x(dt, offset)
    return offset + self.radius * math.sin(self:theta(dt))
end

function Body:pos_y(dt, offset)
    return offset + -(self.radius * math.cos(self:theta(dt)))
end

function Body:distance_to(dt, other)
    return math.sqrt(
        (self:pos_x(dt, 0) - other:pos_x(dt, 0))^2 + (self:pos_y(dt, 0) - other:pos_y(dt, 0))^2
    )
end
