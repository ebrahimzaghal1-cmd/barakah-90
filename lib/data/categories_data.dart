class CategoryItem {
  final String title;
  final String image;

  CategoryItem({required this.title, required this.image});
}

final List<CategoryItem> categories = [
  CategoryItem(
    title: 'مخبوزات',
    image: 'assets/images/categories/bakery.jpg',
  ),
  CategoryItem(
    title: 'دجاج',
    image: 'assets/images/categories/chicken.jpg',
  ),
  CategoryItem(
    title: 'أسماك',
    image: 'assets/images/categories/fish.jpg',
  ),
  CategoryItem(
    title: 'خضار وفواكه',
    image: 'assets/images/categories/fruits_veggies.jpg',
  ),
  CategoryItem(
    title: 'لحوم',
    image: 'assets/images/categories/meat.jpg',
  ),
  CategoryItem(
    title: 'صيدلية',
    image: 'assets/images/categories/pharmacy.jpg',
  ),
  CategoryItem(
    title: 'مطاعم',
    image: 'assets/images/categories/restaurants.jpg',
  ),
  CategoryItem(
    title: 'سوبرماركت',
    image: 'assets/images/categories/supermarket.jpg',
  ),
];
