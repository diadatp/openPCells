local M = {}

M.__index = M

local function _create(value)
    local self = {
        value = value,
        isgeneric = true,
        get = function(self)
            if self.typ == "via" then
                return self.value.from, self.value.to
            else
                return self.value
            end
        end,
        str = function(self)
            if self.typ == "metal" then
                return string.format("M%d", self:get())
            elseif self.typ == "via" then
                return string.format("viaM%dM%d", self:get())
            elseif self.typ == "contact" then
                return string.format("contact%s", self:get())
            elseif self.typ == "feol" then
                return "feol"
            else
                return self.value
            end
        end
    }
    setmetatable(self, M)
    return self
end

function M.metal(num)
    local self = _create(num)
    self.typ = "metal"
    return self
end

function M.via(from, to)
    if not from or not to then
        error("generic.via with nil")
    end
    local self = _create({ from = from, to = to })
    self.typ = "via"
    return self
end

function M.contact(region)
    local self = _create(region)
    self.typ = "contact"
    return self
end

function M.feol(settings)
    local self = _create(settings)
    self.typ = "feol"
    return self
end

function M.other(layer)
    local self = _create(layer)
    self.typ = "other"
    return self
end

function M.mapped(layer)
    local self = _create(layer)
    self.typ = "mapped"
    return self
end

function M.is_type(self, ...)
    local comp = function(v) return self.typ == v end
    return aux.any_of(comp, { ... })
end

return M
