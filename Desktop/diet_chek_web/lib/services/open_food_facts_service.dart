import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/online_product.dart';

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';

  Future<List<OnlineProduct>> searchByName(String query) async {
    try {
      final String url = '$_baseUrl/cgi/search.pl?search_terms=${Uri.encodeComponent(query)}'
          '&search_simple=1&json=1&page_size=5';

      final http.Response response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'DietChek/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> products = data['products'] as List<dynamic>? ?? [];

        return products
            .map((dynamic p) => OnlineProduct.fromOpenFoodFacts({'product': p}))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<OnlineProduct?> searchByBarcode(String barcode) async {
    try {
      final String url = '$_baseUrl/api/v0/product/$barcode.json';
      final http.Response response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'DietChek/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1) {
          return OnlineProduct.fromOpenFoodFacts(data);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> quickSearch(String productName) async {
    final List<OnlineProduct> results = await searchByName(productName)
        .timeout(const Duration(seconds: 5));

    if (results.isEmpty) return null;

    final OnlineProduct best = results.first;

    return {
      'product': best,
      'ingredients': best.ingredientsText ?? '',
      'nutrients': best.nutrients,
      'allergens': best.allergens,
      'source': 'open_food_facts',
    };
  }
}