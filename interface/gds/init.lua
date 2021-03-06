local M = {}

function M.get_extension()
    return "gds"
end

local baseunit = 1

local recordtypes = {
    HEADER       = 0x00,
    BGNLIB       = 0x01,
    LIBNAME      = 0x02,
    UNITS        = 0x03,
    ENDLIB       = 0x04,
    BGNSTR       = 0x05,
    STRNAME      = 0x06,
    ENDSTR       = 0x07,
    BOUNDARY     = 0x08,
    PATH         = 0x09,
    SREF         = 0x0a,
    AREF         = 0x0b,
    TEXT         = 0x0c,
    LAYER        = 0x0d,
    DATATYPE     = 0x0e,
    WIDTH        = 0x0f,
    XY           = 0x10,
    ENDEL        = 0x11,
    SNAME        = 0x12,
    COLROW       = 0x13,
    TEXTNODE     = 0x14,
    NODE         = 0x15,
    TEXTTYPE     = 0x16,
    PRESENTATION = 0x17,
    SPACING      = 0x18,
    STRING       = 0x19,
    STRANS       = 0x1a,
    MAG          = 0x1b,
    ANGLE        = 0x1c,
    UINTEGER     = 0x1d,
    USTRING      = 0x1e,
    REFLIBS      = 0x1f,
    FONTS        = 0x20,
    PATHTYPE     = 0x21,
    GENERATIONS  = 0x22,
    ATTRTABLE    = 0x23,
    STYPTABLE    = 0x24,
    STRTYPE      = 0x25,
    ELFLAGS      = 0x26,
}

local datatypes = {
    NONE                = 0x00,
    BIT_ARRAY           = 0x01,
    TWO_BYTE_INTEGER    = 0x02,
    FOUR_BYTE_INTEGER   = 0x03,
    FOUR_BYTE_REAL      = 0x04,
    EIGHT_BYTE_REAL     = 0x05,
    ASCII_STRING        = 0x06,
}

-- helper functions
--[[ not used right now
local function _gdsfloat_to_number(data, width)
    local sign      = data[1] & 0x80
    local exp       = data[1] & 0x7f - 64
    local mantissa  = 0
    for m = 2, width do
        mantissa = mantissa + data[m] * (256 ^ (1 - m))
    end
    local num = mantissa * 16^exp
    if sign > 0 then
        return -num
    else
        return num
    end
end
--]]

local function _number_to_gdsfloat(num, width)
    local data = {}
    if num == 0 then
        for i = 1, width do
            data[i] = 0x00
        end
        return data
    end
    local sign = num < 0
    local exp = 0
    while num >= 1 do
        num = num / 16
        exp = exp + 1
    end
    while num < 0.0625 do
        num = num * 16
        exp = exp - 1
    end
    if sign then
        data[1] = 0x80 + ((exp + 64) & 0x7f)
    else
        data[1] = 0x00 + ((exp + 64) & 0x7f)
    end
    for i = 2, width do
        local int, frac = math.modf(num * 256)
        num = frac
        data[i] = int
    end
    return data
end

local function _split_in_bytes(number, bytes)
    local bits = 8
    local t = {}
    local num = number
    for i = bytes, 1, -1 do
        local byte = math.floor(num / 2^(bits * (i - 1)))
        num = num - byte * 2^(bits * (i - 1))
        table.insert(t, byte)
    end
    if number < 0 then -- compensate for two's complement
        t[1] = t[1] + 256
    end
    return t
end

local datatable = {
    [0x00] = nil,
    [0x01] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(_split_in_bytes(num, 2)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [0x02] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(_split_in_bytes(num, 2)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [0x03] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(_split_in_bytes(num, 4)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [0x04] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in _number_to_gdsfloat(num, 4) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [0x05] = function(nums)
        local data = {}
        for _, num in ipairs(nums) do
            for _, b in ipairs(_number_to_gdsfloat(num, 8)) do
                table.insert(data, b)
            end
        end
        return data
    end,
    [0x06] = function(str) return { string.byte(str, 1, #str) } end,
}

local function _assemble(...)
    local args = { ... }
    local t = {}
    for _, data in ipairs(args) do
        for _, datum in ipairs(data) do
            table.insert(t, string.char(datum))
        end
    end
    return table.concat(t)
end

local function _write_record(file, recordtype, datatype, content)
    local data = {
        0x00, 0x00, -- dummy bytes for length, will be filled later
        recordtype, datatype
    }
    local func = datatable[datatype]
    if func then
        for _, b in ipairs(func(content)) do
            table.insert(data, b)
        end
    end
    -- pad with final zero if #data is odd
    if #data % 2 ~= 0 then
        table.insert(data, 0x00)
    end
    local lenbytes = _split_in_bytes(#data, 2)
    data[1], data[2] = lenbytes[1], lenbytes[2]
    file:write(_assemble(data))
end

local function _unpack_points(pts, multiplier)
    local stream = {}
    for _, pt in ipairs(pts) do
        local x, y = pt:unwrap(multiplier)
        table.insert(stream, math.floor(x))
        table.insert(stream, math.floor(y))
    end
    return stream
end

function M.get_layer(shape)
    return { layer = shape.lpp:get().layer, purpose = shape.lpp:get().purpose }
end

function M.get_points(shape)
    local s = shape:convert_to_polygon()
    local points = _unpack_points(s.points, baseunit)
    return points
end

function M.at_begin(file)
    _write_record(file, recordtypes.HEADER, datatypes.TWO_BYTE_INTEGER, { 5 })
    _write_record(file, recordtypes.BGNLIB, datatypes.TWO_BYTE_INTEGER, { 2020, 7, 5, 18, 17, 51, 2020, 7, 5, 18, 17, 51 })
    _write_record(file, recordtypes.LIBNAME, datatypes.ASCII_STRING, "testlib")
    _write_record(file, recordtypes.UNITS, datatypes.EIGHT_BYTE_REAL, { 1 / baseunit, 1e-9 })
end

function M.at_end(file)
    _write_record(file, recordtypes.ENDLIB, datatypes.NONE)
end

function M.at_begin_cell(file)
    _write_record(file, recordtypes.BGNSTR, datatypes.TWO_BYTE_INTEGER, { 2020, 7, 5, 18, 17, 51, 2020, 7, 5, 18, 17, 51 })
    _write_record(file, recordtypes.STRNAME, datatypes.ASCII_STRING, "toplevelcell")
end

function M.at_end_cell(file)
    _write_record(file, recordtypes.ENDSTR, datatypes.NONE)
end

function M.write_layer(file, layer, pcol)
    for _, pts in ipairs(pcol) do
        _write_record(file, recordtypes.BOUNDARY, datatypes.NONE)
        _write_record(file, recordtypes.LAYER, datatypes.TWO_BYTE_INTEGER, { layer.layer })
        _write_record(file, recordtypes.DATATYPE, datatypes.TWO_BYTE_INTEGER, { layer.purpose})
        _write_record(file, recordtypes.XY, datatypes.FOUR_BYTE_INTEGER, pts)
        _write_record(file, recordtypes.ENDEL, datatypes.NONE)
    end
end

return M
