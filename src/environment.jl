abstract type AbstractCompiler end

struct Namespace
    counts
end
Namespace() = Namespace(Dict())
function freshen(spc::Namespace, tags...)
    name = Symbol(tags...)
    m = match(r"^(.*)_(\d*)$", string(name))
    if m === nothing
        tag = name
        n = 1
    else
        tag = Symbol(m.captures[1])
        n = parse(BigInt, m.captures[2])
    end
    n = max(get(spc.counts, tag, 0) + 1, n)
    spc.counts[tag] = n
    if n == 1
        return Symbol(tag)
    else
        return Symbol(tag, :_, n)
    end
end

@kwdef mutable struct JuliaContext <: AbstractCompiler
    namespace::Namespace = Namespace()
    preamble::Vector{Any} = []
    epilogue::Vector{Any} = []
    task = VirtualSerial()
end

"""
    virtualize(ctx, ex, T, [tag])

Return the virtual program corresponding to the Julia expression `ex` of type
`T` in the `JuliaContext` `ctx`. Implementaters may support the optional `tag`
argument is used to name the resulting virtual variable.
"""
virtualize(ctx, ex, T, tag) = virtualize(ctx, ex, T)
function virtualize(ctx, ex, T::Type{NamedTuple{names, args}}) where {names, args}
    Dict(map(zip(names, args.parameters)) do (name, arg)
        name => virtualize(ctx, :($ex.$(QuoteNode(name))), arg, name)
    end...)
end

freshen(ctx::JuliaContext, tags...) = freshen(ctx.namespace, tags...)

contain_epilogue_helper(node, epilogue) = node
function contain_epilogue_helper(node::Expr, epilogue)
    if @capture node :for(~ext, ~body)
        return node
    elseif @capture node :while(~ext, ~body)
        return node
    elseif @capture node :break()
        return Expr(:block, epilogue, node)
    else
        return Expr(node.head, map(x -> contain_epilogue_helper(x, epilogue), node.args)...)
    end
end

"""
    contain(f, ctx)

Call f on a subcontext of `ctx` and return the result. Variable bindings,
preambles, and epilogues defined in the subcontext will not escape the call to
contain.
"""
function contain(f, ctx::AbstractCompiler; task=nothing)
    ctx_2 = shallowcopy(ctx)
    ctx_2.task = something(task, ctx.task)
    preamble = Expr(:block)
    ctx_2.preamble = preamble.args
    epilogue = Expr(:block)
    ctx_2.epilogue = epilogue.args
    body = f(ctx_2)
    if epilogue == Expr(:block)
        return quote
            $preamble
            $body
        end
    else
        res = freshen(ctx_2, :res)
        return quote
            $preamble
            $res = $(contain_epilogue_helper(body, epilogue))
            $epilogue
            $res
        end
    end
end
