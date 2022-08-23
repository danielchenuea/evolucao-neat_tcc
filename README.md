# Neuro-Evolução aplicado na conclusão de jogos, utilizando Neat. TCC

Saudações!

Este aqui é um repositório referente ao trabalho de TCC desenvolvido por mim (Daniel!). Se você não sabe do que se trata, eu tento escrever um breve resumo para os desavisados. Para aqueles que tiverem um pouco mais de paciência, eu tenho minha monografia ([AQUI](http://repositorioinstitucional.uea.edu.br//handle/riuea/4015)).

Além disso, eu faço um breve tutorial de como fazer as coisas funcionarem.

Uma última coisa a se mencionar, este trabalho foi altamente inspirado no trabalho feito pelo Youtuber [Sethbling](https://www.youtube.com/watch?v=qv6UVOQ0F44&t). O trabalho dele inspirou minha monografia e ajudou bastante na codificação.

## Introdução geral

Assim como está no título, a ideia deste trabalho é a criação de uma [rede neural](https://en.wikipedia.org/wiki/Artificial_neural_network), utilizando [neuro-evolução](https://en.wikipedia.org/wiki/Neuroevolution) e o método [NEAT](https://en.wikipedia.org/wiki/Neuroevolution_of_augmenting_topologies) (links para wikipedia). Fazendo isso, o algoritmo treina redes neurais de maneira autônoma para que ele consiga jogar os jogos de maneira autônoma! (através de neuro-evolução!).

O algoritmo foi escrito em LUA para funcionar junto com o emulador de BizHawk! O script pode treinar redes do zero, mas eu também deixei disponível uma geração de treinamento completo!

Para mais informações, leia meu TCC!

## Como fazer funcionar

Para esse algoritmo funcionar, você deve baixar o emulador [BizHawk](https://tasvideos.org/Bizhawk) e uma ROM **Global/Americana** do jogo Super Mario Bros (usem o Google!).

Depois de baixado e extraído os dois, coloquem o conteúdo da pasta *neat_resources* na pasta LUA.

Assim que tiver o emulador aberto (EmuHawk), carregue o jogo e carregue o script no BizHawk.

Se estiver executando o algoritmo, você pode carregar a geração treinada e/ou iniciar uma nova!
(PS: para treinar a rede neural, eu aumentei a velocidade de execução no emulador, mas ainda assim demorou cerca de **70h**!)

## Instruções básicas de uso

Você vai ter:
- 1 espaço pro colocar o nome do arquivo pra poder salvar/carregar. (Coloque o nome do arquivo aqui!)
- 1 Botão de Salvar no arquivo.
- 1 Botão de Carregar o arquivo.
- 1 Botão para recomeçar o treinamento do zero.
- 1 Botão de "Melhor" para poder desmontrar a melhor rede daquela geração.
- 1 *Checkbox* para esconder o mapa de ações
- 1 *Checkbox* para esconder as informações adicionais.
- Além de 1 indicador da distância (fitness) máximo obtido!

Imagem de ilustração!
![EmuHawk_UiJKFPkie5](https://user-images.githubusercontent.com/55398457/186278606-3f857f6d-f5a3-429c-84df-c49a8fc5c048.png)

## Créditos

Quero agradecer ao meu orientador pela paciência e tempo =^).
Mas também agradeço ao Sethbling, pela ideia e pela disponibilidade de código.

É só isso, boa noite.
