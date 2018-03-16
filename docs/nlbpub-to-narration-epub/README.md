Lag innlesingsklar EPUB fra NLBPUB
=================

Dette steget:
- legger inn ekstra informasjon i HTML-dokumentet; lydbokavtalen; informasjon om den trykte boka (basert på metadata); informasjon om lydboken (basert på HTML-filenes struktur); annonsering av lydbokens slutt
- TODO: genererer *fortsettelsesoverskrifter* der det er behov for det, det vil si når et `section`-element etterfølges av noe annet enn andre `section`-elementer
- genererer *synkroniseringspunkter*, der flere `p`-elementer er samlet i ett synkroniseringspunkt. Dette bidrar til å redusere det manuelle synkronseringsarbeidet til innleseren.
