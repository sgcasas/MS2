package pe.utec.cs2032.ms2.export;

public enum FormatoExport {

    /** Un objeto JSON plano por línea. Es el formato que leen AWS Glue y Athena sin configuración extra. */
    NDJSON("application/x-ndjson", "ndjson"),

    /** CSV RFC 4180 con fila de cabecera. */
    CSV("text/csv", "csv");

    private final String contentType;
    private final String extension;

    FormatoExport(String contentType, String extension) {
        this.contentType = contentType;
        this.extension = extension;
    }

    public String contentType() {
        return contentType;
    }

    public String extension() {
        return extension;
    }

    public static FormatoExport desde(String valor) {
        if (valor == null || valor.isBlank()) {
            return NDJSON;
        }
        return switch (valor.trim().toLowerCase()) {
            case "ndjson", "json" -> NDJSON;
            case "csv" -> CSV;
            default -> throw new IllegalArgumentException(
                    "Formato de export no soportado: " + valor + ". Use 'ndjson' o 'csv'.");
        };
    }
}
