/// Dietary modifiers presented after photo capture.
///
/// [standard] is the default selection.
enum DietaryModifier {
  standard('Standard'),
  vegan('Vegan'),
  glutenFree('Gluten-Free'),
  healthier('Healthier');

  const DietaryModifier(this.label);
  final String label;
}
