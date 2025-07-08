module AlgebraStreamFrames
using AlgebraFrames
using AlgebraFrames: Transform
import AlgebraFrames: join!, join, deleteat!, generate, drop!, framerows
import Base: getindex, setindex!, filter!, filter

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

struct StreamDataType{T} end

mutable struct StreamFrame{T <: Any} <: AlgebraFrames.AbstractAlgebraFrame
	paths::Dict{String, String} 
	length::Int64
    T::Vector{Type}           
	names::Vector{String}
    gen::Vector{Function}  
	transformations::Vector{Transform}
    offsets::Int64
    function StreamFrame{T}(n::Int64, info::Dict{String, String}, names::Vector{String}, 
        gen::Vector{Function}, types::Vector{<:Any}, transforms::Vector{AlgebraFrames.Transform} = 
        Vector{Transform}()) where {T}
        new{T}(info, n, Vector{Type}(types), names, gen, transforms, 0)
    end
end

function get_datatype(std::Type{StreamDataType{:Integer}})
    Int64
end

function get_datatype(std::Type{StreamDataType{:Float}})
    Float64
end

function get_datatype(std::Type{StreamDataType{:String}})
    String
end

function get_datatype(std::Type{StreamDataType{:Bool}})
    Bool
end

function StreamFrame(named_paths::Pair{String, String} ...)
    paths = Dict{String, String}(named_paths...)
    names = collect(keys(paths))
    first_file = first(values(paths))
    if ~(isfile(first_file))
        touch(first_file)
    end
    filts = filter!(x -> x != "" && x != "\n" && x != " ", readlines(first_file))
    n = length(filts) - 1
    types::Vector{Type} = Vector{Type}([begin
        if ~(isfile(fp))
            touch(fp)
        end
        data_type = StreamDataType{Symbol(readlines(fp)[1])}
        get_datatype(data_type)
    end for fp in values(paths)])  # Infer types
    gen::Vector{Function} = Vector{Function}([begin 
        T = types[enum]
        lines = filter!(x -> is_emptystr(x), 
            readlines(paths[names[enum]]))
        if T == String
            e::Int64 -> begin
                lines = filter!(x -> is_emptystr(x), 
                    readlines(paths[names[enum]]))
                lines[e + 1]
            end
        else
            e::Int64 -> begin
                lines = filter!(x -> is_emptystr(x), 
                    readlines(paths[names[enum]]))
                parse(T, lines[e + 1])
            end
        end
    end for enum in 1:length(names)])
    StreamFrame{:ff}(n, paths, names, gen, types, 
        Vector{Transform}())::StreamFrame{:ff}
end

function is_emptystr(str::AbstractString)
    found = findfirst(c::Char -> c != ' ' && c != '\n', str)
    ~(isnothing(found))
end

include("frameops.jl")

function StreamFrame{T}() where {T}
    StreamFrame{:ff}(0, Dict{String, String}(), 
        Vector{String}(), Vector{Function}(), Vector{Type}(), 
        Vector{Transform}())::StreamFrame{:ff}
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
    StreamFrame{T}(n, paths, names, types)
end

struct DataFileType{T} end

function algebraic_read(T::Type{DataFileType{<:Any}}, path::String)

end

function algebraic_read(T::Type{DataFileType{:json}}, path::String)

end

function algebraic_read(T::Type{DataFileType{:csv}}, path::String)
    StreamFrame{:csv}()
end

export StreamFrame, generate, algebra!, algebra, set_generator!, join!
end # module AlgebraStreamFrames
