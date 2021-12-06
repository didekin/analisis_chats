using Test
import ChatAnalysis as CH

@test replace("https://www.pccomponentes.com/soporte/contacto", CH.soporte_regx => CH.soporte_sub) == "https://www.pccomponentes.com/"*CH.mark_soporte