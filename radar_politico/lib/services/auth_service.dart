import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants.dart';
import '../models/conteudo.dart';

class AuthException implements Exception {
  final String mensagem;
  const AuthException(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Login com Conta Google (google_sign_in 7.x). Se o projeto não estiver
/// configurado no Google Cloud (ver README), o login falha com mensagem clara
/// e o app continua funcionando no modo visitante.
class AuthService {
  bool _iniciado = false;

  Future<void> _init() async {
    if (_iniciado) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppInfo.googleServerClientId.isEmpty ? null : AppInfo.googleServerClientId,
    );
    _iniciado = true;
  }

  Future<Usuario> entrarComGoogle() async {
    try {
      await _init();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthException('Login com Google não é suportado neste dispositivo.');
      }
      final conta = await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
      return Usuario(
        id: 'google:${conta.id}',
        nome: conta.displayName ?? conta.email,
        email: conta.email,
        tipo: 'google',
        fotoUrl: conta.photoUrl,
      );
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          throw const AuthException('Login cancelado.');
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const AuthException(
              'O login com Google ainda não foi configurado nesta versão do app. Você pode continuar como visitante; seus dados ficam salvos no aparelho.');
        default:
          throw AuthException('Não foi possível entrar com Google (${e.code.name}). Tente novamente ou continue sem login.');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw const AuthException(
          'Não foi possível entrar com Google agora. Verifique a conexão ou continue sem login.');
    }
  }

  Future<void> sair() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Sair localmente mesmo que o provedor falhe.
    }
  }
}
