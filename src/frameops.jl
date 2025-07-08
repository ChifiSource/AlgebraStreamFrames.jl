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
        allvals = filter!(x -> is_emptystr(x), 
                readlines(curr_path))
        push!(rendered_cols, allvals[2:end])
    end
    if length(rendered_cols) > 1
        return(hcat(renderd_cols ...))
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

function setindex!(sf::StreamFrame, val::Any, col::String, r::Any)

end

function setindex!(sf::StreamFrame, val::Any, col::Int64, r::Any)

end

function setindex!(sf::StreamFrame, val::Any, col::Int64, r::UnitRange{Int64})
    if length(r) > 1

    end
end
