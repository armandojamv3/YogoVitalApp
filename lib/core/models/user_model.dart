class UserModel {
  final String id;
  final String nombre;
  final String correo;
  final String? telefono;
  final String rol;

  const UserModel({
    required this.id,
    required this.nombre,
    required this.correo,
    this.telefono,
    this.rol = 'cliente',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        nombre: json['nombre'] as String? ?? '',
        correo: json['correo'] as String? ?? '',
        telefono: json['telefono'] as String?,
        rol: json['rol'] as String? ?? 'cliente',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'correo': correo,
        if (telefono != null) 'telefono': telefono,
        'rol': rol,
      };
}
