# Changelog

## [1.0.0] - 2026-11-07

Primeira versão do Doro List, um aplicativo de tarefas e Pomodoro com dados
armazenados no dispositivo.

### Tarefas

- Crie, edite, conclua e exclua tarefas, com opção de desfazer a última exclusão.
- Filtre por tarefas pendentes ou concluídas, reordene por arraste e limpe as concluídas.
- Exporte e importe backups de tarefas em JSON.

### Foco e histórico

- Vincule uma tarefa à sessão de foco ou use o cronômetro sem tarefa.
- Configure a duração do foco e das pausas, o número de sessões antes da pausa
  longa e o avanço automático. O padrão é 25 minutos de foco, 5 de pausa curta
  e 15 de pausa longa a cada quatro sessões.
- Pause, retome ou reinicie o cronômetro, defina uma duração personalizada e
  recupere a sessão ao reabrir o app.
- Consulte o resumo diário de tarefas concluídas, sessões e tempo de foco.

### Notificações e interface

- Receba avisos locais ao fim do foco e das pausas no Android, iOS e macOS,
  conforme as permissões do sistema.
- Acompanhe o cronômetro pela notificação de andamento no Android ou pela
  Atividade ao Vivo no iOS 16.1 ou posterior, em aparelhos compatíveis.
- Escolha entre os temas Sistema (padrão), Claro e Escuro em **Resumo → Tema**.
- Use a interface Cupertino no iOS ou Material Design no Android e desktop.

### Estrutura

- Arquitetura MVVM com ViewModels para o estado da interface e repositórios e
  serviços para armazenamento e integrações nativas.
