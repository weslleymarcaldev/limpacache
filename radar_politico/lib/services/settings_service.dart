import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Preferências simples (tema, aceite de termos, usuário atual, chave de IA).
class SettingsService {
  late SharedPreferences _p;
  Future<void> init() async => _p = await SharedPreferences.getInstance();

  ThemeMode get themeMode => ThemeMode.values[_p.getInt('theme_mode') ?? 0];
  set themeMode(ThemeMode m) => _p.setInt('theme_mode', m.index);

  bool get onboardingConcluido => _p.getBool('onboarding_ok') ?? false;
  set onboardingConcluido(bool v) => _p.setBool('onboarding_ok', v);

  String? get termosAceitosEm => _p.getString('termos_aceitos_em');
  set termosAceitosEm(String? v) => v == null ? _p.remove('termos_aceitos_em') : _p.setString('termos_aceitos_em', v);

  String? get usuarioAtual => _p.getString('usuario_atual');
  set usuarioAtual(String? v) => v == null ? _p.remove('usuario_atual') : _p.setString('usuario_atual', v);

  String get apiKeyIa {
    final k = _p.getString('ia_api_key') ?? '';
    return k.isNotEmpty ? k : AppInfo.anthropicApiKeyBuild;
  }

  set apiKeyIa(String v) => _p.setString('ia_api_key', v.trim());

  String get modeloIa => _p.getString('ia_modelo') ?? AppInfo.modeloIaPadrao;
  set modeloIa(String v) => _p.setString('ia_modelo', v.trim().isEmpty ? AppInfo.modeloIaPadrao : v.trim());

  String get nomeJogador => _p.getString('nome_jogador') ?? '';
  set nomeJogador(String v) => _p.setString('nome_jogador', v);
}
