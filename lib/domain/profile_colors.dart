/// Colores de persona: 10 tonos de señalética, todos con contraste ≥ 5:1 frente a texto
/// blanco y separados entre sí al menos ΔE2000 = 15 (claramente distinguibles).
/// Evitan el rojo de "omitida", el ámbar de "tardía" y el azul marino de las placas.
library;

class ProfileColor {
  final int argb;
  final String name;
  const ProfileColor(this.argb, this.name);
}

const profilePalette = <ProfileColor>[
  ProfileColor(0xFF1B6E43, 'Verde'),
  ProfileColor(0xFF1D6FB3, 'Azul'),
  ProfileColor(0xFFB04A0C, 'Naranja'),
  ProfileColor(0xFF9A22AE, 'Morado'),
  ProfileColor(0xFF13797E, 'Petróleo'),
  ProfileColor(0xFFC2185B, 'Frambuesa'),
  ProfileColor(0xFF6B7516, 'Oliva'),
  ProfileColor(0xFF4B3FC2, 'Índigo'),
  ProfileColor(0xFF5C4628, 'Café'),
  ProfileColor(0xFF7A2156, 'Vino'),
];

/// Primer color de la paleta que nadie usa; si los 10 están ocupados, el menos repetido.
int suggestProfileColor(Iterable<int> usedByOthers) {
  final counts = <int, int>{for (final c in profilePalette) c.argb: 0};
  for (final u in usedByOthers) {
    if (counts.containsKey(u)) counts[u] = counts[u]! + 1;
  }
  return profilePalette.map((c) => c.argb).reduce((a, b) => counts[b]! < counts[a]! ? b : a);
}

/// Un color está disponible si nadie más lo usa, o si ya están ocupados los 10.
bool isProfileColorAvailable(int argb, Iterable<int> usedByOthers) {
  final used = usedByOthers.toSet();
  final allTaken = profilePalette.every((c) => used.contains(c.argb));
  return allTaken || !used.contains(argb);
}
