function parameters()
    pcell.add_parameters(
        { "fingers",       1 },
        { "gatetype", "nand" }
    )
end

function layout(gate, _P)
    local bp = pcell.get_parameters("logic/_base")
    local xpitch = bp.gspace + bp.glength
    local block = object.create()

    gate:merge_into(pcell.create_layout("logic/_harness", { fingers = 2 * _P.fingers }))

    -- common transistor options
    pcell.push_overwrites("basic/transistor", {
        fingers = 2,
        gatelength = bp.glength,
        gatespace = bp.gspace,
        sdwidth = bp.sdwidth,
        drawinnersourcedrain = false,
        drawoutersourcedrain = false,
    })

    -- pmos
    pcell.push_overwrites("basic/transistor", {
        channeltype = "pmos",
        fwidth = bp.pwidth,
        gtopext = bp.powerspace + bp.dummycontheight / 2 + bp.powerwidth / 2,
        gbotext = bp.separation / 2,
        clipbot = true,
    })
    block:merge_into(pcell.create_layout("basic/transistor"):move_anchor("botgate"))
    pcell.pop_overwrites("basic/transistor")

    -- nmos
    pcell.push_overwrites("basic/transistor", {
        channeltype = "nmos",
        fwidth = bp.nwidth,
        gbotext = bp.powerspace + bp.dummycontheight / 2 + bp.powerwidth / 2,
        gtopext = bp.separation / 2,
        cliptop = true,
    })
    block:merge_into(pcell.create_layout("basic/transistor"):move_anchor("topgate"))
    pcell.pop_overwrites("basic/transistor")

    -- gate contacts
    block:merge_into(geometry.rectangle(
        generics.contact("gate"), bp.glength, bp.gstwidth
    ):translate(xpitch / 2, bp.separation / 4))
    block:merge_into(geometry.rectangle(
        generics.contact("gate"), bp.glength, bp.gstwidth
    ):translate(-xpitch / 2, -bp.separation / 4))
    local num = 2 * _P.fingers - 1 - math.abs(_P.fingers % 2 - 1)
    local num2 = 2 * _P.fingers - 1 + math.abs(_P.fingers % 2 - 1)
    gate:merge_into(geometry.rectangle(
        generics.metal(1), num * bp.glength + (num - 1) * bp.gspace, bp.gstwidth
    ):translate(-(_P.fingers % 2) * xpitch / 2, -bp.separation / 4))
    gate:merge_into(geometry.rectangle(
        generics.metal(1), num2 * bp.glength + (num2 - 1) * bp.gspace, bp.gstwidth
    ):translate((_P.fingers % 2) * xpitch / 2, bp.separation / 4))

    -- TODO: improve structure by re-using statements
    -- pmos source/drain contacts
    if _P.gatetype == "nand" then
        block:merge_into(geometry.rectangle( -- drain contact
            generics.contact("active"), bp.sdwidth, bp.pwidth / 2
        ):translate(0, (bp.separation + bp.pwidth / 2) / 2))
        block:merge_into(geometry.multiple(  -- source contact
            geometry.rectangle(generics.contact("active"), bp.sdwidth, bp.pwidth / 2),
            2, 1, 2 * xpitch, 0
        ):translate(0, bp.separation / 2 + bp.pwidth * 3 / 4))
        block:merge_into(geometry.multiple( -- source to power connection
            geometry.rectangle(generics.metal(1), bp.sdwidth, bp.powerspace),
            2, 1, 2 * xpitch, 0
        ):translate(0, bp.separation / 2 + bp.pwidth + bp.powerspace / 2))
        -- nmos source/drain contacts
        block:merge_into(geometry.rectangle(
            generics.contact("active"), bp.sdwidth, bp.nwidth / 2
        ):translate(-xpitch, -(bp.separation + bp.nwidth / 2) / 2))
        block:merge_into(geometry.rectangle(
            generics.contact("active"), bp.sdwidth, bp.nwidth / 2
        ):translate(xpitch, -bp.separation / 2 - bp.nwidth * 3 / 4))
        block:merge_into(geometry.rectangle(
            generics.metal(1), bp.sdwidth, bp.powerspace
        ):translate(xpitch, -bp.separation / 2 - bp.nwidth - bp.powerspace / 2))
    else -- nor
        -- pmos source/drain contacts
        block:merge_into(geometry.rectangle(
            generics.contact("active"), bp.sdwidth, bp.pwidth / 2
        ):translate(-xpitch, (bp.separation + bp.pwidth / 2) / 2))
        block:merge_into(geometry.rectangle(
            generics.contact("active"), bp.sdwidth, bp.pwidth / 2
        ):translate(xpitch, bp.separation / 2 + bp.pwidth * 3 / 4))
        block:merge_into(geometry.rectangle(
            generics.metal(1), bp.sdwidth, bp.powerspace
        ):translate(xpitch, bp.separation / 2 + bp.pwidth - bp.powerspace / 2))
        -- nmos source/drain contacts
        block:merge_into(geometry.rectangle(
            generics.contact("active"), bp.sdwidth, bp.nwidth / 2
        ):translate(0, -(bp.separation + bp.nwidth / 2) / 2))
        block:merge_into(geometry.multiple(
            geometry.rectangle(generics.contact("active"), bp.sdwidth, bp.nwidth / 2),
            2, 1, 2 * xpitch, 0
        ):translate(0, -bp.separation / 2 - bp.nwidth * 3 / 4))
        block:merge_into(geometry.multiple(
            geometry.rectangle(generics.metal(1), bp.sdwidth, bp.powerspace),
            2, 1, 2 * xpitch, 0
        ):translate(0, -bp.separation / 2 - bp.nwidth - bp.powerspace / 2))
    end

    -- place block
    for i = 1, _P.fingers do
        local shift = 2 * (i - 1) - (_P.fingers - 1)
        if i % 2 == 0 then
            gate:merge_into(block:copy():flipx():translate(-shift * xpitch, 0))
        else
            gate:merge_into(block:copy():translate(-shift * xpitch, 0))
        end
    end
    
    -- drain connection
    local xincr = bp.compact and 0 or 1
    local yinvert = _P.gatetype == "nand" and 1 or -1
    local poffset = _P.fingers % 2 == 0 and (_P.fingers - 2) or _P.fingers
    gate:merge_into(geometry.path(
        generics.metal(1),
        {
            point.create(-_P.fingers * xpitch + xpitch,   yinvert * (bp.separation + bp.sdwidth) / 2),
            point.create( (_P.fingers + xincr) * xpitch,  yinvert * (bp.separation + bp.sdwidth) / 2),
            point.create( (_P.fingers + xincr) * xpitch, -yinvert * (bp.separation + bp.sdwidth) / 2),
            point.create(   -poffset * xpitch,           -yinvert * (bp.separation + bp.sdwidth) / 2),
        },
        bp.sdwidth,
        true
    ))

    pcell.pop_overwrites("basic/transistor")
end
