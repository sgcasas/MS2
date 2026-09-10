package pe.utec.cs2032.ms2.plato.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record PlatoRequest(

        @NotNull
        Long categoriaId,

        @NotBlank
        @Size(max = 120)
        String nombre,

        @Size(max = 400)
        String descripcion,

        @NotNull
        @DecimalMin(value = "0.0", inclusive = false)
        @Digits(integer = 8, fraction = 2)
        BigDecimal precio,

        Boolean disponible,

        @Min(0)
        Integer tiempoPreparacionMin,

        @Min(0)
        Integer calorias,

        @Size(max = 300)
        String imagenUrl
) {
}
