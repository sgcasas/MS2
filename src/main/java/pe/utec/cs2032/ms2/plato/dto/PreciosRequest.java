package pe.utec.cs2032.ms2.plato.dto;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record PreciosRequest(

        @NotEmpty
        List<Long> ids
) {
}
