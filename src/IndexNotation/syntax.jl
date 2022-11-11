#TODO use MacroTools?

const incs = Dict(:+= => :+, :*= => :*, :&= => :&, :|= => :|)

const program_nodes = (
    pass = pass,
    loop = loop,
    chunk = chunk,
    with = with,
    sieve = sieve,
    multi = multi,
    assign = assign,
    call = call,
    access = access,
    protocol = protocol,
    reader = reader,
    writer = writer,
    updater = updater,
    name = name,
    label = (ex) -> :($(esc(:dollar))(index_terminal($(esc(ex))))),
    literal = literal,
    value = (ex) -> :($(esc(:dollar))(index_terminal($(esc(ex))))),
)

const instance_nodes = (
    pass = pass_instance,
    loop = loop_instance,
    chunk = :(throw(NotImplementedError("TODO"))),
    with = with_instance,
    sieve = sieve_instance,
    multi = multi_instance,
    assign = assign_instance,
    call = call_instance,
    access = access_instance,
    protocol = protocol_instance,
    name = name_instance,
    reader = reader_instance,
    writer = writer_instance,
    updater = updater_instance,
    label = (ex) -> :($label_instance($(QuoteNode(ex)), $index_terminal_instance($(esc(ex))))),
    literal = literal_instance,
    value = (ex) -> :($index_terminal_instance($(esc(ex))))
)

and() = true
and(x) = x
and(x, y, tail...) = x && and(y, tail...)
or() = false
or(x) = x
or(x, y, tail...) = x || or(y, tail...)
right(l, m, r...) = right(m, r)
right(l, r) = r

function _finch_capture(ex, ctx)
    #extra sugar
    if ex isa Expr && ex.head == :macrocall && length(ex.args) >= 3 && ex.args[1] == Symbol("@∀")
        idxs = ex.args[3:end-1]; body = ex.args[end]
        return _finch_capture(:(@loop($(idxs...), $body)), ctx)
    elseif ex isa Expr && ex.head == :block
        bodies = filter(arg->!(arg isa LineNumberNode), ex.args)
        if length(bodies) == 1
            return _finch_capture(:($(bodies[1])), ctx)
        else
            return _finch_capture(:(@multi($(bodies...),)), ctx)
        end
    elseif ex isa Expr && haskey(incs, ex.head)
        (lhs, rhs) = ex.args; op = incs[ex.head]
        return _finch_capture(:($lhs << $op >>= $rhs), ctx)
    elseif ex isa Expr && ex.head == :comparison
        @assert length(ex.args) >= 3
        (a, cmp, b, tail...) = ex.args
        ex = :($cmp($a, $b))
        if isempty(tail)
            return _finch_capture(:($cmp($a, $b)), ctx)
        else
            return _finch_capture(:($cmp($a, $b) && $(Expr(:comparison, b, tail...))), ctx)
        end
    elseif ex isa Expr && ex.head == :&&
        (a, b) = ex.args
        return _finch_capture(:($and($a, $b)), ctx)
    elseif ex isa Expr && ex.head == :||
        (a, b) = ex.args
        return _finch_capture(:($or($a, $b)), ctx)
    end

    if @capture ex (@pass(args__))
        args = map(arg -> _finch_capture(arg, (ctx..., namify=false)), args)
        return :($(ctx.nodes.pass)($(args...)))
    elseif @capture ex (@sieve cond_ body_)
        cond = _finch_capture(cond, (ctx..., namify=true))
        body = _finch_capture(body, ctx)
        return :($(ctx.nodes.sieve)($cond, $body))
    elseif @capture ex (@loop idxs__ body_)
        preamble = Expr(:block)
        idxs = map(idxs) do idx
            if idx isa Symbol
                push!(preamble.args, :($(esc(idx)) = $(ctx.nodes.name(idx))))
                esc(idx)
            else
                _finch_capture(idx, ctx)
            end
        end
        body = _finch_capture(body, ctx)
        return quote
            let
                $preamble
                $(ctx.nodes.loop)($(idxs...), $body)
            end
        end
    elseif @capture ex (@chunk idx_ ext_ body_)
        preamble = Expr(:block)
        if idx isa Symbol
            push!(preamble.args, :($(esc(idx)) = $(ctx.nodes.name(idx))))
            esc(idx)
        else
            _finch_capture(idx, ctx)
        end
        ext = _finch_capture(idx, ctx)
        body = _finch_capture(body, ctx)
        return quote
            let
                $preamble
                $(ctx.nodes.chunk)($idx, $ext, $body)
            end
        end
    elseif @capture ex (@chunk idx_ ext_ body_)
        idx = _finch_capture(idx, ctx)
        ext = _finch_capture(ext, (ctx..., namify=false))
        body = _finch_capture(body, ctx)
        return :($(ctx.nodes.chunk)($idx, $ext, $body))
    elseif @capture ex (cons_ where prod_)
        cons = _finch_capture(cons, ctx)
        prod = _finch_capture(prod, (ctx..., results=Set()))
        return :($(ctx.nodes.with)($cons, $prod))
    elseif @capture ex (@multi bodies__)
        bodies = map(arg -> _finch_capture(arg, ctx), bodies)
        return :($(ctx.nodes.multi)($(bodies...)))
    elseif @capture ex (tns_[idxs__])
        tns = _finch_capture(tns, (ctx..., namify=false))
        idxs = map(idx->_finch_capture(idx, (ctx..., namify=true)), idxs)
        mode = :($(ctx.nodes.reader)())
        return :($(ctx.nodes.access)($tns, $mode, $(idxs...)))
    elseif @capture ex (tns_[idxs__] = rhs_)
        return _finch_capture(:($tns[$(idxs...)] << $right >>= $rhs), ctx)
    elseif @capture ex (!tns_[idxs__] = rhs_)
        return _finch_capture(:(!$tns[$(idxs...)] << $right >>= $rhs), ctx)
    elseif @capture ex (tns_[idxs__] <<op_>>= rhs_)
        tns isa Symbol && push!(ctx.results, tns)
        tns = _finch_capture(tns, (ctx..., namify=false))
        op = _finch_capture(op, (ctx..., namify = false))
        mode = :($(ctx.nodes.updater)($op, $(ctx.nodes.literal(false))))
        idxs = map(idx->_finch_capture(idx, ctx), idxs)
        rhs = _finch_capture(rhs, ctx)
        lhs = :($(ctx.nodes.access)($tns, $mode, $(idxs...)))
        return :($(ctx.nodes.assign)($lhs, $rhs))
    elseif @capture ex (!tns_[idxs__] <<op_>>= rhs_)
        tns isa Symbol && push!(ctx.results, tns)
        tns = _finch_capture(tns, (ctx..., namify=false))
        op = _finch_capture(op, (ctx..., namify = false))
        mode = :($(ctx.nodes.updater)($op, $(ctx.nodes.literal(true))))
        idxs = map(idx->_finch_capture(idx, ctx), idxs)
        rhs = _finch_capture(rhs, ctx)
        lhs = :($(ctx.nodes.access)($tns, $mode, $(idxs...)))
        return :($(ctx.nodes.assign)($lhs, $rhs))
    elseif @capture ex (op_(args__))
        op = _finch_capture(op, (ctx..., namify=false))
        args = map(arg->_finch_capture(arg, ctx), args)
        return :($(ctx.nodes.call)($op, $(args...)))
    elseif @capture ex (idx_::proto_)
        idx = _finch_capture(idx, ctx)
        return :($(ctx.nodes.protocol)($idx, $(esc(proto))))
    elseif ex isa Expr && ex.head == :...
        return esc(ex)
    elseif ex isa Expr && ex.head == :$ && length(ex.args) == 1
        return esc(ex.args[1])
    elseif ex isa Symbol
        return ctx.nodes.label(ex)
    elseif ex isa Expr
        return ctx.nodes.value(ex)
    elseif ex isa QuoteNode
        return ctx.nodes.literal(ex.value)
    else
        return ctx.nodes.literal(ex)
    end
end

capture_finch_program(ex; results=Set()) = _finch_capture(ex, (nodes=program_nodes, namify=true, results = results))
capture_finch_instance(ex; results=Set()) = _finch_capture(ex, (nodes=instance_nodes, namify=true, results = results))

macro finch_program(ex)
    return quote
        let $(esc(:dollar))=identity
            $(capture_finch_program(ex))
        end
    end
end

macro f(ex)
    return quote
        let $(esc(:dollar))=identity
            $(capture_finch_program(ex))
        end
    end
end

macro finch_program_instance(ex)
    return quote
        $(capture_finch_instance(ex))
    end
end