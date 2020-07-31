using RBNF
using MLStyle
using PrettyPrint

struct QASMLang end
using Qaintessent

second((a, b)) = b
second(vec::V) where V <: AbstractArray = vec[2]



struct Struct_bin
    l
    op :: RBNF.Token
    r
end

RBNF.@parser QASMLang begin
    # define ignorances
    ignore{includes, space, comments}

    @grammar
    # define grammars
    mainprogram := ["OPENQASM", ver=real, ';', prog=program]
    program     = statement{*}
    statement   = (decl | gate | opaque | ifstmt | barrier | qop)
    # stmts
    ifstmt      := ["if", '(', l=id, "==", r=nninteger, ')', gate_name=id, ['(', [args=explist].?, ')'].?, outs=mixedlist, ';']
    opaque      := ["opaque", id=id, ['(', [arglist1=idlist].?, ')'].? , arglist2=idlist, ';']
    barrier     := ["barrier", value=mixedlist]
    decl        := [regtype=("qreg" | "creg"), id=id, '[', int=nninteger, ']', ';']

    # gate
    gate        := [decl=gatedecl, [goplist=goplist].?, '}']
    gatedecl    := ["gate", id=id, ['(', [args=idlist].?, ')'].?, (outs=idlist), '{']

    goplist     = (barrier_ids | uop){*}
    barrier_ids := ["barrier", ids=idlist, ';'] # not impl
    # qop
    qop         = (measure | reset | uop)
    reset       := ["reset", arg=argument, ';'] # not impl
    measure     := ["measure", arg1=argument, "->", arg2=argument, ';'] # not impl

    uop         = (u | cx | x | iduop)
    u          := ['U', '(', in1=exp, ',', in2=exp, ',', in3 = exp, ')', out=argument, ';']
    cx         := ["CX", out1=argument, ',', out2=argument, ';']
    x          := ['x',  out=argument, ';']
    iduop      := [gate_name=id, ['(', [args=explist].?, ')'].?, outs=mixedlist, ';']

    idlist     := [hd=id, [',', tl=idlist].?]

    mixedlist  := [hd=argument, [',', tl=mixedlist].?]

    argument   := [id=id, ['[', (arg=nninteger), ']'].?]

    explist    := [hd=exp, [',', tl=explist].?]
    pi         := "pi"
    atom       =  (real | nninteger | pi | id | fnexp) | (['(', exp, ')'] % second) | neg
    fnexp      := [fn=fn, '(', arg=exp, ')']
    neg        := ['-', value=exp]

    exp        = [l=mul,  [op=('+' |'-'), r=exp].?] => _.op === nothing ? _.l : Struct_bin(_.l, _.op, _.r)
    mul        = [l=atom, [op=('*' | '/'), r=mul].?] => _.op === nothing ? _.l : Struct_bin(_.l, _.op, _.r)
    fn         = ("sin" | "cos" | "tan" | "exp" | "ln" | "sqrt")

    # define tokens
    @token
    includes  := r"\Ginclude .*;"
    id        := r"\G[a-z]{1}[A-Za-z0-9_]*"
    real      := r"\G([0-9]+\.[0-9]*|[0-9]*\.[0.9]+)([eE][-+]?[0-9]+)?"
    nninteger := r"\G([1-9]+[0-9]*|0)"
    space     := r"\G\s+"
    comments  := r"\G//.*"
end


Token = RBNF.Token


function lex(src :: String)
    RBNF.runlexer(QASMLang, src)
end

function parse_qasm(tokens :: Vector{Token{A} where A})
    ast, ctx = RBNF.runparser(mainprogram, tokens)
    ast
end

@as_record Token
@as_record Struct_mainprogram
@as_record Struct_ifstmt
@as_record Struct_gate
@as_record Struct_gatedecl
@as_record Struct_decl
@as_record Struct_barrier_ids
@as_record Struct_reset
@as_record Struct_measure
@as_record Struct_iduop
@as_record Struct_u
@as_record Struct_cx
@as_record Struct_x
@as_record Struct_idlist
@as_record Struct_mixedlist
@as_record Struct_argument
@as_record Struct_explist
@as_record Struct_pi
@as_record Struct_fnexp
@as_record Struct_neg
@as_record Struct_bin


# src1 = """
# // Repetition code syndrome measurement
# OPENQASM 2.0;
# include "qelib1.inc";
# qreg q[3];
# qreg a[2];
# creg c[3];
# creg syn[2];
# gate syndrome d1,d2,d3,a1,a2
# {
#   cx d1,a1; cx d2,a1;
#   cx d2,a2; cx d3,a2;
# }
# x q[0];
# barrier q;
# syndrome q[0],q[1],q[2],a[0],a[1];
# measure a -> syn;
# if(syn==1) x q[0];
# if(syn==2) x q[2];
# if(syn==3) x q[1];
# measure q -> c;
# """

src1 = """
// Repetition code syndrome measurement
OPENQASM 2.0;
include "qelib1.inc";
qreg q[3];
qreg a[2];
creg c[3];
creg syn[2];
x q[2];
x q;
CX q, a[0];
barrier q;
if(syn==1) x q[0];
if(syn==2) x q[2];
if(syn==3) x q[1];
"""

function x(args, outs; ccntrl=nothing)
    if isnothing(ccntrl)
        return :(cgc([single_qubit_circuit_gate(($outs[1]), X, N)]))
    else
        return :(cgc([controlled_circuit_gate($ccntrl, ($outs[1]), X, N)]))
    end
end

function cx(args, outs; ccntrl=nothing)
    if isnothing(ccntrl)
        return :(cgc([single_qubit_circuit_gate(($outs[1]), X, N)]))
    else
        return :(cgc([controlled_circuit_gate($ccntrl, ($outs[1]), X, N)]))
    end

end

function u(args, out; ccntrl=nothing)
end

function rec(ctx_tokens)
    function app(op, args...)
        args = map(rec, args)
        op = Symbol(op)
        :($op($(args...)))
    end

    @match ctx_tokens begin
        Struct_pi(_) => Base.pi
        Token{:id}(str=str) => Symbol(str)
        Token{:real}(str=str) => parse(Float64, str)
        Token{:nninteger}(str=str) => parse(Int64, str)
        Struct_neg(value=value) => :(-$(rec(value)))
        Struct_bin(l=l, op=Token(str=op), r=r) => app(op, l, r)
        Struct_idlist(hd=Token(str=hd), tl=nothing) => [Symbol(hd)]
        Struct_idlist(hd=Token(str=hd), tl=tl) => [Symbol(hd), rec(tl)...]

        Struct_explist(hd=hd, tl=nothing) => [trans_reg(hd)]
        Struct_explist(hd=hd, tl=tl) => [rec(hd), rec(tl)...]

        Struct_mixedlist(hd=hd, tl=nothing) => [rec(hd)]
        Struct_mixedlist(hd=hd, tl=tl) => [rec(hd), rec(tl)...]

        Struct_argument(id=Token(str=id), arg=nothing) => Symbol(id)
        Struct_argument(id=Token(str=id), arg=Token(str=int)) =>
            let ind = parse(Int, int) + 1 # due to julia 1-based index
                :($(Symbol(id))[$ind])
            end
    end
end

function trans_reg(ctx_tokens)
    function app(op, args...)
        args = map(rec, args)
        op = Symbol(op)
        :($op($(args...)))
    end
    @match ctx_tokens begin
        Struct_decl(
            regtype = Token(str=regtype),
            id = Token(str=id),
            int = Token(str = n)
        ) =>
            let id = Symbol(id),
                n = parse(Int, n)
                if regtype == "qreg"
                    return :($id = qreg($n); push!(qregs, $id))
                else
                    return :($id = creg($n); push!(cregs, $id))
                end
            end

        Struct_mainprogram(
            prog = stmts
        ) =>
            let stmts = map(trans_reg, stmts)
                stmts
            end
        _ => nothing
    end
end

function trans_gates(ctx_tokens)
    function app(op, args...)
        args = map(rec, args)
        op = Symbol(op)
        :($op($(args...)))
    end
    @match ctx_tokens begin
        Struct_iduop(gate_name = Token(str=gate_name), args=nothing, outs=outs) =>
            let refs = rec(outs),
                gate_name = Symbol(gate_name)
                :($gate_name($args, $outs))
            end

        Struct_iduop(gate_name = Token(str=gate_name), args=exprlist, outs=outs) =>
            let refs = rec(outs),
                exprs = Expr(:tuple, rec(exprlist)...),
                gate_name = Symbol(gate_name)
                :($gate_name($exprs, $(refs...)))
            end

        Struct_cx(out1=out1, out2=out2) =>
            let ref1 = rec(out1),
                ref2 = rec(out2)
                :(cgc([controlled_circuit_gate(($ref1), ($ref2), X, N)]))
            end

        Struct_u(in1=in1, in2=in2, in3=in3, out=out) =>
            let (a, b, c) = map(rec, (in1, in2, in3)),
                ref = :($(rec(out))[1])
                :(cgc([single_qubit_circuit_gate(($ref), Rz($in1), N),
                   single_qubit_circuit_gate(($ref), Ry($in2), N),
                   single_qubit_circuit_gate(($ref), Rz($in2), N),]))
            end

        Struct_x(out=out) =>
            let ref = :($(rec(out)))
                :(cgc([single_qubit_circuit_gate(($ref), X, N)]))
            end

        Struct_ifstmt(l=Token(str=l), r=r, gate_name=id, args=explist, outs=mixedlist =>
            let l = Symbol(l),
                r = rec(r),
                body = rec(body)
                :(cgc([controlled_circuit_gate(($ref), , N)]))
            end

        Struct_mainprogram(
            prog = stmts
        ) =>
            let stmts = map(trans_gates, stmts)
                stmts
            end

        _ => println("Nothing")
    end
end


function trans(ctx_tokens)

    global cregs = Qaintessent.CRegister[]
    global qregs = Qaintessent.QRegister[]

    a = trans_reg(ctx_tokens)
    println(a)
    eval.(a)
    println(cregs)
    println(qregs)
    global cgc = CircuitGateChain(qregs, cregs)
    global N = size(cgc)

    a = trans_gates(ctx_tokens)
    println(a)
    eval.(a)
    println(cgc)
    # println(trans_gates(ctx_tokens))
    cgc
end

print_ast = PrettyPrint.pprint
string_ast = PrettyPrint.pformat

a = lex(src1)
a = parse_qasm(a)
println(a)
a = trans(a)
# @eval $a