package pe.utec.cs2032.ms2.resena;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.GenerationTime;

import java.time.Instant;

@Entity
@Table(name = "resenas")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Resena {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Se mapea como columna simple y no como @ManyToOne a propósito: las reseñas
     * siempre se consultan por plato_id y nunca hace falta navegar al plato desde
     * acá. Así se evita un join por fila al paginar 20,000+ registros.
     */
    @Column(name = "plato_id", nullable = false)
    private Long platoId;

    @Column(name = "calificacion", nullable = false)
    private Short calificacion;

    @Column(name = "comentario", length = 400)
    private String comentario;

    @Column(name = "autor", nullable = false, length = 80)
    private String autor;

    @Generated(GenerationTime.INSERT)
    @Column(name = "creado_en", nullable = false, updatable = false, insertable = false)
    private Instant creadoEn;
}
