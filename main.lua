function _load_module(name)
    local path = _get_opc_home()
    local filename = string.format("%s/%s.lua", path, name)
    local module = dofile(filename)
    return module
end

-- load API into global space
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

local techlib = _load_module("technology")
local interface = _load_module("interface")

-- parse command line arguments
local argparse = _load_module("argparse")
local args = argparse.parse(arg)
-- prepare cell arguments
local cellargs = {}
for k, v in string.gmatch(table.concat(args.cellargs, " "), "(%w+)%s*=%s*(%S+)") do
    cellargs[k] = v
end

if not args.cell then
    print("no cell type given")
    os.exit(exitcodes.nocelltype)
end

-- output cell parameters
if args.params then
    celllib.print_parameters(args.cell)
    os.exit(0)
end

if not args.technology then
    print("no technology given")
    os.exit(exitcodes.notechnology)
end
if not args.interface then
    print("no interface given")
    os.exit(exitcodes.nointerface)
end

techlib.load(args.technology)
interface.load(args.interface)

local cell, msg = celllib.create_layout(args.cell, cellargs)
if args.origin then
    local dx, dy = string.match(args.origin, "%(%s*([-.%d]+)%s*,%s*([-.%d]+)%s*%)")
    cell:translate(dx, dy)
end

if not cell then
    print(string.format("error while creating cell, received: %s", msg))
    os.exit(exitcodes.errorincell)
end

techlib.translate_metals(cell)
techlib.split_vias(cell)
techlib.create_via_geometries(cell)
techlib.map_layers(cell)
techlib.fix_to_grid(cell)

local filename = args.filename or "openPCells"
interface.set_options(args.interface_options)
interface.write_cell(filename, cell)

-- vim: ft=lua
