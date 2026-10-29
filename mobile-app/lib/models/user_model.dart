import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final int? id;
  final String email;
  final String password;
  final String fullName;
  final String? birthdate;
  final String? phone;
  final String? address;

  const UserModel({
    this.id,
    required this.email,
    required this.password,
    required this.fullName,
    this.birthdate,
    this.phone,
    this.address,
  });

  UserModel copyWith({
    int? id,
    String? email,
    String? password,
    String? fullName,
    String? birthdate,
    String? phone,
    String? address,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      birthdate: birthdate ?? this.birthdate,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }
}
