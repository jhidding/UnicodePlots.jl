"""
    Plot(graphics; kw...)

# Description

Decoration for objects that are `GraphicsArea` (or `Canvas`).
It is used to surround the inner `GraphicsArea` object with
additional information such as a title, border, and axis labels.

# Usage

    Plot(graphics; $(keywords(; default = (), add = (:title, :xlabel, :ylabel, :zlabel, :border, :margin, :padding, :compact, :labels))))

    Plot(x, y, z, canvas; $(keywords()))

# Arguments

$(arguments(
    (; graphics = "the `GraphicsArea` (e.g. a subtype of `Canvas`) that the plot should decorate");
    add = (:x, :y, :z, :canvas)
))

# Methods

- `title!(plot::Plot, title::String)`

- `xlabel!(plot::Plot, xlabel::String)`

- `ylabel!(plot::Plot, xlabel::String)`

- `zlabel!(plot::Plot, zlabel::String)`

- `label!(plot::Plot, where::Symbol, value::String)`

- `label!(plot::Plot, where::Symbol, row::Int, value::String)`

Author(s)

- Christof Stocker (github.com/Evizero)

# See also

[`scatterplot`](@ref), [`lineplot`](@ref),
[`BarplotGraphics`](@ref), [`BrailleCanvas`](@ref),
[`BlockCanvas`](@ref), [`AsciiCanvas`](@ref)
"""
struct Plot{T<:GraphicsArea,E,F}
    graphics::T
    projection::MVP{E,F}
    autocolor::RefValue{Int}
    series::RefValue{Int}
    title::RefValue{String}
    xlabel::RefValue{String}
    ylabel::RefValue{String}
    zlabel::RefValue{String}
    margin::Int
    padding::Int
    border::Symbol
    compact::Bool
    labels::Bool
    labels_left::Dict{Int,String}
    labels_right::Dict{Int,String}
    colors_left::Dict{Int,ColorType}
    colors_right::Dict{Int,ColorType}
    decorations::Dict{Symbol,String}
    colors_deco::Dict{Symbol,ColorType}
    cmap::ColorMap
end

function Plot(
    graphics::T;
    title::AbstractString = KEYWORDS.title,
    xlabel::AbstractString = KEYWORDS.xlabel,
    ylabel::AbstractString = KEYWORDS.ylabel,
    zlabel::AbstractString = KEYWORDS.zlabel,
    border::Symbol = KEYWORDS.border,
    compact::Bool = KEYWORDS.compact,
    margin::Int = KEYWORDS.margin,
    padding::Int = KEYWORDS.padding,
    labels::Bool = KEYWORDS.labels,
    colorbar::Bool = KEYWORDS.colorbar,
    colorbar_border::Symbol = KEYWORDS.colorbar_border,
    colorbar_lim = KEYWORDS.colorbar_lim,
    colormap::Any = nothing,
    projection::Union{Nothing,MVP} = nothing,
    ignored...,
) where {T<:GraphicsArea}
    margin < 0 && throw(ArgumentError("`margin` must be ≥ 0"))
    projection = something(projection, MVP())
    E = Val{is_enabled(projection)}
    F = typeof(projection.dist)
    p = Plot{T,E,F}(
        graphics,
        projection,
        Ref(0),
        Ref(0),
        Ref(string(title)),
        Ref(string(xlabel)),
        Ref(string(ylabel)),
        Ref(string(zlabel)),
        margin,
        padding,
        border,
        compact,
        labels && graphics.visible,
        Dict{Int,String}(),
        Dict{Int,String}(),
        Dict{Int,ColorType}(),
        Dict{Int,ColorType}(),
        Dict{Symbol,String}(),
        Dict{Symbol,ColorType}(),
        ColorMap(colorbar_border, colorbar, colorbar_lim, colormap_callback(colormap)),
    )
    if compact
        xlabel != "" && label!(p, :b, xlabel)
        ylabel != "" && label!(p, :l, round(Int, nrows(graphics) / 2), ylabel)
    end
    p
end

"""
    validate_input(x, y, z = nothing)

# Description

Check for invalid input (length) and selects only finite input data.
"""
function validate_input(
    x::AbstractVector{<:Number},
    y::AbstractVector{<:Number},
    z::AbstractVector{<:Number},
)
    length(x) == length(y) == length(z) ||
        throw(DimensionMismatch("`x`, `y` and `z` must have same length"))
    idx = BitVector(map(x, y, z) do i, j, k
        isfinite(i) && isfinite(j) && isfinite(k)
    end)
    x[idx], y[idx], z[idx]
end

function validate_input(
    x::AbstractVector{<:Number},
    y::AbstractVector{<:Number},
    z::Nothing,
)
    length(x) == length(y) || throw(DimensionMismatch("`x` and `y` must have same length"))
    idx = BitVector(map(x, y) do i, j
        isfinite(i) && isfinite(j)
    end)
    x[idx], y[idx], z
end

function Plot(
    x::AbstractVector{<:Number},
    y::AbstractVector{<:Number},
    z::Union{AbstractVector{<:Number},Nothing} = nothing,
    ::Type{C} = BrailleCanvas;
    title::AbstractString = KEYWORDS.title,
    xlabel::AbstractString = KEYWORDS.xlabel,
    ylabel::AbstractString = KEYWORDS.ylabel,
    zlabel::AbstractString = KEYWORDS.zlabel,
    xscale::Union{Symbol,Function} = KEYWORDS.xscale,
    yscale::Union{Symbol,Function} = KEYWORDS.yscale,
    height::Union{Int,Nothing,Symbol} = nothing,
    width::Union{Int,Nothing,Symbol} = nothing,
    border::Symbol = KEYWORDS.border,
    compact::Bool = KEYWORDS.compact,
    blend::Bool = KEYWORDS.blend,
    xlim = KEYWORDS.xlim,
    ylim = KEYWORDS.ylim,
    margin::Int = KEYWORDS.margin,
    padding::Int = KEYWORDS.padding,
    labels::Bool = KEYWORDS.labels,
    unicode_exponent::Bool = KEYWORDS.unicode_exponent,
    colorbar::Bool = KEYWORDS.colorbar,
    colorbar_border::Symbol = KEYWORDS.colorbar_border,
    colorbar_lim = KEYWORDS.colorbar_lim,
    colormap::Any = nothing,
    grid::Bool = KEYWORDS.grid,
    xticks::Bool = KEYWORDS.xticks,
    yticks::Bool = KEYWORDS.yticks,
    min_height::Int = 2,
    min_width::Int = 5,
    yflip::Bool = KEYWORDS.yflip,
    xflip::Bool = KEYWORDS.xflip,
    projection::Union{Nothing,Symbol,MVP} = nothing,
    axes3d = KEYWORDS.axes3d,
    canvas_kw = (;),
    kw...,
) where {C<:Canvas}
    length(xlim) == length(ylim) == 2 ||
        throw(ArgumentError("`xlim` and `ylim` must be tuples or vectors of length 2"))

    height = something(height ≡ :auto ? displaysize(stdout)[1] - 6 - (isempty(title) ? 0 : 1) : height, DEFAULT_HEIGHT[])
    width  = something(width ≡ :auto ? displaysize(stdout)[2] - 10 : width, DEFAULT_WIDTH[])

    (visible = width > 0) && (width = max(width, min_width))
    height = max(height, min_height)

    x, y, z = validate_input(x, y, z)

    base_x = xscale isa Symbol ? get(BASES, xscale, nothing) : nothing
    base_y = yscale isa Symbol ? get(BASES, yscale, nothing) : nothing

    xscale = scale_callback(xscale)
    yscale = scale_callback(yscale)

    if projection ≢ nothing  # 3D
        (xscale ≢ identity || yscale ≢ identity) &&
            throw(ArgumentError("`xscale` or `yscale` are unsupported in 3D"))

        projection isa Symbol && (projection = MVP(x, y, z; kw...))

        # normalized coordinates, but allow override (artifact for zooming):
        # using `xlim = (-0.5, 0.5)` & `ylim = (-0.5, 0.5)`
        # should be close to using `zoom = 2`
        autolims(lims) = is_auto(lims) ? (-1.0, 1.0) : as_float(lims)
        mx, Mx = autolims(xlim)
        my, My = autolims(ylim)

        grid = blend = false
    else  # 2D
        projection = MVP()
        mx, Mx = extend_limits(x, xlim, xscale)
        my, My = extend_limits(y, ylim, yscale)
    end

    p_width = Mx - mx
    p_height = My - my

    canvas = C(
        height,
        width;
        blend = blend,
        visible = visible,
        origin_y = my,
        origin_x = mx,
        height = p_height,
        width = p_width,
        yscale = yscale,
        xscale = xscale,
        yflip = yflip,
        xflip = xflip,
        canvas_kw...,
    )
    plot = Plot(
        canvas;
        title = title,
        margin = margin,
        padding = padding,
        border = border,
        compact = compact,
        labels = labels,
        xlabel = xlabel,
        ylabel = ylabel,
        zlabel = zlabel,
        colormap = colormap,
        colorbar = colorbar,
        colorbar_border = colorbar_border,
        colorbar_lim = colorbar_lim,
        projection = projection,
    )
    if xticks || yticks
        m_x, M_x, m_y, M_y = nice_repr.((mx, Mx, my, My))
        if unicode_exponent
            m_x, M_x = map(v -> base_x ≢ nothing ? superscript(v) : v, (m_x, M_x))
            m_y, M_y = map(v -> base_y ≢ nothing ? superscript(v) : v, (m_y, M_y))
        end
        bc = BORDER_COLOR[]
        if xticks
            base_x_str = base_x ≡ nothing ? "" : base_x * (unicode_exponent ? "" : "^")
            label!(plot, :bl, base_x_str * (xflip ? M_x : m_x), color = bc)
            label!(plot, :br, base_x_str * (xflip ? m_x : M_x), color = bc)
        end
        if yticks
            base_y_str = base_y ≡ nothing ? "" : base_y * (unicode_exponent ? "" : "^")
            label!(plot, :l, nrows(canvas), base_y_str * (yflip ? M_y : m_y), color = bc)
            label!(plot, :l, 1, base_y_str * (yflip ? m_y : M_y), color = bc)
        end
    end
    if grid && (xscale ≡ identity && yscale ≡ identity)
        my < 0 < My && lines!(plot, mx, 0.0, Mx, 0.0)
        mx < 0 < Mx && lines!(plot, 0.0, my, 0.0, My)
    end

    (is_enabled(projection) && axes3d) && draw_axes!(plot, 0.8 .* [mx, my])

    plot
end

function next_color!(plot::Plot)
    next_idx = plot.autocolor[] + 1
    next_color = COLOR_CYCLE[][next_idx]
    plot.autocolor[] = next_idx % length(COLOR_CYCLE[])
    next_color
end

"""
    title(plot) -> String

Returns the current title of the given plot.
Alternatively, the title can be changed with `title!`.
"""
@inline title(plot::Plot) = plot.title[]

"""
    title!(plot, newtitle)

Sets a new title for the given plot.
Alternatively, the current title can be queried using `title`.
"""
function title!(plot::Plot, title::AbstractString)
    plot.title[] = title
    plot
end

"""
    xlabel(plot) -> String

Returns the current label for the x-axis.
Alternatively, the x-label can be changed with `xlabel!`.
"""
@inline xlabel(plot::Plot) = plot.xlabel[]

"""
    xlabel!(plot, newlabel)

Sets a new x-label for the given plot.
Alternatively, the current label can be queried using `xlabel`.
"""
function xlabel!(plot::Plot, xlabel::AbstractString)
    plot.xlabel[] = xlabel
    plot
end

"""
    ylabel(plot) -> String

Returns the current label for the y-axis.
Alternatively, the y-label can be changed with `ylabel!`.
"""
@inline ylabel(plot::Plot) = plot.ylabel[]

"""
    ylabel!(plot, newlabel)

Sets a new y-label for the given plot.
Alternatively, the current label can be
queried using `ylabel`
"""
function ylabel!(plot::Plot, ylabel::AbstractString)
    plot.ylabel[] = ylabel
    plot
end

"""
    zlabel(plot) -> String

Returns the current label for the z-axis (colorbar).
Alternatively, the z-label can be changed with `zlabel!`.
"""
@inline zlabel(plot::Plot) = plot.zlabel[]

"""
    zlabel!(plot, newlabel)

Sets a new z-label (colorbar label) for the given plot.
Alternatively, the current label can be queried using `zlabel`.
"""
function zlabel!(plot::Plot, zlabel::AbstractString)
    plot.zlabel[] = zlabel
    plot
end

"""
    label!(plot, where, value, [color])

    label!(plot, where, row, value, [color])

This method is responsible for the setting all the textual decorations of a plot.

Note that `where` can be any of: `:tl` (top-left),
`:t` (top-center), `:tr` (top-right),
`:bl` (bottom-left), `:b` (bottom-center),
`:br` (bottom-right), `:l` (left), `:r` (right).

If `where` is either `:l`, or `:r`, then `row` can be between 1
and the number of character rows of the plots canvas.
"""
function label!(plot::Plot, loc::Symbol, value::AbstractString, color::UserColorType)
    loc ∈ (:t, :b, :l, :r, :tl, :tr, :bl, :br) || throw(
        ArgumentError("unknown location $loc: try one of these :tl :t :tr :bl :b :br"),
    )
    if loc ≡ :l || loc ≡ :r
        for row in 1:nrows(plot.graphics)
            if loc ≡ :l
                if !haskey(plot.labels_left, row) || isempty(plot.labels_left[row])
                    plot.labels_left[row] = value
                    plot.colors_left[row] = ansi_color(color)
                    break
                end
            elseif loc ≡ :r
                if !haskey(plot.labels_right, row) || isempty(plot.labels_right[row])
                    plot.labels_right[row] = value
                    plot.colors_right[row] = ansi_color(color)
                    break
                end
            end
        end
    else
        plot.decorations[loc] = value
        plot.colors_deco[loc] = ansi_color(color)
    end
    plot
end

label!(plot::Plot, loc::Symbol, value::AbstractString; color::UserColorType = :normal) =
    label!(plot, loc, value, color)

function label!(
    plot::Plot,
    loc::Symbol,
    row::Int,
    value::AbstractString,
    color::UserColorType,
)
    if loc ≡ :l
        plot.labels_left[row] = value
        plot.colors_left[row] = ansi_color(color)
    elseif loc ≡ :r
        plot.labels_right[row] = value
        plot.colors_right[row] = ansi_color(color)
    else
        throw(ArgumentError("unknown location $loc, try `:l` or `:r` instead"))
    end
    plot
end

label!(
    plot::Plot,
    loc::Symbol,
    row::Int,
    value::AbstractString;
    color::UserColorType = :normal,
) = label!(plot, loc, row, value, color)

"""
    annotate!(plot, x, y, text; kw...)

# Description

Adds text to the plot at the position `(x, y)`.

# Arguments

$(arguments((; text = "a string of text"); default = (), add = (:x, :y, :color)))

# Examples

```julia-repl
julia> plt = lineplot([1, 2, 7], [9, -6, 8], title = "My Lineplot");

julia> annotate!(plt, 5, 5, "My text")
       ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀My Lineplot⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ 
       ┌────────────────────────────────────────┐ 
    10 │⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⢇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠│ 
       │⠘⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠤⠊⠁⠀│ 
       │⠀⢣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀My text⠀⠀⣀⠔⠊⠁⠀⠀⠀⠀│ 
       │⠀⠈⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠔⠊⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠔⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⠀⢇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡠⠒⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠤⠤⠤⠼⡤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⢤⠤⠶⠥⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤⠤│ 
       │⠀⠀⠀⠀⢣⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠤⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⠀⠀⠈⡆⠀⠀⠀⠀⠀⠀⠀⣀⠔⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⠀⠀⠀⢱⠀⠀⠀⠀⡠⠔⠊⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⠀⠀⠀⠀⢇⡠⠔⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
   -10 │⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀│ 
       └────────────────────────────────────────┘ 
       ⠀1⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀7⠀
```

# See also

[`Plot`](@ref), [`lineplot`](@ref), [`scatterplot`](@ref),
[`stairs`](@ref), [`BrailleCanvas`](@ref), [`BlockCanvas`](@ref),
[`AsciiCanvas`](@ref), [`DotCanvas`](@ref)
"""
function annotate!(
    plot::Plot{<:Canvas},
    x::Number,
    y::Number,
    text::Union{AbstractChar,AbstractString};
    color = :normal,
    kw...,
)
    color = color ≡ :auto ? next_color!(plot) : color
    annotate!(plot.graphics, x, y, text, color; kw...)
    plot
end

transform(tr, args...) = args  # catch all
transform(tr::MVP{Val{false}}, x, y, c::UserColorType) = (x, y, c)
transform(tr::MVP{Val{false}}, x, y, z::Nothing, c::UserColorType) = (x, y, c)  # drop z
transform(tr::MVP{Val{true}}, x, y, z::Union{AbstractVector,Number}, args...) =
    (tr(vcat(x', y', z', ones(1, length(x))))..., args...)

function lines!(plot::Plot{<:Canvas}, args...; kw...)
    lines!(plot.graphics, transform(plot.projection, args...)...; kw...)
    plot
end

function pixel!(plot::Plot{<:Canvas}, args...; kw...)
    pixel!(plot.graphics, transform(plot.projection, args...)...; kw...)
    plot
end

function points!(plot::Plot{<:Canvas}, args...; kw...)
    points!(plot.graphics, transform(plot.projection, args...)...; kw...)
    plot
end
