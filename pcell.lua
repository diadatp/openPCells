--[[
This file is part of the openPCells project.

This module provides the pcell functionality:
    - functions for cell parameterization
    - parameter inheritance and binding (cell hierarchies)
    - layout generation
    - parameter summary

Implementation note:
    Every parameter stores a function return its value, which is only
    evaluated when it is needed: at the moment of shape creation.
    This more complex approach (compared to just storing the values)
    allows for easy binding and inheritance of parameters.
--]]

local M = {}

local function identity(arg) return arg end
local function toboolean(arg)
    return arg == "true" and true or false
end
local function tointeger(arg)
    return math.floor(tonumber(arg))
end
local function tonumtable(arg)
    local t = {}
    for e in string.gmatch(arg, "[^;,]+") do
        table.insert(t, tonumber(e))
    end
    return t
end
local function tostrtable(arg)
    local t = {}
    for e in string.gmatch(arg, "[^;,]+") do
        table.insert(t, tostring(e))
    end
    return t
end
local evaluators = {
    number   = tonumber,
    integer  = tointeger,
    string   = identity,
    boolean  = toboolean,
    numtable = tonumtable,
    strtable = tostrtable,
}

local function _prepare_cell_environment(cellname)
    local bindcell = function(func)
        return bind(func, 1, cellname)
    end
    return {
        pcell = {
            add_parameter                   = bindcell(add_parameter),
            add_parameters                  = bindcell(add_parameters),
            inherit_parameter               = bindcell(inherit_parameter),
            inherit_parameter_as            = bindcell(inherit_parameter_as),
            bind_parameter                  = bindcell(bind_parameter),
            inherit_all_parameters          = bindcell(inherit_all_parameters),
            inherit_and_bind_parameter      = bindcell(inherit_and_bind_parameter),
            inherit_and_bind_parameter_as   = bindcell(inherit_and_bind_parameter_as),
            inherit_and_bind_all_parameters = bindcell(inherit_and_bind_all_parameters),
            -- the following functions don't not need cell binding as they are called for other cells
            clone_parameters                = clone_parameters,
            clone_matching_parameters       = clone_matching_parameters,
            push_overwrites                 = push_overwrites,
            pop_overwrites                  = pop_overwrites,
            get_parameters                  = function(cellname) return _get_parameters(cellname) end,
            create_layout = M.create_layout
        },
        -- fake modules, the shapes are really created later
        -- this enables some tricks for example regarding even/odd metals
        -- to build metal grids with unknown number of metals
        geometry = abstract.geometry,
        graphics = abstract.graphics,
        shape = shape,
        object = object,
        generics = generics,
        point = point,
        util = util,
        aux = aux,
        math = math,
        enable = function(bool, val) return (bool and 1 or 0) * val end,
        string = string,
        table = table,
        print = print,
        type = type,
        ipairs = ipairs,
        pairs = pairs,
    }
end

local cellpaths = {}
function M.add_cellpath(path)
    table.insert(cellpaths, path)
end

local function _load(cellname)
    local filename = string.format("%s/cells/%s.lua", _get_opc_home(), cellname)
    for _, path in ipairs(cellpaths) do
        local tmp = string.format("%s/%s.lua", path, cellname)
        if tmp then
            filename = tmp
        end
    end
    local chunkname = string.format("@cell '%s'", cellname)

    local reader = _get_reader(filename)
    if not reader then
        error(string.format("unknown cell '%s'", cellname))
    end
    local env = _prepare_cell_environment(cellname)
    _generic_load(
        reader, chunkname,
        string.format("syntax error in cell '%s'", cellname),
        string.format("semantic error in cell '%s'", cellname),
        env
    )
    return env
end

local meta = {}
meta.__index = function(t, cellname)
    local funcs = _load(cellname)
    if not (funcs.parameters or funcs.layout) then
        error("every cell must define at least the public functions 'parameters' or 'layout'")
    end
    local cell = {
        funcs = funcs,
        parameters = {},
        indices = {},
        num = 0
    }
    rawset(t, cellname, cell)
    funcs.parameters()
    return cell
end
local loadedcells = setmetatable({}, meta)
local bindings = {}
local bindingsbackup = {}

local function _get_pname_dname(name)
    local pname, dname = string.match(name, "^([^(]+)%(([^)]+)%)")
    if not pname then pname = name end -- no display name
    return pname, dname
end

local function _add_parameter(cellname, name, value, argtype, posvals, follow, overwrite)
    argtype = argtype or type(value)
    local pname, dname = _get_pname_dname(name)
    local new = {
        display = dname,
        func    = funcobject.identity(value),
        argtype = argtype,
        posvals = posvals,
        followers = {}
    }
    if not loadedcells[cellname].parameters[pname] or overwrite then
        loadedcells[cellname].parameters[pname] = new
        loadedcells[cellname].num = loadedcells[cellname].num + 1
        loadedcells[cellname].indices[pname] = loadedcells[cellname].num
        if follow then
            loadedcells[cellname].parameters[follow].followers[pname] = true
        end
    else
        return false
    end
    return true
end

local function _split_input_arguments(args)
    local t = {}
    for name, value in pairs(args) do
        local parent, arg = string.match(name, "^([^.]+)%.(.+)$")
        if not parent then
            arg = name
        end
        table.insert(t, { parent = parent, name = arg, value = value })
    end
    return t
end

local function _set_parameter_function(cellname, name, value, backup, evaluate, overwrite)
    local p = loadedcells[cellname].parameters[name]
    if not p then
        error(string.format("argument '%s' has no matching parameter in cell '%s', maybe it was spelled wrong?", name, cellname))
    end
    if overwrite then
        p.overwritten = true
    end
    local value = value
    if evaluate then
        local eval = evaluators[p.argtype]
        value = eval(value)
    end
    -- store old function for restoration
    backup[name] = p.func:get()
    -- important: use :replace(), don't create a new function object.
    -- Otherwise parameter binding does not work, because bound parameters link to the original function object
    p.func:replace(function() return value end)
end

local function _process_input_parameters(cellname, cellargs, evaluate, overwrite)
    local backup = {}
    if cellargs then
        local args = _split_input_arguments(cellargs)
        for _, arg in ipairs(args) do
            if arg.parent then
                _set_parameter_function(arg.parent, arg.name, arg.value, {}, evaluate, overwrite)
            else
                _set_parameter_function(cellname, arg.name, arg.value, backup, evaluate, overwrite)
            end
        end
    end
    return backup
end

-- FIXME: this function was local, but the order of the functions matters, 
-- since they are added to the sandbox environment for the cell layout functions
-- This is not very good, work on this
function _get_parameters(cellname, cellargs, evaluate)
    local cellparams = loadedcells[cellname].parameters
    cellargs = cellargs or {}

    local backup = _process_input_parameters(cellname, cellargs, evaluate)

    -- store parameters in user-readable table
    local P = {}
    local handled = {}
    for name, entry in pairs(cellparams) do
        if not handled[name] or rawget(cellargs, name) then
            P[name] = entry.func()
            if rawget(cellargs, name) then
                handled[name] = true
            end
        end
        for follower in pairs(entry.followers) do
            if not (handled[follower] or cellparams[follower].overwritten) then
                P[follower] = entry.func()
                handled[follower] = true
            end
        end
    end

    -- install meta method for non-existing parameters as safety check
    -- this avoids arithmetic-with-nil-errors
    setmetatable(P, {
        __index = function(_, k)
            error(string.format("trying to access undefined parameter value '%s'", k))
        end,
    })

    return P, backup
end

local function _restore_parameters(cellname, backup)
    local cellparams = loadedcells[cellname].parameters
    -- restore old functions
    for name, func in pairs(backup) do
        cellparams[name].func:replace(func)
        cellparams[name].overwritten = nil
    end
end

local function _install_bindings(cellname)
    if bindings[cellname] then
        if not bindingsbackup[cellname] then
            bindingsbackup[cellname] = stack.create()
        end
        local backup = {}
        for name, other in pairs(bindings[cellname]) do
            local param = loadedcells[cellname].parameters[name]
            local otherparam = loadedcells[other.cell].parameters[other.name]
            table.insert(backup, { cell = other.cell, name = other.name, func = otherparam.func })
            otherparam.func = param.func
        end
        bindingsbackup[cellname]:push(backup)
    end
end

local function _remove_bindings(cellname)
    if bindingsbackup[cellname] then
        if bindingsbackup[cellname]:peek() then
            for _, other in ipairs(bindingsbackup[cellname]:top()) do
                local otherparam = loadedcells[other.cell].parameters[other.name]
                otherparam.func = other.func
            end
            bindingsbackup[cellname]:pop()
        end
    end
end

--------------------------------------------------------------------
function add_parameter(cellname, name, value, opt)
    opt = opt or {}
    _add_parameter(cellname, name, value, opt.argtype, opt.posvals, opt.follow)
end

function add_parameters(cellname, ...)
    for _, parameter in ipairs({ ... }) do
        local name, value = parameter[1], parameter[2]
        _add_parameter(
            cellname,
            name, value,
            parameter.argtype, parameter.posvals, parameter.follow
        )
    end
end

function inherit_parameter(cellname, othercell, name)
    local param = loadedcells[othercell].parameters[name]
    if param.display then
        name = string.format("%s(%s)", name, param.display)
    end
    _add_parameter(cellname, name, param.func(), param.argtype, param.posvals)
end

function inherit_parameter_as(cellname, name, othercell, othername)
    local param = loadedcells[othercell].parameters[othername]
    _add_parameter(cellname, name, param.func(), param.argtype, param.posvals)
end

function bind_parameter(cellname, name, othercell, othername)
    local param = loadedcells[cellname].parameters[name]
    if not param then
        error(string.format("trying to bind '%s.%s' to '%s.%s', which is unknown", othercell, othername, cellname, name))
    end
    if not bindings[cellname] then bindings[cellname] = {} end
    bindings[cellname][name] = { cell = othercell, name = othername }
end

function inherit_all_parameters(cellname, othercell)
    local inherited = loadedcells[othercell]
    local parameters = {}
    for k in pairs(inherited.parameters) do
        parameters[inherited.indices[k]] = k
    end
    for _, name in ipairs(parameters) do
        inherit_parameter(cellname, othercell, name)
    end
end

function inherit_and_bind_parameter(cellname, othercell, name)
    inherit_parameter(cellname, othercell, name)
    bind_parameter(cellname, name, othercell, name)
end

function inherit_and_bind_parameter_as(cellname, name, othercell, othername)
    inherit_parameter_as(cellname, name, othercell, othername)
    bind_parameter(cellname, name, othercell, othername)
end

function inherit_and_bind_all_parameters(cellname, othercell)
    local inherited = loadedcells[othercell]
    local parameters = {}
    for k in pairs(inherited.parameters) do
        parameters[inherited.indices[k]] = k
    end
    for _, name in ipairs(parameters) do
        inherit_and_bind_parameter(cellname, othercell, name)
    end
end

local backupstacks = {}
function push_overwrites(cellname, cellargs)
    assert(type(cellname) == "string", "push_overwrites: cellname must be a string")
    local backup = _process_input_parameters(cellname, cellargs, false, true)
    if not backupstacks[cellname] then
        backupstacks[cellname] = stack.create()
    end
    backupstacks[cellname]:push(backup)
end

function pop_overwrites(cellname)
    if (not backupstacks[cellname]) or (not backupstacks[cellname]:peek()) then
        error(string.format("trying to restore default parameters for '%s', but there where no previous overwrites", cellname))
    end
    _restore_parameters(cellname, backupstacks[cellname]:top())
    backupstacks[cellname]:pop()
end

function empty_overwrite_stack(cellname)
    -- restore all cell defaults
    if backupstacks[cellname] then
        while backupstacks[cellname]:peek() do
            _restore_parameters(cellname, backupstacks[cellname]:top())
            backupstacks[cellname]:pop()
        end
    end
end

function clone_parameters(P)
    assert(P, "pcell.clone_parameters: no parameters given")
    local new = {}
    for k, v in pairs(P) do
        new[k] = v
    end
    return new
end

function clone_matching_parameters(cellname, P)
    local cell = loadedcells[cellname]
    local new = {}
    for k, v in pairs(P) do
        if cell.parameters[k] then
            new[k] = v
        end
    end
    return new
end
--------------------------------------------------------------------

function M.create_layout(cellname, args, evaluate)
    local cell = loadedcells[cellname]
    if not cell.funcs.layout then
        error(string.format("cell '%s' has no layout definition", cellname))
    end
    local obj = object.create()
    local parameters, backup = _get_parameters(cellname, args, evaluate)
    _restore_parameters(cellname, backup)
    _install_bindings(cellname)
    local status, msg = pcall(cell.funcs.layout, obj, parameters)
    _remove_bindings(cellname)
    if not status then
        error(string.format("could not create cell '%s': %s", cellname, msg))
    end
    return obj
end

function M.parameters(name)
    local cell = loadedcells[name]
    local str = {}
    for k, v in pairs(cell.parameters) do
        local val = v.func()
        if type(val) == "table" then
            val = table.concat(val, ",")
        else
            val = tostring(val)
        end
        str[cell.indices[k]] = string.format("%s:%s:%s:%s", k, v.display or "_NONE_", val, tostring(v.argtype))
    end
    return str
end

return M
