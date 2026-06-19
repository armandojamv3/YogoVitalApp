/// Devuelve los primeros 8 caracteres de un ID (normalmente un UUID) en
/// mayúsculas, para mostrarlo como código corto al usuario (ej. `A1B2C3D4`).
///
/// Seguro ante ids vacíos o de menos de 8 caracteres: en ese caso devuelve
/// lo que haya, evitando el `RangeError` que lanza `String.substring(0, 8)`
/// cuando la cadena es más corta.
String shortId(String id) {
  final corto = id.length >= 8 ? id.substring(0, 8) : id;
  return corto.toUpperCase();
}
