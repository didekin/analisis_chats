function lengthCol(col)::Int64
    length(collect(skipmissing(col)))
end

function isSoporteTk(tokensLinks::String)::Bool
    contains(tokensLinks, mark_soporte)
end

function minTurnoSoporte(dfIn::NamedTuple)
    filter_df = DataFrame(dfIn) |> df1 -> filter(:issoporte => (x -> identity.(x)), df1)
    if nrow(filter_df) == 0
        return 0
    end
    combine(filter_df, :turno_rol => minimum => :turno_soporte) |> df3 -> first(df3).turno_soporte
end

function convbyturnossopor(dfIn::DataFrame)
    groupby(dfIn, :turnos) |>
    gdf -> combine(gdf, nrow => :conversaciones) |>
           gdf2 -> select!(gdf2, All(), :conversaciones => (c -> cumsum(c / sum(c))) => :ratio)
end

function convbylinksutil(colName::String, groupLinksDf::GroupedDataFrame)::DataFrame
    combine(groupLinksDf, :enlace => lengthCol => Symbol("enlaces_" * colName)) |>
    gdf2 -> groupby(gdf2, Symbol("enlaces_" * colName)) |>
            gdf3 -> combine(gdf3, nrow => :conversaciones) |>
                    gdf4 -> combine(gdf4, All(), :conversaciones => (c -> cumsum(c / sum(c))) => :ratio)
end

function convbylinks(linksDf::DataFrame)::DataFrame
    groupby(linksDf[:, [:id_conv, :rol, :enlace]], [:id_conv]) |>
    df -> convbylinksutil("", df)
end

function convbylinksrol(rol::String, linksDf::DataFrame)::DataFrame
    groupby(linksDf[linksDf.rol.==rol, [:id_conv, :rol, :enlace]], [:id_conv]) |>
    df -> convbylinksutil(rol, df)
end

# (numEnlaces) enlaces más frecuentes en conversaciones de un rol y otro, excluyendo soporte.
function linksMasFreqByRole(linkDf::DataFrame, rol::String, numEnlaces::Int64)::DataFrame
    dropmissing(linkDf) |>
    df -> filter([:rol, :enlace] => (r, e) -> r .== rol && e .!= mark_soporte, df) |>
          df -> groupby(df, :enlace) |>
                gdf1 -> combine(gdf1, nrow => :frecuencia_enlace) |>
                        gdf2 -> sort!(gdf2, :frecuencia_enlace; rev = true) |>
                                gdf4 -> gdf4[1:numEnlaces, [:enlace, :frecuencia_enlace]]
end

function convbylinksturno(linksDf::DataFrame)::DataFrame
    groupby(linksDf[:, [:id_conv, :turno_rol, :enlace]], [:id_conv]) |>
    gdf1 -> combine(gdf1, :turno_rol => maximum => :turnos, :enlace => lengthCol => :enlaces) |>
            gdf2 -> groupby(gdf2, :turnos) |>
                    gdf3 -> combine(gdf3,
        nrow => :conversaciones,
        :enlaces => sum => :sum_enlaces,
        :enlaces => median => :enlaces_mediana,
        :enlaces => mean => :enlaces_media)

end



