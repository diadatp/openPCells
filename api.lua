object     = _load_module("object")
shape      = _load_module("shape")
point      = _load_module("point")
geometry   = _load_module("geometry")
graphics   = _load_module("graphics")
pcell      = _load_module("pcell")
generics   = _load_module("generics")
bitop      = _load_module("bitop")
celllib    = _load_module("cell")
stringfile = _load_module("stringfile")
util       = _load_module("util")
aux        = _load_module("aux")
exitcodes  = _load_module("exitcodes")

function enable(bool, value)
    return (bool and 1 or 0) * value
end