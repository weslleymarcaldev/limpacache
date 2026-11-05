import 'package:flutter/material.dart';

class TermosScreen extends StatelessWidget {
  const TermosScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Termos e privacidade')),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          Text('Termos de uso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('1. O Radar Político é uma ferramenta educativa e informativa. Não recomenda votos e não defende partidos, candidatos, governos ou ideologias.\n\n'
              '2. Os resultados dos testes e a compatibilidade com políticos são estimativas baseadas nas respostas do usuário e em informações públicas, que podem estar incompletas ou desatualizadas.\n\n'
              '3. O usuário é responsável pelo conteúdo que envia em reportes de correção. Mensagens ofensivas não são analisadas.\n\n'
              '4. O conteúdo pode ser atualizado a qualquer momento para corrigir erros ou incluir novas informações.\n\n'
              '5. O uso do aplicativo é gratuito e voluntário.', style: TextStyle(height: 1.45)),
          SizedBox(height: 20),
          Text('Política de privacidade', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('• Dados coletados: respostas aos testes, resultados, pontuações do quiz e reportes de correção. No login com Google: nome, e-mail, foto e identificador da conta.\n\n'
              '• Armazenamento: todos os dados ficam no banco local do aparelho (SQLite). Nesta versão não há servidor do aplicativo.\n\n'
              '• Compartilhamento: o app não vende nem compartilha dados. Ao reportar uma correção com IA ativada, apenas o texto do reporte (trecho, motivo e fonte) é enviado ao provedor de IA configurado (Anthropic). Suas respostas aos testes e seu perfil não são enviados.\n\n'
              '• Opiniões políticas são dados pessoais sensíveis segundo a LGPD (Lei 13.709/2018, art. 5º, II). Por isso ficam apenas no seu aparelho e você pode apagá-las a qualquer momento em Configurações > Apagar meus dados.\n\n'
              '• Compartilhamento de resultados só acontece quando você toca em "Compartilhar".', style: TextStyle(height: 1.45)),
        ]),
      );
}
