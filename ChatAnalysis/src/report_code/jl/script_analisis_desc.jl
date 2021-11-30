# ===================================== 2.  Análisis preliminar ==================================== 

turno_link_issop = queryDbtoDf(sql_turno_enlace) |>
                   df -> select!(df, Not([:tokens, :tokens_links]), :tokens_links => ByRow(isSoporteTk) => :issoporte)

# Número de turnos, enlaces y issopporte, por conversación. 
# El número de turnos es el máximo en cualquiera de los dos roles (son iguales o con diferencia de 1).
# El número de links es el resultado de contar los links en cualquiera de los roles.
cv_te_s = select(turno_link_issop, Not(:rol)) |>
          df -> groupby(df, :id_conv) |>
                gdf -> combine(gdf, :turno_rol => maximum => :turnos, :link => (l -> count(!ismissing, l)) => :enlaces, :issoporte => maximum => :issoporte)

# ---------------- 2.1  Totales ---------------- 
# Tabla de totales
summary_1 = combine(cv_te_s, nrow => :conversaciones, :turnos => sum => :tot_turnos, :enlaces => sum => :tot_enlaces, :issoporte => sum => :tot_soporte)
# Scatter-plot de todas las conversaciones.
scatter_cv_te_s = plot(cv_te_s, x = :turnos, y = :enlaces, color = :issoporte, Geom.point)
draw(PNG(imgReportDir * "/scatter_cv_te_s.png", 15cm, 12cm), scatter_cv_te_s)

# ---------------- 2.2 Conversaciones, número de turnos y soporte ---------------- 
# Número de conversaciones por número de turnos, diferenciando por soporte.
convs_by_numturnos_s = convbyturnossopor(cv_te_s[cv_te_s.issoporte, :])
convs_by_numturnos_ns = convbyturnossopor(cv_te_s[.!cv_te_s.issoporte, :])
# Plot con frecuencia de conversaciones, simple y acumulada, por número de turnos. Soporte.
plotConvTurnos(convs_by_numturnos_s, [colorant"orange2"], "s")
# Plot con frecuencia de conversaciones, simple y acumulada, por número de turnos. No soporte.
plotConvTurnos(convs_by_numturnos_ns, [colorant"darkorange3"], "ns")
# Conversaciones con soporte: número de turnos y número del primer turno con referencia a soporte.
minturno_soporte = groupby(turno_link_issop, :id_conv) |>
                   gdf -> combine(gdf, :turno_rol => maximum => :turnos, AsTable([:turno_rol, :issoporte]) => minTurnoSoporte => :min_turnosoporte) |>
                          df1 -> filter!(:min_turnosoporte => .>(0), df1)
# Scatter plot.
scatter_turnos_soporte = plot(minturno_soporte, x = :min_turnosoporte, y = :turnos,
    Guide.yticks(ticks = collect(0:2:maximum(minturno_soporte.turnos))), Geom.point)
draw(PNG(imgReportDir * "/scatter_turnos_soporte.png", 15cm, 12cm), scatter_turnos_soporte)
# Media de turnos tras referencia a soporte.
summary_turnos_soporte = combine(minturno_soporte, [:turnos, :min_turnosoporte] => ((t, s) -> (media_turnos = mean(t - s), mediana_turnos = median(t - s))) => AsTable)

# ---------------- 2.2  Conversaciones y enlaces ---------------- 
# --- Datos tabla enlace (no diferenciamos 'soporte' ) ---
link_df = select(turno_link_issop, Not([:issoporte, :link]), :link => :enlace)

# Número de conversaciones por número de links, en conjunto.
convs_by_numlinks = convbylinks(link_df)
# Número de conversaciones por número de links; rol ag.
convs_by_numlinks_ag = convbylinksrol(agente, link_df)
# Número de conversaciones por número de links; rol cl.
convs_by_numlinks_cl = convbylinksrol(cliente, link_df)
# Plot con frecuencia de conversaciones, simple y acumulada, por número de enlaces. 
plotConvLinks(convs_by_numlinks, [colorant"lightgoldenrod1"], "")
# Plot con frecuencia de conversaciones, simple y acumulada, por número de enlaces. Agente.
plotConvLinks(convs_by_numlinks_ag, [colorant"khaki3"], agente)
# Plot con frecuencia de conversaciones, simple y acumulada, por número de enlaces. Cliente.
plotConvLinks(convs_by_numlinks_cl, [colorant"gold4"], cliente)

# ---------------- 2.3  Enlaces más frecuentes ---------------- 

# --------------- 2.4 Conversaciones, enlaces y turnos ---------------- 
# num_conv, sum_enlaces, mediana y media de enlaces por conversación, según el número de turnos de la conversación.
lk_by_tu = convbylinksturno(link_df) |>
           df -> filter!(:conversaciones => .>=(5), df) |>
                 df1 -> select!(df1, [:turnos, :conversaciones, :enlaces_media])
scatter_links_numturnos = plot(lk_by_tu, x = :turnos, y = :enlaces_media,
    Guide.xticks(ticks = collect(0:1:maximum(lk_by_tu.turnos))),
    Guide.yticks(ticks = collect(0:0.5:(1.25*maximum(lk_by_tu.enlaces_media)))),
    Geom.point, Geom.line)
draw(PNG(imgReportDir * "/scatter_links_numturnos.png", 15cm, 12cm), scatter_links_numturnos)
