package pe.utec.cs2032.ms2.common;

import java.time.Instant;

public record ApiError(
        Instant timestamp,
        int status,
        String error,
        String mensaje,
        String path
) {
}
