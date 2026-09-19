package pe.utec.cs2032.ms2.resena.dto;

import pe.utec.cs2032.ms2.resena.Resena;

import java.time.Instant;

public record ResenaResponse(
        Long id,
        Long platoId,
        Short calificacion,
        String comentario,
        String autor,
        Instant creadoEn
) {
    public static ResenaResponse from(Resena resena) {
        return new ResenaResponse(
                resena.getId(),
                resena.getPlatoId(),
                resena.getCalificacion(),
                resena.getComentario(),
                resena.getAutor(),
                resena.getCreadoEn()
        );
    }
}
