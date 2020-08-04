return function(args)
    pcell.clear()
    -- momcap settings
    local fingers    = pcell.process_args(args, "fingers", "number", 4)
    local fwidth     = pcell.process_args(args, "fwidth", "number", 0.1)
    local fspace     = pcell.process_args(args, "fspace", "number", 0.1)
    local fheight    = pcell.process_args(args, "fheight", "number", 1)
    local foffset    = pcell.process_args(args, "foffset", "number", 0.1)
    local rwidth     = pcell.process_args(args, "rwidth", "number", 0.1)
    local firstmetal = pcell.process_args(args, "firstmetal", "number", 1)
    local lastmetal  = pcell.process_args(args, "lastmetal", "number", 2)
    pcell.check_args(args)

    -- derived settings
    local pitch = fwidth + fspace

    local momcap = object.create()

    for i = firstmetal, lastmetal do
        momcap:merge_into(layout.multiple(
            layout.rectangle(string.format("M%d", i), "drawing", fwidth, fheight),
            fingers + 1, 1, 2 * pitch, 0
        ):translate(0, foffset))
        momcap:merge_into(layout.multiple(
            layout.rectangle(string.format("M%d", i), "drawing", fwidth, fheight),
            fingers, 1, 2 * pitch, 0
        ):translate(0, -foffset))
        -- rails
        momcap:merge_into(layout.multiple(
            layout.rectangle(string.format("M%d", i), "drawing", (2 * fingers + 1) * (fwidth + fspace), rwidth),
            1, 2, 0, 2 * foffset + fheight + rwidth
        ))
    end
    momcap:merge_into(layout.multiple(
        layout.via(string.format("M%d->M%d", firstmetal, lastmetal), (2 * fingers + 1) * (fwidth + fspace), rwidth, true),
        1, 2, 0, 2 * foffset + fheight + rwidth
    ))

    return momcap
end
