/// Dietary modifiers presented after photo capture.
///
/// [vegan] is the default selection per product spec.
enum DietaryModifier {
  standard('Standard'),
  vegan('Vegan'),
  glutenFree('Gluten-Free'),
  healthier('Healthier');

  const DietaryModifier(this.label);
  final String label;
}
