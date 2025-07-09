function join!(sf::StreamFrame, namepath::Pair{String, String})
    lns = countlines(namepath[2])
    if ~(length(lns) == length(sf))
        throw(DimensionMismatch())
    end
    push!(sf.paths, namepath)
    push!(sf.names, namepath[1])
    gen = e::Int64 -> begin 
        readlines(namepath[2])[e + 1]
    end
    push!(sf.gen, gen)
    T = get_datatype(StreamDataType{Symbol(readlines(namepath[2])[1])})
    push!(sf.T, T)
end

function join!(sf::StreamFrame, T::Type{<:Any}, namepath::Pair{String, String})
    lns = countlines(namepath[2])
    if ~(lns - 1 == length(sf))
        throw(DimensionMismatch("$lns, length of file, does not equal $(length(sf))"))
    end
    this_p = namepath[2]
    lines = filter!(x -> is_emptystr(x), 
            readlines(this_p))
    n = length(lines) - 1
    gen = if T == String
        e::Int64 -> begin
                lines = filter!(x -> is_emptystr(x), 
                    readlines(this_p))
            lines[e + 1]
        end
    else
        e::Int64 -> begin
            lines = filter!(x -> is_emptystr(x), 
                    readlines(this_p))
            parse(T, lines[e + 1])
        end
    end
    push!(sf.gen, gen)
    push!(sf.paths, namepath)
    push!(sf.names, namepath[1])
    push!(sf.T, T)
end

function deleteat!(sf::StreamFrame, r::UnitRange{Int64})
    pathkeys = keys(sf.paths)
    for col in sf.names
        if ~(col in pathkeys)
            continue
        end
        curr_path::String = sf.paths[col]
        allvals = filter!(x -> is_emptystr(x), 
                    readlines(curr_path))
        T, allvals = (allvals[1], allvals[2:end])
        deleteat!(allvals, r)
        open(curr_path, "w") do o::IOStream
            write(o, join((T, allvals ...), "\n"))
        end
    end
    sf.length -= length(r)
    nothing::Nothing
end

function deleteat!(sf::StreamFrame, r::Int64 ...)
    pathkeys = keys(sf.paths)
    for col in sf.names
        if ~(col in pathkeys)
            continue
        end
        curr_path::String = sf.paths[col]
        allvals = filter!(x -> is_emptystr(x), 
                    readlines(curr_path))
        T, allvals = (allvals[1], allvals[2:end])
        for val in sort(dels, lt=(>))
            deleteat!(allvals, val)
        end
        open(curr_path, "w") do o::IOStream
            write(o, join((T, allvals ...), "\n"))
        end
    end
    sf.length -= length(r)
    nothing::Nothing
end


deleteat!(sf::StreamFrame, r::Int64) = deleteat!(sf, r:r)

function drop!(af::StreamFrame, axis::Int64; delete::Bool = false)
    colname = af.names[axis]
    if colname in keys(af.paths) && delete
        rm(af.paths[colname])
    end
    deleteat!(af.names, axis)
    deleteat!(af.T, axis)
    deleteat!(af.gen, axis)
    af::StreamFrame
end

function getindex(sf::StreamFrame, cols::UnitRange{Int64} = 1:length(sf.names), rows::UnitRange{Int64} = 1:length(sf))
    path_keys = keys(sf.paths)
    rendered_cols = []
    for cole in cols
        colname = sf.names[cole]
        if ~(colname in path_keys)
            f = sf.gen[cole]
            push!(rendered_cols, [f(row) for row in rows])
            continue
        end
        curr_path = sf.paths[colname]
        T = sf.T[cole]
        is_str = T <: AbstractString
        allvals = [begin 
            if is_str
                line
            else
                parse(T, line)
            end
        end for line in filter!(x -> is_emptystr(x), readlines(curr_path)[2:end])]
        push!(rendered_cols, allvals)
    end
    if length(rendered_cols) > 1
        return(hcat(rendered_cols ...))
    else
        return(rendered_cols[1])
    end
end

function getindex(sf::StreamFrame, col::Int64, r::UnitRange{Int64} = 1:length(sf))
    getindex(sf, col:col, r)
end

function getindex(sf::StreamFrame, col::String, r::UnitRange{Int64} = 1:length(sf))
    axis = findfirst(x -> x == col, sf.names)
    if isnothing(axis)
        throw("column $col not found")
    end
    getindex(sf, axis, r)
end

function setindex!(sf::StreamFrame, val::Any, col::Any, r::UnitRange{Int64})::Nothing
    col = get_axis(sf, col)
    curr_path = sf.paths[col]
    allvals = filter!(x -> is_emptystr(x), 
                readlines(curr_path))
    T, allvals = (allvals[1], allvals[2:end])
    if typeof(val) <: AbstractVector
        for (e, x) in enumerate(r)
            allvals[x] = val[e]
        end
    else
        for x in r
            allvals[x] = val
        end
    end
    open(curr_path, "w") do o::IOStream
        write(o, join((T, allvals ...), "\n"))
    end
    return
end

setindex!(sf::StreamFrame, val::Any, col::Any, r::Int64) = setindex!(sf, val, col, r:r)


generate(sf::StreamFrame) = begin
    cols = getindex(sf)
    frame = AlgebraFrames.Frame(sf.names, sf.T, [eachcol(cols) ...])
    cols = nothing
    return(frame)::Frame
end

eachrow(sf::StreamFrame) = begin
    cols = getindex(sf)
    eachrow(cols)
end

framerows(sf::StreamFrame) = begin
    framerows(generate(sf))
end

function filter(f::Function, sf::StreamFrame)
    rows = framerows(sf)
    dels = Vector{Int64}()
    for (e, row) in enumerate(rows)
        confirm_filt = f(row)
        if ~(confirm_filt)
            continue
        end
        push!(dels, e)
    end
    for del in dels
        deleteat!(rows, del)
    end
    Frame(rows ...)::Frame
end

function filter!(f::Function, sf::StreamFrame)
    rows = framerows(sf)
    dels = Vector{Int64}()
    for (e, row) in enumerate(rows)
        confirm_filt = f(row)
        if ~(confirm_filt)
            continue
        end
        push!(dels, e)
    end
    sf.length -= length(dels)
    deleteat!(sf, dels ...)
    nothing::Nothing
end