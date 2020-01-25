import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:linkedin_login/src/linked_in_auth_response_wrapper.dart';
import 'package:linkedin_login/src/linked_in_user_model.dart';
import 'package:linkedin_login/src/linked_in_authorization_webview.dart';
import 'package:http/http.dart';

/// This class is responsible to fetch all information for user after we get
/// token and code from LinkedIn
class LinkedInUserWidget extends StatelessWidget {
  final Function onGetUserProfile;
  final Function catchError;
  final String redirectUrl;
  final String clientId, clientSecret;
  final AppBar appBar;
  final bool destroySession;
  final _ViewModel _viewModel;

  /// Client state parameter needs to be unique range of characters - random one
  LinkedInUserWidget({
    @required this.onGetUserProfile,
    @required this.redirectUrl,
    @required this.clientId,
    @required this.clientSecret,
    this.catchError,
    this.destroySession = false,
    this.appBar,
  })  : assert(onGetUserProfile != null),
        assert(redirectUrl != null),
        assert(clientId != null),
        assert(clientSecret != null),
        _viewModel = const _ViewModel();

  @override
  Widget build(BuildContext context) => LinkedInAuthorization(
        destroySession: destroySession,
        redirectUrl: redirectUrl,
        clientSecret: clientSecret,
        clientId: clientId,
        appBar: appBar,
        onCallBack: (AuthorizationCodeResponse authCodeResponse) {
          if (_viewModel.isAuthorizationSuccess(authCodeResponse)) {
            _viewModel.handleApiCalls(authCodeResponse).then(
                (LinkedInUserModel codeResponse) =>
                    onGetUserProfile(codeResponse));
          } else if (_viewModel.containsError(authCodeResponse)) {
            catchError(authCodeResponse.error);
          }
        },
      );
}

@immutable
class _ViewModel {
  const _ViewModel();

  get _getUrlUsers => 'https://api.linkedin.com/v2/me';

  get _getUrlUserEmail =>
      'https://api.linkedin.com/v2/emailAddress?q=members&projection=(elements*(handle~))';

  Future<LinkedInUserModel> handleApiCalls(
      AuthorizationCodeResponse codeResponse) async {
    final Response basicProfile = await get(
      _getUrlUsers,
      headers: _generateAuthHeaders(codeResponse),
    );

    final Response emailProfile = await get(
      _getUrlUserEmail,
      headers: _generateAuthHeaders(codeResponse),
    );

    return _generateUserProfile(
      basicProfile,
      emailProfile,
      codeResponse.accessToken,
    );
  }

  String _generateToken(LinkedInTokenObject token) {
    return 'Bearer ${token?.accessToken ?? ''}';
  }

  Map<String, String> _generateAuthHeaders(
      AuthorizationCodeResponse codeResponse) {
    return {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.authorizationHeader: _generateToken(codeResponse.accessToken),
    };
  }

  LinkedInUserModel _generateUserProfile(Response jsonBasicProfile,
      Response jsonEmail, LinkedInTokenObject token) {
    return LinkedInUserModel.fromJson(json.decode(jsonBasicProfile.body))
      ..email = LinkedInProfileEmail.fromJson(
        json.decode(jsonEmail.body),
      )
      ..token = token;
  }

  bool isAuthorizationSuccess(AuthorizationCodeResponse codeResponse) =>
      codeResponse != null && codeResponse.accessToken != null;

  bool containsError(AuthorizationCodeResponse codeResponse) =>
      codeResponse.error != null && codeResponse.error.description.isNotEmpty;
}
