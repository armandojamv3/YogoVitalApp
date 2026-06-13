class PromedioCalificacion {
  final String saborId;
  final double promedio;
  final int? total;

  const PromedioCalificacion({
    required this.saborId,
    required this.promedio,
    this.total,
  });
}
