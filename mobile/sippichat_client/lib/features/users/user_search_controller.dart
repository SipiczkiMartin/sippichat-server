import 'package:flutter/material.dart';
import 'package:sippichat_client/features/users/models/user_search_result.dart';
import 'package:sippichat_client/features/users/user_search_service.dart';

class UserSearchController  extends ChangeNotifier{
  final UserSearchService searchService;

  UserSearchController(this.searchService);

  List<UserSearchResult> _results = [];
  List<UserSearchResult> get results => _results;

  bool _loading = false;
  bool get loading => _loading;

  String _query = '';
  String get query => _query;

  Future search(String query) async{
    _query = query.trim();

    if(_query.length < 2) {
      _results = [];
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try{
      _results = await searchService.searchUsers(_query);
    }finally{
      _loading = false;
      notifyListeners();
    }
  }

  void clear(){
    _query = '';
    _results = [];
    notifyListeners();
  }
}