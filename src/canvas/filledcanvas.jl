"""
FilledCanvas uses the Unicode [Symbols for Legacy Computing](https://en.wikipedia.org/wiki/Symbols_for_Legacy_Computing)
to draw boundary segments. This is used for filled contour plots.
"""

struct FilledCanvas{YS<:Function,XS<:Function} <: LookupCanvas
    grid::Transpose{UInt16,Matrix{UInt16}}
    colors::Transpose{ColorType,Matrix{ColorType}}
    visible::Bool
    blend::Bool
    yflip::Bool
    xflip::Bool
    pixel_height::Int
    pixel_width::Int
    origin_y::Float64
    origin_x::Float64
    height::Float64
    width::Float64
    min_max::NTuple{2,UnicodeType}
    yscale::YS
    xscale::XS
end

const FULL_BLOCK = '█'
const EMPTY_BLOCK = '\x00'    # Replaced during rendering, not to overdraw lower layers

const GLYPHS = [
    ((1, 4), '🭍'),
    ((1, 5), '🭏'),
    ((1, 6), '◣'),
    ((1, 7), '🭀'),
    ((2, 4), '🭌'),
    ((2, 5), '🭎'),
    ((2, 6), '🭐'),
    ((2, 7), '▌'),
    ((2, 8), '🭛'),
    ((2, 9), '🭙'),
    ((2, 10), '🭗'),
    ((3, 7), '🭡'),
    ((3, 8), '◤'),
    ((3, 9), '🭚'),
    ((3, 10), '🭘'),
    ((4, 1), '🭣'),
    ((4, 2), '🭢'),
    ((4, 7), '🭟'),
    ((4, 8), '🭠'),
    ((4, 9), '🭜'),
    ((4, 10), '🬂'),
    ((5, 1), '🭥'),
    ((5, 2), '🭤'),
    ((5, 7), '🭝'),
    ((5, 8), '🭞'),
    ((5, 9), '🬎'),
    ((5, 10), '🭧'),
    ((6, 1), '◥'),
    ((6, 2), '🭦'),
    ((6, 9), '🭓'),
    ((6, 10), '🭕'),
    ((7, 1), '🭖'),
    ((7, 2), '▐'),
    ((7, 3), '🭋'),
    ((7, 4), '🭉'),
    ((7, 5), '🭇'),
    ((7, 9), '🭒'),
    ((7, 10), '🭔'),
    ((8, 2), '🭅'),
    ((8, 3), '◢'),
    ((8, 4), '🭊'),
    ((8, 5), '🭈'),
    ((9, 2), '🭃'),
    ((9, 3), '🭄'),
    ((9, 4), '🭆'),
    ((9, 5), '🬭'),
    ((9, 6), '🬽'),
    ((9, 7), '🬼'),
    ((10, 2), '🭁'),
    ((10, 3), '🭂'),
    ((10, 4), '🬹'),
    ((10, 5), '🭑'),
    ((10, 6), '🬿'),
    ((10, 7), '🬾'),
]

const N_FILLED = gridtype(FilledCanvas)(56)
const FILLED_DECODE = Vector{Char}(undef, typemax(N_BLOCK))

FILLED_DECODE[1] = EMPTY_BLOCK
FILLED_DECODE[2] = FULL_BLOCK
FILLED_DECODE[3:56] = collect("🭍🭏◣🭀🭌🭎🭐▌🭛🭙🭗🭡◤🭚🭘🭣🭢🭟🭠🭜🬂🭥🭤🭝🭞🬎🭧◥🭦🭓🭕🭖▐🭋🭉🭇🭒🭔🭅◢🭊🭈🭃🭄🭆🬭🬽🬼🭁🭂🬹🭑🬿🬾")
FILLED_DECODE[(N_FILLED + 1):typemax(N_FILLED)] =
    UNICODE_TABLE[1:(typemax(N_FILLED) - N_FILLED)]

# Not sure that these are meaningful
# @inline x_pixel_per_char(::Type{<:FilledCanvas}) = 2
# @inline y_pixel_per_char(::Type{<:FilledCanvas}) = 3
# @inline lookup_encode(::BlockCanvas) = FILLED_SIGNS

@inline lookup_decode(::BlockCanvas) = FILLED_DECODE
@inline lookup_offset(::BlockCanvas) = N_FILLED

FilledCanvas(args...; kw...) = CreateLookupCanvas(FilledCanvas, (0, 56), args...; kw...)
