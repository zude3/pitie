import 'package:flutter/material.dart';

class CategoryModel {
  const CategoryModel(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

const transactionCategories = <CategoryModel>[
  CategoryModel('Gaji', Icons.work_outline, Color(0xFF80C88B)),
  CategoryModel('Freelance', Icons.laptop_mac, Color(0xFF4AB8E5)),
  CategoryModel('Bonus', Icons.card_giftcard_outlined, Color(0xFFB464C6)),
  CategoryModel('Makanan', Icons.restaurant, Color(0xFFFF8866)),
  CategoryModel(
    'Transportasi',
    Icons.directions_car_outlined,
    Color(0xFF4AB8E5),
  ),
  CategoryModel('Belanja', Icons.shopping_basket_outlined, Color(0xFFB464C6)),
  CategoryModel('Hiburan', Icons.movie_outlined, Color(0xFFE9A33A)),
  CategoryModel('Pendidikan', Icons.menu_book_outlined, Color(0xFF6E7CF6)),
];

CategoryModel categoryFor(String name) => transactionCategories.firstWhere(
  (category) => category.name == name,
  orElse: () => transactionCategories.first,
);
