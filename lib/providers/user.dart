import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_app_course_resto/helpers/order.dart';
import 'package:food_app_course_resto/helpers/product.dart';
import 'package:food_app_course_resto/helpers/restaurant.dart';
import 'package:food_app_course_resto/models/cart_item.dart';
import 'package:food_app_course_resto/models/order.dart';
import 'package:food_app_course_resto/models/product.dart';
import 'package:food_app_course_resto/models/restaurant.dart';
import 'package:uuid/uuid.dart';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class UserProvider with ChangeNotifier {
  FirebaseAuth _auth;
  FirebaseUser _user;
  Status _status = Status.Uninitialized;
  Firestore _firestore = Firestore.instance;
  OrderServices _orderServices = OrderServices();
  RestaurantServices _restaurantServices = RestaurantServices();
  ProductServices _productServices = ProductServices();
  double _totalSales = 0;
  double _avgPrice = 0;
  double _restaurantRating = 0;


  RestaurantModel _restaurant;
  List<ProductModel> products = <ProductModel>[];
  List<CartItemModel> cartItems = [];

//  getter
  Status get status => _status;

  FirebaseUser get user => _user;

  RestaurantModel get restaurant => _restaurant;

  double get totalSales => _totalSales;
  double get avgPrice => _avgPrice;
  double get restaurantRating => _restaurantRating;


  // public variables
  List<OrderModel> orders = [];

  final formkey = GlobalKey<FormState>();

  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController name = TextEditingController();

  UserProvider.initialize() : _auth = FirebaseAuth.instance {
    _auth.onAuthStateChanged.listen(_onStateChanged);
  }

  Future<bool> signIn() async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(
          email: email.text.trim(), password: password.text.trim());
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      print(e.toString());
      return false;
    }
  }

  Future<bool> signUp() async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth
          .createUserWithEmailAndPassword(
              email: email.text.trim(), password: password.text.trim())
          .then((result) {
        _firestore.collection('restaurants').document(result.user.uid).setData({
          'name': name.text,
          'email': email.text,
          'id': result.user.uid,
          "avgPrice": 0.0,
          "image": "",
          "popular": false,
          "rates": 0,
          "rating": 0.0,
        });
      });
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      print(e.toString());
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  void clearController() {
    name.text = "";
    password.text = "";
    email.text = "";
  }

  Future<void> reload() async {
    _restaurant = await _restaurantServices.getRestaurantById(id: user.uid);
    await loadProductsByRestaurant(restaurantId: user.uid);
    await getOrders();
    await getTotalSales();
    await getAvgPrice();
    notifyListeners();
  }

  Future<void> _onStateChanged(FirebaseUser firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
      await loadProductsByRestaurant(restaurantId: user.uid);
      await getOrders();
      await getTotalSales();
      await getAvgPrice();
      _restaurant = await _restaurantServices.getRestaurantById(id: user.uid);
    }
    notifyListeners();
  }

  getOrders() async {
    orders = await _orderServices.restaurantOrders(restaurantId: _user.uid);
    notifyListeners();
  }

  getTotalSales() async {
    for (OrderModel order in orders) {
      for (CartItemModel item in order.cart) {
        if (item.restaurantId == user.uid) {
          _totalSales = _totalSales + item.totalRestaurantSale;
          cartItems.add(item);
        }
      }
    }
    _totalSales = _totalSales / 100;
    notifyListeners();
  }

  getAvgPrice()async{
    if(products.length != 0){
      int amountSum = 0;
      for(ProductModel product in products){
        amountSum = product.price;
      }
      _avgPrice = (amountSum / products.length) / 100;
    }
    notifyListeners();
  }

  getRating(){
    if(_restaurant.rates != 0){
      _restaurantRating = restaurant.rating / restaurant.rates;
    }
  }



  Future<bool> removeFromCart({Map cartItem}) async {
    print("THE PRODUC IS: ${cartItem.toString()}");

    try {
//      _userServicse.removeFromCart(userId: _user.uid, cartItem: cartItem);
      return true;
    } catch (e) {
      print("THE ERROR ${e.toString()}");
      return false;
    }
  }

  Future loadProductsByRestaurant({String restaurantId}) async {
    products = await _productServices.getProductsByRestaurant(id: restaurantId);
    notifyListeners();
  }
}
