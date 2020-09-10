function parameters()
    pcell.add_parameters({ "transistors(Number of Transistors)", 2, "integer" })
    pcell.add_parameters({ "fingers(Number of Fingers)", { 4, 4 }, "table" })
    pcell.inherit_and_bind_all_parameters("single_transistor")
end

function layout(array, _P)
    local gatepitch = _P.gatelength + _P.gatespace
    local numtransistors = #_P.fingers
    local numfingers = aux.sum(_P.fingers)
    local gatestrspace = 0.2

    local ttypes = {}
    local indices = {}
    for i, f in ipairs(_P.fingers) do
        ttypes[i] = { 
            drawtopgate = true, 
            drawbotgate = true, 
            topgatestrspace = i * gatestrspace + (i - 1) * _P.topgatestrwidth,
            botgatestrspace = i * gatestrspace + (i - 1) * _P.botgatestrwidth,
            gtopext = numtransistors * (gatestrspace + _P.topgatestrwidth),
            gbotext = numtransistors * (gatestrspace + _P.botgatestrwidth),
        }
        for j = 1, f / 2 do
            table.insert(indices, i)
        end
    end
    aux.shuffle(indices)
    for i = 1, #indices do
        local offset = (i - 1) - 0.5 * (2 * #indices - 1)
        local ttype = ttypes[indices[i]]
        array:merge_into(
            celllib.create_layout("single_transistor", ttype)
            :translate( offset * gatepitch, 0)
        )
        array:merge_into(
            celllib.create_layout("single_transistor", ttype)
            :translate(-offset * gatepitch, 0)
        )
    end
    for i = 1, #ttypes do
        array:merge_into(geometry.rectangle(
            generics.metal(1), numfingers * gatepitch, _P.topgatestrwidth
            ):translate(0, 0.5 * (_P.fwidth + _P.topgatestrwidth) + i * gatestrspace + (i - 1) * _P.topgatestrwidth)
        )
        array:merge_into(geometry.rectangle(
            generics.metal(1), numfingers * gatepitch, _P.topgatestrwidth
            ):translate(0, -0.5 * (_P.fwidth + _P.botgatestrwidth) - i * gatestrspace - (i - 1) * _P.botgatestrwidth)
        )
    end
end