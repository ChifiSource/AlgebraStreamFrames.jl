module AlgebraStreams
using AlgebraFrames

SUPPORTED_FILES = [:ff, :csv, :json]

function infer_type(fp::String)
    if fp == ""
        return(String)
    end
    try
        parse(Int, fp); return Int
    catch
        try
            parse(Float64, fp); return Float64
        catch
            try
                parse(Bool, fp); return Bool
            catch
                return String
            end
        end
    end
end

mutable struct StreamFrame{T <: Any} <: AlgebraFrames.AbstractAlgebraFrame
	paths::Dict{String, String}  # Mapping column names to file paths
	n::Int64                     # Number of rows (determined from files)
	names::Vector{String}         # Column names
	types::Vector{Type}           # Data types for each column
	algebra::Vector{Algebra{<:Any, 1}}
    function StreamFrame{T}(n::Int64, info::Dict{String, String}, names::Vector{String}, types::Vector{Type}, algebra::Vector{Algebra{<:Any, 1}})
        new{T}(info, n, names, types, algebra)
    end
end

function StreamFrame(named_paths::Pair{String, String} ...)
    paths = Dict(named_paths...)
    names = collect(keys(paths))
    first_file = first(values(paths))
    if ~(isfile(first_file))
        touch(first_file)
    end
    n = countlines(first_file)  # Assume all files have same row count
    @info n
    if n == 0
        return(new{Symbol(:feature_file)}(paths, n, names, Vector{Symbol}(), Vector{Algebra{<:Any, 1}}()))
    end
    types = [begin
        if ~(isfile(fp))
            touch(fp)
        end
        @info fp
        infer_type(readlines(fp)[1])
    end for fp in values(paths)]  # Infer types
    @info types
    alg = [begin
            T = types[enum]
            if T == String
                algebra(types[enum], n) do e::Int64
                    readlines(paths[names[enum]])[e]
                end
            else
                algebra(types[enum], n) do e::Int64
                    parse(T, readlines(paths[names[enum]])[e])
                end
            end
        end for enum in 1:length(names)]
    @info alg
    StreamFrame{Symbol(:feature_file)}(n, paths, names, types, alg)  # Default type
end

function StreamFrame(path::String, T::Symbol = :ff)
    if T == :csv
        data = read_csv(path)
    elseif T == :json
        data = read_json(path)
    else
        error("Unsupported file type: $T")
    end

    names = keys(data)
    n = length(data[names[1]])  # Assume all columns have same length
    types = [eltype(col) for col in values(data)]

    paths = Dict(name => path for name in names)  # Single-file storage
    StreamFrame{T}(n, paths names, types, [])
end

end # module AlgebraStreamFrames
