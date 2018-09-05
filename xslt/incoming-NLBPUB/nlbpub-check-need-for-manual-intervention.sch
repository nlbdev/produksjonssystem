<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xslt2">

    <title>Undersøk innkommende NLBPUB for å se om det er behov for manuell kontroll</title>
    
    <!-- Denne Schematron-filen brukes i produksjonssystemet for å se etter litt rar eller unventet markup i innkommende filer, og varsle om dette. -->

    <ns prefix="html" uri="http://www.w3.org/1999/xhtml"/>
    <ns prefix="epub" uri="http://www.idpf.org/2007/ops"/>
    <ns prefix="mathml" uri="http://www.w3.org/1998/Math/MathML"/>
    
    <pattern id="nlbpub001">
        <p>Sjekk lister, og varsle hvis det er lister med bare ett listepunkt. </p>
        <rule context="html:ol | html:ul">
            <report test="count(html:li) eq 1">
                [nlbpub001] Et listepunkt bør normalt ikke opptre alene i en liste. Kanskje det bare er et vanlig avsnitt?
            </report>
        </rule>
    </pattern>
    
    <pattern id="nlbpub002">
        <p>
            Sjekk tabeller, og varsle hvis det bare er én kolonne, og b) hvis det er rader der alle td har all tekst plassert i strong. Burde mest sannsynlig vært th-elementer istedenfor
        </p>

        <rule context="html:table">
            <report test="every $tr in descendant::html:tr satisfies count($tr/html:td) eq 1">
                [nlbpub002a] En tabell bør normalt inneholde mer enn én kolonne. Kanskje listemarkup er mer egnet.
            </report>
        </rule>

        <rule context="html:tr[html:td]">
            <report test="every $td in child::html:td satisfies (exists($td/html:strong) and (normalize-space($td) eq normalize-space($td/html:strong)))">[nlbpub002b] Denne raden med td-elementer later til å fungere som kolonneoverskrifter, så th-elementer hadde kanskje vært bedre.</report>
        </rule>        

    </pattern>
    
    

    

</schema>
