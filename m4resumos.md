Resumo
Plugins no Jenkins
O Jenkins é uma ferramenta que funciona por plugins. Tem literalmente plugins para tudo que você imaginar.

Uma coisa interessante é configurar a instalação dos plugins como código direto no Helm Chart:

additionalPlugins:
  - basic-branch-build-strategies:81.v05e333931c7d
  - multibranch-scan-webhook-trigger:1.0.9
  - pipeline-stage-view:2.34
  - discord-notifier:241.v448b_ccd0c0d6

  https://plugins.jenkins.io/