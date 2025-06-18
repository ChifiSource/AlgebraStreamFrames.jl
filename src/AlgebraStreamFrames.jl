module AlgebraStreams
using AlgebraFrames
using AlgebraFrames: Transform

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
	paths::Dict{String, String} 
	length::Int64
    T::Vector{Type}           
	names::Vector{String}
    gen::Vector{Function}     
	         
	transformations::Vector{Transform}
    function StreamFrame{T}(n::Int64, info::Dict{String, String}, names::Vector{String}, 
        gen::Vector{Function}, types::Vector{Type}, transforms::Vector{AlgebraFrames.Transform} = 
        Vector{Transform}())
        new{T}(info, n, names, types, transforms)
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
    if n == 0
        return(StreamFrame{Symbol(:feature_file)}(paths,
            n, names, Vector{Symbol}(), Vector{Algebra{<:Any, 1}}()))
    end
    types = [begin
        if ~(isfile(fp))
            touch(fp)
        end
        @info fp
        infer_type(readlines(fp)[1])
    end for fp in values(paths)]  # Infer types
    gen::Vector{Function} = [begin 
        if T == String
            e::Int64 -> readlines(paths[names[enum]])[e]
        else
            e::Int64 -> parse(T, readlines(paths[names[enum]])[e])
        end
    end for enum in 1:length(names)]
    StreamFrame{Symbol(:feature_file)}(n, paths, names, gen, types)  # Default type
end

function StreamFrame(path::String)
    if ~(contains(path, "."))
        # TODO
    end
    f_typespl = split(path, ".")[2:end]
    df = DataFileType{Symbol(f_typespl)}
    algebraic_read(df, path)
    names = keys(data)
    n = length(data[names[1]])  # Assume all columns have same length
    types = [eltype(col) for col in values(data)]

    paths = Dict(name => path for name in names)  # Single-file storage
    StreamFrame{T}(n, paths names, types)
end

struct DataFileType{T} end

function algebraic_read(T::Type{DataFileType{<:Any}}, path::String)

end

function algebraic_read(T::Type{DataFileType{:json}}, path::String)

end

function algebraic_read(T::Type{DataFileType{:csv}}, path::String)
    StreamFrame{:csv}()
end


end # module AlgebraStreamFrames
