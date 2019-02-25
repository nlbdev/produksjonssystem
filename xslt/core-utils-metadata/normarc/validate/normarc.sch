<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
        xmlns:sqf="http://www.schematron-quickfix.com/validator/process"
        queryBinding="xslt2">
    
    <title>Regler for katalogposter i NORMARC</title>
    
    <ns prefix="SRU" uri="http://www.loc.gov/zing/sru/"/>
    <ns prefix="dc" uri="info:sru/schema/1/dc-v1.1"/>
    <ns prefix="normarc" uri="info:lc/xmlns/marcxchange-v1"/>
    <ns prefix="xsi" uri="http://www.w3.org/2001/XMLSchema-instance"/>
    <ns prefix="DIAG" uri="http://www.loc.gov/zing/sru/diagnostics/"/>
    <ns prefix="marcxchange" uri="info:lc/xmlns/marcxchange-v1"/>
    
    <let name="identifier" value="replace(string((//marcxchange:record/marcxchange:controlfield[@tag='001'])[1]), '^[ 0]+', '')"/>
    <let name="is-publication" value="//marcxchange:record/marcxchange:controlfield[@tag='001']/substring(text(),1,1) = ('1','2','3','4','6','7','8','9')"/>
    <let name="is-magazine" value="//marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text() = 'jp' or //marcxchange:datafield[@tag='650']/marcxchange:subfield[@code='a']/text() = 'Tidsskrifter'"/>
    <let name="is-newspaper" value="//marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text() = 'jn' or //marcxchange:datafield[@tag='650']/marcxchange:subfield[@code='a']/text() = 'Avis'"/>
    <let name="is-periodical" value="$is-magazine or $is-newspaper or //marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text() = 'j'"/>
    <let name="isbn-missing" value="//marcxchange:datafield[@tag='598']/marcxchange:subfield[@code='a']/text() = 'Originalutgavens ISBN mangler'"/>
    <let name="issn-missing" value="//marcxchange:datafield[@tag='598']/marcxchange:subfield[@code='a']/text() = 'Originalutgavens ISSN mangler'"/>
    <let name="is-translated" value="boolean(//marcxchange:datafield[@tag='041']/marcxchange:subfield[@code='h']
                                           | //marcxchange:datafield[@tag='574']/marcxchange:subfield[@code='a']
                                           | //marcxchange:datafield[@tag='700']/marcxchange:subfield[@code='e' and text() = 'overs.'])"/>
    <let name="explain-why-translated" value="concat('Boken er oversatt fordi ', string-join((
        if (exists(//marcxchange:datafield[@tag='041']/marcxchange:subfield[@code='h'])) then '`*041$h` finnes' else (),
        if (exists(//marcxchange:datafield[@tag='574']/marcxchange:subfield[@code='a'])) then '`*574$a` finnes' else (),
        if (exists(//marcxchange:datafield[@tag='700']/marcxchange:subfield[@code='e' and text() = 'overs.'])) then 'det finnes en oversetter i `*700`' else ()
    ), ' og '), '.')"/>
    <let name="is-audiobook" value="exists(//marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b' and tokenize(text(),',') = ('dc','dj')])"/>
    <let name="library" value="(//marcxchange:datafield[@tag='850']/marcxchange:subfield[@code='a']/text()/lower-case(.))[1]"/>
    
    
    <!-- Format -->
    <pattern>
        <title>Format for punktskrift</title>
        <rule context="marcxchange:record[starts-with($identifier,'1') and not($library = 'statped')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('za','c')">Utgaver med boknummer som starter med 1 må være markert som punktbok i `*019$b` ('za' for vanlig, eller 'c' for musikktrykk; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Format for lydbok</title>
        <rule context="marcxchange:record[starts-with($identifier,'2') or starts-with($identifier,'6') and not($library = 'statped')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('dc','dj')">Utgaver med boknummer som starter med 2 eller 6 må være markert som lydbok i `*019$b` ('dc' og/eller 'dj'; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Format for e-bok</title>
        <rule context="marcxchange:record[starts-with($identifier,'3') and not($library = 'statped')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('la')">Utgaver med boknummer som starter med 3 må være markert som e-bok i `*019$b` ('la', gjerne med 'ga' i tillegg; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Format for EPUB</title>
        <rule context="marcxchange:record[starts-with($identifier,'5') and not($library = 'statped')]">
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('gt','nb')">Utgaver med boknummer som starter med 5 må være markert som EPUB i `*019$b` ('nb' og/eller 'gt'; var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Format for Statped</title>
        <rule context="marcxchange:record[starts-with($identifier, '86')]">
            <assert test="$library = 'statped'">Utgaver med boknummer som starter med 86 må tilhøre Statped (`*850$a` må inneholde 'StatPed'; var: '<value-of select="$library"/>')</assert>
        </rule>
        <rule context="marcxchange:record[$library = 'statped']">
            <assert test="starts-with($identifier, '86')">Utgaver som tilhører Statped (i følge `*850$a`) må ha boknummer som starter på 86 (var: '<value-of select="$identifier"/>').</assert>
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/tokenize(text(),',') = ('za','c','dc','dj','la','gt','nb')">Alle utgaver må være markert som enten punktbok ('za' for vanlig, 'c' for musikktrykk), lydbok ('dc' og/eller 'dj'), e-bok ('la', gjerne med 'ga' i tillegg), eller EPUB ('nb' og/eller 'gt') (var: '<value-of select="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text()"/>').</assert>
        </rule>
    </pattern>
    
    <!-- Forlag -->
    <pattern>
        <title>Forlag for alle utgaver</title>
        <rule context="marcxchange:record[$is-publication]">
            <assert test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='a']">Utgivelsessted for utgaven må være definert i `*260$a`</assert>
            <assert test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='b']">Forlag for utgaven må være definert i `*260$b`</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Forlag for bøker</title>
        <rule context="marcxchange:record[$is-publication and not($is-periodical)]">
            <assert test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='c']">For bøker må utgivelsesår for utgaven være definert i `*260$c`</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Forlag for periodika</title>
        <rule context="marcxchange:record[$is-publication and $is-periodical]">
            <report test="marcxchange:datafield[@tag='260']/marcxchange:subfield[@code='c']">For periodika må `*260$c` ikke være definert</report>
        </rule>
    </pattern>
    <!-- Merk: Dersom utgave (schema:bookEdition) ikke er definert i `*250$a` så blir den satt til "1" i marcxchange-to-opf.xsl. Derfor krever vi ikke at den er katalogisert her. -->
    
    <pattern>
        <title>Beskrivelse av originalutgaven</title>
        <rule context="marcxchange:record[$is-publication]">
            <report test="count(marcxchange:datafield[@tag='596']) = 0">Informasjon om originalen (forlag, år, sted, ISBN) må være definert i `*596`</report>
            <report test="count(marcxchange:datafield[@tag='596']) gt 1">Informasjon om originalen (forlag, år, sted, ISBN) må være definert i ett `*596`-felt (fant <value-of select="count(marcxchange:datafield[@tag='596'])"/>).</report>
        </rule>
    </pattern>
    <pattern>
        <title>Originalforlag for alle utgaver</title>
        <rule context="marcxchange:record[$is-publication]/marcxchange:datafield[@tag='596']">
            <assert test="marcxchange:subfield[@code='a']">Utgivelsessted for originalen må være definert i `*596$a`</assert>
            <assert test="marcxchange:subfield[@code='b']">Forlag for originalen må være definert i `*596$b`</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Originalforlag for bøker</title>
        <rule context="marcxchange:record[$is-publication and not($is-periodical)]/marcxchange:datafield[@tag='596']">
            <assert test="marcxchange:subfield[@code='c']">For bøker må utgivelsesår for originalen være definert i `*596$c`</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Originalforlag for periodika</title>
        <rule context="marcxchange:record[$is-publication and $is-periodical]/marcxchange:datafield[@tag='596']">
            <report test="marcxchange:subfield[@code='c']">For periodika må `*596$c` ikke være definert</report>
        </rule>
    </pattern>
    <!-- Merk: Dersom utgave for originalen (schema:bookEdition.original) ikke er definert i `*596$d` så blir den satt til "1" i marcxchange-to-opf.xsl. Derfor krever vi ikke at den er katalogisert her. -->
    
    <pattern>
        <title>ISBN og ISSN for periodika</title>
        <rule context="marcxchange:record[$is-periodical]">
            <report test="$is-magazine and $is-newspaper">Et verk kan ikke både være et tidsskrift og en avis. Vennligst kontroller at det ikke er noen konflikt mellom `*019$b` og `*650$a`.</report>
            <report test="not($is-newspaper or $is-magazine)">Et periodika må være enten en avis eller et tidsskrift. Vennligst sjekk `*019$b` og `*650$a`.</report>
            <assert test="marcxchange:datafield[@tag='019']/marcxchange:subfield[@code='b']/text() = ('jp','jn')">Periodika må være definert som avis ("jn") eller tidsskrift ("jp") i `*019$b`.</assert>
        </rule>
    </pattern>
    
    <!-- Spesifikt for originalen -->
    <pattern>
        <title>Original ISBN og ISSN</title>
        <rule context="marcxchange:record[$is-publication and not($isbn-missing) and not($issn-missing)]/marcxchange:datafield[@tag='596']">
            <assert test="marcxchange:subfield[@code='f']">ISBN eller ISSN for originalen må være definert i `*596$f`</assert>
        </rule>
    </pattern>
    <pattern>
        <title>EPUB-nr når originalen mangler ISBN og ISSN</title>
        <rule context="marcxchange:record[$is-publication and $isbn-missing and $issn-missing]">
            <assert test="marcxchange:datafield[@tag='599' and marcxchange:subfield[@code='a']/text()='EPUB-nr' and marcxchange:subfield[@code='b']/text()/matches(.,'^\d+$')]">Når originalens ISBN og ISSN er ukjent, så må det finnes en tag `*599` med "EPUB-nr" i delfelt $a, og boknummeret til EPUBen i delfelt $b.</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Formatering av ISBN og ISSN for originalen (bruk av tegn)</title>
        <rule context="marcxchange:record/marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='f']">
            <assert test="string-length(replace(text(),'[^\dxX-]','')) gt 0">ISBN og ISSN i `*596$f` kan ikke inneholde andre tegn enn tall, "X" og bindestrek (var: '<value-of select="text()"/>').</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Formatering av ISBN for originalen (antall siffer)</title>
        <rule context="marcxchange:record[not($is-periodical)]/marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='f']">
            <assert test="matches(replace(text(),'[^0-9xX]',''), '^(\d{9}|\d{12})[\dxX]$')">ISBN i `*596$f` må bestå av enten 10 eller 13 siffer. Det siste sifferet kan være "X". (var: '<value-of select="text()"/>').
            <value-of select="if (string-length(replace(text(),'[^0-9xX]','')) lt 9) then concat('Dette ser mer ut som et ISSN-nummer enn et ISBN-nummer, men ', $identifier, ' er ikke katalogisert som periodika.') else ''"/></assert>
        </rule>
    </pattern>
    <pattern>
        <title>Formatering av ISSN for originalen (antall siffer)</title>
        <rule context="marcxchange:record[$is-periodical]/marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='f']">
            <assert test="matches(replace(text(),'[^0-9xX]',''), '^\d{7}[\dxX]$')">ISSN i `*596$f` må bestå av 8 siffer (var: '<value-of select="text()"/>').
            <value-of select="if (string-length(replace(text(),'[^0-9xX]','')) ge 9) then concat('Dette ser mer ut som et ISBN-nummer enn et ISSN-nummer, men ', $identifier, ' er katalogisert som periodika.') else ''"/></assert>
        </rule>
    </pattern>
    <pattern>
        <title>Føring av manglende ISBN/ISSN i feil felt</title>
        <rule context="marcxchange:datafield[@tag='596']/marcxchange:subfield[@code='f']">
            <report test="contains(lower-case(text()), 'originalutgaven') or contains(lower-case(text()), 'mangler')">Teksten "Originalutgavens ISBN/ISSN mangler" skal stå i `*598$a`, ikke i `*596$f`.</report>
        </rule>
    </pattern>
    
    <!-- Spesifikt for bøker -->
    <pattern>
        <title>ISBN for bøker</title>
        <rule context="marcxchange:record[$is-publication and not($is-periodical) and not($library = 'statped' and not($is-audiobook))]">
            <assert test="marcxchange:datafield[@tag='020']/marcxchange:subfield[@code='a']">ISBN for utgaven må være definert i `*020$a`.
            <value-of select="if (exists(marcxchange:datafield[@tag='022']/marcxchange:subfield[@code='a'])) then concat('(Det finnes et ISSN-nummer i `*022$a`, men ', $identifier, ' er ikke katalogisert som periodika.') else ''"/></assert>
        </rule>
    </pattern>
    <pattern>
        <title>Formatering av ISBN for bøker (bruk av tegn)</title>
        <rule context="marcxchange:datafield[@tag='020']/marcxchange:subfield[@code='a']">
            <assert test="string-length(replace(text(),'[^\dxX-]','')) gt 0">ISBN i `*020$a` kan ikke inneholde andre tegn enn tall, "X" og bindestrek (var: '<value-of select="text()"/>').</assert>
        </rule>
    </pattern>
    <pattern>
        <title>Formatering av ISBN for bøker (antall siffer)</title>
        <rule context="marcxchange:datafield[@tag='020']/marcxchange:subfield[@code='a']">
            <assert test="matches(replace(text(),'[^0-9xX]',''), '^(\d{9}|\d{12})[\dxX]$')">ISBN i `*020$a` må bestå av enten 10 eller 13 siffer. Det siste sifferet kan være "X" (var: '<value-of select="text()"/>').</assert>
        </rule>
    </pattern>
    
    <!-- Spesifikt for periodika -->
    <pattern>
        <title>ISSN for periodika</title>
        <rule context="marcxchange:record[$is-publication and $is-periodical]/marcxchange:datafield[@tag='022']/marcxchange:subfield[@code='a']">
            <assert test="text() = '0'">Hvis ISSN for utgaven er definert i `*022$a` så må den være "0" (var: <value-of select="text()"/>). Vi har ikke egne ISSN-nummer for våre utgaver som inngår i serier eller periodika. ISSN for originalen katalogiseres i `*596$f`.</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Oversatte utgaver</title>
        <rule context="marcxchange:record[$identifier and $is-translated]">
            <assert test="exists(marcxchange:datafield[@tag='041']/marcxchange:subfield[@code='h']) or starts-with($identifier,'5')">For oversatte utgaver må originalspråk være definert i `*041$h` (med mindre boknummeret starter med "5"). <value-of select="$explain-why-translated"/></assert>
            <assert test="exists(marcxchange:datafield[@tag='574']/marcxchange:subfield[@code='a']) or starts-with($identifier,'5')">For oversatte utgaver må originaltittel være definert i `*574$a`. <value-of select="$explain-why-translated"/></assert>
            <assert test="marcxchange:datafield[@tag='700']/marcxchange:subfield[@code='e']/text() = 'overs.'">For oversatte utgaver må det være definert en oversetter i `*700` ($e må være "overs."). <value-of select="$explain-why-translated"/></assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Avdeling / bibliotek</title>
        <rule context="marcxchange:record[not(starts-with($identifier,'5'))]">
            <assert test="exists(marcxchange:datafield[@tag='850']/marcxchange:subfield[@code='a'])">Avdeling / bibliotek mangler. Dette må være definert i `*850$a` (med mindre boknummeret starter med "5").</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Språk</title>
        <rule context="marcxchange:controlfield[@tag='008' and substring(text(),36,3) = 'mul']">
            <assert test="../marcxchange:datafield[@tag='041']/marcxchange:subfield[@code='a']">For flerspråklige bøker (`*008 POS 35-37` = "mul") så må språkene være definert i `*041$a`.</assert>
        </rule>
    </pattern>
    
    <pattern>
        <title>Alternativ tittel</title>
        <rule context="marcxchange:datafield[@tag='240']">
            <report test="count(marcxchange:subfield[@code='a']) gt 1">Det må ikke være mer enn ett delfelt $a under tagg `*240`.</report>
        </rule>
    </pattern>
    
</schema>
