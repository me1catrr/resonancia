// Hitos de la línea temporal de C0.1–C0.4 y C0.9. Texto propio; cada hito
// enlaza su fuente (primaria salvo que `secundaria` sea true) y se comprobó
// el 23/10/2026. Las pruebas de recursos/js/componentes/ validan este fichero.
export const hitos = [
  {
    anio: 1950, categoria: "Fundamentos",
    titulo: "Turing pregunta si las máquinas pueden pensar",
    texto: "Propone sustituir esa pregunta por un juego de imitación: si una persona no distingue por escrito a la máquina de otra persona, ¿qué más hace falta?",
    fuente: { texto: "Turing (1950), Mind", url: "https://doi.org/10.1093/mind/LIX.236.433" },
  },
  {
    anio: 1955, categoria: "Fundamentos",
    titulo: "La propuesta de Dartmouth da nombre al campo",
    texto: "McCarthy, Minsky, Rochester y Shannon piden fondos para un encuentro de verano en 1956. El título de la propuesta usa la expresión «inteligencia artificial».",
    fuente: { texto: "Propuesta de 31/08/1955, reeditada en AI Magazine (2006)", url: "https://doi.org/10.1609/aimag.v27i4.1904" },
  },
  {
    anio: 1958, categoria: "Redes neuronales",
    titulo: "El perceptrón",
    texto: "Rosenblatt describe un modelo de neurona artificial cuyos pesos se ajustan con ejemplos: aprender en lugar de programar reglas.",
    fuente: { texto: "Rosenblatt (1958), Psychological Review", url: "https://doi.org/10.1037/h0042519" },
  },
  {
    anio: 1966, categoria: "Lenguaje y asistentes",
    titulo: "ELIZA conversa sin entender",
    texto: "Un programa con reglas de sustitución de texto mantiene diálogos verosímiles. Su autor advierte de lo fácil que es atribuirle comprensión.",
    fuente: { texto: "Weizenbaum (1966), Communications of the ACM", url: "https://doi.org/10.1145/365153.365168" },
  },
  {
    anio: 1986, categoria: "Redes neuronales",
    titulo: "Retropropagación del error",
    texto: "Rumelhart, Hinton y Williams muestran cómo entrenar redes con capas ocultas propagando el error hacia atrás, la base del entrenamiento actual.",
    fuente: { texto: "Rumelhart, Hinton y Williams (1986), Nature", url: "https://doi.org/10.1038/323533a0" },
  },
  {
    anio: 1997, categoria: "Redes neuronales",
    titulo: "Memoria a corto y largo plazo (LSTM)",
    texto: "Una red recurrente capaz de conservar información durante muchos pasos; dominó el tratamiento de secuencias hasta los transformers.",
    fuente: { texto: "Hochreiter y Schmidhuber (1997), Neural Computation", url: "https://doi.org/10.1162/neco.1997.9.8.1735" },
  },
  {
    anio: 2012, categoria: "Redes neuronales",
    titulo: "Redes convolucionales profundas en ImageNet",
    texto: "Una red convolucional profunda clasifica las imágenes de ImageNet; su éxito suele tomarse como el arranque del auge del aprendizaje profundo.",
    fuente: { texto: "Krizhevsky, Sutskever y Hinton (2012), NIPS", url: "https://papers.nips.cc/paper_files/paper/2012/hash/c399862d3b9d6b76c8436e924a68c45b-Abstract.html" },
  },
  {
    anio: 2017, categoria: "Lenguaje y asistentes",
    titulo: "El transformer",
    texto: "Una arquitectura basada solo en mecanismos de atención, sin recurrencia. Es la base de los modelos de lenguaje actuales, Claude incluido.",
    fuente: { texto: "Vaswani et al. (2017), arXiv:1706.03762", url: "https://arxiv.org/abs/1706.03762" },
  },
  {
    anio: 2022, categoria: "Lenguaje y asistentes",
    titulo: "Los asistentes conversacionales llegan al gran público",
    texto: "OpenAI abre ChatGPT el 30 de noviembre como versión de prueba gratuita. En pocos días lo usan millones de personas.",
    fuente: { texto: "Wikipedia, «ChatGPT» (el anuncio original no fue accesible)", url: "https://en.wikipedia.org/wiki/ChatGPT" },
    secundaria: true,
  },
  {
    anio: 2023, categoria: "Normativa y gobernanza",
    titulo: "Marco de gestión de riesgos de la IA del NIST",
    texto: "Estados Unidos publica el 26 de enero un marco de uso voluntario para identificar, medir y gestionar los riesgos de la IA en las organizaciones.",
    fuente: { texto: "NIST, AI RMF 1.0", url: "https://www.nist.gov/itl/ai-risk-management-framework" },
  },
  {
    anio: 2023, categoria: "Claude y agentes",
    titulo: "Anthropic presenta Claude",
    texto: "El 14 de marzo se anuncian Claude y Claude Instant, accesibles por chat y por API.",
    fuente: { texto: "Anthropic, «Introducing Claude»", url: "https://www.anthropic.com/news/introducing-claude" },
  },
  {
    anio: 2024, categoria: "Normativa y gobernanza",
    titulo: "Reglamento europeo de inteligencia artificial",
    texto: "El Reglamento (UE) 2024/1689 regula la IA según su nivel de riesgo y exige supervisión humana en los sistemas de alto riesgo. Sus fechas de aplicación se han reformado después.",
    fuente: { texto: "Reglamento (UE) 2024/1689, EUR-Lex", url: "https://eur-lex.europa.eu/eli/reg/2024/1689/oj" },
  },
  {
    anio: 2024, categoria: "Redes neuronales",
    titulo: "Nobel de Física para las redes neuronales",
    texto: "Hopfield y Hinton reciben el premio por descubrimientos que hicieron posible el aprendizaje automático con redes neuronales artificiales.",
    fuente: { texto: "Science News (el sitio del Nobel no fue accesible)", url: "https://sciencenews.org/article/nobel-physics-2024-machine-learning" },
    secundaria: true,
  },
  {
    anio: 2024, categoria: "Claude y agentes",
    titulo: "Protocolo de contexto de modelos (MCP)",
    texto: "El 25 de noviembre Anthropic publica un estándar abierto para conectar asistentes con datos y herramientas externas.",
    fuente: { texto: "Anthropic, «Introducing the Model Context Protocol»", url: "https://www.anthropic.com/news/model-context-protocol" },
  },
  {
    anio: 2025, categoria: "Claude y agentes",
    titulo: "Claude Code, un agente en la terminal",
    texto: "El 24 de febrero aparece como vista previa limitada: busca y lee código, edita ficheros y ejecuta pruebas desde la terminal.",
    fuente: { texto: "Anthropic, «Claude 3.7 Sonnet and Claude Code»", url: "https://www.anthropic.com/news/claude-3-7-sonnet" },
  },
];
