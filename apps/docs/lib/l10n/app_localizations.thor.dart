// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder).
// The messages of lib/l10n/*.arb (template: app_es.arb).
// ignore_for_file: type=lint

import 'package:thor_ui/thor_ui.dart';

/// The app's messages, one subclass per locale of `lib/l10n/`.
///
/// ```dart
/// ThorApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   child: …,
/// )
/// AppLocalizations.of(context).someMessage
/// ```
abstract class AppLocalizations {
  /// Messages in [locale] (`es`, `pt_BR`).
  AppLocalizations(String locale) : localeName = locale;

  /// The locale these messages are in.
  final String localeName;

  /// The messages of the nearest `Localizations` (`ThorApp`).
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// Loads these messages for `Localizations`.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// For `ThorApp(localizationsDelegates:)`.
  static const List<LocalizationsDelegate<Object?>> localizationsDelegates = [
    delegate,
  ];

  /// The locales of `lib/l10n/`, the template's first.
  static const List<Locale> supportedLocales = [Locale('es'), Locale('en')];

  /// In the template: `Thor docs`
  String get siteName;

  /// In the template: `Thor: la API de widgets de Flutter, renderizada como HTML y CSS en el servidor. Guías, catálogo de widgets y referencia de API.`
  String get siteDescription;

  /// In the template: `Thor: la API de widgets de Flutter, renderizada como HTML y CSS.`
  String get siteImageAlt;

  /// In the template: `es_MX`
  String get siteOpenGraphLocale;

  /// In the template: `Guía`
  String get navGuide;

  /// In the template: `Componentes`
  String get navComponents;

  /// In the template: `Ejemplos`
  String get navExamples;

  /// In the template: `API`
  String get navApi;

  /// In the template: `Cambios`
  String get navChanges;

  /// In the template: `Repositorio en GitHub`
  String get navGithub;

  /// In the template: `Empezar`
  String get sectionGetStarted;

  /// In the template: `Fundamentos`
  String get sectionFundamentals;

  /// In the template: `Arquitectura`
  String get sectionArchitecture;

  /// In the template: `Interfaz`
  String get sectionInterface;

  /// In the template: `Datos y estado`
  String get sectionDataAndState;

  /// In the template: `Probar y publicar`
  String get sectionTestAndDeploy;

  /// In the template: `Componentes`
  String get sectionComponents;

  /// In the template: `Ejemplos`
  String get sectionExamples;

  /// In the template: `Qué es Thor, cómo instalarlo, una app completa paso a paso y el mapa desde Flutter.`
  String get sectionGetStartedSummary;

  /// In the template: `Widgets, layout, interactividad, rutas y datos de la página: lo que toda app usa.`
  String get sectionFundamentalsSummary;

  /// In the template: `View, ViewModel, Repository y Service con los nombres de la guía de arquitectura de Flutter, y qué corre dónde.`
  String get sectionArchitectureSummary;

  /// In the template: `Tema, estilos, animación, gestos, diálogos, accesibilidad e idiomas.`
  String get sectionInterfaceSummary;

  /// In the template: `El ViewModel a fondo, acciones del servidor, formularios, datos en vivo, listas largas, paquetes y seguridad.`
  String get sectionDataAndStateSummary;

  /// In the template: `Pruebas por capa, el comando thor, sitio estático o servidor, y SEO.`
  String get sectionTestAndDeploySummary;

  /// In the template: `Cada widget con su demo viva, su código y sus parámetros.`
  String get sectionComponentsSummary;

  /// In the template: `Apps pequeñas y completas (las tareas de 7GUIs y una página de contenido) y cuatro patrones de interacción.`
  String get sectionExamplesSummary;

  /// In the template: `Qué es Thor`
  String get pageWhatIsThor;

  /// In the template: `Instalación`
  String get pageInstallation;

  /// In the template: `Tu primera app`
  String get pageFirstApp;

  /// In the template: `Si vienes de Flutter`
  String get pageFromFlutter;

  /// In the template: `Widgets`
  String get pageWidgets;

  /// In the template: `Layout`
  String get pageLayout;

  /// In the template: `Interactividad`
  String get pageInteractivity;

  /// In the template: `Rutas y navegación`
  String get pageNavigation;

  /// In the template: `Leer datos`
  String get pageReadingData;

  /// In the template: `Arquitectura de una app`
  String get pageAppArchitecture;

  /// In the template: `Estructura del proyecto`
  String get pageProjectStructure;

  /// In the template: `Capa de interfaz`
  String get pageUiLayer;

  /// In the template: `Capa de datos`
  String get pageDataLayer;

  /// In the template: `Patrones`
  String get pagePatterns;

  /// In the template: `Tema y estilos`
  String get pageThemeAndStyles;

  /// In the template: `Estilos avanzados`
  String get pageAdvancedStyles;

  /// In the template: `Animaciones`
  String get pageAnimations;

  /// In the template: `Gestos`
  String get pageGestures;

  /// In the template: `Diálogos y menús`
  String get pageDialogsAndMenus;

  /// In the template: `Listas largas`
  String get pageLongLists;

  /// In the template: `Accesibilidad`
  String get pageAccessibility;

  /// In the template: `Idiomas`
  String get pageLocalization;

  /// In the template: `Estado`
  String get pageState;

  /// In the template: `Servidor y acciones`
  String get pageServerAndActions;

  /// In the template: `Datos en vivo`
  String get pageLiveData;

  /// In the template: `Formularios`
  String get pageForms;

  /// In the template: `Sesión y seguridad`
  String get pageSessionAndSecurity;

  /// In the template: `Paquetes de pub`
  String get pagePubPackages;

  /// In the template: `Pruebas`
  String get pageTesting;

  /// In the template: `El comando thor`
  String get pageCli;

  /// In the template: `Compilar y publicar`
  String get pageBuildAndDeploy;

  /// In the template: `SEO`
  String get pageSeo;

  /// In the template: `Ejemplos`
  String get pageExamples;

  /// In the template: `Componentes`
  String get pageComponents;

  /// In the template: `Botones`
  String get pageComponentsButtons;

  /// In the template: `Entradas`
  String get pageComponentsInputs;

  /// In the template: `Selección`
  String get pageComponentsSelection;

  /// In the template: `Contenido`
  String get pageComponentsContent;

  /// In the template: `Navegación`
  String get pageComponentsNavigation;

  /// In the template: `Avisos`
  String get pageComponentsFeedback;

  /// In the template: `Qué corre dónde`
  String get pageHowItWorks;

  /// In the template: `Flutter embebido`
  String get pageEmbeddedFlutter;

  /// In the template: `Empezar`
  String get footerStart;

  /// In the template: `Referencia`
  String get footerReference;

  /// In the template: `Recursos`
  String get footerResources;

  /// In the template: `Errores`
  String get footerErrors;

  /// In the template: `GitHub`
  String get footerGithub;

  /// In the template: `Editar en GitHub`
  String get docEditPage;

  /// In the template: `Copiar como Markdown`
  String get docCopyMarkdown;

  /// In the template: `Acciones de la página`
  String get docPageActions;

  /// In the template: `Esta página todavía no está disponible en tu idioma: se muestra la versión en {language}.`
  String docFallbackNotice(String language);

  /// In the template: `Nota`
  String get calloutNote;

  /// In the template: `Consejo`
  String get calloutTip;

  /// In the template: `Importante`
  String get calloutWarning;

  /// Another label a callout quote may use for the warning tone (`> **Ojo:**`); the page shows calloutWarning.
  ///
  /// In the template: `Ojo`
  String get calloutWarningAlias;

  /// In the template: `Cuidado`
  String get calloutDanger;

  /// In the template: `Diferencia con Flutter`
  String get calloutFlutter;

  /// In the template: `Terminal`
  String get codeTerminal;

  /// In the template: `primero`
  String get ladderFirst;

  /// In the template: `último recurso`
  String get ladderLast;

  /// In the template: `El ancho de la caja se ajusta desde su esquina inferior derecha.`
  String get stageResizeHint;

  /// In the template: `Vista previa`
  String get previewLabel;

  /// In the template: `HTML generado`
  String get exampleTabHtml;

  /// In the template: `CSS generado`
  String get exampleTabCss;

  /// In the template: `Repetir`
  String get benchReplay;

  /// In the template: `Interruptores`
  String get benchSwitches;

  /// In the template: `Niveles`
  String get benchLevels;

  /// In the template: `Código de la app`
  String get benchAppCode;

  /// In the template: `Inicio`
  String get benchSegmentStart;

  /// In the template: `Centro`
  String get benchSegmentCenter;

  /// In the template: `Final`
  String get benchSegmentEnd;

  /// In the template: `Entre`
  String get benchSegmentBetween;

  /// In the template: `mainAxisAlignment en una fila`
  String get benchRowTitle;

  /// In the template: `mainAxisAlignment reparte el espacio libre de la fila; spacing fija la separación entre sus hijos.`
  String get benchRowDescription;

  /// In the template: `Alineación`
  String get benchRowAlignment;

  /// In the template: `Espacio`
  String get benchRowSpacing;

  /// In the template: `Una tarjeta con su estilo`
  String get benchCardTitle;

  /// In the template: `La tarjeta lee su radio, su espacio interior y su relleno de campos de estado del ViewModel.`
  String get benchCardDescription;

  /// In the template: `Relleno`
  String get benchCardFill;

  /// In the template: `Suave`
  String get benchCardFillSoft;

  /// In the template: `Pleno`
  String get benchCardFillSolid;

  /// In the template: `Radio`
  String get benchCardRadius;

  /// In the template: `Espacio`
  String get benchCardPadding;

  /// In the template: `Un contador con paso`
  String get benchCounterTitle;

  /// In the template: `El paso es otro campo de estado del ViewModel: cada botón llama a un método que lo lee.`
  String get benchCounterDescription;

  /// In the template: `Paso`
  String get benchCounterStep;

  /// In the template: `Widget`
  String get layersOrdersViewKind;

  /// In the template: `ViewModel (ThorState)`
  String get layersOrdersViewModelKind;

  /// In the template: `Clase`
  String get layersOrdersRepositoryKind;

  /// In the template: `Cliente HTTP`
  String get layersOrdersServiceKind;

  /// In the template: `Middleware`
  String get layersOrdersInjectionKind;

  /// In the template: `Tabla de rutas`
  String get layersOrdersNavigationKind;

  /// In the template: `dart test`
  String get layersOrdersTestsKind;

  /// In the template: `Muestra los datos del ViewModel y le avisa lo que hace el usuario. No tiene lógica: lee el ViewModel y llama a sus métodos.`
  String get layersOrdersViewDescription;

  /// In the template: `Guarda los datos de la pantalla y las acciones que la vista puede pedir. En Thor es un ThorState: una query lee, un command cambia.`
  String get layersOrdersViewModelDescription;

  /// In the template: `La fuente única de los pedidos: le pide al servicio, convierte la respuesta en objetos Order y esconde de dónde vienen los datos.`
  String get layersOrdersRepositoryDescription;

  /// In the template: `Habla con el backend y nada más. En Thor usa ThorHttpClient en el servidor.`
  String get layersOrdersServiceDescription;

  /// In the template: `Entrega a cada capa lo que necesita sin que la pida por su cuenta. En Flutter es un Provider; en Thor, un middleware que deja el repositorio en la petición con un ContextKey.`
  String get layersOrdersInjectionDescription;

  /// In the template: `Dice qué pantalla vive en qué dirección. En Flutter es go_router; en Thor, una ThorRoute por página en un ThorRouter.`
  String get layersOrdersNavigationDescription;

  /// In the template: `Cada capa se prueba sola: el repositorio con un servicio falso, el ViewModel con un repositorio falso y la vista con los datos que quieras.`
  String get layersOrdersTestsDescription;

  /// In the template: `API y errores`
  String get llmsReferenceHeading;

  /// In the template: `API de thor_ui`
  String get llmsApiTitle;

  /// In the template: `clases, funciones y constructores públicos, por carpeta`
  String get llmsApiDescription;

  /// In the template: `Códigos de error`
  String get llmsErrorsTitle;

  /// In the template: `cada 'THOR-xxx' con qué pasó, por qué y cómo se arregla`
  String get llmsErrorsDescription;

  /// In the template: `Todo en un archivo`
  String get llmsFullTitle;

  /// In the template: `la guía completa en Markdown`
  String get llmsFullDescription;

  /// In the template: `Referencia de API`
  String get apiEyebrow;

  /// In the template: `{name} · API`
  String apiPageTitle(String name);

  /// In the template: `Referencia de API de {name}: clases, funciones y constructores públicos.`
  String apiPageDescription(String name);

  /// In the template: `Clases, funciones y constructores públicos.`
  String get apiSummary;

  /// In the template: `Widget · {topic}`
  String widgetEyebrow(String topic);

  /// In the template: `{name} · Widget`
  String widgetPageTitle(String name);

  /// In the template: `El widget {name} de Thor: firma, parámetros y documentación`
  String widgetPageDescription(String name);

  /// In the template: `Códigos de error`
  String get errorsEyebrow;

  /// In the template: `Versiones`
  String get changesEyebrow;

  /// In the template: `Cambios`
  String get changesTitle;

  /// In the template: `Cambios de {name}`
  String changesPackageTitle(String name);

  /// In the template: `Sin publicar`
  String get changesVersionUnreleased;

  /// In the template: `{version} (sin publicar)`
  String changesVersionNotPublished(String version);

  /// In the template: `Lo que cambia en '{package}' ({role}) para quien hace una app. Thor todavía no publica una versión: lo de «Sin publicar» ya está en el código y llegará en la próxima.`
  String changesPackageIntro(String package, String role);

  /// In the template: `Cada cambio se cuenta como lo escriben los autores del paquete, en inglés, igual que el código.`
  String get changesLanguageNote;

  /// In the template: `Cambios que rompen`
  String get changesBreakingTitle;

  /// In the template: `Nuevo`
  String get changesGroupAdded;

  /// In the template: `Cambió`
  String get changesGroupChanged;

  /// In the template: `Deprecado (usa X)`
  String get changesGroupDeprecated;

  /// In the template: `Qué cambió en Thor, por paquete, y qué hacer en tu app cuando un nombre se va. Thor todavía no publica una versión: aquí está lo que ya entró y llegará en la primera.`
  String get changesIndexIntro;

  /// In the template: `Migrar`
  String get changesMigrateHeading;

  /// In the template: `Un nombre público no desaparece de golpe: pasa una versión menor como '@Deprecated("Usa X")', con un alias cuando se puede, y el analizador te lo marca. Esto es lo que ya está deprecado o rompe, y qué usar en su lugar.`
  String get changesMigrateIntro;

  /// In the template: `Nada está deprecado ni rompe por ahora.`
  String get changesMigrateNone;

  /// In the template: `Por paquete`
  String get changesPackagesHeading;

  /// In the template: `Paquete`
  String get changesColPackage;

  /// In the template: `Qué es`
  String get changesColRole;

  /// In the template: `Cambios sin publicar`
  String get changesColCount;

  /// In the template: `los widgets y el renderizado`
  String get changesRoleThorUi;

  /// In the template: `valores de estilo y CSS`
  String get changesRoleThorStyle;

  /// In the template: `el estado de la página: ThorState, query y command`
  String get changesRoleThorEngine;

  /// In the template: `rutas, datos, sesión y exportación`
  String get changesRoleThorServer;

  /// In the template: `el sistema de diseño`
  String get changesRoleThorStudio;

  /// In the template: `los errores THOR-* del build`
  String get changesRoleThorBuilder;

  /// In the template: `el comando 'thor'`
  String get changesRoleThorCli;

  /// In the template: `las reglas del analizador`
  String get changesRoleThorLints;

  /// In the template: `las herramientas de test`
  String get changesRoleThorTest;

  /// In the template: `El widget '{name}'.`
  String widgetDefaultDoc(String name);

  /// In the template: `Ejemplo`
  String get widgetExampleHeading;

  /// In the template: `Firma`
  String get widgetSignatureHeading;

  /// In the template: `Parámetros`
  String get widgetParamsHeading;

  /// In the template: `Parámetros de '{name}'`
  String widgetParamsOf(String name);

  /// In the template: `Parámetro`
  String get widgetColParam;

  /// In the template: `Tipo`
  String get widgetColType;

  /// In the template: `Qué hace`
  String get widgetColDoc;

  /// In the template: `(requerido)`
  String get widgetRequired;

  /// In the template: `Deprecado`
  String get widgetDeprecated;

  /// In the template: `En Flutter`
  String get widgetInFlutterHeading;

  /// In the template: `Es el mismo widget que '{name}' de Flutter: [documentación de Flutter]({url}).`
  String widgetFlutterSame(String name, String url);

  /// In the template: `'{name}' no tiene un equivalente directo en Flutter: es una pieza propia de Thor.`
  String widgetFlutterNone(String name);

  /// In the template: `Página del widget`
  String get widgetPageLink;

  /// In the template: `Símbolos`
  String get apiSymbolsHeading;

  /// In the template: `Sí`
  String get badgeYes;

  /// In the template: `No`
  String get badgeNo;

  /// In the template: `Parcial`
  String get badgePartial;

  /// In the template: `No encontramos esa página`
  String get errorNotFoundTitle;

  /// In the template: `Quizá cambió de nombre. Empieza por la guía o busca en la API.`
  String get errorNotFoundLead;

  /// In the template: `Algo salió mal`
  String get errorGenericTitle;

  /// In the template: `Inténtalo de nuevo en un momento.`
  String get errorGenericLead;

  /// In the template: `El punto de partida de la guía`
  String get errorStartSubtitle;

  /// In the template: `No hay esa guía`
  String get notFoundGuide;

  /// In the template: `No hay ese paquete`
  String get notFoundPackage;

  /// In the template: `No hay esa carpeta`
  String get notFoundFolder;

  /// In the template: `No hay ese widget`
  String get notFoundWidget;

  /// In the template: `No hay ese código`
  String get notFoundCode;

  /// In the template: `No hay códigos`
  String get notFoundCodes;

  /// In the template: `No hay cambios de ese paquete`
  String get notFoundChanges;

  /// In the template: `Buscar`
  String get searchTitle;

  /// In the template: `Busca en las guías, la referencia de API y los códigos de error de Thor.`
  String get searchDescription;

  /// In the template: `Buscar en los docs`
  String get searchHint;

  /// In the template: `La búsqueda necesita JavaScript. Sin él, usa el menú de la guía o busca en el sitio desde tu buscador.`
  String get searchNeedsJs;

  /// In the template: `Escribe lo que buscas.`
  String get searchPrompt;

  /// In the template: `1 resultado para «{query}»`
  String searchResultOne(String query);

  /// In the template: `{count} resultados para «{query}»`
  String searchResultMany(String count, String query);

  /// In the template: `Ver {count} más`
  String searchShowMore(String count);

  /// In the template: `Ver menos`
  String get searchShowLess;

  /// In the template: `Mejor coincidencia`
  String get searchBestMatch;

  /// In the template: `Nada para «{query}». Prueba con otra palabra.`
  String searchNone(String query);

  /// In the template: `La búsqueda no está disponible en esta copia del sitio.`
  String get searchNoIndex;

  /// In the template: `Thor · la API de Flutter, el HTML de la web`
  String get homeMetaTitle;

  /// In the template: `Escribe páginas web con los widgets de Flutter en Dart; llegan al navegador como HTML semántico y CSS.`
  String get homeMetaDescription;

  /// In the template: `Errores`
  String get navErrors;

  /// In the template: `Licencia MIT. Este sitio está construido con Thor.`
  String get footerLegal;

  /// In the template: `Escribe la web con widgets de Flutter.`
  String get homeHeroTitle;

  /// In the template: `Thor convierte tu código Dart en HTML semántico y CSS. El JavaScript llega solo donde hay estado.`
  String get homeHeroLead;

  /// In the template: `Empezar`
  String get homeCtaStart;

  /// In the template: `Si vienes de Flutter`
  String get homeCtaFlutter;

  /// In the template: `crossAxisAlignment en una columna`
  String get exLayoutColumnTitle;

  /// In the template: `crossAxisAlignment decide el ancho de cada hijo y su posición dentro de la columna.`
  String get exLayoutColumnDescription;

  /// In the template: `Alinear`
  String get exLayoutColumnAlignment;

  /// In the template: `Llenar`
  String get exLayoutColumnStretch;

  /// In the template: `Expanded y Flexible en una fila`
  String get exLayoutFlexTitle;

  /// In the template: `Dos hijos se reparten el ancho que deja el hijo de tamaño fijo: Expanded lo llena y Flexible lo usa solo si lo necesita.`
  String get exLayoutFlexDescription;

  /// In the template: `Widget`
  String get exLayoutFlexKind;

  /// In the template: `Expanded`
  String get exLayoutFlexExpanded;

  /// In the template: `Flexible`
  String get exLayoutFlexFlexible;

  /// In the template: `Flex de B`
  String get exLayoutFlexFactor;

  /// In the template: `Positioned en un Stack`
  String get exLayoutStackTitle;

  /// In the template: `El primer hijo define el tamaño del Stack; Positioned coloca el otro hijo a una distancia fija de una esquina.`
  String get exLayoutStackDescription;

  /// In the template: `Esquina`
  String get exLayoutStackCorner;

  /// In the template: `↖`
  String get exLayoutStackTopLeft;

  /// In the template: `↗`
  String get exLayoutStackTopRight;

  /// In the template: `↙`
  String get exLayoutStackBottomLeft;

  /// In the template: `↘`
  String get exLayoutStackBottomRight;

  /// In the template: `Distancia`
  String get exLayoutStackInset;

  /// In the template: `Wrap con etiquetas`
  String get exLayoutWrapTitle;

  /// In the template: `Los hijos que no caben en el ancho disponible pasan a la línea siguiente.`
  String get exLayoutWrapDescription;

  /// In the template: `Ancho`
  String get exLayoutWrapWidth;

  /// In the template: `Espacio`
  String get exLayoutWrapSpacing;

  /// In the template: `Entre líneas`
  String get exLayoutWrapRunSpacing;

  /// In the template: `Una cuadrícula de seis casillas`
  String get exLayoutGridTitle;

  /// In the template: `Las casillas se reparten en columnas con un espacio fijo entre ellas; la primera puede ocupar toda la fila.`
  String get exLayoutGridDescription;

  /// In the template: `Primera`
  String get exLayoutGridFirst;

  /// In the template: `1 col.`
  String get exLayoutGridSingle;

  /// In the template: `Fila`
  String get exLayoutGridWide;

  /// In the template: `Columnas`
  String get exLayoutGridColumns;

  /// In the template: `Hueco`
  String get exLayoutGridGap;

  /// In the template: `Una tarjeta que sigue el ancho de su caja`
  String get exLayoutResponsiveTitle;

  /// In the template: `Desde 420 px de ancho de la caja, la columna pasa a fila con el mismo árbol de widgets.`
  String get exLayoutResponsiveDescription;

  /// In the template: `Ancho de la caja`
  String get exLayoutResponsiveWidth;

  /// In the template: `Un widget hecho de otros widgets`
  String get exWidgetsComposeTitle;

  /// In the template: `UserTile es una clase que la lista reutiliza en cada fila; la lista decide solo cómo se acomodan.`
  String get exWidgetsComposeDescription;

  /// In the template: `Disposición`
  String get exWidgetsComposeAxis;

  /// In the template: `Columna`
  String get exWidgetsComposeColumn;

  /// In the template: `Fila`
  String get exWidgetsComposeRow;

  /// In the template: `Cuántos`
  String get exWidgetsComposeCount;

  /// In the template: `Un ViewModel con dos campos de estado`
  String get exStateGreetingTitle;

  /// In the template: `El campo de texto llama a setName con lo que escribe el usuario y el Switch cambia el saludo; el resto de la página solo lee los dos campos.`
  String get exStateGreetingDescription;

  /// In the template: `Saludo`
  String get exStateGreetingSalutation;

  /// In the template: `Hola`
  String get exStateGreetingHello;

  /// In the template: `La URL que arma una ruta`
  String get exRoutesLinkTitle;

  /// In the template: `link() arma la dirección a partir del parámetro y la query; un parámetro de otro tipo es un error al construirla.`
  String get exRoutesLinkDescription;

  /// In the template: `Estado`
  String get exRoutesLinkQuery;

  /// In the template: `Todos`
  String get exRoutesLinkNone;

  /// In the template: `Abiertos`
  String get exRoutesLinkOpen;

  /// In the template: `Cerrados`
  String get exRoutesLinkClosed;

  /// In the template: `Parámetro id`
  String get exRoutesLinkId;

  /// In the template: `Lo que decide un middleware`
  String get exRoutesMiddlewareTitle;

  /// In the template: `El middleware deja pasar la petición, redirige o responde con un error según el usuario y la ruta.`
  String get exRoutesMiddlewareDescription;

  /// In the template: `Usuario`
  String get exRoutesMiddlewareVisitor;

  /// In the template: `Sin sesión`
  String get exRoutesMiddlewareGuest;

  /// In the template: `Miembro`
  String get exRoutesMiddlewareMember;

  /// In the template: `Admin`
  String get exRoutesMiddlewareAdmin;

  /// In the template: `Ruta`
  String get exRoutesMiddlewareTarget;

  /// In the template: `Cuenta`
  String get exRoutesMiddlewareAccount;

  /// In the template: `Panel`
  String get exRoutesMiddlewareAdminPage;

  /// In the template: `Qué puede devolver load`
  String get exDataLoadTitle;

  /// In the template: `Según lo que responde el repositorio, load entrega los datos a la página o termina en una página de error.`
  String get exDataLoadDescription;

  /// In the template: `El repositorio`
  String get exDataLoadAnswer;

  /// In the template: `Pedidos`
  String get exDataLoadOrders;

  /// In the template: `Nada`
  String get exDataLoadMissing;

  /// In the template: `Falla`
  String get exDataLoadFailing;

  /// In the template: `Cuántos pedidos`
  String get exDataLoadCount;

  /// In the template: `Los colores del tema`
  String get exThemeColorsTitle;

  /// In the template: `La tarjeta lee sus colores con Theme.of(context) y sigue el modo y el acento del tema.`
  String get exThemeColorsDescription;

  /// In the template: `Modo`
  String get exThemeLook;

  /// In the template: `Claro`
  String get exThemeLookLight;

  /// In the template: `Oscuro`
  String get exThemeLookDark;

  /// In the template: `Acento`
  String get exThemeAccent;

  /// In the template: `Lila`
  String get exThemeAccentViolet;

  /// In the template: `Verde`
  String get exThemeAccentTeal;

  /// In the template: `Ámbar`
  String get exThemeAccentOrange;

  /// In the template: `Un estilo de texto`
  String get exThemeTextTitle;

  /// In the template: `copyWith cambia el tamaño y el peso de un rol del TextTheme; el resto del estilo sigue al tema.`
  String get exThemeTextDescription;

  /// In the template: `Tamaño`
  String get exThemeTextSize;

  /// In the template: `Peso`
  String get exThemeTextWeight;

  /// In the template: `Una animación implícita`
  String get exMotionImplicitTitle;

  /// In the template: `AnimatedContainer anima el cambio de posición con la duración y la curva indicadas.`
  String get exMotionImplicitDescription;

  /// In the template: `Posición`
  String get exMotionPlace;

  /// In the template: `Inicio`
  String get exMotionPlaceStart;

  /// In the template: `Final`
  String get exMotionPlaceEnd;

  /// In the template: `Curva`
  String get exMotionCurve;

  /// In the template: `easeOut`
  String get exMotionCurveOut;

  /// In the template: `easeInOut`
  String get exMotionCurveInOut;

  /// In the template: `easeOutBack`
  String get exMotionCurveBack;

  /// In the template: `Duración`
  String get exMotionDuration;

  /// In the template: `TweenAnimationBuilder`
  String get exMotionTweenTitle;

  /// In the template: `TweenAnimationBuilder anima el punto hacia el valor final del tween.`
  String get exMotionTweenDescription;

  /// In the template: `Destino`
  String get exMotionTweenEnd;

  /// In the template: `Una animación explícita`
  String get exMotionExplicitTitle;

  /// In the template: `AnimationController inicia la animación al cargar la página; el navegador la ejecuta.`
  String get exMotionExplicitDescription;

  /// In the template: `AnimatedList`
  String get exMotionListTitle;

  /// In the template: `Las filas de AnimatedList entran al agregarse y salen al quitarse, con la duración indicada.`
  String get exMotionListDescription;

  /// In the template: `Transición entre páginas`
  String get exMotionPageTitle;

  /// In the template: `Vista previa de PageTransition entre una lista y un artículo. La real ocurre entre dos documentos.`
  String get exMotionPageDescription;

  /// In the template: `Transición`
  String get exMotionPageKind;

  /// In the template: `Fundido`
  String get exMotionPageFade;

  /// In the template: `Deslizar`
  String get exMotionPageSlide;

  /// In the template: `Subir`
  String get exMotionPageFadeUp;

  /// In the template: `Dónde cayó el toque`
  String get exGestureTapTitle;

  /// In the template: `onTapDown y onTapUp reciben la posición del toque dentro del widget.`
  String get exGestureTapDescription;

  /// In the template: `Evento`
  String get exGestureTapEvent;

  /// In the template: `onTapDown`
  String get exGestureTapDown;

  /// In the template: `onTapUp`
  String get exGestureTapUp;

  /// In the template: `Punto`
  String get exGestureTapSize;

  /// In the template: `Arrastrar y soltar`
  String get exGestureDragTitle;

  /// In the template: `El navegador mueve la ficha con el puntero; el método del ViewModel recibe el desplazamiento al soltarla.`
  String get exGestureDragDescription;

  /// In the template: `Eje`
  String get exGestureDragAxis;

  /// In the template: `Libre`
  String get exGestureDragFree;

  /// In the template: `Horizontal`
  String get exGestureDragHorizontal;

  /// In the template: `Vertical`
  String get exGestureDragVertical;

  /// In the template: `Al soltar`
  String get exGestureDragRest;

  /// In the template: `Vuelve`
  String get exGestureDragSnap;

  /// In the template: `Se queda`
  String get exGestureDragStay;

  /// In the template: `Variantes de un ícono`
  String get exIconsTitle;

  /// In the template: `Los mismos seis nombres en sus cuatro variantes y a cualquier tamaño.`
  String get exIconsDescription;

  /// In the template: `Variante`
  String get exIconsVariant;

  /// In the template: `Lleno`
  String get exIconsFilled;

  /// In the template: `Borde`
  String get exIconsOutlined;

  /// In the template: `Suave`
  String get exIconsRounded;

  /// In the template: `Filo`
  String get exIconsSharp;

  /// In the template: `Tamaño`
  String get exIconsSize;

  /// In the template: `Un command: pendiente, error y resultado`
  String get exArchCommandTitle;

  /// In the template: `Mientras el command espera, el botón no se repite; si el servidor falla, error dice por qué.`
  String get exArchCommandDescription;

  /// In the template: `Estado optimista a mano`
  String get exArchOptimisticTitle;

  /// In the template: `Con «Optimista» la estrella cambia al pulsar y vuelve atrás si el servidor falla.`
  String get exArchOptimisticDescription;

  /// In the template: `Servidor`
  String get exArchServer;

  /// In the template: `Responde`
  String get exArchServerOk;

  /// In the template: `Falla`
  String get exArchServerFails;

  /// In the template: `Latencia`
  String get exArchLatency;

  /// In the template: `Optimista`
  String get exArchOptimistic;

  /// In the template: `ThorPage`
  String get layersOrdersPageKind;

  /// In the template: `Clase`
  String get layersOrdersModelKind;

  /// In the template: `Es un widget: muestra lo que el ViewModel le da y le pasa lo que hace el usuario. QueryBuilder renderiza la espera, el error y los datos; el botón llama a un método del ViewModel.`
  String get layersOrdersUiViewDescription;

  /// In the template: `La parte del ViewModel que vive en el navegador: query lee, command escribe, state guarda lo que el usuario cambia y derived calcula a partir de ellos.`
  String get layersOrdersUiViewModelDescription;

  /// In the template: `La otra mitad del ViewModel vive en el servidor: load trae los datos antes de renderizar y una acción recibe el formulario. Lanzar NotFound o Redirect decide qué página se ve.`
  String get layersOrdersPageDescription;

  /// In the template: `Un dato del negocio, inmutable y sin lógica de pantalla. Lo que viaja en una query necesita toJson y fromJson.`
  String get layersOrdersModelDescription;

  /// In the template: `Una interfaz con una implementación HTTP. Convierte la respuesta en modelos y los errores del backend en lo que una página sabe lanzar: NotFound o HttpError. Nunca un Redirect: adónde va un usuario sin sesión lo decide el middleware.`
  String get layersOrdersDataRepositoryDescription;

  /// In the template: `Un cliente por backend, sin estado ni reglas: pregunta y devuelve la respuesta tal cual. ThorHttpClient pone el plazo y reutiliza conexiones.`
  String get layersOrdersDataServiceDescription;

  /// In the template: `Un middleware deja el repositorio en la petición con un ContextKey. El mismo Group sirve al repositorio real en producción y a uno falso en pruebas.`
  String get layersOrdersDataInjectionDescription;

  /// In the template: `Con un repositorio falso la página se prueba sin red ni backend: el cliente de pruebas hace la petición y la respuesta se comprueba.`
  String get layersOrdersDataTestsDescription;

  /// In the template: `Un valor calculado una vez`
  String get exStateDerivedTitle;

  /// In the template: `La lista y el contador leen el mismo derived: se recalcula una vez por cambio, no una por Watch.`
  String get exStateDerivedDescription;

  /// In the template: `Orden`
  String get exStateDerivedOrder;

  /// In the template: `Magnitud`
  String get exStateDerivedOrderMag;

  /// In the template: `Lugar`
  String get exStateDerivedOrderPlace;

  /// In the template: `Magnitud mínima`
  String get exStateDerivedMin;

  /// In the template: `Los tres estados de un QueryBuilder`
  String get exStateQueryTitle;

  /// In the template: `El builder se renderiza una vez por estado del snapshot, y el navegador cambia entre esas variantes.`
  String get exStateQueryDescription;

  /// In the template: `Snapshot`
  String get exStateQueryPhase;

  /// In the template: `Espera`
  String get exStateQueryLoading;

  /// In the template: `Datos`
  String get exStateQueryReady;

  /// In the template: `Error`
  String get exStateQueryError;

  /// In the template: `Una lista que el servidor mantiene al día`
  String get exDataFeedTitle;

  /// In the template: `El servidor envía cada cambio de la lista y la página muestra el estado de la conexión.`
  String get exDataFeedDescription;

  /// In the template: `Red`
  String get exDataFeedLink;

  /// In the template: `Activa`
  String get exDataFeedLive;

  /// In the template: `Espera`
  String get exDataFeedWaiting;

  /// In the template: `Cerrada`
  String get exDataFeedClosed;

  /// In the template: `Una parte bajo demanda`
  String get exDataPieceTitle;

  /// In the template: `La página lleva un enlace de respaldo y el servidor envía la parte cuando el navegador la pide.`
  String get exDataPieceDescription;

  /// In the template: `Se pide al`
  String get exDataPieceTrigger;

  /// In the template: `Abrir`
  String get exDataPieceOpen;

  /// In the template: `Verse`
  String get exDataPieceVisible;

  /// In the template: `Cargar`
  String get exDataPieceIdle;

  /// In the template: `La página`
  String get exDataPieceMoment;

  /// In the template: `Antes`
  String get exDataPieceBefore;

  /// In the template: `Después`
  String get exDataPieceAfter;

  /// In the template: `La regla de un campo`
  String get exFormsRuleTitle;

  /// In the template: `Cada regla del campo tiene su mensaje: al enviar, se muestra el de la primera que no se cumple.`
  String get exFormsRuleDescription;

  /// In the template: `Regla`
  String get exFormsRuleLabel;

  /// In the template: `Vacío`
  String get exFormsRuleRequired;

  /// In the template: `Correo`
  String get exFormsRuleEmail;

  /// In the template: `Largo`
  String get exFormsRuleMin;

  /// In the template: `Un formulario que va al servidor`
  String get exFormsPhaseTitle;

  /// In the template: `Un Form que navega se marca ocupado mientras envía y, si el servidor lo rechaza, vuelve con el primer error.`
  String get exFormsPhaseDescription;

  /// In the template: `Estado`
  String get exFormsPhaseLabel;

  /// In the template: `Edición`
  String get exFormsPhaseEditing;

  /// In the template: `Envío`
  String get exFormsPhaseSending;

  /// In the template: `Error`
  String get exFormsPhaseFailed;

  /// In the template: `De los comandos a la primera página`
  String get exStartInstallTitle;

  /// In the template: `Los comandos y el título de la página de inicio dependen de dónde toma Thor el proyecto.`
  String get exStartInstallDescription;

  /// In the template: `Thor desde`
  String get exStartInstallSource;

  /// In the template: `Esta máquina`
  String get exStartInstallSourceLocal;

  /// In the template: `Título`
  String get exStartInstallTitleLabel;

  /// In the template: `Sí`
  String get exCatYes;

  /// In the template: `Habilitado`
  String get exCatEnabled;

  /// In the template: `Ícono`
  String get exCatIcon;

  /// In the template: `Variante`
  String get exCatVariant;

  /// In the template: `Tamaño`
  String get exCatSize;

  /// In the template: `Pequeño`
  String get exCatSmall;

  /// In the template: `Mediano`
  String get exCatMedium;

  /// In the template: `Grande`
  String get exCatLarge;

  /// In the template: `FilledButton`
  String get exBtnFilledTitle;

  /// In the template: `La acción principal: relleno o tonal, con o sin ícono, habilitado o no.`
  String get exBtnFilledDescription;

  /// In the template: `Relleno`
  String get exBtnKindFilled;

  /// In the template: `Tonal`
  String get exBtnKindTonal;

  /// In the template: `Borde`
  String get exBtnKindOutlined;

  /// In the template: `Texto`
  String get exBtnKindText;

  /// In the template: `ElevatedButton`
  String get exBtnElevatedTitle;

  /// In the template: `Un botón elevado sobre la superficie, con o sin ícono.`
  String get exBtnElevatedDescription;

  /// In the template: `El constructor .icon`
  String get exBtnIconLabelsTitle;

  /// In the template: `Los cuatro botones aceptan .icon; FilledButton además .tonal y .tonalIcon.`
  String get exBtnIconLabelsDescription;

  /// In the template: `Enlace`
  String get exBtnLink;

  /// In the template: `OutlinedButton`
  String get exBtnOutlinedTitle;

  /// In the template: `Una acción secundaria: con onPressed es un botón, con href un enlace.`
  String get exBtnOutlinedDescription;

  /// In the template: `TextButton`
  String get exBtnTextTitle;

  /// In the template: `La acción de menor peso: con onPressed es un botón, con href un enlace.`
  String get exBtnTextDescription;

  /// In the template: `IconButton`
  String get exBtnIconTitle;

  /// In the template: `Un botón de ícono con nombre accesible: cambia el tamaño del ícono.`
  String get exBtnIconDescription;

  /// In the template: `Variantes de IconButton`
  String get exBtnVariantsTitle;

  /// In the template: `Estándar, filled, filledTonal y outlined; con href es un enlace.`
  String get exBtnVariantsDescription;

  /// In the template: `Estándar`
  String get exBtnVarStandard;

  /// In the template: `FloatingActionButton`
  String get exBtnFabTitle;

  /// In the template: `Los tamaños del botón de acción flotante.`
  String get exBtnFabDescription;

  /// In the template: `Extendido`
  String get exBtnFabExtended;

  /// In the template: `ButtonStyle y styleFrom`
  String get exBtnStyleTitle;

  /// In the template: `Forma, radio y espacio de un botón con styleFrom.`
  String get exBtnStyleDescription;

  /// In the template: `Forma`
  String get exBtnShape;

  /// In the template: `Redondeada`
  String get exBtnShapeRounded;

  /// In the template: `Estadio`
  String get exBtnShapeStadium;

  /// In the template: `Radio`
  String get exBtnRadius;

  /// In the template: `Espacio`
  String get exBtnPadding;

  /// In the template: `Contador`
  String get pageExampleCounter;

  /// In the template: `Convertidor de temperatura`
  String get pageExampleTemperature;

  /// In the template: `Reserva de vuelos`
  String get pageExampleFlightBooker;

  /// In the template: `Temporizador`
  String get pageExampleTimer;

  /// In the template: `Lista con CRUD`
  String get pageExampleCrud;

  /// In the template: `Círculos con deshacer`
  String get pageExampleCircleDrawer;

  /// In the template: `Hoja de cálculo`
  String get pageExampleCells;

  /// In the template: `Página de contenido`
  String get pageExampleContentPage;

  /// In the template: `Ayuda`
  String get exInpHelper;

  /// In the template: `Error`
  String get exInpError;

  /// In the template: `Nombre`
  String get exInpName;

  /// In the template: `TextField`
  String get exInpTextFieldTitle;

  /// In the template: `Un campo de texto: ayuda, ícono, error y habilitado.`
  String get exInpTextFieldDescription;

  /// In the template: `Estados del campo`
  String get exInpStatesTitle;

  /// In the template: `Correo, contraseña o varias líneas; normal, con error o bloqueado.`
  String get exInpStatesDescription;

  /// In the template: `Tipo`
  String get exInpKind;

  /// In the template: `Correo`
  String get exInpKindEmail;

  /// In the template: `Normal`
  String get exInpStateNormal;

  /// In the template: `Error`
  String get exInpStateError;

  /// In the template: `TextFormField`
  String get exInpFormTitle;

  /// In the template: `Las reglas del esquema: deja el campo mal y pulsa Enviar.`
  String get exInpFormDescription;

  /// In the template: `Reglas`
  String get exInpRule;

  /// In the template: `DropdownButton`
  String get exInpDropdownTitle;

  /// In the template: `Una lista de opciones: ancho, pista y habilitado.`
  String get exInpDropdownDescription;

  /// In the template: `Ancho`
  String get exInpExpanded;

  /// In the template: `Pista`
  String get exInpHint;

  /// In the template: `Autocomplete`
  String get exInpAutocompleteTitle;

  /// In the template: `Un campo que sugiere opciones: la lista, hacia dónde se abre y su alto.`
  String get exInpAutocompleteDescription;

  /// In the template: `Lista`
  String get exInpList;

  /// In the template: `Frutas`
  String get exInpListFruits;

  /// In the template: `Colores`
  String get exInpListColors;

  /// In the template: `Se abre`
  String get exInpOpens;

  /// In the template: `Abajo`
  String get exInpOpensDown;

  /// In the template: `Arriba`
  String get exInpOpensUp;

  /// In the template: `Alto del panel`
  String get exInpPanelHeight;

  /// In the template: `DropdownButtonFormField`
  String get exInpDdffTitle;

  /// In the template: `La lista con etiqueta, ayuda y error.`
  String get exInpDdffDescription;

  /// In the template: `Campos de fecha`
  String get exInpDateTitle;

  /// In the template: `El campo del navegador o el campo con calendario. Meses, días, primer día de la semana y dígitos salen del idioma de la página.`
  String get exInpDateDescription;

  /// In the template: `Campo`
  String get exInpDateKind;

  /// In the template: `Nativo`
  String get exInpDateNative;

  /// In the template: `Calendario`
  String get exInpDateCalendar;

  /// In the template: `Permite vacío`
  String get exInpAllowEmpty;

  /// In the template: `Slider`
  String get exInpSliderTitle;

  /// In the template: `Un valor entre min y max, continuo o en pasos.`
  String get exInpSliderDescription;

  /// In the template: `Divisiones`
  String get exInpDivisions;

  /// In the template: `Clave`
  String get exInpSegPassword;

  /// In the template: `Notas`
  String get exInpSegComments;

  /// In the template: `Modo`
  String get exInpMode;

  /// In the template: `Bloqueo`
  String get exInpModeLocked;

  /// In the template: `Valor`
  String get exSelValue;

  /// In the template: `No`
  String get exSelOff;

  /// In the template: `Encendido`
  String get exSelOn;

  /// In the template: `Mixto`
  String get exSelMixed;

  /// In the template: `Elegido`
  String get exSelChosen;

  /// In the template: `Checkbox`
  String get exSelCheckboxTitle;

  /// In the template: `Una casilla: marcada, sin marcar o mixta, habilitada o no.`
  String get exSelCheckboxDescription;

  /// In the template: `Switch`
  String get exSelSwitchTitle;

  /// In the template: `Un interruptor de encendido y apagado.`
  String get exSelSwitchDescription;

  /// In the template: `RadioGroup y Radio`
  String get exSelRadioTitle;

  /// In the template: `El grupo guarda el valor elegido; cada Radio solo dice su value.`
  String get exSelRadioDescription;

  /// In the template: `SegmentedButton`
  String get exSelSegmentedTitle;

  /// In the template: `Varios segmentos nativos para elegir un valor: sin JavaScript se elige y se recorre con las flechas.`
  String get exSelSegmentedDescription;

  /// In the template: `Tarjeta`
  String get exSelCard;

  /// In the template: `Efectivo`
  String get exSelCash;

  /// In the template: `Banco`
  String get exSelTransfer;

  /// In the template: `ChoiceChip`
  String get exSelChoiceTitle;

  /// In the template: `Chips para elegir una sola opción.`
  String get exSelChoiceDescription;

  /// In the template: `InputChip`
  String get exSelInputTitle;

  /// In the template: `Una etiqueta de lo ya elegido, con su equis para quitarla.`
  String get exSelInputDescription;

  /// In the template: `Con equis`
  String get exSelDeletable;

  /// In the template: `Etiquetas`
  String get exSelChips;

  /// In the template: `Chips que son enlaces`
  String get exSelLinkTitle;

  /// In the template: `Con href el chip es un enlace y funciona sin JavaScript.`
  String get exSelLinkDescription;

  /// In the template: `Elegido`
  String get exSelSelected;

  /// In the template: `Marca`
  String get exSelCheckmark;

  /// In the template: `Equis enlace`
  String get exSelDeleteLink;

  /// In the template: `FilterChip`
  String get exSelFilterTitle;

  /// In the template: `Chips para elegir varias opciones a la vez.`
  String get exSelFilterDescription;

  /// In the template: `ListTile con control`
  String get exSelTilesTitle;

  /// In the template: `Checkbox, Switch o Radio con su título: toda la fila responde.`
  String get exSelTilesDescription;

  /// In the template: `Control`
  String get exSelTile;

  /// In the template: `Checkbox`
  String get exSelTileCheckbox;

  /// In the template: `Switch`
  String get exSelTileSwitch;

  /// In the template: `Radio`
  String get exSelTileRadio;

  /// In the template: `Posición`
  String get exSelControl;

  /// In the template: `Antes`
  String get exSelLeading;

  /// In the template: `Después`
  String get exSelTrailing;

  /// In the template: `Subtítulo`
  String get exSelSubtitle;

  /// In the template: `AppBar`
  String get exNavAppBarTitle;

  /// In the template: `La barra de arriba: título centrado o no, botón de menú, acciones y elevación.`
  String get exNavAppBarDescription;

  /// In the template: `Título centrado`
  String get exNavCenterTitle;

  /// In the template: `Botón de menú`
  String get exNavLeading;

  /// In the template: `Acción de búsqueda`
  String get exNavSearchAction;

  /// In the template: `Elevación`
  String get exNavElevation;

  /// In the template: `TabBar y TabBarView`
  String get exNavTabsTitle;

  /// In the template: `Pestañas nativas con su contenido: cambia cuántas hay y si la barra se desplaza.`
  String get exNavTabsDescription;

  /// In the template: `Barra con scroll`
  String get exNavScrollable;

  /// In the template: `Pestañas`
  String get exNavTabCount;

  /// In the template: `Drawer`
  String get exNavDrawerTitle;

  /// In the template: `Un menú que entra desde el lado: elige el borde y el ancho, y ábrelo.`
  String get exNavDrawerDescription;

  /// In the template: `Borde`
  String get exNavSide;

  /// In the template: `Inicio`
  String get exNavSideStart;

  /// In the template: `Final`
  String get exNavSideEnd;

  /// In the template: `NavigationBar`
  String get exNavBarTitle;

  /// In the template: `La barra de destinos de abajo: cuántos destinos y cómo se muestran las etiquetas.`
  String get exNavBarDescription;

  /// In the template: `Etiquetas`
  String get exNavLabels;

  /// In the template: `Todas`
  String get exNavLabelsAll;

  /// In the template: `Una`
  String get exNavLabelsSelected;

  /// In the template: `Sin`
  String get exNavLabelsNone;

  /// In the template: `Destinos`
  String get exNavDestinations;

  /// In the template: `NavigationRail`
  String get exNavRailTitle;

  /// In the template: `La barra de destinos del lado: etiquetas y rail extendido.`
  String get exNavRailDescription;

  /// In the template: `Extendido`
  String get exNavExtended;

  /// In the template: `Link`
  String get exNavLinkTitle;

  /// In the template: `Cualquier widget como enlace: interno o externo, en otra pestaña, o marcado como página actual.`
  String get exNavLinkDescription;

  /// In the template: `Externo`
  String get exNavExternal;

  /// In the template: `Otra pestaña`
  String get exNavNewTab;

  /// In the template: `Página actual`
  String get exNavCurrent;

  /// In the template: `ModalBottomSheet`
  String get exNavSheetTitle;

  /// In the template: `Una hoja que sube desde abajo: con o sin asa y con más o menos opciones.`
  String get exNavSheetDescription;

  /// In the template: `Asa`
  String get exNavDragHandle;

  /// In the template: `Opciones`
  String get exNavOptions;

  /// In the template: `AlertDialog`
  String get exFbAlertTitle;

  /// In the template: `Un diálogo nativo con título, contenido y acciones: ábrelo con el botón.`
  String get exFbAlertDescription;

  /// In the template: `Cierra al tocar fuera`
  String get exFbBarrier;

  /// In the template: `Contenido`
  String get exFbContent;

  /// In the template: `Dos acciones`
  String get exFbTwoActions;

  /// In the template: `Dialog con DialogController`
  String get exFbControllerTitle;

  /// In the template: `Un método del ViewModel abre el diálogo y otro lo cierra.`
  String get exFbControllerDescription;

  /// In the template: `Contactos`
  String get exFbContacts;

  /// In the template: `Cierra al borrar`
  String get exFbCloseAfter;

  /// In the template: `SnackBar`
  String get exFbSnackTitle;

  /// In the template: `Un mensaje breve que se oculta solo: con o sin acción, más corto o más largo.`
  String get exFbSnackDescription;

  /// In the template: `Acción`
  String get exFbAction;

  /// In the template: `Flotante`
  String get exFbFloating;

  /// In the template: `Duración`
  String get exFbDuration;

  /// In the template: `2 s`
  String get exFbDur2;

  /// In the template: `4 s`
  String get exFbDur4;

  /// In the template: `6 s`
  String get exFbDur6;

  /// In the template: `Indicadores de progreso`
  String get exFbProgressTitle;

  /// In the template: `Lineal o circular, con valor o girando sin fin.`
  String get exFbProgressDescription;

  /// In the template: `Forma`
  String get exFbShape;

  /// In the template: `Lineal`
  String get exFbLinear;

  /// In the template: `Circular`
  String get exFbCircular;

  /// In the template: `Con valor`
  String get exFbDeterminate;

  /// In the template: `Valor`
  String get exFbValue;

  /// In the template: `PopupMenuButton`
  String get exFbPopupTitle;

  /// In the template: `Un menú de opciones: marca la actual o deshabilita una.`
  String get exFbPopupDescription;

  /// In the template: `Marca la actual`
  String get exFbMarkCurrent;

  /// In the template: `Última opción`
  String get exFbLastEnabled;

  /// In the template: `Arriba`
  String get exContAbove;

  /// In the template: `Abajo`
  String get exContBelow;

  /// In the template: `Color`
  String get exContAccent;

  /// In the template: `Acordeón`
  String get exContAccordion;

  /// In the template: `Acciones`
  String get exContActions;

  /// In the template: `Ascendente`
  String get exContAscending;

  /// In the template: `CircleAvatar y Badge`
  String get exContAvatarTitle;

  /// In the template: `Un avatar con un distintivo: etiqueta, punto o número.`
  String get exContAvatarDescription;

  /// In the template: `Tipo`
  String get exContBadge;

  /// In the template: `Texto`
  String get exContBadgeLabel;

  /// In the template: `Punto`
  String get exContBadgeDot;

  /// In the template: `Número`
  String get exContBadgeCount;

  /// In the template: `Abrir en otra pestaña`
  String get exContBlank;

  /// In the template: `Imagen rota`
  String get exContBroken;

  /// In the template: `Builders`
  String get exContBuilders;

  /// In the template: `Cuando la imagen falla o tarda`
  String get exContBuildersTitle;

  /// In the template: `Con los builders, el fallo muestra tu widget; sin ellos, la imagen rota del navegador.`
  String get exContBuildersDescription;

  /// In the template: `Card`
  String get exContCardTitle;

  /// In the template: `Una superficie con sombra: cambia su elevación y su espacio interior.`
  String get exContCardDescription;

  /// In the template: `Casillas`
  String get exContCheckboxes;

  /// In the template: `Chip y ActionChip`
  String get exContChipTitle;

  /// In the template: `Una etiqueta, con avatar o con equis, o una etiqueta que se pulsa.`
  String get exContChipDescription;

  /// In the template: `Chip`
  String get exContChipPlain;

  /// In the template: `Avatar`
  String get exContChipAvatar;

  /// In the template: `Action`
  String get exContChipAction;

  /// In the template: `Con equis`
  String get exContDeletable;

  /// In the template: `Retraso`
  String get exContDelay;

  /// In the template: `Compacto`
  String get exContDense;

  /// In the template: `Divider`
  String get exContDividerTitle;

  /// In the template: `Una línea horizontal: grosor y sangría en los extremos.`
  String get exContDividerDescription;

  /// In the template: `Grosor`
  String get exContThickness;

  /// In the template: `Sangría`
  String get exContIndent;

  /// In the template: `Elevación`
  String get exContElevation;

  /// In the template: `ExpansionTile`
  String get exContExpansionTitle;

  /// In the template: `Filas que se abren; con el mismo name forman un acordeón.`
  String get exContExpansionDescription;

  /// In the template: `Primera abierta`
  String get exContOpen;

  /// In the template: `Ajuste`
  String get exContFit;

  /// In the template: `Cover`
  String get exContFitCover;

  /// In the template: `Contain`
  String get exContFitContain;

  /// In the template: `Fill`
  String get exContFitFill;

  /// In the template: `Ícono`
  String get exContGlyph;

  /// In the template: `Home`
  String get exContGlyphHome;

  /// In the template: `Star`
  String get exContGlyphStar;

  /// In the template: `Bell`
  String get exContGlyphBell;

  /// In the template: `HTML con script`
  String get exContHostile;

  /// In the template: `nofollow`
  String get exContNofollow;

  /// In the template: `HtmlWidget`
  String get exContHtmlTitle;

  /// In the template: `HTML ajeno, limpiado contra una lista permitida; la política cambia lo que se deja.`
  String get exContHtmlDescription;

  /// In the template: `Icon`
  String get exContIconTitle;

  /// In the template: `Un ícono SVG: elige el glifo, el tamaño y el color.`
  String get exContIconDescription;

  /// In the template: `Image.asset`
  String get exContImageTitle;

  /// In the template: `Una imagen de tu carpeta web: ajuste, esquinas y ancho.`
  String get exContImageDescription;

  /// In the template: `Esquinas redondas`
  String get exContRounded;

  /// In the template: `Ancho`
  String get exContWidth;

  /// In the template: `Alto de línea`
  String get exContLineHeight;

  /// In the template: `Líneas`
  String get exContLines;

  /// In the template: `Todas`
  String get exContLinesAll;

  /// In the template: `Una`
  String get exContLinesOne;

  /// In the template: `Dos`
  String get exContLinesTwo;

  /// In the template: `Mensaje largo`
  String get exContLongMessage;

  /// In the template: `Posición`
  String get exContPlacement;

  /// In the template: `Radio`
  String get exContRadius;

  /// In the template: `RichText y SelectableText`
  String get exContRichTitle;

  /// In the template: `Un tramo con otro estilo dentro del texto, y un texto que se puede seleccionar.`
  String get exContRichDescription;

  /// In the template: `Tramo`
  String get exContSpan;

  /// In the template: `Cursiva`
  String get exContItalic;

  /// In the template: `Igual`
  String get exContPlain;

  /// In the template: `Seleccionable`
  String get exContSelectable;

  /// In the template: `Seleccionada`
  String get exContSelected;

  /// In the template: `Subtítulo`
  String get exContSubtitle;

  /// In the template: `Filas`
  String get exContRows;

  /// In the template: `Ordenar por columna`
  String get exContSortBy;

  /// In the template: `-`
  String get exContSortNone;

  /// In the template: `DataTable`
  String get exContTableTitle;

  /// In the template: `Una tabla con encabezados: orden, casillas y número de filas.`
  String get exContTableDescription;

  /// In the template: `Text y TextStyle`
  String get exContTextTitle;

  /// In the template: `Tamaño, peso y límite de líneas de un texto.`
  String get exContTextDescription;

  /// In the template: `Peso`
  String get exContWeight;

  /// In the template: `400`
  String get exContWeightRegular;

  /// In the template: `600`
  String get exContWeightSemibold;

  /// In the template: `700`
  String get exContWeightBold;

  /// In the template: `ListTile`
  String get exContTileTitle;

  /// In the template: `Una fila con ícono, título y subtítulo: estados y densidad.`
  String get exContTileDescription;

  /// In the template: `Tooltip`
  String get exContTooltipTitle;

  /// In the template: `Una burbuja al pasar el puntero: posición, texto y retraso.`
  String get exContTooltipDescription;

  /// In the template: `Mail`
  String get exContGlyphMail;

  /// In the template: `1`
  String get exContSortFirst;

  /// In the template: `2`
  String get exContSortSecond;

  /// In the template: `3`
  String get exContSortThird;

  /// In the template: `Contador`
  String get exRecCounterTitle;

  /// In the template: `Una etiqueta con la cuenta y un botón que la aumenta según el paso.`
  String get exRecCounterDescription;

  /// In the template: `Paso`
  String get exRecCounterStep;

  /// In the template: `Convertidor de temperatura`
  String get exRecTempTitle;

  /// In the template: `Dos campos que se actualizan entre sí mientras el texto es un número.`
  String get exRecTempDescription;

  /// In the template: `Decimales`
  String get exRecTempDecimals;

  /// In the template: `0`
  String get exRecTempDec0;

  /// In the template: `1`
  String get exRecTempDec1;

  /// In the template: `2`
  String get exRecTempDec2;

  /// In the template: `Temporizador`
  String get exRecTimerTitle;

  /// In the template: `Una barra que se llena durante la duración del control deslizante, el tiempo transcurrido y un botón que la reinicia.`
  String get exRecTimerDescription;

  /// In the template: `Una página de contenido`
  String get exRecPageTitle;

  /// In the template: `Un hero y una cuadrícula de entradas: cambia el tono, la carga de la imagen y las columnas.`
  String get exRecPageDescription;

  /// In the template: `Tono`
  String get exRecPageTone;

  /// In the template: `Suave`
  String get exRecPageToneSoft;

  /// In the template: `Tinta`
  String get exRecPageToneInk;

  /// In the template: `Imagen diferida`
  String get exRecPageLazy;

  /// In the template: `Columnas`
  String get exRecPageColumns;

  /// In the template: `Diálogo, hoja y cajón`
  String get exUiOverlayTitle;

  /// In the template: `El navegador abre el diálogo, la hoja o el cajón, atrapa el foco y lo cierra con Esc.`
  String get exUiOverlayDescription;

  /// In the template: `Abre`
  String get exUiOverlayKind;

  /// In the template: `Diálogo`
  String get exUiOverlayDialog;

  /// In the template: `Hoja`
  String get exUiOverlaySheet;

  /// In the template: `Cajón`
  String get exUiOverlayDrawer;

  /// In the template: `Lista de filas`
  String get exUiListTitle;

  /// In the template: `Sube las filas hasta 10 000: la página conserva solo las que están cerca de la pantalla.`
  String get exUiListDescription;

  /// In the template: `Filas`
  String get exUiListRows;

  /// In the template: `Lo que dice Semantics`
  String get exUiSemTitle;

  /// In the template: `Semantics indica qué es el texto para un lector de pantalla, y Thor renderiza el elemento que le corresponde.`
  String get exUiSemDescription;

  /// In the template: `Rol`
  String get exUiSemKind;

  /// In the template: `Título`
  String get exUiSemHeading;

  /// In the template: `Botón`
  String get exUiSemButton;

  /// In the template: `Aviso`
  String get exUiSemStatus;

  /// In the template: `Nivel`
  String get exUiSemLevel;

  /// In the template: `Una tarjeta en cuatro idiomas`
  String get exUiLocaleTitle;

  /// In the template: `El texto, el plural, el dinero, la fecha y la dirección siguen al idioma de la página.`
  String get exUiLocaleDescription;

  /// In the template: `Idioma`
  String get exUiLocaleLanguage;

  /// In the template: `Inglés`
  String get exUiLocaleEn;

  /// In the template: `Español`
  String get exUiLocaleEs;

  /// In the template: `Alemán`
  String get exUiLocaleDe;

  /// In the template: `Árabe`
  String get exUiLocaleAr;

  /// In the template: `Artículos`
  String get exUiLocaleItems;

  /// In the template: `Del widget a la página`
  String get exTitleStartWidgetToWeb;

  /// In the template: `La tienda: una cuadrícula de tarjetas`
  String get exTitleStartStoreGrid;

  /// In the template: `La tienda: un carrito en el navegador`
  String get exTitleStartCart;

  /// In the template: `La tienda: un formulario`
  String get exTitleStartCheckout;

  /// In the template: `Una tarjeta de producto`
  String get exTitleCard;

  /// In the template: `Color por estado con .when()`
  String get exTitleHover;

  /// In the template: `Acordeón exclusivo`
  String get exTitleAccordion;

  /// In the template: `Carrusel con flechas y puntos`
  String get exTitleCarousel;

  /// In the template: `Pestañas sin JS`
  String get exTitleTabs;

  /// In the template: `Diálogo nativo`
  String get exTitleDialog;

  /// In the template: `Menú con popover`
  String get exTitleMenu;

  /// In the template: `MenuAnchor`
  String get exTitleMenuAnchor;

  /// In the template: `Controles con estado`
  String get exTitleFormControls;

  /// In the template: `Enviar sin recargar`
  String get exTitleFormSubmit;

  /// In the template: `Un formulario con esquema`
  String get exTitleFormSchema;

  /// In the template: `Cuando el servidor dice que no`
  String get exTitleFormSchemaFailed;

  /// In the template: `Subir un archivo`
  String get exTitleFormUpload;

  /// In the template: `Atributos del campo`
  String get exTitleFormFieldParams;

  /// In the template: `Slider con burbuja`
  String get exTitleSliderBubble;

  /// In the template: `Selector en píldora`
  String get exTitleSegmentedPill;

  /// In the template: `Transición en hover`
  String get exTitleScale;

  /// In the template: `Entrada y bucle con AnimationController`
  String get exTitleEntrance;

  /// In the template: `Chips y progreso`
  String get exTitleChips;

  /// In the template: `Una tarjeta de producto completa`
  String get exTitleProductCard;

  /// In the template: `Wrappers sin elemento`
  String get exTitleWrappers;

  /// In the template: `Cuadrícula por breakpoint`
  String get exTitleGrid;

  /// In the template: `Variantes por ancho y estado`
  String get exTitleVariants;

  /// In the template: `Hover en grupo`
  String get exTitleHoverGroup;

  /// In the template: `SizedBox, Container, ConstrainedBox y FractionallySizedBox`
  String get exTitleLayoutSizes;

  /// In the template: `Tamaños relativos a la ventana`
  String get exTitleLayoutScreen;

  /// In the template: `GridView.extent cuenta las columnas como Flutter`
  String get exTitleLayoutGridExtent;

  /// In the template: `Scroll vertical y horizontal`
  String get exTitleLayoutScroll;

  /// In the template: `Responsivo con .when() y ResponsiveVisibility`
  String get exTitleLayoutResponsive;

  /// In the template: `Unidades, medidas de verdad`
  String get exTitleUnits;

  /// In the template: `Una tarjeta que sigue a su caja`
  String get exTitleResponsiveCard;

  /// In the template: `Encabezados sticky en una lista`
  String get exTitleStickyList;

  /// In the template: `Giro, desplazamiento y desenfoque en hover`
  String get exTitleHoverEffects;

  /// In the template: `Un tema por componente`
  String get exTitleComponentThemes;

  /// In the template: `Theme.of sigue al cambiar de modo`
  String get exTitleThemeFollowsSwitch;

  /// In the template: `HTML crudo con estilo por etiqueta`
  String get exTitleDescendants;

  /// In the template: `Patrones en mosaico`
  String get exTitlePatterns;

  /// In the template: `El proyecto nuevo`
  String get exTitleDemoExplorer;

  /// In the template: `Dos estados con un bool`
  String get exTitleStateBool;

  /// In the template: `Un estado por valor de un enum`
  String get exTitleStateEnum;

  /// In the template: `Una lista de tareas`
  String get exTitleStateTodo;

  /// In the template: `Controles ligados al estado`
  String get exTitleStateForm;

  /// In the template: `Dos instancias con key`
  String get exTitleStateKeyed;

  /// In the template: `Controladores y Timer`
  String get exTitleStateControllers;

  /// In the template: `PageController y onPageChanged`
  String get exTitleStatePages;

  /// In the template: `onHydrated y dispose`
  String get exTitleStateLifecycle;

  /// In the template: `confirm() y toast()`
  String get exTitleStateFeedback;

  /// In the template: `toggle() y un conjunto`
  String get exTitleStateSet;

  /// In the template: `ValueListenableBuilder`
  String get exTitleStateNotifier;

  /// In the template: `La tabla de una app con módulos`
  String get exTitleRoutesTree;

  /// In the template: `Enlaces desde las rutas`
  String get exTitleRoutesNav;

  /// In the template: `Un formulario con esquema`
  String get exTitleDataForm;

  /// In the template: `Después de un 422`
  String get exTitleDataFormFailed;

  /// In the template: `Icons`
  String get exTitleCatIcons;

  /// In the template: `Variantes de un ícono`
  String get exTitleCatIconVariants;

  /// In the template: `AnimatedSize`
  String get exTitleMotionAnimatedSize;

  /// In the template: `MouseRegion y Focus`
  String get exTitleEventsHoverFocus;

  /// In the template: `ExpansionTile.onExpansionChanged`
  String get exTitleEventsExpansion;

  /// In the template: `InkWell`
  String get exTitleGestureInkwell;

  /// In the template: `Deslizar con el teclado`
  String get exTitleGestureSwipeKeys;

  /// In the template: `Dismissible`
  String get exTitleGestureDismissible;

  /// In the template: `Draggable y DragTarget`
  String get exTitleGestureDraggable;

  /// In the template: `ReorderableListView`
  String get exTitleGestureReorderable;

  /// In the template: `CustomScrollView con una SliverAppBar fija`
  String get exTitleNavSlivers;

  /// In the template: `Un cajón que es panel fijo desde md`
  String get exTitleDialogPermanentDrawer;

  /// In the template: `Reserva de vuelos`
  String get exTitleRecipeFlights;

  /// In the template: `CRUD`
  String get exTitleRecipeCrud;

  /// In the template: `Circle drawer`
  String get exTitleRecipeCircles;

  /// In the template: `Cells`
  String get exTitleRecipeCells;

  /// In the template: `La tabla de rutas: el grupo de cada módulo dentro del marco de la app.`
  String get structAbout01;

  /// In the template: `La app, declarada una vez: rutas, tema y estilos base.`
  String get structAbout02;

  /// In the template: `La página de inicio, en /.`
  String get structAbout03;

  /// In the template: `El marco de todas las páginas: encabezado, la página y pie.`
  String get structAbout04;

  /// In the template: `Lo que se muestra ante una URL que no existe o un error.`
  String get structAbout05;

  /// In the template: `Las variables de entorno, tipadas y validadas al arrancar.`
  String get structAbout06;

  /// In the template: `El servidor: sirve la app en el puerto del entorno.`
  String get structAbout07;

  /// In the template: `Pruebas de la app, desde el primer día.`
  String get structAbout08;

  /// In the template: `El módulo de inicio: sus rutas en un Group, que la tabla pone en su lugar.`
  String get structAboutHomeRoutes;

  /// In the template: `El componente del módulo: el contador y sus botones.`
  String get structAboutCounterCard;

  /// In the template: `El ViewModel: el estado que cambia en el navegador.`
  String get structAboutCounterViewModel;

  /// In the template: `Los temas claro y oscuro que leen los widgets.`
  String get structAboutTheme;

  /// In the template: `Un componente general: no conoce ningún módulo, así que cualquier página lo usa.`
  String get structAboutPageTitle;

  /// In the template: `El ViewModel probado solo, sin página.`
  String get structAboutCounterTest;

  /// In the template: `La tabla de la app solo compone: el marco, la sesión y los módulos.`
  String get structAbout09;

  /// In the template: `El marco de toda la app. Puede importar las rutas de los módulos para su navegación; core/ no.`
  String get structAbout10;

  /// In the template: `Un cliente para todo el backend: URL base, token y traducción de errores.`
  String get structAbout11;

  /// In the template: `Quién es el usuario: lee la cookie y deja en el contexto el usuario y el cliente API.`
  String get structAbout12;

  /// In the template: `Qué puede hacer: el Group de cada módulo pide el rol que necesita.`
  String get structAbout13;

  /// In the template: `Un componente general: no conoce el negocio, recibe datos simples.`
  String get structAbout14;

  /// In the template: `El módulo es un Group: su marco, sus permisos, su hoja de estilos y su página de error.`
  String get structAbout15;

  /// In the template: `Una regla que solo aplica a ventas: vive en el módulo, no en core/.`
  String get structAbout16;

  /// In the template: `Operaciones del negocio con modelos tipados. Nunca devuelve JSON.`
  String get structAbout17;

  /// In the template: `Un componente del módulo: conoce los pedidos y lo usan varios submódulos.`
  String get structAbout18;

  /// In the template: `Las rutas del submódulo. Otro módulo que enlace aquí importa solo este archivo.`
  String get structAbout19;

  /// In the template: `La página lee los filtros de la URL, pide al repositorio y muestra el resultado.`
  String get structAbout20;

  /// In the template: `Las reglas del formulario, una vez: el navegador y el servidor las aplican igual.`
  String get structAbout21;

  /// In the template: `Un componente del submódulo. Sube a sales/widgets/ cuando otro submódulo lo necesita.`
  String get structAbout22;

  /// In the template: `El ViewModel del navegador, solo para lo que cambia sin ir al servidor.`
  String get structAbout23;

  /// In the template: `La página de error del módulo: gana a la general en las rutas de ventas.`
  String get structAbout24;

  /// In the template: `Qué es una curva`
  String get exMotion2CurvesTitle;

  /// In the template: `Una curva relaciona el tiempo, en el eje horizontal, con el avance de la animación, en el vertical.`
  String get exMotion2CurvesDescription;

  /// In the template: `Curva`
  String get exMotion2Curve;

  /// In the template: `AnimatedAlign y AnimatedPositioned`
  String get exMotion2PositionTitle;

  /// In the template: `AnimatedAlign anima la alineación del hijo; AnimatedPositioned, sus distancias y su tamaño dentro de un Stack.`
  String get exMotion2PositionDescription;

  /// In the template: `Widget`
  String get exMotion2Widget;

  /// In the template: `Destino`
  String get exMotion2Spot;

  /// In the template: `AnimatedSwitcher con Hero`
  String get exMotion2SwitcherTitle;

  /// In the template: `AnimatedSwitcher funde el estado nuevo sobre el anterior, y cada Hero presente en los dos viaja a su nuevo lugar y tamaño.`
  String get exMotion2SwitcherDescription;

  /// In the template: `Disposición`
  String get exMotion2Layout;

  /// In the template: `Fila`
  String get exMotion2LayoutRow;

  /// In the template: `Columna`
  String get exMotion2LayoutColumn;

  /// In the template: `Entrada escalonada`
  String get exMotion2StaggerTitle;

  /// In the template: `Un solo controller y un Interval por fila: cada fila entra un retraso después de la anterior.`
  String get exMotion2StaggerDescription;

  /// In the template: `Retraso`
  String get exMotion2Delay;

  /// In the template: `Un bucle entre dos valores`
  String get exMotion2RepeatTitle;

  /// In the template: `repeat(min:, max:) limita el bucle a un tramo del recorrido; la opacidad y el tamaño del círculo lo siguen.`
  String get exMotion2RepeatDescription;

  /// In the template: `Al llegar`
  String get exMotion2Reverse;

  /// In the template: `Vuelve`
  String get exMotion2ReverseBack;

  /// In the template: `Salta`
  String get exMotion2ReverseJump;

  /// In the template: `Mínimo`
  String get exMotion2Min;

  /// In the template: `Máximo`
  String get exMotion2Max;

  /// In the template: `Periodo`
  String get exMotion2Period;

  /// In the template: `Aparecer al desplazarse`
  String get exMotion2ScrollTitle;

  /// In the template: `Con inView, la animación avanza con el desplazamiento y se revierte al volver; con onVisible corre una sola vez, a su ritmo.`
  String get exMotion2ScrollDescription;

  /// In the template: `Lo mueve`
  String get exMotion2Driver;

  /// In the template: `Efecto`
  String get exMotion2Effect;

  /// In the template: `Sube`
  String get exMotion2EffectRise;

  /// In the template: `Crece`
  String get exMotion2EffectScale;

  /// In the template: `Desliza`
  String get exMotion2EffectSlide;

  /// In the template: `Deslizar para confirmar`
  String get pageExampleSlideToConfirm;

  /// In the template: `Botón de copiar`
  String get pageExampleCopyButton;

  /// In the template: `Pestañas con indicador`
  String get pageExampleTabIndicator;

  /// In the template: `Pila de avisos`
  String get pageExampleToastStack;

  /// In the template: `Deslizar para confirmar`
  String get exMotion2SlideTitle;

  /// In the template: `Arrastra la manija hasta el final. El navegador la mueve con el puntero y el ViewModel recibe solo la posición final: si pasa el umbral, se confirma; si no, la manija vuelve al inicio.`
  String get exMotion2SlideDescription;

  /// In the template: `Umbral`
  String get exMotion2Threshold;

  /// In the template: `Botón de copiar`
  String get exMotion2CopyTitle;

  /// In the template: `Al copiar el comando, el ícono se vuelve una marca de verificación durante un momento y luego regresa.`
  String get exMotion2CopyDescription;

  /// In the template: `Cambio`
  String get exMotion2Morph;

  /// In the template: `Fundido`
  String get exMotion2MorphFade;

  /// In the template: `Escala`
  String get exMotion2MorphScale;

  /// In the template: `Giro`
  String get exMotion2MorphTurn;

  /// In the template: `Se queda`
  String get exMotion2Hold;

  /// In the template: `Pestañas con indicador`
  String get exMotion2TabsTitle;

  /// In the template: `El indicador es un solo elemento que se desliza bajo las etiquetas; el contenido de abajo cambia con un fundido.`
  String get exMotion2TabsDescription;

  /// In the template: `Indicador`
  String get exMotion2Indicator;

  /// In the template: `Píldora`
  String get exMotion2IndicatorPill;

  /// In the template: `Línea`
  String get exMotion2IndicatorLine;

  /// In the template: `Pila de avisos`
  String get exMotion2ToastsTitle;

  /// In the template: `Cada aviso entra por el borde que elijas, el más nuevo queda delante y los anteriores se encogen y se desvanecen detrás. Al descartar, el aviso sale por donde entró.`
  String get exMotion2ToastsDescription;

  /// In the template: `Borde`
  String get exMotion2Edge;

  /// In the template: `Abajo`
  String get exMotion2EdgeBottom;

  /// In the template: `Arriba`
  String get exMotion2EdgeTop;

  /// How a page's title reads in the tab.
  ///
  /// In the template: `{title} · {site}`
  String siteTitleTemplate(String title, String site);

  /// In the template: `El widget {name} de Thor: firma, parámetros y documentación. {summary}`
  String widgetPageDescriptionWithSummary(String name, String summary);

  /// In the template: `Fuente: {url}`
  String llmsSource(String url);

  /// In the template: `Volver arriba`
  String get tocBackToTop;

  /// In the template: `En esta página`
  String get tocOnThisPage;

  /// In the template: `Áreas del sitio`
  String get navAreas;

  /// In the template: `Aplicaciones`
  String get navExamplesApps;

  /// In the template: `Patrones de interacción`
  String get navExamplesPatterns;

  /// In the template: `Servidor`
  String get apiLabelServer;

  /// In the template: `Rutas`
  String get apiLabelRouter;

  /// In the template: `HTML`
  String get apiLabelHtml;

  /// In the template: `Pruebas`
  String get apiLabelTesting;

  /// In the template: `Idiomas`
  String get apiLabelIntl;

  /// In the template: `Herramientas de prueba`
  String get apiLabelThorTest;

  /// In the template: `Sistema de diseño`
  String get apiLabelStudio;

  /// In the template: `Empieza aquí`
  String get homeStartHeading;

  /// In the template: `La guía`
  String get homeGuideHeading;

  /// In the template: `Referencia`
  String get homeReferenceHeading;

  /// In the template: `Apps pequeñas y completas, y patrones de interacción.`
  String get homeExamplesSummary;

  /// In the template: `Cada widget con su demo, su código y sus parámetros.`
  String get homeComponentsSummary;

  /// In the template: `Buscar en la documentación`
  String get searchDialogLabel;

  /// In the template: `Mover`
  String get searchDialogHintMove;

  /// In the template: `Abrir`
  String get searchDialogHintOpen;

  /// In the template: `Cerrar`
  String get searchDialogHintClose;

  /// In the template: `Instala el comando thor y crea tu primer proyecto.`
  String get homeStartInstall;

  /// In the template: `Una app completa, de la pantalla a los datos, paso a paso.`
  String get homeStartFirstApp;

  /// In the template: `Qué se queda igual y qué cambia al pasar de Flutter a la web.`
  String get homeStartFlutter;
}

/// The messages in `es` (app_es.arb).
class AppLocalizationsEs extends AppLocalizations {
  /// Messages in [locale].
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get siteName => 'Thor docs';

  @override
  String get siteDescription =>
      'Thor: la API de widgets de Flutter, renderizada como HTML y CSS en el servidor. Guías, catálogo de widgets y referencia de API.';

  @override
  String get siteImageAlt =>
      'Thor: la API de widgets de Flutter, renderizada como HTML y CSS.';

  @override
  String get siteOpenGraphLocale => 'es_MX';

  @override
  String get navGuide => 'Guía';

  @override
  String get navComponents => 'Componentes';

  @override
  String get navExamples => 'Ejemplos';

  @override
  String get navApi => 'API';

  @override
  String get navChanges => 'Cambios';

  @override
  String get navGithub => 'Repositorio en GitHub';

  @override
  String get sectionGetStarted => 'Empezar';

  @override
  String get sectionFundamentals => 'Fundamentos';

  @override
  String get sectionArchitecture => 'Arquitectura';

  @override
  String get sectionInterface => 'Interfaz';

  @override
  String get sectionDataAndState => 'Datos y estado';

  @override
  String get sectionTestAndDeploy => 'Probar y publicar';

  @override
  String get sectionComponents => 'Componentes';

  @override
  String get sectionExamples => 'Ejemplos';

  @override
  String get sectionGetStartedSummary =>
      'Qué es Thor, cómo instalarlo, una app completa paso a paso y el mapa desde Flutter.';

  @override
  String get sectionFundamentalsSummary =>
      'Widgets, layout, interactividad, rutas y datos de la página: lo que toda app usa.';

  @override
  String get sectionArchitectureSummary =>
      'View, ViewModel, Repository y Service con los nombres de la guía de arquitectura de Flutter, y qué corre dónde.';

  @override
  String get sectionInterfaceSummary =>
      'Tema, estilos, animación, gestos, diálogos, accesibilidad e idiomas.';

  @override
  String get sectionDataAndStateSummary =>
      'El ViewModel a fondo, acciones del servidor, formularios, datos en vivo, listas largas, paquetes y seguridad.';

  @override
  String get sectionTestAndDeploySummary =>
      'Pruebas por capa, el comando thor, sitio estático o servidor, y SEO.';

  @override
  String get sectionComponentsSummary =>
      'Cada widget con su demo viva, su código y sus parámetros.';

  @override
  String get sectionExamplesSummary =>
      'Apps pequeñas y completas (las tareas de 7GUIs y una página de contenido) y cuatro patrones de interacción.';

  @override
  String get pageWhatIsThor => 'Qué es Thor';

  @override
  String get pageInstallation => 'Instalación';

  @override
  String get pageFirstApp => 'Tu primera app';

  @override
  String get pageFromFlutter => 'Si vienes de Flutter';

  @override
  String get pageWidgets => 'Widgets';

  @override
  String get pageLayout => 'Layout';

  @override
  String get pageInteractivity => 'Interactividad';

  @override
  String get pageNavigation => 'Rutas y navegación';

  @override
  String get pageReadingData => 'Leer datos';

  @override
  String get pageAppArchitecture => 'Arquitectura de una app';

  @override
  String get pageProjectStructure => 'Estructura del proyecto';

  @override
  String get pageUiLayer => 'Capa de interfaz';

  @override
  String get pageDataLayer => 'Capa de datos';

  @override
  String get pagePatterns => 'Patrones';

  @override
  String get pageThemeAndStyles => 'Tema y estilos';

  @override
  String get pageAdvancedStyles => 'Estilos avanzados';

  @override
  String get pageAnimations => 'Animaciones';

  @override
  String get pageGestures => 'Gestos';

  @override
  String get pageDialogsAndMenus => 'Diálogos y menús';

  @override
  String get pageLongLists => 'Listas largas';

  @override
  String get pageAccessibility => 'Accesibilidad';

  @override
  String get pageLocalization => 'Idiomas';

  @override
  String get pageState => 'Estado';

  @override
  String get pageServerAndActions => 'Servidor y acciones';

  @override
  String get pageLiveData => 'Datos en vivo';

  @override
  String get pageForms => 'Formularios';

  @override
  String get pageSessionAndSecurity => 'Sesión y seguridad';

  @override
  String get pagePubPackages => 'Paquetes de pub';

  @override
  String get pageTesting => 'Pruebas';

  @override
  String get pageCli => 'El comando thor';

  @override
  String get pageBuildAndDeploy => 'Compilar y publicar';

  @override
  String get pageSeo => 'SEO';

  @override
  String get pageExamples => 'Ejemplos';

  @override
  String get pageComponents => 'Componentes';

  @override
  String get pageComponentsButtons => 'Botones';

  @override
  String get pageComponentsInputs => 'Entradas';

  @override
  String get pageComponentsSelection => 'Selección';

  @override
  String get pageComponentsContent => 'Contenido';

  @override
  String get pageComponentsNavigation => 'Navegación';

  @override
  String get pageComponentsFeedback => 'Avisos';

  @override
  String get pageHowItWorks => 'Qué corre dónde';

  @override
  String get pageEmbeddedFlutter => 'Flutter embebido';

  @override
  String get footerStart => 'Empezar';

  @override
  String get footerReference => 'Referencia';

  @override
  String get footerResources => 'Recursos';

  @override
  String get footerErrors => 'Errores';

  @override
  String get footerGithub => 'GitHub';

  @override
  String get docEditPage => 'Editar en GitHub';

  @override
  String get docCopyMarkdown => 'Copiar como Markdown';

  @override
  String get docPageActions => 'Acciones de la página';

  @override
  String docFallbackNotice(String language) =>
      'Esta página todavía no está disponible en tu idioma: se muestra la versión en ${language}.';

  @override
  String get calloutNote => 'Nota';

  @override
  String get calloutTip => 'Consejo';

  @override
  String get calloutWarning => 'Importante';

  @override
  String get calloutWarningAlias => 'Ojo';

  @override
  String get calloutDanger => 'Cuidado';

  @override
  String get calloutFlutter => 'Diferencia con Flutter';

  @override
  String get codeTerminal => 'Terminal';

  @override
  String get ladderFirst => 'primero';

  @override
  String get ladderLast => 'último recurso';

  @override
  String get stageResizeHint =>
      'El ancho de la caja se ajusta desde su esquina inferior derecha.';

  @override
  String get previewLabel => 'Vista previa';

  @override
  String get exampleTabHtml => 'HTML generado';

  @override
  String get exampleTabCss => 'CSS generado';

  @override
  String get benchReplay => 'Repetir';

  @override
  String get benchSwitches => 'Interruptores';

  @override
  String get benchLevels => 'Niveles';

  @override
  String get benchAppCode => 'Código de la app';

  @override
  String get benchSegmentStart => 'Inicio';

  @override
  String get benchSegmentCenter => 'Centro';

  @override
  String get benchSegmentEnd => 'Final';

  @override
  String get benchSegmentBetween => 'Entre';

  @override
  String get benchRowTitle => 'mainAxisAlignment en una fila';

  @override
  String get benchRowDescription =>
      'mainAxisAlignment reparte el espacio libre de la fila; spacing fija la separación entre sus hijos.';

  @override
  String get benchRowAlignment => 'Alineación';

  @override
  String get benchRowSpacing => 'Espacio';

  @override
  String get benchCardTitle => 'Una tarjeta con su estilo';

  @override
  String get benchCardDescription =>
      'La tarjeta lee su radio, su espacio interior y su relleno de campos de estado del ViewModel.';

  @override
  String get benchCardFill => 'Relleno';

  @override
  String get benchCardFillSoft => 'Suave';

  @override
  String get benchCardFillSolid => 'Pleno';

  @override
  String get benchCardRadius => 'Radio';

  @override
  String get benchCardPadding => 'Espacio';

  @override
  String get benchCounterTitle => 'Un contador con paso';

  @override
  String get benchCounterDescription =>
      'El paso es otro campo de estado del ViewModel: cada botón llama a un método que lo lee.';

  @override
  String get benchCounterStep => 'Paso';

  @override
  String get layersOrdersViewKind => 'Widget';

  @override
  String get layersOrdersViewModelKind => 'ViewModel (ThorState)';

  @override
  String get layersOrdersRepositoryKind => 'Clase';

  @override
  String get layersOrdersServiceKind => 'Cliente HTTP';

  @override
  String get layersOrdersInjectionKind => 'Middleware';

  @override
  String get layersOrdersNavigationKind => 'Tabla de rutas';

  @override
  String get layersOrdersTestsKind => 'dart test';

  @override
  String get layersOrdersViewDescription =>
      'Muestra los datos del ViewModel y le avisa lo que hace el usuario. No tiene lógica: lee el ViewModel y llama a sus métodos.';

  @override
  String get layersOrdersViewModelDescription =>
      'Guarda los datos de la pantalla y las acciones que la vista puede pedir. En Thor es un ThorState: una query lee, un command cambia.';

  @override
  String get layersOrdersRepositoryDescription =>
      'La fuente única de los pedidos: le pide al servicio, convierte la respuesta en objetos Order y esconde de dónde vienen los datos.';

  @override
  String get layersOrdersServiceDescription =>
      'Habla con el backend y nada más. En Thor usa ThorHttpClient en el servidor.';

  @override
  String get layersOrdersInjectionDescription =>
      'Entrega a cada capa lo que necesita sin que la pida por su cuenta. En Flutter es un Provider; en Thor, un middleware que deja el repositorio en la petición con un ContextKey.';

  @override
  String get layersOrdersNavigationDescription =>
      'Dice qué pantalla vive en qué dirección. En Flutter es go_router; en Thor, una ThorRoute por página en un ThorRouter.';

  @override
  String get layersOrdersTestsDescription =>
      'Cada capa se prueba sola: el repositorio con un servicio falso, el ViewModel con un repositorio falso y la vista con los datos que quieras.';

  @override
  String get llmsReferenceHeading => 'API y errores';

  @override
  String get llmsApiTitle => 'API de thor_ui';

  @override
  String get llmsApiDescription =>
      'clases, funciones y constructores públicos, por carpeta';

  @override
  String get llmsErrorsTitle => 'Códigos de error';

  @override
  String get llmsErrorsDescription =>
      'cada `THOR-xxx` con qué pasó, por qué y cómo se arregla';

  @override
  String get llmsFullTitle => 'Todo en un archivo';

  @override
  String get llmsFullDescription => 'la guía completa en Markdown';

  @override
  String get apiEyebrow => 'Referencia de API';

  @override
  String apiPageTitle(String name) => '${name} · API';

  @override
  String apiPageDescription(String name) =>
      'Referencia de API de ${name}: clases, funciones y constructores públicos.';

  @override
  String get apiSummary => 'Clases, funciones y constructores públicos.';

  @override
  String widgetEyebrow(String topic) => 'Widget · ${topic}';

  @override
  String widgetPageTitle(String name) => '${name} · Widget';

  @override
  String widgetPageDescription(String name) =>
      'El widget ${name} de Thor: firma, parámetros y documentación';

  @override
  String get errorsEyebrow => 'Códigos de error';

  @override
  String get changesEyebrow => 'Versiones';

  @override
  String get changesTitle => 'Cambios';

  @override
  String changesPackageTitle(String name) => 'Cambios de ${name}';

  @override
  String get changesVersionUnreleased => 'Sin publicar';

  @override
  String changesVersionNotPublished(String version) =>
      '${version} (sin publicar)';

  @override
  String changesPackageIntro(String package, String role) =>
      'Lo que cambia en `${package}` (${role}) para quien hace una app. Thor todavía no publica una versión: lo de «Sin publicar» ya está en el código y llegará en la próxima.';

  @override
  String get changesLanguageNote =>
      'Cada cambio se cuenta como lo escriben los autores del paquete, en inglés, igual que el código.';

  @override
  String get changesBreakingTitle => 'Cambios que rompen';

  @override
  String get changesGroupAdded => 'Nuevo';

  @override
  String get changesGroupChanged => 'Cambió';

  @override
  String get changesGroupDeprecated => 'Deprecado (usa X)';

  @override
  String get changesIndexIntro =>
      'Qué cambió en Thor, por paquete, y qué hacer en tu app cuando un nombre se va. Thor todavía no publica una versión: aquí está lo que ya entró y llegará en la primera.';

  @override
  String get changesMigrateHeading => 'Migrar';

  @override
  String get changesMigrateIntro =>
      'Un nombre público no desaparece de golpe: pasa una versión menor como `@Deprecated("Usa X")`, con un alias cuando se puede, y el analizador te lo marca. Esto es lo que ya está deprecado o rompe, y qué usar en su lugar.';

  @override
  String get changesMigrateNone => 'Nada está deprecado ni rompe por ahora.';

  @override
  String get changesPackagesHeading => 'Por paquete';

  @override
  String get changesColPackage => 'Paquete';

  @override
  String get changesColRole => 'Qué es';

  @override
  String get changesColCount => 'Cambios sin publicar';

  @override
  String get changesRoleThorUi => 'los widgets y el renderizado';

  @override
  String get changesRoleThorStyle => 'valores de estilo y CSS';

  @override
  String get changesRoleThorEngine =>
      'el estado de la página: ThorState, query y command';

  @override
  String get changesRoleThorServer => 'rutas, datos, sesión y exportación';

  @override
  String get changesRoleThorStudio => 'el sistema de diseño';

  @override
  String get changesRoleThorBuilder => 'los errores THOR-* del build';

  @override
  String get changesRoleThorCli => 'el comando `thor`';

  @override
  String get changesRoleThorLints => 'las reglas del analizador';

  @override
  String get changesRoleThorTest => 'las herramientas de test';

  @override
  String widgetDefaultDoc(String name) => 'El widget `${name}`.';

  @override
  String get widgetExampleHeading => 'Ejemplo';

  @override
  String get widgetSignatureHeading => 'Firma';

  @override
  String get widgetParamsHeading => 'Parámetros';

  @override
  String widgetParamsOf(String name) => 'Parámetros de `${name}`';

  @override
  String get widgetColParam => 'Parámetro';

  @override
  String get widgetColType => 'Tipo';

  @override
  String get widgetColDoc => 'Qué hace';

  @override
  String get widgetRequired => '(requerido)';

  @override
  String get widgetDeprecated => 'Deprecado';

  @override
  String get widgetInFlutterHeading => 'En Flutter';

  @override
  String widgetFlutterSame(String name, String url) =>
      'Es el mismo widget que `${name}` de Flutter: [documentación de Flutter](${url}).';

  @override
  String widgetFlutterNone(String name) =>
      '`${name}` no tiene un equivalente directo en Flutter: es una pieza propia de Thor.';

  @override
  String get widgetPageLink => 'Página del widget';

  @override
  String get apiSymbolsHeading => 'Símbolos';

  @override
  String get badgeYes => 'Sí';

  @override
  String get badgeNo => 'No';

  @override
  String get badgePartial => 'Parcial';

  @override
  String get errorNotFoundTitle => 'No encontramos esa página';

  @override
  String get errorNotFoundLead =>
      'Quizá cambió de nombre. Empieza por la guía o busca en la API.';

  @override
  String get errorGenericTitle => 'Algo salió mal';

  @override
  String get errorGenericLead => 'Inténtalo de nuevo en un momento.';

  @override
  String get errorStartSubtitle => 'El punto de partida de la guía';

  @override
  String get notFoundGuide => 'No hay esa guía';

  @override
  String get notFoundPackage => 'No hay ese paquete';

  @override
  String get notFoundFolder => 'No hay esa carpeta';

  @override
  String get notFoundWidget => 'No hay ese widget';

  @override
  String get notFoundCode => 'No hay ese código';

  @override
  String get notFoundCodes => 'No hay códigos';

  @override
  String get notFoundChanges => 'No hay cambios de ese paquete';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get searchDescription =>
      'Busca en las guías, la referencia de API y los códigos de error de Thor.';

  @override
  String get searchHint => 'Buscar en los docs';

  @override
  String get searchNeedsJs =>
      'La búsqueda necesita JavaScript. Sin él, usa el menú de la guía o busca en el sitio desde tu buscador.';

  @override
  String get searchPrompt => 'Escribe lo que buscas.';

  @override
  String searchResultOne(String query) => '1 resultado para «${query}»';

  @override
  String searchResultMany(String count, String query) =>
      '${count} resultados para «${query}»';

  @override
  String searchShowMore(String count) => 'Ver ${count} más';

  @override
  String get searchShowLess => 'Ver menos';

  @override
  String get searchBestMatch => 'Mejor coincidencia';

  @override
  String searchNone(String query) =>
      'Nada para «${query}». Prueba con otra palabra.';

  @override
  String get searchNoIndex =>
      'La búsqueda no está disponible en esta copia del sitio.';

  @override
  String get homeMetaTitle => 'Thor · la API de Flutter, el HTML de la web';

  @override
  String get homeMetaDescription =>
      'Escribe páginas web con los widgets de Flutter en Dart; llegan al navegador como HTML semántico y CSS.';

  @override
  String get navErrors => 'Errores';

  @override
  String get footerLegal =>
      'Licencia MIT. Este sitio está construido con Thor.';

  @override
  String get homeHeroTitle => 'Escribe la web con widgets de Flutter.';

  @override
  String get homeHeroLead =>
      'Thor convierte tu código Dart en HTML semántico y CSS. El JavaScript llega solo donde hay estado.';

  @override
  String get homeCtaStart => 'Empezar';

  @override
  String get homeCtaFlutter => 'Si vienes de Flutter';

  @override
  String get exLayoutColumnTitle => 'crossAxisAlignment en una columna';

  @override
  String get exLayoutColumnDescription =>
      'crossAxisAlignment decide el ancho de cada hijo y su posición dentro de la columna.';

  @override
  String get exLayoutColumnAlignment => 'Alinear';

  @override
  String get exLayoutColumnStretch => 'Llenar';

  @override
  String get exLayoutFlexTitle => 'Expanded y Flexible en una fila';

  @override
  String get exLayoutFlexDescription =>
      'Dos hijos se reparten el ancho que deja el hijo de tamaño fijo: Expanded lo llena y Flexible lo usa solo si lo necesita.';

  @override
  String get exLayoutFlexKind => 'Widget';

  @override
  String get exLayoutFlexExpanded => 'Expanded';

  @override
  String get exLayoutFlexFlexible => 'Flexible';

  @override
  String get exLayoutFlexFactor => 'Flex de B';

  @override
  String get exLayoutStackTitle => 'Positioned en un Stack';

  @override
  String get exLayoutStackDescription =>
      'El primer hijo define el tamaño del Stack; Positioned coloca el otro hijo a una distancia fija de una esquina.';

  @override
  String get exLayoutStackCorner => 'Esquina';

  @override
  String get exLayoutStackTopLeft => '↖';

  @override
  String get exLayoutStackTopRight => '↗';

  @override
  String get exLayoutStackBottomLeft => '↙';

  @override
  String get exLayoutStackBottomRight => '↘';

  @override
  String get exLayoutStackInset => 'Distancia';

  @override
  String get exLayoutWrapTitle => 'Wrap con etiquetas';

  @override
  String get exLayoutWrapDescription =>
      'Los hijos que no caben en el ancho disponible pasan a la línea siguiente.';

  @override
  String get exLayoutWrapWidth => 'Ancho';

  @override
  String get exLayoutWrapSpacing => 'Espacio';

  @override
  String get exLayoutWrapRunSpacing => 'Entre líneas';

  @override
  String get exLayoutGridTitle => 'Una cuadrícula de seis casillas';

  @override
  String get exLayoutGridDescription =>
      'Las casillas se reparten en columnas con un espacio fijo entre ellas; la primera puede ocupar toda la fila.';

  @override
  String get exLayoutGridFirst => 'Primera';

  @override
  String get exLayoutGridSingle => '1 col.';

  @override
  String get exLayoutGridWide => 'Fila';

  @override
  String get exLayoutGridColumns => 'Columnas';

  @override
  String get exLayoutGridGap => 'Hueco';

  @override
  String get exLayoutResponsiveTitle =>
      'Una tarjeta que sigue el ancho de su caja';

  @override
  String get exLayoutResponsiveDescription =>
      'Desde 420 px de ancho de la caja, la columna pasa a fila con el mismo árbol de widgets.';

  @override
  String get exLayoutResponsiveWidth => 'Ancho de la caja';

  @override
  String get exWidgetsComposeTitle => 'Un widget hecho de otros widgets';

  @override
  String get exWidgetsComposeDescription =>
      'UserTile es una clase que la lista reutiliza en cada fila; la lista decide solo cómo se acomodan.';

  @override
  String get exWidgetsComposeAxis => 'Disposición';

  @override
  String get exWidgetsComposeColumn => 'Columna';

  @override
  String get exWidgetsComposeRow => 'Fila';

  @override
  String get exWidgetsComposeCount => 'Cuántos';

  @override
  String get exStateGreetingTitle => 'Un ViewModel con dos campos de estado';

  @override
  String get exStateGreetingDescription =>
      'El campo de texto llama a setName con lo que escribe el usuario y el Switch cambia el saludo; el resto de la página solo lee los dos campos.';

  @override
  String get exStateGreetingSalutation => 'Saludo';

  @override
  String get exStateGreetingHello => 'Hola';

  @override
  String get exRoutesLinkTitle => 'La URL que arma una ruta';

  @override
  String get exRoutesLinkDescription =>
      'link() arma la dirección a partir del parámetro y la query; un parámetro de otro tipo es un error al construirla.';

  @override
  String get exRoutesLinkQuery => 'Estado';

  @override
  String get exRoutesLinkNone => 'Todos';

  @override
  String get exRoutesLinkOpen => 'Abiertos';

  @override
  String get exRoutesLinkClosed => 'Cerrados';

  @override
  String get exRoutesLinkId => 'Parámetro id';

  @override
  String get exRoutesMiddlewareTitle => 'Lo que decide un middleware';

  @override
  String get exRoutesMiddlewareDescription =>
      'El middleware deja pasar la petición, redirige o responde con un error según el usuario y la ruta.';

  @override
  String get exRoutesMiddlewareVisitor => 'Usuario';

  @override
  String get exRoutesMiddlewareGuest => 'Sin sesión';

  @override
  String get exRoutesMiddlewareMember => 'Miembro';

  @override
  String get exRoutesMiddlewareAdmin => 'Admin';

  @override
  String get exRoutesMiddlewareTarget => 'Ruta';

  @override
  String get exRoutesMiddlewareAccount => 'Cuenta';

  @override
  String get exRoutesMiddlewareAdminPage => 'Panel';

  @override
  String get exDataLoadTitle => 'Qué puede devolver load';

  @override
  String get exDataLoadDescription =>
      'Según lo que responde el repositorio, load entrega los datos a la página o termina en una página de error.';

  @override
  String get exDataLoadAnswer => 'El repositorio';

  @override
  String get exDataLoadOrders => 'Pedidos';

  @override
  String get exDataLoadMissing => 'Nada';

  @override
  String get exDataLoadFailing => 'Falla';

  @override
  String get exDataLoadCount => 'Cuántos pedidos';

  @override
  String get exThemeColorsTitle => 'Los colores del tema';

  @override
  String get exThemeColorsDescription =>
      'La tarjeta lee sus colores con Theme.of(context) y sigue el modo y el acento del tema.';

  @override
  String get exThemeLook => 'Modo';

  @override
  String get exThemeLookLight => 'Claro';

  @override
  String get exThemeLookDark => 'Oscuro';

  @override
  String get exThemeAccent => 'Acento';

  @override
  String get exThemeAccentViolet => 'Lila';

  @override
  String get exThemeAccentTeal => 'Verde';

  @override
  String get exThemeAccentOrange => 'Ámbar';

  @override
  String get exThemeTextTitle => 'Un estilo de texto';

  @override
  String get exThemeTextDescription =>
      'copyWith cambia el tamaño y el peso de un rol del TextTheme; el resto del estilo sigue al tema.';

  @override
  String get exThemeTextSize => 'Tamaño';

  @override
  String get exThemeTextWeight => 'Peso';

  @override
  String get exMotionImplicitTitle => 'Una animación implícita';

  @override
  String get exMotionImplicitDescription =>
      'AnimatedContainer anima el cambio de posición con la duración y la curva indicadas.';

  @override
  String get exMotionPlace => 'Posición';

  @override
  String get exMotionPlaceStart => 'Inicio';

  @override
  String get exMotionPlaceEnd => 'Final';

  @override
  String get exMotionCurve => 'Curva';

  @override
  String get exMotionCurveOut => 'easeOut';

  @override
  String get exMotionCurveInOut => 'easeInOut';

  @override
  String get exMotionCurveBack => 'easeOutBack';

  @override
  String get exMotionDuration => 'Duración';

  @override
  String get exMotionTweenTitle => 'TweenAnimationBuilder';

  @override
  String get exMotionTweenDescription =>
      'TweenAnimationBuilder anima el punto hacia el valor final del tween.';

  @override
  String get exMotionTweenEnd => 'Destino';

  @override
  String get exMotionExplicitTitle => 'Una animación explícita';

  @override
  String get exMotionExplicitDescription =>
      'AnimationController inicia la animación al cargar la página; el navegador la ejecuta.';

  @override
  String get exMotionListTitle => 'AnimatedList';

  @override
  String get exMotionListDescription =>
      'Las filas de AnimatedList entran al agregarse y salen al quitarse, con la duración indicada.';

  @override
  String get exMotionPageTitle => 'Transición entre páginas';

  @override
  String get exMotionPageDescription =>
      'Vista previa de PageTransition entre una lista y un artículo. La real ocurre entre dos documentos.';

  @override
  String get exMotionPageKind => 'Transición';

  @override
  String get exMotionPageFade => 'Fundido';

  @override
  String get exMotionPageSlide => 'Deslizar';

  @override
  String get exMotionPageFadeUp => 'Subir';

  @override
  String get exGestureTapTitle => 'Dónde cayó el toque';

  @override
  String get exGestureTapDescription =>
      'onTapDown y onTapUp reciben la posición del toque dentro del widget.';

  @override
  String get exGestureTapEvent => 'Evento';

  @override
  String get exGestureTapDown => 'onTapDown';

  @override
  String get exGestureTapUp => 'onTapUp';

  @override
  String get exGestureTapSize => 'Punto';

  @override
  String get exGestureDragTitle => 'Arrastrar y soltar';

  @override
  String get exGestureDragDescription =>
      'El navegador mueve la ficha con el puntero; el método del ViewModel recibe el desplazamiento al soltarla.';

  @override
  String get exGestureDragAxis => 'Eje';

  @override
  String get exGestureDragFree => 'Libre';

  @override
  String get exGestureDragHorizontal => 'Horizontal';

  @override
  String get exGestureDragVertical => 'Vertical';

  @override
  String get exGestureDragRest => 'Al soltar';

  @override
  String get exGestureDragSnap => 'Vuelve';

  @override
  String get exGestureDragStay => 'Se queda';

  @override
  String get exIconsTitle => 'Variantes de un ícono';

  @override
  String get exIconsDescription =>
      'Los mismos seis nombres en sus cuatro variantes y a cualquier tamaño.';

  @override
  String get exIconsVariant => 'Variante';

  @override
  String get exIconsFilled => 'Lleno';

  @override
  String get exIconsOutlined => 'Borde';

  @override
  String get exIconsRounded => 'Suave';

  @override
  String get exIconsSharp => 'Filo';

  @override
  String get exIconsSize => 'Tamaño';

  @override
  String get exArchCommandTitle => 'Un command: pendiente, error y resultado';

  @override
  String get exArchCommandDescription =>
      'Mientras el command espera, el botón no se repite; si el servidor falla, error dice por qué.';

  @override
  String get exArchOptimisticTitle => 'Estado optimista a mano';

  @override
  String get exArchOptimisticDescription =>
      'Con «Optimista» la estrella cambia al pulsar y vuelve atrás si el servidor falla.';

  @override
  String get exArchServer => 'Servidor';

  @override
  String get exArchServerOk => 'Responde';

  @override
  String get exArchServerFails => 'Falla';

  @override
  String get exArchLatency => 'Latencia';

  @override
  String get exArchOptimistic => 'Optimista';

  @override
  String get layersOrdersPageKind => 'ThorPage';

  @override
  String get layersOrdersModelKind => 'Clase';

  @override
  String get layersOrdersUiViewDescription =>
      'Es un widget: muestra lo que el ViewModel le da y le pasa lo que hace el usuario. QueryBuilder renderiza la espera, el error y los datos; el botón llama a un método del ViewModel.';

  @override
  String get layersOrdersUiViewModelDescription =>
      'La parte del ViewModel que vive en el navegador: query lee, command escribe, state guarda lo que el usuario cambia y derived calcula a partir de ellos.';

  @override
  String get layersOrdersPageDescription =>
      'La otra mitad del ViewModel vive en el servidor: load trae los datos antes de renderizar y una acción recibe el formulario. Lanzar NotFound o Redirect decide qué página se ve.';

  @override
  String get layersOrdersModelDescription =>
      'Un dato del negocio, inmutable y sin lógica de pantalla. Lo que viaja en una query necesita toJson y fromJson.';

  @override
  String get layersOrdersDataRepositoryDescription =>
      'Una interfaz con una implementación HTTP. Convierte la respuesta en modelos y los errores del backend en lo que una página sabe lanzar: NotFound o HttpError. Nunca un Redirect: adónde va un usuario sin sesión lo decide el middleware.';

  @override
  String get layersOrdersDataServiceDescription =>
      'Un cliente por backend, sin estado ni reglas: pregunta y devuelve la respuesta tal cual. ThorHttpClient pone el plazo y reutiliza conexiones.';

  @override
  String get layersOrdersDataInjectionDescription =>
      'Un middleware deja el repositorio en la petición con un ContextKey. El mismo Group sirve al repositorio real en producción y a uno falso en pruebas.';

  @override
  String get layersOrdersDataTestsDescription =>
      'Con un repositorio falso la página se prueba sin red ni backend: el cliente de pruebas hace la petición y la respuesta se comprueba.';

  @override
  String get exStateDerivedTitle => 'Un valor calculado una vez';

  @override
  String get exStateDerivedDescription =>
      'La lista y el contador leen el mismo derived: se recalcula una vez por cambio, no una por Watch.';

  @override
  String get exStateDerivedOrder => 'Orden';

  @override
  String get exStateDerivedOrderMag => 'Magnitud';

  @override
  String get exStateDerivedOrderPlace => 'Lugar';

  @override
  String get exStateDerivedMin => 'Magnitud mínima';

  @override
  String get exStateQueryTitle => 'Los tres estados de un QueryBuilder';

  @override
  String get exStateQueryDescription =>
      'El builder se renderiza una vez por estado del snapshot, y el navegador cambia entre esas variantes.';

  @override
  String get exStateQueryPhase => 'Snapshot';

  @override
  String get exStateQueryLoading => 'Espera';

  @override
  String get exStateQueryReady => 'Datos';

  @override
  String get exStateQueryError => 'Error';

  @override
  String get exDataFeedTitle => 'Una lista que el servidor mantiene al día';

  @override
  String get exDataFeedDescription =>
      'El servidor envía cada cambio de la lista y la página muestra el estado de la conexión.';

  @override
  String get exDataFeedLink => 'Red';

  @override
  String get exDataFeedLive => 'Activa';

  @override
  String get exDataFeedWaiting => 'Espera';

  @override
  String get exDataFeedClosed => 'Cerrada';

  @override
  String get exDataPieceTitle => 'Una parte bajo demanda';

  @override
  String get exDataPieceDescription =>
      'La página lleva un enlace de respaldo y el servidor envía la parte cuando el navegador la pide.';

  @override
  String get exDataPieceTrigger => 'Se pide al';

  @override
  String get exDataPieceOpen => 'Abrir';

  @override
  String get exDataPieceVisible => 'Verse';

  @override
  String get exDataPieceIdle => 'Cargar';

  @override
  String get exDataPieceMoment => 'La página';

  @override
  String get exDataPieceBefore => 'Antes';

  @override
  String get exDataPieceAfter => 'Después';

  @override
  String get exFormsRuleTitle => 'La regla de un campo';

  @override
  String get exFormsRuleDescription =>
      'Cada regla del campo tiene su mensaje: al enviar, se muestra el de la primera que no se cumple.';

  @override
  String get exFormsRuleLabel => 'Regla';

  @override
  String get exFormsRuleRequired => 'Vacío';

  @override
  String get exFormsRuleEmail => 'Correo';

  @override
  String get exFormsRuleMin => 'Largo';

  @override
  String get exFormsPhaseTitle => 'Un formulario que va al servidor';

  @override
  String get exFormsPhaseDescription =>
      'Un Form que navega se marca ocupado mientras envía y, si el servidor lo rechaza, vuelve con el primer error.';

  @override
  String get exFormsPhaseLabel => 'Estado';

  @override
  String get exFormsPhaseEditing => 'Edición';

  @override
  String get exFormsPhaseSending => 'Envío';

  @override
  String get exFormsPhaseFailed => 'Error';

  @override
  String get exStartInstallTitle => 'De los comandos a la primera página';

  @override
  String get exStartInstallDescription =>
      'Los comandos y el título de la página de inicio dependen de dónde toma Thor el proyecto.';

  @override
  String get exStartInstallSource => 'Thor desde';

  @override
  String get exStartInstallSourceLocal => 'Esta máquina';

  @override
  String get exStartInstallTitleLabel => 'Título';

  @override
  String get exCatYes => 'Sí';

  @override
  String get exCatEnabled => 'Habilitado';

  @override
  String get exCatIcon => 'Ícono';

  @override
  String get exCatVariant => 'Variante';

  @override
  String get exCatSize => 'Tamaño';

  @override
  String get exCatSmall => 'Pequeño';

  @override
  String get exCatMedium => 'Mediano';

  @override
  String get exCatLarge => 'Grande';

  @override
  String get exBtnFilledTitle => 'FilledButton';

  @override
  String get exBtnFilledDescription =>
      'La acción principal: relleno o tonal, con o sin ícono, habilitado o no.';

  @override
  String get exBtnKindFilled => 'Relleno';

  @override
  String get exBtnKindTonal => 'Tonal';

  @override
  String get exBtnKindOutlined => 'Borde';

  @override
  String get exBtnKindText => 'Texto';

  @override
  String get exBtnElevatedTitle => 'ElevatedButton';

  @override
  String get exBtnElevatedDescription =>
      'Un botón elevado sobre la superficie, con o sin ícono.';

  @override
  String get exBtnIconLabelsTitle => 'El constructor .icon';

  @override
  String get exBtnIconLabelsDescription =>
      'Los cuatro botones aceptan .icon; FilledButton además .tonal y .tonalIcon.';

  @override
  String get exBtnLink => 'Enlace';

  @override
  String get exBtnOutlinedTitle => 'OutlinedButton';

  @override
  String get exBtnOutlinedDescription =>
      'Una acción secundaria: con onPressed es un botón, con href un enlace.';

  @override
  String get exBtnTextTitle => 'TextButton';

  @override
  String get exBtnTextDescription =>
      'La acción de menor peso: con onPressed es un botón, con href un enlace.';

  @override
  String get exBtnIconTitle => 'IconButton';

  @override
  String get exBtnIconDescription =>
      'Un botón de ícono con nombre accesible: cambia el tamaño del ícono.';

  @override
  String get exBtnVariantsTitle => 'Variantes de IconButton';

  @override
  String get exBtnVariantsDescription =>
      'Estándar, filled, filledTonal y outlined; con href es un enlace.';

  @override
  String get exBtnVarStandard => 'Estándar';

  @override
  String get exBtnFabTitle => 'FloatingActionButton';

  @override
  String get exBtnFabDescription => 'Los tamaños del botón de acción flotante.';

  @override
  String get exBtnFabExtended => 'Extendido';

  @override
  String get exBtnStyleTitle => 'ButtonStyle y styleFrom';

  @override
  String get exBtnStyleDescription =>
      'Forma, radio y espacio de un botón con styleFrom.';

  @override
  String get exBtnShape => 'Forma';

  @override
  String get exBtnShapeRounded => 'Redondeada';

  @override
  String get exBtnShapeStadium => 'Estadio';

  @override
  String get exBtnRadius => 'Radio';

  @override
  String get exBtnPadding => 'Espacio';

  @override
  String get pageExampleCounter => 'Contador';

  @override
  String get pageExampleTemperature => 'Convertidor de temperatura';

  @override
  String get pageExampleFlightBooker => 'Reserva de vuelos';

  @override
  String get pageExampleTimer => 'Temporizador';

  @override
  String get pageExampleCrud => 'Lista con CRUD';

  @override
  String get pageExampleCircleDrawer => 'Círculos con deshacer';

  @override
  String get pageExampleCells => 'Hoja de cálculo';

  @override
  String get pageExampleContentPage => 'Página de contenido';

  @override
  String get exInpHelper => 'Ayuda';

  @override
  String get exInpError => 'Error';

  @override
  String get exInpName => 'Nombre';

  @override
  String get exInpTextFieldTitle => 'TextField';

  @override
  String get exInpTextFieldDescription =>
      'Un campo de texto: ayuda, ícono, error y habilitado.';

  @override
  String get exInpStatesTitle => 'Estados del campo';

  @override
  String get exInpStatesDescription =>
      'Correo, contraseña o varias líneas; normal, con error o bloqueado.';

  @override
  String get exInpKind => 'Tipo';

  @override
  String get exInpKindEmail => 'Correo';

  @override
  String get exInpStateNormal => 'Normal';

  @override
  String get exInpStateError => 'Error';

  @override
  String get exInpFormTitle => 'TextFormField';

  @override
  String get exInpFormDescription =>
      'Las reglas del esquema: deja el campo mal y pulsa Enviar.';

  @override
  String get exInpRule => 'Reglas';

  @override
  String get exInpDropdownTitle => 'DropdownButton';

  @override
  String get exInpDropdownDescription =>
      'Una lista de opciones: ancho, pista y habilitado.';

  @override
  String get exInpExpanded => 'Ancho';

  @override
  String get exInpHint => 'Pista';

  @override
  String get exInpAutocompleteTitle => 'Autocomplete';

  @override
  String get exInpAutocompleteDescription =>
      'Un campo que sugiere opciones: la lista, hacia dónde se abre y su alto.';

  @override
  String get exInpList => 'Lista';

  @override
  String get exInpListFruits => 'Frutas';

  @override
  String get exInpListColors => 'Colores';

  @override
  String get exInpOpens => 'Se abre';

  @override
  String get exInpOpensDown => 'Abajo';

  @override
  String get exInpOpensUp => 'Arriba';

  @override
  String get exInpPanelHeight => 'Alto del panel';

  @override
  String get exInpDdffTitle => 'DropdownButtonFormField';

  @override
  String get exInpDdffDescription => 'La lista con etiqueta, ayuda y error.';

  @override
  String get exInpDateTitle => 'Campos de fecha';

  @override
  String get exInpDateDescription =>
      'El campo del navegador o el campo con calendario. Meses, días, primer día de la semana y dígitos salen del idioma de la página.';

  @override
  String get exInpDateKind => 'Campo';

  @override
  String get exInpDateNative => 'Nativo';

  @override
  String get exInpDateCalendar => 'Calendario';

  @override
  String get exInpAllowEmpty => 'Permite vacío';

  @override
  String get exInpSliderTitle => 'Slider';

  @override
  String get exInpSliderDescription =>
      'Un valor entre min y max, continuo o en pasos.';

  @override
  String get exInpDivisions => 'Divisiones';

  @override
  String get exInpSegPassword => 'Clave';

  @override
  String get exInpSegComments => 'Notas';

  @override
  String get exInpMode => 'Modo';

  @override
  String get exInpModeLocked => 'Bloqueo';

  @override
  String get exSelValue => 'Valor';

  @override
  String get exSelOff => 'No';

  @override
  String get exSelOn => 'Encendido';

  @override
  String get exSelMixed => 'Mixto';

  @override
  String get exSelChosen => 'Elegido';

  @override
  String get exSelCheckboxTitle => 'Checkbox';

  @override
  String get exSelCheckboxDescription =>
      'Una casilla: marcada, sin marcar o mixta, habilitada o no.';

  @override
  String get exSelSwitchTitle => 'Switch';

  @override
  String get exSelSwitchDescription => 'Un interruptor de encendido y apagado.';

  @override
  String get exSelRadioTitle => 'RadioGroup y Radio';

  @override
  String get exSelRadioDescription =>
      'El grupo guarda el valor elegido; cada Radio solo dice su value.';

  @override
  String get exSelSegmentedTitle => 'SegmentedButton';

  @override
  String get exSelSegmentedDescription =>
      'Varios segmentos nativos para elegir un valor: sin JavaScript se elige y se recorre con las flechas.';

  @override
  String get exSelCard => 'Tarjeta';

  @override
  String get exSelCash => 'Efectivo';

  @override
  String get exSelTransfer => 'Banco';

  @override
  String get exSelChoiceTitle => 'ChoiceChip';

  @override
  String get exSelChoiceDescription => 'Chips para elegir una sola opción.';

  @override
  String get exSelInputTitle => 'InputChip';

  @override
  String get exSelInputDescription =>
      'Una etiqueta de lo ya elegido, con su equis para quitarla.';

  @override
  String get exSelDeletable => 'Con equis';

  @override
  String get exSelChips => 'Etiquetas';

  @override
  String get exSelLinkTitle => 'Chips que son enlaces';

  @override
  String get exSelLinkDescription =>
      'Con href el chip es un enlace y funciona sin JavaScript.';

  @override
  String get exSelSelected => 'Elegido';

  @override
  String get exSelCheckmark => 'Marca';

  @override
  String get exSelDeleteLink => 'Equis enlace';

  @override
  String get exSelFilterTitle => 'FilterChip';

  @override
  String get exSelFilterDescription =>
      'Chips para elegir varias opciones a la vez.';

  @override
  String get exSelTilesTitle => 'ListTile con control';

  @override
  String get exSelTilesDescription =>
      'Checkbox, Switch o Radio con su título: toda la fila responde.';

  @override
  String get exSelTile => 'Control';

  @override
  String get exSelTileCheckbox => 'Checkbox';

  @override
  String get exSelTileSwitch => 'Switch';

  @override
  String get exSelTileRadio => 'Radio';

  @override
  String get exSelControl => 'Posición';

  @override
  String get exSelLeading => 'Antes';

  @override
  String get exSelTrailing => 'Después';

  @override
  String get exSelSubtitle => 'Subtítulo';

  @override
  String get exNavAppBarTitle => 'AppBar';

  @override
  String get exNavAppBarDescription =>
      'La barra de arriba: título centrado o no, botón de menú, acciones y elevación.';

  @override
  String get exNavCenterTitle => 'Título centrado';

  @override
  String get exNavLeading => 'Botón de menú';

  @override
  String get exNavSearchAction => 'Acción de búsqueda';

  @override
  String get exNavElevation => 'Elevación';

  @override
  String get exNavTabsTitle => 'TabBar y TabBarView';

  @override
  String get exNavTabsDescription =>
      'Pestañas nativas con su contenido: cambia cuántas hay y si la barra se desplaza.';

  @override
  String get exNavScrollable => 'Barra con scroll';

  @override
  String get exNavTabCount => 'Pestañas';

  @override
  String get exNavDrawerTitle => 'Drawer';

  @override
  String get exNavDrawerDescription =>
      'Un menú que entra desde el lado: elige el borde y el ancho, y ábrelo.';

  @override
  String get exNavSide => 'Borde';

  @override
  String get exNavSideStart => 'Inicio';

  @override
  String get exNavSideEnd => 'Final';

  @override
  String get exNavBarTitle => 'NavigationBar';

  @override
  String get exNavBarDescription =>
      'La barra de destinos de abajo: cuántos destinos y cómo se muestran las etiquetas.';

  @override
  String get exNavLabels => 'Etiquetas';

  @override
  String get exNavLabelsAll => 'Todas';

  @override
  String get exNavLabelsSelected => 'Una';

  @override
  String get exNavLabelsNone => 'Sin';

  @override
  String get exNavDestinations => 'Destinos';

  @override
  String get exNavRailTitle => 'NavigationRail';

  @override
  String get exNavRailDescription =>
      'La barra de destinos del lado: etiquetas y rail extendido.';

  @override
  String get exNavExtended => 'Extendido';

  @override
  String get exNavLinkTitle => 'Link';

  @override
  String get exNavLinkDescription =>
      'Cualquier widget como enlace: interno o externo, en otra pestaña, o marcado como página actual.';

  @override
  String get exNavExternal => 'Externo';

  @override
  String get exNavNewTab => 'Otra pestaña';

  @override
  String get exNavCurrent => 'Página actual';

  @override
  String get exNavSheetTitle => 'ModalBottomSheet';

  @override
  String get exNavSheetDescription =>
      'Una hoja que sube desde abajo: con o sin asa y con más o menos opciones.';

  @override
  String get exNavDragHandle => 'Asa';

  @override
  String get exNavOptions => 'Opciones';

  @override
  String get exFbAlertTitle => 'AlertDialog';

  @override
  String get exFbAlertDescription =>
      'Un diálogo nativo con título, contenido y acciones: ábrelo con el botón.';

  @override
  String get exFbBarrier => 'Cierra al tocar fuera';

  @override
  String get exFbContent => 'Contenido';

  @override
  String get exFbTwoActions => 'Dos acciones';

  @override
  String get exFbControllerTitle => 'Dialog con DialogController';

  @override
  String get exFbControllerDescription =>
      'Un método del ViewModel abre el diálogo y otro lo cierra.';

  @override
  String get exFbContacts => 'Contactos';

  @override
  String get exFbCloseAfter => 'Cierra al borrar';

  @override
  String get exFbSnackTitle => 'SnackBar';

  @override
  String get exFbSnackDescription =>
      'Un mensaje breve que se oculta solo: con o sin acción, más corto o más largo.';

  @override
  String get exFbAction => 'Acción';

  @override
  String get exFbFloating => 'Flotante';

  @override
  String get exFbDuration => 'Duración';

  @override
  String get exFbDur2 => '2 s';

  @override
  String get exFbDur4 => '4 s';

  @override
  String get exFbDur6 => '6 s';

  @override
  String get exFbProgressTitle => 'Indicadores de progreso';

  @override
  String get exFbProgressDescription =>
      'Lineal o circular, con valor o girando sin fin.';

  @override
  String get exFbShape => 'Forma';

  @override
  String get exFbLinear => 'Lineal';

  @override
  String get exFbCircular => 'Circular';

  @override
  String get exFbDeterminate => 'Con valor';

  @override
  String get exFbValue => 'Valor';

  @override
  String get exFbPopupTitle => 'PopupMenuButton';

  @override
  String get exFbPopupDescription =>
      'Un menú de opciones: marca la actual o deshabilita una.';

  @override
  String get exFbMarkCurrent => 'Marca la actual';

  @override
  String get exFbLastEnabled => 'Última opción';

  @override
  String get exContAbove => 'Arriba';

  @override
  String get exContBelow => 'Abajo';

  @override
  String get exContAccent => 'Color';

  @override
  String get exContAccordion => 'Acordeón';

  @override
  String get exContActions => 'Acciones';

  @override
  String get exContAscending => 'Ascendente';

  @override
  String get exContAvatarTitle => 'CircleAvatar y Badge';

  @override
  String get exContAvatarDescription =>
      'Un avatar con un distintivo: etiqueta, punto o número.';

  @override
  String get exContBadge => 'Tipo';

  @override
  String get exContBadgeLabel => 'Texto';

  @override
  String get exContBadgeDot => 'Punto';

  @override
  String get exContBadgeCount => 'Número';

  @override
  String get exContBlank => 'Abrir en otra pestaña';

  @override
  String get exContBroken => 'Imagen rota';

  @override
  String get exContBuilders => 'Builders';

  @override
  String get exContBuildersTitle => 'Cuando la imagen falla o tarda';

  @override
  String get exContBuildersDescription =>
      'Con los builders, el fallo muestra tu widget; sin ellos, la imagen rota del navegador.';

  @override
  String get exContCardTitle => 'Card';

  @override
  String get exContCardDescription =>
      'Una superficie con sombra: cambia su elevación y su espacio interior.';

  @override
  String get exContCheckboxes => 'Casillas';

  @override
  String get exContChipTitle => 'Chip y ActionChip';

  @override
  String get exContChipDescription =>
      'Una etiqueta, con avatar o con equis, o una etiqueta que se pulsa.';

  @override
  String get exContChipPlain => 'Chip';

  @override
  String get exContChipAvatar => 'Avatar';

  @override
  String get exContChipAction => 'Action';

  @override
  String get exContDeletable => 'Con equis';

  @override
  String get exContDelay => 'Retraso';

  @override
  String get exContDense => 'Compacto';

  @override
  String get exContDividerTitle => 'Divider';

  @override
  String get exContDividerDescription =>
      'Una línea horizontal: grosor y sangría en los extremos.';

  @override
  String get exContThickness => 'Grosor';

  @override
  String get exContIndent => 'Sangría';

  @override
  String get exContElevation => 'Elevación';

  @override
  String get exContExpansionTitle => 'ExpansionTile';

  @override
  String get exContExpansionDescription =>
      'Filas que se abren; con el mismo name forman un acordeón.';

  @override
  String get exContOpen => 'Primera abierta';

  @override
  String get exContFit => 'Ajuste';

  @override
  String get exContFitCover => 'Cover';

  @override
  String get exContFitContain => 'Contain';

  @override
  String get exContFitFill => 'Fill';

  @override
  String get exContGlyph => 'Ícono';

  @override
  String get exContGlyphHome => 'Home';

  @override
  String get exContGlyphStar => 'Star';

  @override
  String get exContGlyphBell => 'Bell';

  @override
  String get exContHostile => 'HTML con script';

  @override
  String get exContNofollow => 'nofollow';

  @override
  String get exContHtmlTitle => 'HtmlWidget';

  @override
  String get exContHtmlDescription =>
      'HTML ajeno, limpiado contra una lista permitida; la política cambia lo que se deja.';

  @override
  String get exContIconTitle => 'Icon';

  @override
  String get exContIconDescription =>
      'Un ícono SVG: elige el glifo, el tamaño y el color.';

  @override
  String get exContImageTitle => 'Image.asset';

  @override
  String get exContImageDescription =>
      'Una imagen de tu carpeta web: ajuste, esquinas y ancho.';

  @override
  String get exContRounded => 'Esquinas redondas';

  @override
  String get exContWidth => 'Ancho';

  @override
  String get exContLineHeight => 'Alto de línea';

  @override
  String get exContLines => 'Líneas';

  @override
  String get exContLinesAll => 'Todas';

  @override
  String get exContLinesOne => 'Una';

  @override
  String get exContLinesTwo => 'Dos';

  @override
  String get exContLongMessage => 'Mensaje largo';

  @override
  String get exContPlacement => 'Posición';

  @override
  String get exContRadius => 'Radio';

  @override
  String get exContRichTitle => 'RichText y SelectableText';

  @override
  String get exContRichDescription =>
      'Un tramo con otro estilo dentro del texto, y un texto que se puede seleccionar.';

  @override
  String get exContSpan => 'Tramo';

  @override
  String get exContItalic => 'Cursiva';

  @override
  String get exContPlain => 'Igual';

  @override
  String get exContSelectable => 'Seleccionable';

  @override
  String get exContSelected => 'Seleccionada';

  @override
  String get exContSubtitle => 'Subtítulo';

  @override
  String get exContRows => 'Filas';

  @override
  String get exContSortBy => 'Ordenar por columna';

  @override
  String get exContSortNone => '-';

  @override
  String get exContTableTitle => 'DataTable';

  @override
  String get exContTableDescription =>
      'Una tabla con encabezados: orden, casillas y número de filas.';

  @override
  String get exContTextTitle => 'Text y TextStyle';

  @override
  String get exContTextDescription =>
      'Tamaño, peso y límite de líneas de un texto.';

  @override
  String get exContWeight => 'Peso';

  @override
  String get exContWeightRegular => '400';

  @override
  String get exContWeightSemibold => '600';

  @override
  String get exContWeightBold => '700';

  @override
  String get exContTileTitle => 'ListTile';

  @override
  String get exContTileDescription =>
      'Una fila con ícono, título y subtítulo: estados y densidad.';

  @override
  String get exContTooltipTitle => 'Tooltip';

  @override
  String get exContTooltipDescription =>
      'Una burbuja al pasar el puntero: posición, texto y retraso.';

  @override
  String get exContGlyphMail => 'Mail';

  @override
  String get exContSortFirst => '1';

  @override
  String get exContSortSecond => '2';

  @override
  String get exContSortThird => '3';

  @override
  String get exRecCounterTitle => 'Contador';

  @override
  String get exRecCounterDescription =>
      'Una etiqueta con la cuenta y un botón que la aumenta según el paso.';

  @override
  String get exRecCounterStep => 'Paso';

  @override
  String get exRecTempTitle => 'Convertidor de temperatura';

  @override
  String get exRecTempDescription =>
      'Dos campos que se actualizan entre sí mientras el texto es un número.';

  @override
  String get exRecTempDecimals => 'Decimales';

  @override
  String get exRecTempDec0 => '0';

  @override
  String get exRecTempDec1 => '1';

  @override
  String get exRecTempDec2 => '2';

  @override
  String get exRecTimerTitle => 'Temporizador';

  @override
  String get exRecTimerDescription =>
      'Una barra que se llena durante la duración del control deslizante, el tiempo transcurrido y un botón que la reinicia.';

  @override
  String get exRecPageTitle => 'Una página de contenido';

  @override
  String get exRecPageDescription =>
      'Un hero y una cuadrícula de entradas: cambia el tono, la carga de la imagen y las columnas.';

  @override
  String get exRecPageTone => 'Tono';

  @override
  String get exRecPageToneSoft => 'Suave';

  @override
  String get exRecPageToneInk => 'Tinta';

  @override
  String get exRecPageLazy => 'Imagen diferida';

  @override
  String get exRecPageColumns => 'Columnas';

  @override
  String get exUiOverlayTitle => 'Diálogo, hoja y cajón';

  @override
  String get exUiOverlayDescription =>
      'El navegador abre el diálogo, la hoja o el cajón, atrapa el foco y lo cierra con Esc.';

  @override
  String get exUiOverlayKind => 'Abre';

  @override
  String get exUiOverlayDialog => 'Diálogo';

  @override
  String get exUiOverlaySheet => 'Hoja';

  @override
  String get exUiOverlayDrawer => 'Cajón';

  @override
  String get exUiListTitle => 'Lista de filas';

  @override
  String get exUiListDescription =>
      'Sube las filas hasta 10 000: la página conserva solo las que están cerca de la pantalla.';

  @override
  String get exUiListRows => 'Filas';

  @override
  String get exUiSemTitle => 'Lo que dice Semantics';

  @override
  String get exUiSemDescription =>
      'Semantics indica qué es el texto para un lector de pantalla, y Thor renderiza el elemento que le corresponde.';

  @override
  String get exUiSemKind => 'Rol';

  @override
  String get exUiSemHeading => 'Título';

  @override
  String get exUiSemButton => 'Botón';

  @override
  String get exUiSemStatus => 'Aviso';

  @override
  String get exUiSemLevel => 'Nivel';

  @override
  String get exUiLocaleTitle => 'Una tarjeta en cuatro idiomas';

  @override
  String get exUiLocaleDescription =>
      'El texto, el plural, el dinero, la fecha y la dirección siguen al idioma de la página.';

  @override
  String get exUiLocaleLanguage => 'Idioma';

  @override
  String get exUiLocaleEn => 'Inglés';

  @override
  String get exUiLocaleEs => 'Español';

  @override
  String get exUiLocaleDe => 'Alemán';

  @override
  String get exUiLocaleAr => 'Árabe';

  @override
  String get exUiLocaleItems => 'Artículos';

  @override
  String get exTitleStartWidgetToWeb => 'Del widget a la página';

  @override
  String get exTitleStartStoreGrid => 'La tienda: una cuadrícula de tarjetas';

  @override
  String get exTitleStartCart => 'La tienda: un carrito en el navegador';

  @override
  String get exTitleStartCheckout => 'La tienda: un formulario';

  @override
  String get exTitleCard => 'Una tarjeta de producto';

  @override
  String get exTitleHover => 'Color por estado con .when()';

  @override
  String get exTitleAccordion => 'Acordeón exclusivo';

  @override
  String get exTitleCarousel => 'Carrusel con flechas y puntos';

  @override
  String get exTitleTabs => 'Pestañas sin JS';

  @override
  String get exTitleDialog => 'Diálogo nativo';

  @override
  String get exTitleMenu => 'Menú con popover';

  @override
  String get exTitleMenuAnchor => 'MenuAnchor';

  @override
  String get exTitleFormControls => 'Controles con estado';

  @override
  String get exTitleFormSubmit => 'Enviar sin recargar';

  @override
  String get exTitleFormSchema => 'Un formulario con esquema';

  @override
  String get exTitleFormSchemaFailed => 'Cuando el servidor dice que no';

  @override
  String get exTitleFormUpload => 'Subir un archivo';

  @override
  String get exTitleFormFieldParams => 'Atributos del campo';

  @override
  String get exTitleSliderBubble => 'Slider con burbuja';

  @override
  String get exTitleSegmentedPill => 'Selector en píldora';

  @override
  String get exTitleScale => 'Transición en hover';

  @override
  String get exTitleEntrance => 'Entrada y bucle con AnimationController';

  @override
  String get exTitleChips => 'Chips y progreso';

  @override
  String get exTitleProductCard => 'Una tarjeta de producto completa';

  @override
  String get exTitleWrappers => 'Wrappers sin elemento';

  @override
  String get exTitleGrid => 'Cuadrícula por breakpoint';

  @override
  String get exTitleVariants => 'Variantes por ancho y estado';

  @override
  String get exTitleHoverGroup => 'Hover en grupo';

  @override
  String get exTitleLayoutSizes =>
      'SizedBox, Container, ConstrainedBox y FractionallySizedBox';

  @override
  String get exTitleLayoutScreen => 'Tamaños relativos a la ventana';

  @override
  String get exTitleLayoutGridExtent =>
      'GridView.extent cuenta las columnas como Flutter';

  @override
  String get exTitleLayoutScroll => 'Scroll vertical y horizontal';

  @override
  String get exTitleLayoutResponsive =>
      'Responsivo con .when() y ResponsiveVisibility';

  @override
  String get exTitleUnits => 'Unidades, medidas de verdad';

  @override
  String get exTitleResponsiveCard => 'Una tarjeta que sigue a su caja';

  @override
  String get exTitleStickyList => 'Encabezados sticky en una lista';

  @override
  String get exTitleHoverEffects =>
      'Giro, desplazamiento y desenfoque en hover';

  @override
  String get exTitleComponentThemes => 'Un tema por componente';

  @override
  String get exTitleThemeFollowsSwitch => 'Theme.of sigue al cambiar de modo';

  @override
  String get exTitleDescendants => 'HTML crudo con estilo por etiqueta';

  @override
  String get exTitlePatterns => 'Patrones en mosaico';

  @override
  String get exTitleDemoExplorer => 'El proyecto nuevo';

  @override
  String get exTitleStateBool => 'Dos estados con un bool';

  @override
  String get exTitleStateEnum => 'Un estado por valor de un enum';

  @override
  String get exTitleStateTodo => 'Una lista de tareas';

  @override
  String get exTitleStateForm => 'Controles ligados al estado';

  @override
  String get exTitleStateKeyed => 'Dos instancias con key';

  @override
  String get exTitleStateControllers => 'Controladores y Timer';

  @override
  String get exTitleStatePages => 'PageController y onPageChanged';

  @override
  String get exTitleStateLifecycle => 'onHydrated y dispose';

  @override
  String get exTitleStateFeedback => 'confirm() y toast()';

  @override
  String get exTitleStateSet => 'toggle() y un conjunto';

  @override
  String get exTitleStateNotifier => 'ValueListenableBuilder';

  @override
  String get exTitleRoutesTree => 'La tabla de una app con módulos';

  @override
  String get exTitleRoutesNav => 'Enlaces desde las rutas';

  @override
  String get exTitleDataForm => 'Un formulario con esquema';

  @override
  String get exTitleDataFormFailed => 'Después de un 422';

  @override
  String get exTitleCatIcons => 'Icons';

  @override
  String get exTitleCatIconVariants => 'Variantes de un ícono';

  @override
  String get exTitleMotionAnimatedSize => 'AnimatedSize';

  @override
  String get exTitleEventsHoverFocus => 'MouseRegion y Focus';

  @override
  String get exTitleEventsExpansion => 'ExpansionTile.onExpansionChanged';

  @override
  String get exTitleGestureInkwell => 'InkWell';

  @override
  String get exTitleGestureSwipeKeys => 'Deslizar con el teclado';

  @override
  String get exTitleGestureDismissible => 'Dismissible';

  @override
  String get exTitleGestureDraggable => 'Draggable y DragTarget';

  @override
  String get exTitleGestureReorderable => 'ReorderableListView';

  @override
  String get exTitleNavSlivers => 'CustomScrollView con una SliverAppBar fija';

  @override
  String get exTitleDialogPermanentDrawer =>
      'Un cajón que es panel fijo desde md';

  @override
  String get exTitleRecipeFlights => 'Reserva de vuelos';

  @override
  String get exTitleRecipeCrud => 'CRUD';

  @override
  String get exTitleRecipeCircles => 'Circle drawer';

  @override
  String get exTitleRecipeCells => 'Cells';

  @override
  String get structAbout01 =>
      'La tabla de rutas: el grupo de cada módulo dentro del marco de la app.';

  @override
  String get structAbout02 =>
      'La app, declarada una vez: rutas, tema y estilos base.';

  @override
  String get structAbout03 => 'La página de inicio, en /.';

  @override
  String get structAbout04 =>
      'El marco de todas las páginas: encabezado, la página y pie.';

  @override
  String get structAbout05 =>
      'Lo que se muestra ante una URL que no existe o un error.';

  @override
  String get structAbout06 =>
      'Las variables de entorno, tipadas y validadas al arrancar.';

  @override
  String get structAbout07 =>
      'El servidor: sirve la app en el puerto del entorno.';

  @override
  String get structAbout08 => 'Pruebas de la app, desde el primer día.';

  @override
  String get structAboutHomeRoutes =>
      'El módulo de inicio: sus rutas en un Group, que la tabla pone en su lugar.';

  @override
  String get structAboutCounterCard =>
      'El componente del módulo: el contador y sus botones.';

  @override
  String get structAboutCounterViewModel =>
      'El ViewModel: el estado que cambia en el navegador.';

  @override
  String get structAboutTheme =>
      'Los temas claro y oscuro que leen los widgets.';

  @override
  String get structAboutPageTitle =>
      'Un componente general: no conoce ningún módulo, así que cualquier página lo usa.';

  @override
  String get structAboutCounterTest => 'El ViewModel probado solo, sin página.';

  @override
  String get structAbout09 =>
      'La tabla de la app solo compone: el marco, la sesión y los módulos.';

  @override
  String get structAbout10 =>
      'El marco de toda la app. Puede importar las rutas de los módulos para su navegación; core/ no.';

  @override
  String get structAbout11 =>
      'Un cliente para todo el backend: URL base, token y traducción de errores.';

  @override
  String get structAbout12 =>
      'Quién es el usuario: lee la cookie y deja en el contexto el usuario y el cliente API.';

  @override
  String get structAbout13 =>
      'Qué puede hacer: el Group de cada módulo pide el rol que necesita.';

  @override
  String get structAbout14 =>
      'Un componente general: no conoce el negocio, recibe datos simples.';

  @override
  String get structAbout15 =>
      'El módulo es un Group: su marco, sus permisos, su hoja de estilos y su página de error.';

  @override
  String get structAbout16 =>
      'Una regla que solo aplica a ventas: vive en el módulo, no en core/.';

  @override
  String get structAbout17 =>
      'Operaciones del negocio con modelos tipados. Nunca devuelve JSON.';

  @override
  String get structAbout18 =>
      'Un componente del módulo: conoce los pedidos y lo usan varios submódulos.';

  @override
  String get structAbout19 =>
      'Las rutas del submódulo. Otro módulo que enlace aquí importa solo este archivo.';

  @override
  String get structAbout20 =>
      'La página lee los filtros de la URL, pide al repositorio y muestra el resultado.';

  @override
  String get structAbout21 =>
      'Las reglas del formulario, una vez: el navegador y el servidor las aplican igual.';

  @override
  String get structAbout22 =>
      'Un componente del submódulo. Sube a sales/widgets/ cuando otro submódulo lo necesita.';

  @override
  String get structAbout23 =>
      'El ViewModel del navegador, solo para lo que cambia sin ir al servidor.';

  @override
  String get structAbout24 =>
      'La página de error del módulo: gana a la general en las rutas de ventas.';

  @override
  String get exMotion2CurvesTitle => 'Qué es una curva';

  @override
  String get exMotion2CurvesDescription =>
      'Una curva relaciona el tiempo, en el eje horizontal, con el avance de la animación, en el vertical.';

  @override
  String get exMotion2Curve => 'Curva';

  @override
  String get exMotion2PositionTitle => 'AnimatedAlign y AnimatedPositioned';

  @override
  String get exMotion2PositionDescription =>
      'AnimatedAlign anima la alineación del hijo; AnimatedPositioned, sus distancias y su tamaño dentro de un Stack.';

  @override
  String get exMotion2Widget => 'Widget';

  @override
  String get exMotion2Spot => 'Destino';

  @override
  String get exMotion2SwitcherTitle => 'AnimatedSwitcher con Hero';

  @override
  String get exMotion2SwitcherDescription =>
      'AnimatedSwitcher funde el estado nuevo sobre el anterior, y cada Hero presente en los dos viaja a su nuevo lugar y tamaño.';

  @override
  String get exMotion2Layout => 'Disposición';

  @override
  String get exMotion2LayoutRow => 'Fila';

  @override
  String get exMotion2LayoutColumn => 'Columna';

  @override
  String get exMotion2StaggerTitle => 'Entrada escalonada';

  @override
  String get exMotion2StaggerDescription =>
      'Un solo controller y un Interval por fila: cada fila entra un retraso después de la anterior.';

  @override
  String get exMotion2Delay => 'Retraso';

  @override
  String get exMotion2RepeatTitle => 'Un bucle entre dos valores';

  @override
  String get exMotion2RepeatDescription =>
      'repeat(min:, max:) limita el bucle a un tramo del recorrido; la opacidad y el tamaño del círculo lo siguen.';

  @override
  String get exMotion2Reverse => 'Al llegar';

  @override
  String get exMotion2ReverseBack => 'Vuelve';

  @override
  String get exMotion2ReverseJump => 'Salta';

  @override
  String get exMotion2Min => 'Mínimo';

  @override
  String get exMotion2Max => 'Máximo';

  @override
  String get exMotion2Period => 'Periodo';

  @override
  String get exMotion2ScrollTitle => 'Aparecer al desplazarse';

  @override
  String get exMotion2ScrollDescription =>
      'Con inView, la animación avanza con el desplazamiento y se revierte al volver; con onVisible corre una sola vez, a su ritmo.';

  @override
  String get exMotion2Driver => 'Lo mueve';

  @override
  String get exMotion2Effect => 'Efecto';

  @override
  String get exMotion2EffectRise => 'Sube';

  @override
  String get exMotion2EffectScale => 'Crece';

  @override
  String get exMotion2EffectSlide => 'Desliza';

  @override
  String get pageExampleSlideToConfirm => 'Deslizar para confirmar';

  @override
  String get pageExampleCopyButton => 'Botón de copiar';

  @override
  String get pageExampleTabIndicator => 'Pestañas con indicador';

  @override
  String get pageExampleToastStack => 'Pila de avisos';

  @override
  String get exMotion2SlideTitle => 'Deslizar para confirmar';

  @override
  String get exMotion2SlideDescription =>
      'Arrastra la manija hasta el final. El navegador la mueve con el puntero y el ViewModel recibe solo la posición final: si pasa el umbral, se confirma; si no, la manija vuelve al inicio.';

  @override
  String get exMotion2Threshold => 'Umbral';

  @override
  String get exMotion2CopyTitle => 'Botón de copiar';

  @override
  String get exMotion2CopyDescription =>
      'Al copiar el comando, el ícono se vuelve una marca de verificación durante un momento y luego regresa.';

  @override
  String get exMotion2Morph => 'Cambio';

  @override
  String get exMotion2MorphFade => 'Fundido';

  @override
  String get exMotion2MorphScale => 'Escala';

  @override
  String get exMotion2MorphTurn => 'Giro';

  @override
  String get exMotion2Hold => 'Se queda';

  @override
  String get exMotion2TabsTitle => 'Pestañas con indicador';

  @override
  String get exMotion2TabsDescription =>
      'El indicador es un solo elemento que se desliza bajo las etiquetas; el contenido de abajo cambia con un fundido.';

  @override
  String get exMotion2Indicator => 'Indicador';

  @override
  String get exMotion2IndicatorPill => 'Píldora';

  @override
  String get exMotion2IndicatorLine => 'Línea';

  @override
  String get exMotion2ToastsTitle => 'Pila de avisos';

  @override
  String get exMotion2ToastsDescription =>
      'Cada aviso entra por el borde que elijas, el más nuevo queda delante y los anteriores se encogen y se desvanecen detrás. Al descartar, el aviso sale por donde entró.';

  @override
  String get exMotion2Edge => 'Borde';

  @override
  String get exMotion2EdgeBottom => 'Abajo';

  @override
  String get exMotion2EdgeTop => 'Arriba';

  @override
  String siteTitleTemplate(String title, String site) => '${title} · ${site}';

  @override
  String widgetPageDescriptionWithSummary(String name, String summary) =>
      'El widget ${name} de Thor: firma, parámetros y documentación. ${summary}';

  @override
  String llmsSource(String url) => 'Fuente: ${url}';

  @override
  String get tocBackToTop => 'Volver arriba';

  @override
  String get tocOnThisPage => 'En esta página';

  @override
  String get navAreas => 'Áreas del sitio';

  @override
  String get navExamplesApps => 'Aplicaciones';

  @override
  String get navExamplesPatterns => 'Patrones de interacción';

  @override
  String get apiLabelServer => 'Servidor';

  @override
  String get apiLabelRouter => 'Rutas';

  @override
  String get apiLabelHtml => 'HTML';

  @override
  String get apiLabelTesting => 'Pruebas';

  @override
  String get apiLabelIntl => 'Idiomas';

  @override
  String get apiLabelThorTest => 'Herramientas de prueba';

  @override
  String get apiLabelStudio => 'Sistema de diseño';

  @override
  String get homeStartHeading => 'Empieza aquí';

  @override
  String get homeGuideHeading => 'La guía';

  @override
  String get homeReferenceHeading => 'Referencia';

  @override
  String get homeExamplesSummary =>
      'Apps pequeñas y completas, y patrones de interacción.';

  @override
  String get homeComponentsSummary =>
      'Cada widget con su demo, su código y sus parámetros.';

  @override
  String get searchDialogLabel => 'Buscar en la documentación';

  @override
  String get searchDialogHintMove => 'Mover';

  @override
  String get searchDialogHintOpen => 'Abrir';

  @override
  String get searchDialogHintClose => 'Cerrar';

  @override
  String get homeStartInstall =>
      'Instala el comando thor y crea tu primer proyecto.';

  @override
  String get homeStartFirstApp =>
      'Una app completa, de la pantalla a los datos, paso a paso.';

  @override
  String get homeStartFlutter =>
      'Qué se queda igual y qué cambia al pasar de Flutter a la web.';
}

/// The messages in `en` (app_en.arb).
class AppLocalizationsEn extends AppLocalizations {
  /// Messages in [locale].
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get siteName => 'Thor docs';

  @override
  String get siteDescription =>
      'Thor: Flutter\'s widget API, rendered as HTML and CSS on the server. Guides, widget catalog and API reference.';

  @override
  String get siteImageAlt =>
      'Thor: Flutter\'s widget API, rendered as HTML and CSS.';

  @override
  String get siteOpenGraphLocale => 'en_US';

  @override
  String get navGuide => 'Guide';

  @override
  String get navComponents => 'Components';

  @override
  String get navExamples => 'Examples';

  @override
  String get navApi => 'API';

  @override
  String get navChanges => 'Changelog';

  @override
  String get navGithub => 'GitHub repository';

  @override
  String get sectionGetStarted => 'Get started';

  @override
  String get sectionFundamentals => 'Fundamentals';

  @override
  String get sectionArchitecture => 'Architecture';

  @override
  String get sectionInterface => 'Interface';

  @override
  String get sectionDataAndState => 'Data and state';

  @override
  String get sectionTestAndDeploy => 'Test and deploy';

  @override
  String get sectionComponents => 'Components';

  @override
  String get sectionExamples => 'Examples';

  @override
  String get sectionGetStartedSummary =>
      'What Thor is, how to install it, a complete app step by step and the map from Flutter.';

  @override
  String get sectionFundamentalsSummary =>
      'Widgets, layout, interactivity, routes and page data: what every app uses.';

  @override
  String get sectionArchitectureSummary =>
      'View, ViewModel, Repository and Service, named as in Flutter\'s architecture guide, and what runs where.';

  @override
  String get sectionInterfaceSummary =>
      'Theme, styles, animation, gestures, dialogs, accessibility and localization.';

  @override
  String get sectionDataAndStateSummary =>
      'The ViewModel in depth, server actions, forms, live data, long lists, packages and security.';

  @override
  String get sectionTestAndDeploySummary =>
      'Testing by layer, the thor command, static site or server, and SEO.';

  @override
  String get sectionComponentsSummary =>
      'Every widget with its live demo, its code and its parameters.';

  @override
  String get sectionExamplesSummary =>
      'Small, complete apps (the 7GUIs tasks and a content page) and four interaction patterns.';

  @override
  String get pageWhatIsThor => 'What is Thor';

  @override
  String get pageInstallation => 'Installation';

  @override
  String get pageFirstApp => 'Your first app';

  @override
  String get pageFromFlutter => 'Coming from Flutter';

  @override
  String get pageWidgets => 'Widgets';

  @override
  String get pageLayout => 'Layout';

  @override
  String get pageInteractivity => 'Interactivity';

  @override
  String get pageNavigation => 'Routes and navigation';

  @override
  String get pageReadingData => 'Reading data';

  @override
  String get pageAppArchitecture => 'App architecture';

  @override
  String get pageProjectStructure => 'Project structure';

  @override
  String get pageUiLayer => 'UI layer';

  @override
  String get pageDataLayer => 'Data layer';

  @override
  String get pagePatterns => 'Patterns';

  @override
  String get pageThemeAndStyles => 'Theme and styles';

  @override
  String get pageAdvancedStyles => 'Advanced styles';

  @override
  String get pageAnimations => 'Animations';

  @override
  String get pageGestures => 'Gestures';

  @override
  String get pageDialogsAndMenus => 'Dialogs and menus';

  @override
  String get pageLongLists => 'Long lists';

  @override
  String get pageAccessibility => 'Accessibility';

  @override
  String get pageLocalization => 'Localization';

  @override
  String get pageState => 'State';

  @override
  String get pageServerAndActions => 'Server and actions';

  @override
  String get pageLiveData => 'Live data';

  @override
  String get pageForms => 'Forms';

  @override
  String get pageSessionAndSecurity => 'Session and security';

  @override
  String get pagePubPackages => 'Pub packages';

  @override
  String get pageTesting => 'Testing';

  @override
  String get pageCli => 'The thor command';

  @override
  String get pageBuildAndDeploy => 'Build and deploy';

  @override
  String get pageSeo => 'SEO';

  @override
  String get pageExamples => 'Examples';

  @override
  String get pageComponents => 'Components';

  @override
  String get pageComponentsButtons => 'Buttons';

  @override
  String get pageComponentsInputs => 'Inputs';

  @override
  String get pageComponentsSelection => 'Selection';

  @override
  String get pageComponentsContent => 'Content';

  @override
  String get pageComponentsNavigation => 'Navigation';

  @override
  String get pageComponentsFeedback => 'Feedback';

  @override
  String get pageHowItWorks => 'What runs where';

  @override
  String get pageEmbeddedFlutter => 'Embedded Flutter';

  @override
  String get footerStart => 'Get started';

  @override
  String get footerReference => 'Reference';

  @override
  String get footerResources => 'Resources';

  @override
  String get footerErrors => 'Errors';

  @override
  String get footerGithub => 'GitHub';

  @override
  String get docEditPage => 'Edit on GitHub';

  @override
  String get docCopyMarkdown => 'Copy as Markdown';

  @override
  String get docPageActions => 'Page actions';

  @override
  String docFallbackNotice(String language) =>
      'This page isn\'t available in your language yet: showing the ${language} version.';

  @override
  String get calloutNote => 'Note';

  @override
  String get calloutTip => 'Tip';

  @override
  String get calloutWarning => 'Important';

  @override
  String get calloutWarningAlias => 'Heads up';

  @override
  String get calloutDanger => 'Caution';

  @override
  String get calloutFlutter => 'Difference from Flutter';

  @override
  String get codeTerminal => 'Terminal';

  @override
  String get ladderFirst => 'first';

  @override
  String get ladderLast => 'last resort';

  @override
  String get stageResizeHint => 'Resize the box from its bottom-right corner.';

  @override
  String get previewLabel => 'Preview';

  @override
  String get exampleTabHtml => 'Generated HTML';

  @override
  String get exampleTabCss => 'Generated CSS';

  @override
  String get benchReplay => 'Replay';

  @override
  String get benchSwitches => 'Switches';

  @override
  String get benchLevels => 'Levels';

  @override
  String get benchAppCode => 'App code';

  @override
  String get benchSegmentStart => 'Start';

  @override
  String get benchSegmentCenter => 'Center';

  @override
  String get benchSegmentEnd => 'End';

  @override
  String get benchSegmentBetween => 'Between';

  @override
  String get benchRowTitle => 'mainAxisAlignment in a row';

  @override
  String get benchRowDescription =>
      'mainAxisAlignment distributes the row\'s free space; spacing sets the gap between its children.';

  @override
  String get benchRowAlignment => 'Alignment';

  @override
  String get benchRowSpacing => 'Spacing';

  @override
  String get benchCardTitle => 'A styled card';

  @override
  String get benchCardDescription =>
      'The card reads its radius, padding and fill from ViewModel state fields.';

  @override
  String get benchCardFill => 'Fill';

  @override
  String get benchCardFillSoft => 'Soft';

  @override
  String get benchCardFillSolid => 'Solid';

  @override
  String get benchCardRadius => 'Radius';

  @override
  String get benchCardPadding => 'Padding';

  @override
  String get benchCounterTitle => 'A counter with a step';

  @override
  String get benchCounterDescription =>
      'The step is another ViewModel state field: each button calls a method that reads it.';

  @override
  String get benchCounterStep => 'Step';

  @override
  String get layersOrdersViewKind => 'Widget';

  @override
  String get layersOrdersViewModelKind => 'ViewModel (ThorState)';

  @override
  String get layersOrdersRepositoryKind => 'Class';

  @override
  String get layersOrdersServiceKind => 'HTTP client';

  @override
  String get layersOrdersInjectionKind => 'Middleware';

  @override
  String get layersOrdersNavigationKind => 'Route table';

  @override
  String get layersOrdersTestsKind => 'dart test';

  @override
  String get layersOrdersViewDescription =>
      'Shows the ViewModel\'s data and tells it what the user does. It has no logic: it reads the ViewModel and calls its methods.';

  @override
  String get layersOrdersViewModelDescription =>
      'Holds the screen\'s data and the actions the view can request. In Thor it is a ThorState: a query reads, a command changes.';

  @override
  String get layersOrdersRepositoryDescription =>
      'The single source of orders: it asks the service, turns the response into Order objects and hides where the data comes from.';

  @override
  String get layersOrdersServiceDescription =>
      'Talks to the backend and nothing else. In Thor it uses ThorHttpClient on the server.';

  @override
  String get layersOrdersInjectionDescription =>
      'Hands each layer what it needs without it asking on its own. In Flutter it is a Provider; in Thor, a middleware that puts the repository on the request with a ContextKey.';

  @override
  String get layersOrdersNavigationDescription =>
      'Says which screen lives at which address. In Flutter it is go_router; in Thor, one ThorRoute per page in a ThorRouter.';

  @override
  String get layersOrdersTestsDescription =>
      'Each layer is tested on its own: the repository with a fake service, the ViewModel with a fake repository and the view with whatever data you want.';

  @override
  String get llmsReferenceHeading => 'API and errors';

  @override
  String get llmsApiTitle => 'thor_ui API';

  @override
  String get llmsApiDescription =>
      'public classes, functions and constructors, by folder';

  @override
  String get llmsErrorsTitle => 'Error codes';

  @override
  String get llmsErrorsDescription =>
      'every `THOR-xxx` with what happened, why and how to fix it';

  @override
  String get llmsFullTitle => 'Everything in one file';

  @override
  String get llmsFullDescription => 'the complete guide in Markdown';

  @override
  String get apiEyebrow => 'API reference';

  @override
  String apiPageTitle(String name) => '${name} · API';

  @override
  String apiPageDescription(String name) =>
      'API reference for ${name}: public classes, functions and constructors.';

  @override
  String get apiSummary => 'Public classes, functions and constructors.';

  @override
  String widgetEyebrow(String topic) => 'Widget · ${topic}';

  @override
  String widgetPageTitle(String name) => '${name} · Widget';

  @override
  String widgetPageDescription(String name) =>
      'Thor\'s ${name} widget: signature, parameters and documentation';

  @override
  String get errorsEyebrow => 'Error codes';

  @override
  String get changesEyebrow => 'Releases';

  @override
  String get changesTitle => 'Changelog';

  @override
  String changesPackageTitle(String name) => '${name} changelog';

  @override
  String get changesVersionUnreleased => 'Unreleased';

  @override
  String changesVersionNotPublished(String version) =>
      '${version} (unreleased)';

  @override
  String changesPackageIntro(String package, String role) =>
      'What changes in `${package}` (${role}) for app developers. Thor hasn\'t published a release yet: everything under “Unreleased” is already in the code and will ship in the next one.';

  @override
  String get changesLanguageNote =>
      'Each change is described as the package authors write it, in English, like the code.';

  @override
  String get changesBreakingTitle => 'Breaking changes';

  @override
  String get changesGroupAdded => 'Added';

  @override
  String get changesGroupChanged => 'Changed';

  @override
  String get changesGroupDeprecated => 'Deprecated (use X)';

  @override
  String get changesIndexIntro =>
      'What changed in Thor, by package, and what to do in your app when a name goes away. Thor hasn\'t published a release yet: here is what has already landed and will ship in the first one.';

  @override
  String get changesMigrateHeading => 'Migrating';

  @override
  String get changesMigrateIntro =>
      'A public name never disappears all at once: for one minor version it stays as `@Deprecated("Use X")`, with an alias when possible, and the analyzer flags it. This is what is already deprecated or breaking, and what to use instead.';

  @override
  String get changesMigrateNone => 'Nothing is deprecated or breaking for now.';

  @override
  String get changesPackagesHeading => 'By package';

  @override
  String get changesColPackage => 'Package';

  @override
  String get changesColRole => 'What it is';

  @override
  String get changesColCount => 'Unreleased changes';

  @override
  String get changesRoleThorUi => 'the widgets and rendering';

  @override
  String get changesRoleThorStyle => 'style values and CSS';

  @override
  String get changesRoleThorEngine =>
      'page state: ThorState, query and command';

  @override
  String get changesRoleThorServer => 'routes, data, session and export';

  @override
  String get changesRoleThorStudio => 'the design system';

  @override
  String get changesRoleThorBuilder => 'the build\'s THOR-* errors';

  @override
  String get changesRoleThorCli => 'the `thor` command';

  @override
  String get changesRoleThorLints => 'the analyzer rules';

  @override
  String get changesRoleThorTest => 'the testing tools';

  @override
  String widgetDefaultDoc(String name) => 'The `${name}` widget.';

  @override
  String get widgetExampleHeading => 'Example';

  @override
  String get widgetSignatureHeading => 'Signature';

  @override
  String get widgetParamsHeading => 'Parameters';

  @override
  String widgetParamsOf(String name) => 'Parameters of `${name}`';

  @override
  String get widgetColParam => 'Parameter';

  @override
  String get widgetColType => 'Type';

  @override
  String get widgetColDoc => 'What it does';

  @override
  String get widgetRequired => '(required)';

  @override
  String get widgetDeprecated => 'Deprecated';

  @override
  String get widgetInFlutterHeading => 'In Flutter';

  @override
  String widgetFlutterSame(String name, String url) =>
      'It is the same widget as Flutter\'s `${name}`: [Flutter documentation](${url}).';

  @override
  String widgetFlutterNone(String name) =>
      '`${name}` has no direct equivalent in Flutter: it is Thor\'s own piece.';

  @override
  String get widgetPageLink => 'Widget page';

  @override
  String get apiSymbolsHeading => 'Symbols';

  @override
  String get badgeYes => 'Yes';

  @override
  String get badgeNo => 'No';

  @override
  String get badgePartial => 'Partial';

  @override
  String get errorNotFoundTitle => 'We couldn\'t find that page';

  @override
  String get errorNotFoundLead =>
      'It may have been renamed. Start with the guide or search the API.';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorGenericLead => 'Try again in a moment.';

  @override
  String get errorStartSubtitle => 'The starting point of the guide';

  @override
  String get notFoundGuide => 'No such guide';

  @override
  String get notFoundPackage => 'No such package';

  @override
  String get notFoundFolder => 'No such folder';

  @override
  String get notFoundWidget => 'No such widget';

  @override
  String get notFoundCode => 'No such code';

  @override
  String get notFoundCodes => 'No codes';

  @override
  String get notFoundChanges => 'No changes for that package';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchDescription =>
      'Search Thor\'s guides, API reference and error codes.';

  @override
  String get searchHint => 'Search the docs';

  @override
  String get searchNeedsJs =>
      'Search needs JavaScript. Without it, use the guide menu or search the site from your search engine.';

  @override
  String get searchPrompt => 'Type what you\'re looking for.';

  @override
  String searchResultOne(String query) => '1 result for “${query}”';

  @override
  String searchResultMany(String count, String query) =>
      '${count} results for “${query}”';

  @override
  String searchShowMore(String count) => 'Show ${count} more';

  @override
  String get searchShowLess => 'Show less';

  @override
  String get searchBestMatch => 'Best match';

  @override
  String searchNone(String query) =>
      'Nothing for “${query}”. Try another word.';

  @override
  String get searchNoIndex =>
      'Search isn\'t available in this copy of the site.';

  @override
  String get homeMetaTitle => 'Thor · Flutter\'s API, the web\'s HTML';

  @override
  String get homeMetaDescription =>
      'Write web pages with Flutter widgets in Dart; they reach the browser as semantic HTML and CSS.';

  @override
  String get navErrors => 'Errors';

  @override
  String get footerLegal => 'MIT License. This site is built with Thor.';

  @override
  String get homeHeroTitle => 'Write the web with Flutter widgets.';

  @override
  String get homeHeroLead =>
      'Thor turns your Dart code into semantic HTML and CSS. JavaScript ships only where there is state.';

  @override
  String get homeCtaStart => 'Get started';

  @override
  String get homeCtaFlutter => 'Coming from Flutter';

  @override
  String get exLayoutColumnTitle => 'crossAxisAlignment in a column';

  @override
  String get exLayoutColumnDescription =>
      'crossAxisAlignment decides each child\'s width and its position within the column.';

  @override
  String get exLayoutColumnAlignment => 'Align';

  @override
  String get exLayoutColumnStretch => 'Stretch';

  @override
  String get exLayoutFlexTitle => 'Expanded and Flexible in a row';

  @override
  String get exLayoutFlexDescription =>
      'Two children share the width left by the fixed-size child: Expanded fills it and Flexible uses it only if it needs it.';

  @override
  String get exLayoutFlexKind => 'Widget';

  @override
  String get exLayoutFlexExpanded => 'Expanded';

  @override
  String get exLayoutFlexFlexible => 'Flexible';

  @override
  String get exLayoutFlexFactor => 'B\'s flex';

  @override
  String get exLayoutStackTitle => 'Positioned in a Stack';

  @override
  String get exLayoutStackDescription =>
      'The first child sets the Stack\'s size; Positioned places the other child at a fixed distance from a corner.';

  @override
  String get exLayoutStackCorner => 'Corner';

  @override
  String get exLayoutStackTopLeft => '↖';

  @override
  String get exLayoutStackTopRight => '↗';

  @override
  String get exLayoutStackBottomLeft => '↙';

  @override
  String get exLayoutStackBottomRight => '↘';

  @override
  String get exLayoutStackInset => 'Distance';

  @override
  String get exLayoutWrapTitle => 'Wrap with tags';

  @override
  String get exLayoutWrapDescription =>
      'Children that don\'t fit in the available width move to the next line.';

  @override
  String get exLayoutWrapWidth => 'Width';

  @override
  String get exLayoutWrapSpacing => 'Spacing';

  @override
  String get exLayoutWrapRunSpacing => 'Between lines';

  @override
  String get exLayoutGridTitle => 'A six-cell grid';

  @override
  String get exLayoutGridDescription =>
      'The cells are laid out in columns with a fixed gap between them; the first one can span the whole row.';

  @override
  String get exLayoutGridFirst => 'First';

  @override
  String get exLayoutGridSingle => '1 col.';

  @override
  String get exLayoutGridWide => 'Row';

  @override
  String get exLayoutGridColumns => 'Columns';

  @override
  String get exLayoutGridGap => 'Gap';

  @override
  String get exLayoutResponsiveTitle => 'A card that follows its box\'s width';

  @override
  String get exLayoutResponsiveDescription =>
      'From a box width of 420 px, the column becomes a row with the same widget tree.';

  @override
  String get exLayoutResponsiveWidth => 'Box width';

  @override
  String get exWidgetsComposeTitle => 'A widget made of other widgets';

  @override
  String get exWidgetsComposeDescription =>
      'UserTile is a class the list reuses for every row; the list only decides how they are arranged.';

  @override
  String get exWidgetsComposeAxis => 'Arrangement';

  @override
  String get exWidgetsComposeColumn => 'Column';

  @override
  String get exWidgetsComposeRow => 'Row';

  @override
  String get exWidgetsComposeCount => 'How many';

  @override
  String get exStateGreetingTitle => 'A ViewModel with two state fields';

  @override
  String get exStateGreetingDescription =>
      'The text field calls setName with what the user types and the Switch changes the greeting; the rest of the page only reads the two fields.';

  @override
  String get exStateGreetingSalutation => 'Greeting';

  @override
  String get exStateGreetingHello => 'Hello';

  @override
  String get exRoutesLinkTitle => 'The URL a route builds';

  @override
  String get exRoutesLinkDescription =>
      'link() builds the address from the parameter and the query; a parameter of another type is an error when building it.';

  @override
  String get exRoutesLinkQuery => 'Status';

  @override
  String get exRoutesLinkNone => 'All';

  @override
  String get exRoutesLinkOpen => 'Open';

  @override
  String get exRoutesLinkClosed => 'Closed';

  @override
  String get exRoutesLinkId => 'id parameter';

  @override
  String get exRoutesMiddlewareTitle => 'What a middleware decides';

  @override
  String get exRoutesMiddlewareDescription =>
      'The middleware lets the request through, redirects or responds with an error depending on the user and the route.';

  @override
  String get exRoutesMiddlewareVisitor => 'User';

  @override
  String get exRoutesMiddlewareGuest => 'Signed out';

  @override
  String get exRoutesMiddlewareMember => 'Member';

  @override
  String get exRoutesMiddlewareAdmin => 'Admin';

  @override
  String get exRoutesMiddlewareTarget => 'Route';

  @override
  String get exRoutesMiddlewareAccount => 'Account';

  @override
  String get exRoutesMiddlewareAdminPage => 'Dashboard';

  @override
  String get exDataLoadTitle => 'What load can return';

  @override
  String get exDataLoadDescription =>
      'Depending on what the repository answers, load hands the data to the page or ends in an error page.';

  @override
  String get exDataLoadAnswer => 'The repository';

  @override
  String get exDataLoadOrders => 'Orders';

  @override
  String get exDataLoadMissing => 'Nothing';

  @override
  String get exDataLoadFailing => 'Fails';

  @override
  String get exDataLoadCount => 'How many orders';

  @override
  String get exThemeColorsTitle => 'The theme\'s colors';

  @override
  String get exThemeColorsDescription =>
      'The card reads its colors with Theme.of(context) and follows the theme\'s mode and accent.';

  @override
  String get exThemeLook => 'Mode';

  @override
  String get exThemeLookLight => 'Light';

  @override
  String get exThemeLookDark => 'Dark';

  @override
  String get exThemeAccent => 'Accent';

  @override
  String get exThemeAccentViolet => 'Lilac';

  @override
  String get exThemeAccentTeal => 'Green';

  @override
  String get exThemeAccentOrange => 'Amber';

  @override
  String get exThemeTextTitle => 'A text style';

  @override
  String get exThemeTextDescription =>
      'copyWith changes the size and weight of a TextTheme role; the rest of the style follows the theme.';

  @override
  String get exThemeTextSize => 'Size';

  @override
  String get exThemeTextWeight => 'Weight';

  @override
  String get exMotionImplicitTitle => 'An implicit animation';

  @override
  String get exMotionImplicitDescription =>
      'AnimatedContainer animates the position change with the given duration and curve.';

  @override
  String get exMotionPlace => 'Position';

  @override
  String get exMotionPlaceStart => 'Start';

  @override
  String get exMotionPlaceEnd => 'End';

  @override
  String get exMotionCurve => 'Curve';

  @override
  String get exMotionCurveOut => 'easeOut';

  @override
  String get exMotionCurveInOut => 'easeInOut';

  @override
  String get exMotionCurveBack => 'easeOutBack';

  @override
  String get exMotionDuration => 'Duration';

  @override
  String get exMotionTweenTitle => 'TweenAnimationBuilder';

  @override
  String get exMotionTweenDescription =>
      'TweenAnimationBuilder animates the dot toward the tween\'s end value.';

  @override
  String get exMotionTweenEnd => 'Target';

  @override
  String get exMotionExplicitTitle => 'An explicit animation';

  @override
  String get exMotionExplicitDescription =>
      'AnimationController starts the animation when the page loads; the browser runs it.';

  @override
  String get exMotionListTitle => 'AnimatedList';

  @override
  String get exMotionListDescription =>
      'AnimatedList rows animate in when added and out when removed, with the given duration.';

  @override
  String get exMotionPageTitle => 'Page transition';

  @override
  String get exMotionPageDescription =>
      'Preview of a PageTransition between a list and an article. The real one happens between two documents.';

  @override
  String get exMotionPageKind => 'Transition';

  @override
  String get exMotionPageFade => 'Fade';

  @override
  String get exMotionPageSlide => 'Slide';

  @override
  String get exMotionPageFadeUp => 'Rise';

  @override
  String get exGestureTapTitle => 'Where the tap landed';

  @override
  String get exGestureTapDescription =>
      'onTapDown and onTapUp receive the tap\'s position within the widget.';

  @override
  String get exGestureTapEvent => 'Event';

  @override
  String get exGestureTapDown => 'onTapDown';

  @override
  String get exGestureTapUp => 'onTapUp';

  @override
  String get exGestureTapSize => 'Dot';

  @override
  String get exGestureDragTitle => 'Drag and drop';

  @override
  String get exGestureDragDescription =>
      'The browser moves the tile with the pointer; the ViewModel method receives the offset when it\'s dropped.';

  @override
  String get exGestureDragAxis => 'Axis';

  @override
  String get exGestureDragFree => 'Free';

  @override
  String get exGestureDragHorizontal => 'Horizontal';

  @override
  String get exGestureDragVertical => 'Vertical';

  @override
  String get exGestureDragRest => 'On drop';

  @override
  String get exGestureDragSnap => 'Snaps back';

  @override
  String get exGestureDragStay => 'Stays';

  @override
  String get exIconsTitle => 'Icon variants';

  @override
  String get exIconsDescription =>
      'The same six names in their four variants and at any size.';

  @override
  String get exIconsVariant => 'Variant';

  @override
  String get exIconsFilled => 'Filled';

  @override
  String get exIconsOutlined => 'Outlined';

  @override
  String get exIconsRounded => 'Rounded';

  @override
  String get exIconsSharp => 'Sharp';

  @override
  String get exIconsSize => 'Size';

  @override
  String get exArchCommandTitle => 'A command: pending, error and result';

  @override
  String get exArchCommandDescription =>
      'While the command waits, the button doesn\'t repeat; if the server fails, error says why.';

  @override
  String get exArchOptimisticTitle => 'Optimistic state by hand';

  @override
  String get exArchOptimisticDescription =>
      'With “Optimistic”, the star changes on tap and reverts if the server fails.';

  @override
  String get exArchServer => 'Server';

  @override
  String get exArchServerOk => 'Responds';

  @override
  String get exArchServerFails => 'Fails';

  @override
  String get exArchLatency => 'Latency';

  @override
  String get exArchOptimistic => 'Optimistic';

  @override
  String get layersOrdersPageKind => 'ThorPage';

  @override
  String get layersOrdersModelKind => 'Class';

  @override
  String get layersOrdersUiViewDescription =>
      'It is a widget: it shows what the ViewModel gives it and passes on what the user does. QueryBuilder renders the loading, error and data states; the button calls a ViewModel method.';

  @override
  String get layersOrdersUiViewModelDescription =>
      'The part of the ViewModel that lives in the browser: query reads, command writes, state holds what the user changes and derived computes from them.';

  @override
  String get layersOrdersPageDescription =>
      'The other half of the ViewModel lives on the server: load fetches the data before rendering and an action receives the form. Throwing NotFound or Redirect decides which page is shown.';

  @override
  String get layersOrdersModelDescription =>
      'A piece of business data, immutable and without screen logic. Whatever travels in a query needs toJson and fromJson.';

  @override
  String get layersOrdersDataRepositoryDescription =>
      'An interface with an HTTP implementation. It turns the response into models and backend errors into what a page knows how to throw: NotFound or HttpError. Never a Redirect: where a signed-out user goes is the middleware\'s call.';

  @override
  String get layersOrdersDataServiceDescription =>
      'One client per backend, with no state or rules: it asks and returns the response as is. ThorHttpClient sets the timeout and reuses connections.';

  @override
  String get layersOrdersDataInjectionDescription =>
      'A middleware puts the repository on the request with a ContextKey. The same Group serves the real repository in production and a fake one in tests.';

  @override
  String get layersOrdersDataTestsDescription =>
      'With a fake repository the page is tested without network or backend: the test client makes the request and the response is checked.';

  @override
  String get exStateDerivedTitle => 'A value computed once';

  @override
  String get exStateDerivedDescription =>
      'The list and the counter read the same derived: it is recomputed once per change, not once per Watch.';

  @override
  String get exStateDerivedOrder => 'Order';

  @override
  String get exStateDerivedOrderMag => 'Magnitude';

  @override
  String get exStateDerivedOrderPlace => 'Place';

  @override
  String get exStateDerivedMin => 'Minimum magnitude';

  @override
  String get exStateQueryTitle => 'The three states of a QueryBuilder';

  @override
  String get exStateQueryDescription =>
      'The builder renders once per snapshot state, and the browser switches between those variants.';

  @override
  String get exStateQueryPhase => 'Snapshot';

  @override
  String get exStateQueryLoading => 'Loading';

  @override
  String get exStateQueryReady => 'Data';

  @override
  String get exStateQueryError => 'Error';

  @override
  String get exDataFeedTitle => 'A list the server keeps up to date';

  @override
  String get exDataFeedDescription =>
      'The server sends every change to the list and the page shows the connection status.';

  @override
  String get exDataFeedLink => 'Network';

  @override
  String get exDataFeedLive => 'Live';

  @override
  String get exDataFeedWaiting => 'Waiting';

  @override
  String get exDataFeedClosed => 'Closed';

  @override
  String get exDataPieceTitle => 'A part on demand';

  @override
  String get exDataPieceDescription =>
      'The page carries a fallback link and the server sends the part when the browser asks for it.';

  @override
  String get exDataPieceTrigger => 'Requested on';

  @override
  String get exDataPieceOpen => 'Open';

  @override
  String get exDataPieceVisible => 'Visible';

  @override
  String get exDataPieceIdle => 'Load';

  @override
  String get exDataPieceMoment => 'The page';

  @override
  String get exDataPieceBefore => 'Before';

  @override
  String get exDataPieceAfter => 'After';

  @override
  String get exFormsRuleTitle => 'A field\'s rule';

  @override
  String get exFormsRuleDescription =>
      'Each field rule has its own message: on submit, the first one that fails is shown.';

  @override
  String get exFormsRuleLabel => 'Rule';

  @override
  String get exFormsRuleRequired => 'Empty';

  @override
  String get exFormsRuleEmail => 'Email';

  @override
  String get exFormsRuleMin => 'Length';

  @override
  String get exFormsPhaseTitle => 'A form that goes to the server';

  @override
  String get exFormsPhaseDescription =>
      'A navigating Form is marked busy while it submits and, if the server rejects it, comes back with the first error.';

  @override
  String get exFormsPhaseLabel => 'Status';

  @override
  String get exFormsPhaseEditing => 'Editing';

  @override
  String get exFormsPhaseSending => 'Sending';

  @override
  String get exFormsPhaseFailed => 'Error';

  @override
  String get exStartInstallTitle => 'From the commands to the first page';

  @override
  String get exStartInstallDescription =>
      'The commands and the home page title depend on where Thor gets the project from.';

  @override
  String get exStartInstallSource => 'Thor from';

  @override
  String get exStartInstallSourceLocal => 'This machine';

  @override
  String get exStartInstallTitleLabel => 'Title';

  @override
  String get exCatYes => 'Yes';

  @override
  String get exCatEnabled => 'Enabled';

  @override
  String get exCatIcon => 'Icon';

  @override
  String get exCatVariant => 'Variant';

  @override
  String get exCatSize => 'Size';

  @override
  String get exCatSmall => 'Small';

  @override
  String get exCatMedium => 'Medium';

  @override
  String get exCatLarge => 'Large';

  @override
  String get exBtnFilledTitle => 'FilledButton';

  @override
  String get exBtnFilledDescription =>
      'The main action: filled or tonal, with or without an icon, enabled or not.';

  @override
  String get exBtnKindFilled => 'Filled';

  @override
  String get exBtnKindTonal => 'Tonal';

  @override
  String get exBtnKindOutlined => 'Outlined';

  @override
  String get exBtnKindText => 'Text';

  @override
  String get exBtnElevatedTitle => 'ElevatedButton';

  @override
  String get exBtnElevatedDescription =>
      'A button raised above the surface, with or without an icon.';

  @override
  String get exBtnIconLabelsTitle => 'The .icon constructor';

  @override
  String get exBtnIconLabelsDescription =>
      'All four buttons accept .icon; FilledButton also .tonal and .tonalIcon.';

  @override
  String get exBtnLink => 'Link';

  @override
  String get exBtnOutlinedTitle => 'OutlinedButton';

  @override
  String get exBtnOutlinedDescription =>
      'A secondary action: with onPressed it\'s a button, with href a link.';

  @override
  String get exBtnTextTitle => 'TextButton';

  @override
  String get exBtnTextDescription =>
      'The lowest-emphasis action: with onPressed it\'s a button, with href a link.';

  @override
  String get exBtnIconTitle => 'IconButton';

  @override
  String get exBtnIconDescription =>
      'An icon button with an accessible name: change the icon size.';

  @override
  String get exBtnVariantsTitle => 'IconButton variants';

  @override
  String get exBtnVariantsDescription =>
      'Standard, filled, filledTonal and outlined; with href it\'s a link.';

  @override
  String get exBtnVarStandard => 'Standard';

  @override
  String get exBtnFabTitle => 'FloatingActionButton';

  @override
  String get exBtnFabDescription => 'The sizes of the floating action button.';

  @override
  String get exBtnFabExtended => 'Extended';

  @override
  String get exBtnStyleTitle => 'ButtonStyle and styleFrom';

  @override
  String get exBtnStyleDescription =>
      'A button\'s shape, radius and padding with styleFrom.';

  @override
  String get exBtnShape => 'Shape';

  @override
  String get exBtnShapeRounded => 'Rounded';

  @override
  String get exBtnShapeStadium => 'Stadium';

  @override
  String get exBtnRadius => 'Radius';

  @override
  String get exBtnPadding => 'Padding';

  @override
  String get pageExampleCounter => 'Counter';

  @override
  String get pageExampleTemperature => 'Temperature converter';

  @override
  String get pageExampleFlightBooker => 'Flight booker';

  @override
  String get pageExampleTimer => 'Timer';

  @override
  String get pageExampleCrud => 'CRUD list';

  @override
  String get pageExampleCircleDrawer => 'Circles with undo';

  @override
  String get pageExampleCells => 'Spreadsheet';

  @override
  String get pageExampleContentPage => 'Content page';

  @override
  String get exInpHelper => 'Helper';

  @override
  String get exInpError => 'Error';

  @override
  String get exInpName => 'Name';

  @override
  String get exInpTextFieldTitle => 'TextField';

  @override
  String get exInpTextFieldDescription =>
      'A text field: helper, icon, error and enabled.';

  @override
  String get exInpStatesTitle => 'Field states';

  @override
  String get exInpStatesDescription =>
      'Email, password or multiline; normal, with an error or locked.';

  @override
  String get exInpKind => 'Type';

  @override
  String get exInpKindEmail => 'Email';

  @override
  String get exInpStateNormal => 'Normal';

  @override
  String get exInpStateError => 'Error';

  @override
  String get exInpFormTitle => 'TextFormField';

  @override
  String get exInpFormDescription =>
      'The schema rules: leave the field invalid and press Submit.';

  @override
  String get exInpRule => 'Rules';

  @override
  String get exInpDropdownTitle => 'DropdownButton';

  @override
  String get exInpDropdownDescription =>
      'A list of options: width, hint and enabled.';

  @override
  String get exInpExpanded => 'Width';

  @override
  String get exInpHint => 'Hint';

  @override
  String get exInpAutocompleteTitle => 'Autocomplete';

  @override
  String get exInpAutocompleteDescription =>
      'A field that suggests options: the list, which way it opens and its height.';

  @override
  String get exInpList => 'List';

  @override
  String get exInpListFruits => 'Fruits';

  @override
  String get exInpListColors => 'Colors';

  @override
  String get exInpOpens => 'Opens';

  @override
  String get exInpOpensDown => 'Down';

  @override
  String get exInpOpensUp => 'Up';

  @override
  String get exInpPanelHeight => 'Panel height';

  @override
  String get exInpDdffTitle => 'DropdownButtonFormField';

  @override
  String get exInpDdffDescription => 'The list with a label, helper and error.';

  @override
  String get exInpDateTitle => 'Date fields';

  @override
  String get exInpDateDescription =>
      'The browser\'s field or the field with a calendar. Months, days, first day of the week and digits come from the page\'s language.';

  @override
  String get exInpDateKind => 'Field';

  @override
  String get exInpDateNative => 'Native';

  @override
  String get exInpDateCalendar => 'Calendar';

  @override
  String get exInpAllowEmpty => 'Allows empty';

  @override
  String get exInpSliderTitle => 'Slider';

  @override
  String get exInpSliderDescription =>
      'A value between min and max, continuous or in steps.';

  @override
  String get exInpDivisions => 'Divisions';

  @override
  String get exInpSegPassword => 'Password';

  @override
  String get exInpSegComments => 'Notes';

  @override
  String get exInpMode => 'Mode';

  @override
  String get exInpModeLocked => 'Locked';

  @override
  String get exSelValue => 'Value';

  @override
  String get exSelOff => 'Off';

  @override
  String get exSelOn => 'On';

  @override
  String get exSelMixed => 'Mixed';

  @override
  String get exSelChosen => 'Selected';

  @override
  String get exSelCheckboxTitle => 'Checkbox';

  @override
  String get exSelCheckboxDescription =>
      'A checkbox: checked, unchecked or mixed, enabled or not.';

  @override
  String get exSelSwitchTitle => 'Switch';

  @override
  String get exSelSwitchDescription => 'An on/off switch.';

  @override
  String get exSelRadioTitle => 'RadioGroup and Radio';

  @override
  String get exSelRadioDescription =>
      'The group holds the selected value; each Radio only states its value.';

  @override
  String get exSelSegmentedTitle => 'SegmentedButton';

  @override
  String get exSelSegmentedDescription =>
      'Several native segments to pick a value: without JavaScript you can pick and move through them with the arrow keys.';

  @override
  String get exSelCard => 'Card';

  @override
  String get exSelCash => 'Cash';

  @override
  String get exSelTransfer => 'Bank';

  @override
  String get exSelChoiceTitle => 'ChoiceChip';

  @override
  String get exSelChoiceDescription => 'Chips to pick a single option.';

  @override
  String get exSelInputTitle => 'InputChip';

  @override
  String get exSelInputDescription =>
      'A tag for something already chosen, with its × to remove it.';

  @override
  String get exSelDeletable => 'With ×';

  @override
  String get exSelChips => 'Tags';

  @override
  String get exSelLinkTitle => 'Chips that are links';

  @override
  String get exSelLinkDescription =>
      'With href the chip is a link and works without JavaScript.';

  @override
  String get exSelSelected => 'Selected';

  @override
  String get exSelCheckmark => 'Checkmark';

  @override
  String get exSelDeleteLink => '× as link';

  @override
  String get exSelFilterTitle => 'FilterChip';

  @override
  String get exSelFilterDescription => 'Chips to pick several options at once.';

  @override
  String get exSelTilesTitle => 'ListTile with a control';

  @override
  String get exSelTilesDescription =>
      'Checkbox, Switch or Radio with its title: the whole row responds.';

  @override
  String get exSelTile => 'Control';

  @override
  String get exSelTileCheckbox => 'Checkbox';

  @override
  String get exSelTileSwitch => 'Switch';

  @override
  String get exSelTileRadio => 'Radio';

  @override
  String get exSelControl => 'Position';

  @override
  String get exSelLeading => 'Leading';

  @override
  String get exSelTrailing => 'Trailing';

  @override
  String get exSelSubtitle => 'Subtitle';

  @override
  String get exNavAppBarTitle => 'AppBar';

  @override
  String get exNavAppBarDescription =>
      'The top bar: centered title or not, menu button, actions and elevation.';

  @override
  String get exNavCenterTitle => 'Centered title';

  @override
  String get exNavLeading => 'Menu button';

  @override
  String get exNavSearchAction => 'Search action';

  @override
  String get exNavElevation => 'Elevation';

  @override
  String get exNavTabsTitle => 'TabBar and TabBarView';

  @override
  String get exNavTabsDescription =>
      'Native tabs with their content: change how many there are and whether the bar scrolls.';

  @override
  String get exNavScrollable => 'Scrollable bar';

  @override
  String get exNavTabCount => 'Tabs';

  @override
  String get exNavDrawerTitle => 'Drawer';

  @override
  String get exNavDrawerDescription =>
      'A menu that slides in from the side: pick the edge and the width, and open it.';

  @override
  String get exNavSide => 'Edge';

  @override
  String get exNavSideStart => 'Start';

  @override
  String get exNavSideEnd => 'End';

  @override
  String get exNavBarTitle => 'NavigationBar';

  @override
  String get exNavBarDescription =>
      'The bottom destination bar: how many destinations and how the labels are shown.';

  @override
  String get exNavLabels => 'Labels';

  @override
  String get exNavLabelsAll => 'All';

  @override
  String get exNavLabelsSelected => 'One';

  @override
  String get exNavLabelsNone => 'None';

  @override
  String get exNavDestinations => 'Destinations';

  @override
  String get exNavRailTitle => 'NavigationRail';

  @override
  String get exNavRailDescription =>
      'The side destination bar: labels and extended rail.';

  @override
  String get exNavExtended => 'Extended';

  @override
  String get exNavLinkTitle => 'Link';

  @override
  String get exNavLinkDescription =>
      'Any widget as a link: internal or external, in a new tab, or marked as the current page.';

  @override
  String get exNavExternal => 'External';

  @override
  String get exNavNewTab => 'New tab';

  @override
  String get exNavCurrent => 'Current page';

  @override
  String get exNavSheetTitle => 'ModalBottomSheet';

  @override
  String get exNavSheetDescription =>
      'A sheet that slides up from the bottom: with or without a handle and with more or fewer options.';

  @override
  String get exNavDragHandle => 'Handle';

  @override
  String get exNavOptions => 'Options';

  @override
  String get exFbAlertTitle => 'AlertDialog';

  @override
  String get exFbAlertDescription =>
      'A native dialog with a title, content and actions: open it with the button.';

  @override
  String get exFbBarrier => 'Closes on outside tap';

  @override
  String get exFbContent => 'Content';

  @override
  String get exFbTwoActions => 'Two actions';

  @override
  String get exFbControllerTitle => 'Dialog with DialogController';

  @override
  String get exFbControllerDescription =>
      'One ViewModel method opens the dialog and another closes it.';

  @override
  String get exFbContacts => 'Contacts';

  @override
  String get exFbCloseAfter => 'Closes on delete';

  @override
  String get exFbSnackTitle => 'SnackBar';

  @override
  String get exFbSnackDescription =>
      'A short message that hides on its own: with or without an action, shorter or longer.';

  @override
  String get exFbAction => 'Action';

  @override
  String get exFbFloating => 'Floating';

  @override
  String get exFbDuration => 'Duration';

  @override
  String get exFbDur2 => '2 s';

  @override
  String get exFbDur4 => '4 s';

  @override
  String get exFbDur6 => '6 s';

  @override
  String get exFbProgressTitle => 'Progress indicators';

  @override
  String get exFbProgressDescription =>
      'Linear or circular, with a value or spinning endlessly.';

  @override
  String get exFbShape => 'Shape';

  @override
  String get exFbLinear => 'Linear';

  @override
  String get exFbCircular => 'Circular';

  @override
  String get exFbDeterminate => 'With value';

  @override
  String get exFbValue => 'Value';

  @override
  String get exFbPopupTitle => 'PopupMenuButton';

  @override
  String get exFbPopupDescription =>
      'A menu of options: mark the current one or disable one.';

  @override
  String get exFbMarkCurrent => 'Mark current';

  @override
  String get exFbLastEnabled => 'Last option';

  @override
  String get exContAbove => 'Above';

  @override
  String get exContBelow => 'Below';

  @override
  String get exContAccent => 'Color';

  @override
  String get exContAccordion => 'Accordion';

  @override
  String get exContActions => 'Actions';

  @override
  String get exContAscending => 'Ascending';

  @override
  String get exContAvatarTitle => 'CircleAvatar and Badge';

  @override
  String get exContAvatarDescription =>
      'An avatar with a badge: label, dot or number.';

  @override
  String get exContBadge => 'Type';

  @override
  String get exContBadgeLabel => 'Text';

  @override
  String get exContBadgeDot => 'Dot';

  @override
  String get exContBadgeCount => 'Number';

  @override
  String get exContBlank => 'Open in a new tab';

  @override
  String get exContBroken => 'Broken image';

  @override
  String get exContBuilders => 'Builders';

  @override
  String get exContBuildersTitle => 'When the image fails or is slow';

  @override
  String get exContBuildersDescription =>
      'With the builders, a failure shows your widget; without them, the browser\'s broken image.';

  @override
  String get exContCardTitle => 'Card';

  @override
  String get exContCardDescription =>
      'A surface with a shadow: change its elevation and its padding.';

  @override
  String get exContCheckboxes => 'Checkboxes';

  @override
  String get exContChipTitle => 'Chip and ActionChip';

  @override
  String get exContChipDescription =>
      'A tag, with an avatar or with an ×, or a tag you can press.';

  @override
  String get exContChipPlain => 'Chip';

  @override
  String get exContChipAvatar => 'Avatar';

  @override
  String get exContChipAction => 'Action';

  @override
  String get exContDeletable => 'With ×';

  @override
  String get exContDelay => 'Delay';

  @override
  String get exContDense => 'Dense';

  @override
  String get exContDividerTitle => 'Divider';

  @override
  String get exContDividerDescription =>
      'A horizontal line: thickness and indent at the ends.';

  @override
  String get exContThickness => 'Thickness';

  @override
  String get exContIndent => 'Indent';

  @override
  String get exContElevation => 'Elevation';

  @override
  String get exContExpansionTitle => 'ExpansionTile';

  @override
  String get exContExpansionDescription =>
      'Rows that expand; with the same name they form an accordion.';

  @override
  String get exContOpen => 'First open';

  @override
  String get exContFit => 'Fit';

  @override
  String get exContFitCover => 'Cover';

  @override
  String get exContFitContain => 'Contain';

  @override
  String get exContFitFill => 'Fill';

  @override
  String get exContGlyph => 'Icon';

  @override
  String get exContGlyphHome => 'Home';

  @override
  String get exContGlyphStar => 'Star';

  @override
  String get exContGlyphBell => 'Bell';

  @override
  String get exContHostile => 'HTML with script';

  @override
  String get exContNofollow => 'nofollow';

  @override
  String get exContHtmlTitle => 'HtmlWidget';

  @override
  String get exContHtmlDescription =>
      'Third-party HTML, sanitized against an allowlist; the policy changes what is kept.';

  @override
  String get exContIconTitle => 'Icon';

  @override
  String get exContIconDescription =>
      'An SVG icon: pick the glyph, the size and the color.';

  @override
  String get exContImageTitle => 'Image.asset';

  @override
  String get exContImageDescription =>
      'An image from your web folder: fit, corners and width.';

  @override
  String get exContRounded => 'Rounded corners';

  @override
  String get exContWidth => 'Width';

  @override
  String get exContLineHeight => 'Line height';

  @override
  String get exContLines => 'Lines';

  @override
  String get exContLinesAll => 'All';

  @override
  String get exContLinesOne => 'One';

  @override
  String get exContLinesTwo => 'Two';

  @override
  String get exContLongMessage => 'Long message';

  @override
  String get exContPlacement => 'Position';

  @override
  String get exContRadius => 'Radius';

  @override
  String get exContRichTitle => 'RichText and SelectableText';

  @override
  String get exContRichDescription =>
      'A span with a different style inside the text, and a text that can be selected.';

  @override
  String get exContSpan => 'Span';

  @override
  String get exContItalic => 'Italic';

  @override
  String get exContPlain => 'Same';

  @override
  String get exContSelectable => 'Selectable';

  @override
  String get exContSelected => 'Selected';

  @override
  String get exContSubtitle => 'Subtitle';

  @override
  String get exContRows => 'Rows';

  @override
  String get exContSortBy => 'Sort by column';

  @override
  String get exContSortNone => '-';

  @override
  String get exContTableTitle => 'DataTable';

  @override
  String get exContTableDescription =>
      'A table with headers: sorting, checkboxes and number of rows.';

  @override
  String get exContTextTitle => 'Text and TextStyle';

  @override
  String get exContTextDescription => 'A text\'s size, weight and line limit.';

  @override
  String get exContWeight => 'Weight';

  @override
  String get exContWeightRegular => '400';

  @override
  String get exContWeightSemibold => '600';

  @override
  String get exContWeightBold => '700';

  @override
  String get exContTileTitle => 'ListTile';

  @override
  String get exContTileDescription =>
      'A row with an icon, title and subtitle: states and density.';

  @override
  String get exContTooltipTitle => 'Tooltip';

  @override
  String get exContTooltipDescription =>
      'A bubble on pointer hover: position, text and delay.';

  @override
  String get exContGlyphMail => 'Mail';

  @override
  String get exContSortFirst => '1';

  @override
  String get exContSortSecond => '2';

  @override
  String get exContSortThird => '3';

  @override
  String get exRecCounterTitle => 'Counter';

  @override
  String get exRecCounterDescription =>
      'A label with the count and a button that increases it by the step.';

  @override
  String get exRecCounterStep => 'Step';

  @override
  String get exRecTempTitle => 'Temperature converter';

  @override
  String get exRecTempDescription =>
      'Two fields that update each other while the text is a number.';

  @override
  String get exRecTempDecimals => 'Decimals';

  @override
  String get exRecTempDec0 => '0';

  @override
  String get exRecTempDec1 => '1';

  @override
  String get exRecTempDec2 => '2';

  @override
  String get exRecTimerTitle => 'Timer';

  @override
  String get exRecTimerDescription =>
      'A bar that fills over the slider\'s duration, the elapsed time and a button that resets it.';

  @override
  String get exRecPageTitle => 'A content page';

  @override
  String get exRecPageDescription =>
      'A hero and a grid of posts: change the tone, the image loading and the columns.';

  @override
  String get exRecPageTone => 'Tone';

  @override
  String get exRecPageToneSoft => 'Soft';

  @override
  String get exRecPageToneInk => 'Ink';

  @override
  String get exRecPageLazy => 'Lazy image';

  @override
  String get exRecPageColumns => 'Columns';

  @override
  String get exUiOverlayTitle => 'Dialog, sheet and drawer';

  @override
  String get exUiOverlayDescription =>
      'The browser opens the dialog, sheet or drawer, traps focus and closes it with Esc.';

  @override
  String get exUiOverlayKind => 'Opens';

  @override
  String get exUiOverlayDialog => 'Dialog';

  @override
  String get exUiOverlaySheet => 'Sheet';

  @override
  String get exUiOverlayDrawer => 'Drawer';

  @override
  String get exUiListTitle => 'List of rows';

  @override
  String get exUiListDescription =>
      'Raise the rows up to 10,000: the page keeps only the ones near the screen.';

  @override
  String get exUiListRows => 'Rows';

  @override
  String get exUiSemTitle => 'What Semantics says';

  @override
  String get exUiSemDescription =>
      'Semantics tells a screen reader what the text is, and Thor renders the matching element.';

  @override
  String get exUiSemKind => 'Role';

  @override
  String get exUiSemHeading => 'Heading';

  @override
  String get exUiSemButton => 'Button';

  @override
  String get exUiSemStatus => 'Status';

  @override
  String get exUiSemLevel => 'Level';

  @override
  String get exUiLocaleTitle => 'A card in four languages';

  @override
  String get exUiLocaleDescription =>
      'The text, plural, money, date and direction follow the page\'s language.';

  @override
  String get exUiLocaleLanguage => 'Language';

  @override
  String get exUiLocaleEn => 'English';

  @override
  String get exUiLocaleEs => 'Spanish';

  @override
  String get exUiLocaleDe => 'German';

  @override
  String get exUiLocaleAr => 'Arabic';

  @override
  String get exUiLocaleItems => 'Items';

  @override
  String get exTitleStartWidgetToWeb => 'From widget to page';

  @override
  String get exTitleStartStoreGrid => 'The store: a grid of cards';

  @override
  String get exTitleStartCart => 'The store: a cart in the browser';

  @override
  String get exTitleStartCheckout => 'The store: a form';

  @override
  String get exTitleCard => 'A product card';

  @override
  String get exTitleHover => 'Color by state with .when()';

  @override
  String get exTitleAccordion => 'Exclusive accordion';

  @override
  String get exTitleCarousel => 'Carousel with arrows and dots';

  @override
  String get exTitleTabs => 'Tabs without JS';

  @override
  String get exTitleDialog => 'Native dialog';

  @override
  String get exTitleMenu => 'Menu with popover';

  @override
  String get exTitleMenuAnchor => 'MenuAnchor';

  @override
  String get exTitleFormControls => 'Stateful controls';

  @override
  String get exTitleFormSubmit => 'Submit without reloading';

  @override
  String get exTitleFormSchema => 'A form with a schema';

  @override
  String get exTitleFormSchemaFailed => 'When the server says no';

  @override
  String get exTitleFormUpload => 'Uploading a file';

  @override
  String get exTitleFormFieldParams => 'Field attributes';

  @override
  String get exTitleSliderBubble => 'Slider with a bubble';

  @override
  String get exTitleSegmentedPill => 'Pill toggle';

  @override
  String get exTitleScale => 'Hover transition';

  @override
  String get exTitleEntrance => 'Entrance and loop with AnimationController';

  @override
  String get exTitleChips => 'Chips and progress';

  @override
  String get exTitleProductCard => 'A complete product card';

  @override
  String get exTitleWrappers => 'Wrappers without an element';

  @override
  String get exTitleGrid => 'Grid by breakpoint';

  @override
  String get exTitleVariants => 'Variants by width and state';

  @override
  String get exTitleHoverGroup => 'Group hover';

  @override
  String get exTitleLayoutSizes =>
      'SizedBox, Container, ConstrainedBox and FractionallySizedBox';

  @override
  String get exTitleLayoutScreen => 'Sizes relative to the window';

  @override
  String get exTitleLayoutGridExtent =>
      'GridView.extent counts columns like Flutter';

  @override
  String get exTitleLayoutScroll => 'Vertical and horizontal scroll';

  @override
  String get exTitleLayoutResponsive =>
      'Responsive with .when() and ResponsiveVisibility';

  @override
  String get exTitleUnits => 'Units, real measurements';

  @override
  String get exTitleResponsiveCard => 'A card that follows its box';

  @override
  String get exTitleStickyList => 'Sticky headers in a list';

  @override
  String get exTitleHoverEffects => 'Rotate, translate and blur on hover';

  @override
  String get exTitleComponentThemes => 'A theme per component';

  @override
  String get exTitleThemeFollowsSwitch =>
      'Theme.of follows when the mode changes';

  @override
  String get exTitleDescendants => 'Raw HTML styled by tag';

  @override
  String get exTitlePatterns => 'Tiled patterns';

  @override
  String get exTitleDemoExplorer => 'The new project';

  @override
  String get exTitleStateBool => 'Two states with a bool';

  @override
  String get exTitleStateEnum => 'One state per enum value';

  @override
  String get exTitleStateTodo => 'A to-do list';

  @override
  String get exTitleStateForm => 'Controls bound to state';

  @override
  String get exTitleStateKeyed => 'Two instances with a key';

  @override
  String get exTitleStateControllers => 'Controllers and Timer';

  @override
  String get exTitleStatePages => 'PageController and onPageChanged';

  @override
  String get exTitleStateLifecycle => 'onHydrated and dispose';

  @override
  String get exTitleStateFeedback => 'confirm() and toast()';

  @override
  String get exTitleStateSet => 'toggle() and a set';

  @override
  String get exTitleStateNotifier => 'ValueListenableBuilder';

  @override
  String get exTitleRoutesTree => 'The route table of an app with modules';

  @override
  String get exTitleRoutesNav => 'Links from routes';

  @override
  String get exTitleDataForm => 'A form with a schema';

  @override
  String get exTitleDataFormFailed => 'After a 422';

  @override
  String get exTitleCatIcons => 'Icons';

  @override
  String get exTitleCatIconVariants => 'Icon variants';

  @override
  String get exTitleMotionAnimatedSize => 'AnimatedSize';

  @override
  String get exTitleEventsHoverFocus => 'MouseRegion and Focus';

  @override
  String get exTitleEventsExpansion => 'ExpansionTile.onExpansionChanged';

  @override
  String get exTitleGestureInkwell => 'InkWell';

  @override
  String get exTitleGestureSwipeKeys => 'Swiping with the keyboard';

  @override
  String get exTitleGestureDismissible => 'Dismissible';

  @override
  String get exTitleGestureDraggable => 'Draggable and DragTarget';

  @override
  String get exTitleGestureReorderable => 'ReorderableListView';

  @override
  String get exTitleNavSlivers => 'CustomScrollView with a pinned SliverAppBar';

  @override
  String get exTitleDialogPermanentDrawer =>
      'A drawer that becomes a fixed panel from md';

  @override
  String get exTitleRecipeFlights => 'Flight booker';

  @override
  String get exTitleRecipeCrud => 'CRUD';

  @override
  String get exTitleRecipeCircles => 'Circle drawer';

  @override
  String get exTitleRecipeCells => 'Cells';

  @override
  String get structAbout01 =>
      'The route table: each module\'s group inside the app\'s frame.';

  @override
  String get structAbout02 =>
      'The app, declared once: routes, theme and base styles.';

  @override
  String get structAbout03 => 'The home page, at /.';

  @override
  String get structAbout04 =>
      'The frame of every page: header, the page and footer.';

  @override
  String get structAbout05 =>
      'What is shown for a URL that doesn\'t exist or an error.';

  @override
  String get structAbout06 =>
      'The environment variables, typed and validated at startup.';

  @override
  String get structAbout07 =>
      'The server: serves the app on the environment\'s port.';

  @override
  String get structAbout08 => 'The app\'s tests, from day one.';

  @override
  String get structAboutHomeRoutes =>
      'The home module: its routes as one Group, which the table puts in place.';

  @override
  String get structAboutCounterCard =>
      'The module\'s component: the counter and its buttons.';

  @override
  String get structAboutCounterViewModel =>
      'The ViewModel: the state that changes in the browser.';

  @override
  String get structAboutTheme => 'The light and dark themes the widgets read.';

  @override
  String get structAboutPageTitle =>
      'A general component: it knows no module, so any page can use it.';

  @override
  String get structAboutCounterTest =>
      'The ViewModel tested on its own, without a page.';

  @override
  String get structAbout09 =>
      'The app\'s route table only composes: the frame, the session and the modules.';

  @override
  String get structAbout10 =>
      'The frame of the whole app. It may import the modules\' routes for its navigation; core/ may not.';

  @override
  String get structAbout11 =>
      'One client for the whole backend: base URL, token and error translation.';

  @override
  String get structAbout12 =>
      'Who the user is: reads the cookie and puts the user and the API client in the context.';

  @override
  String get structAbout13 =>
      'What they can do: each module\'s Group requires the role it needs.';

  @override
  String get structAbout14 =>
      'A general component: it doesn\'t know the business, it receives plain data.';

  @override
  String get structAbout15 =>
      'The module is a Group: its frame, its permissions, its stylesheet and its error page.';

  @override
  String get structAbout16 =>
      'A rule that only applies to sales: it lives in the module, not in core/.';

  @override
  String get structAbout17 =>
      'Business operations with typed models. It never returns JSON.';

  @override
  String get structAbout18 =>
      'A module component: it knows about orders and several submodules use it.';

  @override
  String get structAbout19 =>
      'The submodule\'s routes. Another module that links here imports only this file.';

  @override
  String get structAbout20 =>
      'The page reads the filters from the URL, asks the repository and shows the result.';

  @override
  String get structAbout21 =>
      'The form\'s rules, once: the browser and the server apply them the same way.';

  @override
  String get structAbout22 =>
      'A submodule component. It moves up to sales/widgets/ when another submodule needs it.';

  @override
  String get structAbout23 =>
      'The browser\'s ViewModel, only for what changes without going to the server.';

  @override
  String get structAbout24 =>
      'The module\'s error page: it wins over the general one on the sales routes.';

  @override
  String get exMotion2CurvesTitle => 'What a curve is';

  @override
  String get exMotion2CurvesDescription =>
      'A curve maps time, on the horizontal axis, to the animation\'s progress, on the vertical one.';

  @override
  String get exMotion2Curve => 'Curve';

  @override
  String get exMotion2PositionTitle => 'AnimatedAlign and AnimatedPositioned';

  @override
  String get exMotion2PositionDescription =>
      'AnimatedAlign animates the child\'s alignment; AnimatedPositioned, its offsets and size within a Stack.';

  @override
  String get exMotion2Widget => 'Widget';

  @override
  String get exMotion2Spot => 'Target';

  @override
  String get exMotion2SwitcherTitle => 'AnimatedSwitcher with Hero';

  @override
  String get exMotion2SwitcherDescription =>
      'AnimatedSwitcher fades the new state over the previous one, and each Hero present in both travels to its new place and size.';

  @override
  String get exMotion2Layout => 'Layout';

  @override
  String get exMotion2LayoutRow => 'Row';

  @override
  String get exMotion2LayoutColumn => 'Column';

  @override
  String get exMotion2StaggerTitle => 'Staggered entrance';

  @override
  String get exMotion2StaggerDescription =>
      'A single controller and one Interval per row: each row enters a delay after the previous one.';

  @override
  String get exMotion2Delay => 'Delay';

  @override
  String get exMotion2RepeatTitle => 'A loop between two values';

  @override
  String get exMotion2RepeatDescription =>
      'repeat(min:, max:) limits the loop to a stretch of the path; the circle\'s opacity and size follow it.';

  @override
  String get exMotion2Reverse => 'On arrival';

  @override
  String get exMotion2ReverseBack => 'Reverses';

  @override
  String get exMotion2ReverseJump => 'Jumps';

  @override
  String get exMotion2Min => 'Minimum';

  @override
  String get exMotion2Max => 'Maximum';

  @override
  String get exMotion2Period => 'Period';

  @override
  String get exMotion2ScrollTitle => 'Reveal on scroll';

  @override
  String get exMotion2ScrollDescription =>
      'With inView, the animation advances with scrolling and reverses when you scroll back; with onVisible it runs only once, at its own pace.';

  @override
  String get exMotion2Driver => 'Driven by';

  @override
  String get exMotion2Effect => 'Effect';

  @override
  String get exMotion2EffectRise => 'Rise';

  @override
  String get exMotion2EffectScale => 'Grow';

  @override
  String get exMotion2EffectSlide => 'Slide';

  @override
  String get pageExampleSlideToConfirm => 'Slide to confirm';

  @override
  String get pageExampleCopyButton => 'Copy button';

  @override
  String get pageExampleTabIndicator => 'Tabs with indicator';

  @override
  String get pageExampleToastStack => 'Toast stack';

  @override
  String get exMotion2SlideTitle => 'Slide to confirm';

  @override
  String get exMotion2SlideDescription =>
      'Drag the handle to the end. The browser moves it with the pointer and the ViewModel receives only the final position: if it passes the threshold, it confirms; if not, the handle goes back to the start.';

  @override
  String get exMotion2Threshold => 'Threshold';

  @override
  String get exMotion2CopyTitle => 'Copy button';

  @override
  String get exMotion2CopyDescription =>
      'When you copy the command, the icon turns into a checkmark for a moment and then comes back.';

  @override
  String get exMotion2Morph => 'Change';

  @override
  String get exMotion2MorphFade => 'Fade';

  @override
  String get exMotion2MorphScale => 'Scale';

  @override
  String get exMotion2MorphTurn => 'Rotate';

  @override
  String get exMotion2Hold => 'Holds';

  @override
  String get exMotion2TabsTitle => 'Tab indicator';

  @override
  String get exMotion2TabsDescription =>
      'The indicator is a single element that slides under the labels; the content below changes with a fade.';

  @override
  String get exMotion2Indicator => 'Indicator';

  @override
  String get exMotion2IndicatorPill => 'Pill';

  @override
  String get exMotion2IndicatorLine => 'Line';

  @override
  String get exMotion2ToastsTitle => 'Toast stack';

  @override
  String get exMotion2ToastsDescription =>
      'Each toast enters from the edge you choose, the newest stays in front and the earlier ones shrink and fade behind it. When dismissed, a toast leaves the way it came in.';

  @override
  String get exMotion2Edge => 'Edge';

  @override
  String get exMotion2EdgeBottom => 'Bottom';

  @override
  String get exMotion2EdgeTop => 'Top';

  @override
  String siteTitleTemplate(String title, String site) => '${title} · ${site}';

  @override
  String widgetPageDescriptionWithSummary(String name, String summary) =>
      'Thor\'s ${name} widget: signature, parameters and documentation. ${summary}';

  @override
  String llmsSource(String url) => 'Source: ${url}';

  @override
  String get tocBackToTop => 'Back to top';

  @override
  String get tocOnThisPage => 'On this page';

  @override
  String get navAreas => 'Site areas';

  @override
  String get navExamplesApps => 'Apps';

  @override
  String get navExamplesPatterns => 'Interaction patterns';

  @override
  String get apiLabelServer => 'Server';

  @override
  String get apiLabelRouter => 'Routes';

  @override
  String get apiLabelHtml => 'HTML';

  @override
  String get apiLabelTesting => 'Testing';

  @override
  String get apiLabelIntl => 'Localization';

  @override
  String get apiLabelThorTest => 'Testing tools';

  @override
  String get apiLabelStudio => 'Design system';

  @override
  String get homeStartHeading => 'Start here';

  @override
  String get homeGuideHeading => 'The guide';

  @override
  String get homeReferenceHeading => 'Reference';

  @override
  String get homeExamplesSummary =>
      'Small, complete apps, and interaction patterns.';

  @override
  String get homeComponentsSummary =>
      'Every widget with its demo, its code and its parameters.';

  @override
  String get searchDialogLabel => 'Search the documentation';

  @override
  String get searchDialogHintMove => 'Move';

  @override
  String get searchDialogHintOpen => 'Open';

  @override
  String get searchDialogHintClose => 'Close';

  @override
  String get homeStartInstall =>
      'Install the thor command and create your first project.';

  @override
  String get homeStartFirstApp =>
      'A complete app, from screen to data, step by step.';

  @override
  String get homeStartFlutter =>
      'What stays the same and what changes when moving from Flutter to the web.';
}

/// The messages for [locale]: its region's, else its language's.
/// Throws for a language the app lacks (see `AppLocalizations.supportedLocales`).
AppLocalizations lookupAppLocalizations(Locale locale) {
  final region = [
    locale.languageCode,
    ?locale.scriptCode,
    ?locale.countryCode,
  ].join('_');
  switch (region) {}
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
    case 'en':
      return AppLocalizationsEn();
  }
  throw UnsupportedError(
    'AppLocalizations has no messages for $locale: add lib/l10n/ ARB files or '
    'resolve against AppLocalizations.supportedLocales',
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));

  @override
  bool isSupported(Locale locale) =>
      const {'es', 'en'}.contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
