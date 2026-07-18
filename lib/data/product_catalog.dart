class Product {
  const Product({
    required this.id,
    required this.name,
    required this.malayalamName,
    required this.aliases,
    required this.unitPrice,
  });

  final String id;
  final String name;
  final String malayalamName;
  final List<String> aliases;
  final int unitPrice;
}

const productCatalog = <Product>[
  Product(
    id: 'milk',
    name: 'Milk',
    malayalamName: 'പാൽ',
    aliases: ['milk', 'paal', 'പാൽ'],
    unitPrice: 30,
  ),
  Product(
    id: 'bread',
    name: 'Bread',
    malayalamName: 'ബ്രെഡ്',
    aliases: ['bread', 'ബ്രെഡ്'],
    unitPrice: 40,
  ),
  Product(
    id: 'parle-g',
    name: 'Parle-G',
    malayalamName: 'പാർലെ-ജി',
    aliases: ['parle-g', 'parle g', 'parle', 'പാർലെ-ജി'],
    unitPrice: 10,
  ),
  Product(
    id: 'soap',
    name: 'Soap',
    malayalamName: 'സോപ്പ്',
    aliases: ['soap', 'സോപ്പ്'],
    unitPrice: 35,
  ),
];
