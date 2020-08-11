<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/" xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
    xmlns="http://www.daisy.org/z3986/2005/dtbook/" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 15.01.2019
    -->

    <!--
        Håndterer tabeller:
        
For innleste fulltekstlydbøker gjør vi følgende:
        ** Legger inn informasjon i et eget p-element før tabellen: "Tabellbeskrivelse"
        ** Legger inn informasjon i et eget p-element etter tabellen: "Tabell slutt"

Det overlates til innleseren å gi ytterligere informasjon om tabellens funksjon og oppbygning, tomme celler og lignende.

.....................................

For TTS-baserte fulltekstlydbøker gjør vi følgende.
        ** Legger inn informasjon i et eget p-element før tabellen: "Her følger en tabell med [x] kolonner og [y] rader."
        ** Legger inn informasjon i et eget p-element etter tabellen: "Tabell slutt"

I tillegg legges følgende inn som "usynlig" informasjon, det vil si informasjon som via class-attributt og css får stilen "display:none;". Slik tekst vil medføre at TTS-generatoren genererer tale, men teksten vil ikke vises.

 * caption-elementet: Legg inn "Tabelloverskrift: " før øvrig tekst i elementet.
 * th-elementer:
    ** (A) hvis barn av første tr-element OG alle andre barn av dette tr-elementet også er th-elementer OG det ikke finnes andre th-elementer enn disse i tabellen:
        *** hvis første th-element i tr-elementet og antall th-elementer er forskjellig fra antall kolonner i tabellen: Legg inn teksten "Kolonneoverskrift: " (hvis bare én kolonne) ELLER "Kolonneoverskrifter: " (flere kolonner) som tilleggsinformasjon
        *** hvis første th-element i tr-elementet og antall th-elementer er lik antall kolonner i tabellen: Legg inn teksten "Kolonneoverskrift: " (hvis bare én kolonne) ELLER "Kolonneoverskrifter: Kolonne 1: " (flere kolonner) som tilleggsinformasjon
        *** hvis ikke første th-element i tr-elementet og antall th-elementer er forskjellig fra antall kolonner i tabellen: Ingen tillegsinformasjon
        *** hvis ikke første th-element i tr-elementet og antall th-elementer er lik antall kolonner i tabellen: Legg inn teksten "Kolonne [n]: " (flere kolonner) som tilleggsinformasjon
        *** det andre tr-elementet regnes som første rad
    ** hvis ikke kravet (A) over er oppfylt:
        *** det første tr-elementet regnes som første rad
        *** hvis første th-element i tr-elementet: Legg inn teksten "Rad [n]: " som tilleggsinformasjon
* td-elementer:
    ** hvis første td-element i tr-elementet: Legg inn teksten "Rad [n]: " som tilleggsinformasjon (B)
    ** Hvis (A) over OG hvert th-element bare inneholder ett enkelt ord OG td-elementet ikke spenner over flere kolonner: Legg inn korrekt kolonneovrerskift som tilleggsinformasjon: "Rad [n]: [overskrift]: " (hvis første td i tr) eller "[overskrift]: " (hvis ikke)
    ** Hvis td-elementet spenner over flere kolonner:
        *** Hvis td-spenner over alle kolonner: Bare rad-annonsering som beskrevet i (B) over
        *** Hvis td-spenner over to kolonner: "Celle som spenner over kolonne [x] og [y]: ", eventuelt i etterkant av rad-annonsering som beskrevet i (B) over, som tilleggsinformasjon. (C1)
        *** Hvis td-spenner over flere kolonner: "Celle som spenner over kolonne [x] til [y]: ", eventuelt i etterkant av rad-annonsering som beskrevet i (B) over, som tilleggsinformasjon. (C2)
    ** Hvis normalisert tekst i td-elementet er en tom streng: Legg inn "Tom celle", eventuelt i etterkant av (B) og (C) over,  som tilleggsinformasjon.
    
 ................... (samme info som over, men mer prosa) 

    Hvis første tr-element bare består av th-elementer, skal det første th-elementet få følgende tekst i forkant av den originale teksten: "Kolonneoverskrifter: Kolonne 1: ". De øvrige th-elementene skal få teksten "Kolonne 2: ", "Kolonne 3: " og så videre.
    Raden under blir i så fall å regne som første rad.

    Dersom første tr-element ikke bare består av th-elementer, skal første tr-element regnes som første rad, og første th- eller td-element i tr-elementet skal få teksten "Rad 1: " plassert før øvrig tekst i elementet.

    For andre rader gjelder at vi, for første th- eller td-element i tr-elementet, legger inn teksten "Rad [n]: " før elementets innhold, og også før en eventuell nedtrukket kolonneoverskrift.

    Dersom alle elementer i første tr-elementer er th-elementer, og dersom all disse th-elementene bare består av ett ord, så skal disse overskriftene trekkes ned til hver celle og plasseres før teksten i td-elementet.
    Dette gjelder bare for td-elementer som ikke spenner over flere kolonner.

    Dersom et td-element er tomt, skal det legges inn teksten "Tom celle", muligens med kolonneoverskrift og/eller rad-annonsering foran.

    For celler som spenner over flere kolonner, altså med @colspan gt 1, så skal følgende skje:
        ** kolonneoverskrifter skal ikke trekkes ned
        ** hvis cellene spenner over alle kolonnene, så skal bare celleteksten utvides med radannonsering i forkant.
        ** hvis cellen spenner over to kolonner, skal følgende tekst plasseres i forkant av original tekst: "Celle som spenner over kolonne [x] og [y]: "
        ** hvis cellen spenner over flere enn to kolonner, skal følgende tekst plasseres i forkant av original tekst: "Celle som spenner over kolonne [x] til [z]: "
   -->

    <xsl:template match="table">
        <xsl:variable name="antall-rader" as="xs:integer" select="count(descendant::tr)"/>
        <xsl:variable name="antall-kolonner" as="xs:integer"
            select="
                max(for $rad in descendant::tr
                return
                    (count($rad/element()[not(@colspan)]) + sum($rad/element()/@colspan))) idiv 1"/>

        <xsl:variable name="elementer-i-første-rad" as="element()+"
            select="descendant::tr[1]/element()"/>
        <xsl:variable name="bare-th-i-første-rad" as="xs:boolean"
            select="
                every $t in $elementer-i-første-rad
                    satisfies local-name($t) eq 'th'"/>
        <xsl:variable name="alle-th-er-i-første-rad" as="xs:boolean" select="count(descendant::tr[1]/th) eq count(descendant::th)"/>
        <!-- Legg inn et p-element før tabellen -->
        <p>
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:text>Here is a table with </xsl:text>
                    <xsl:choose>
                        <xsl:when test="$antall-kolonner eq 1">
                            <xsl:text>one column and </xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$antall-kolonner"/>
                            <xsl:text> columns and </xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="$antall-rader eq 1">
                            <xsl:text>one row.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$antall-rader"/>
                            <xsl:text> rows</xsl:text>
                            <xsl:choose>
                                <xsl:when test="$alle-th-er-i-første-rad and $bare-th-i-første-rad">
                                    <!-- Vi har kolonneoverskrifter i tabellen -->
                                    <xsl:text>, including one row with column headings.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:text>Her følgjer ein tabell med </xsl:text>
                    <xsl:choose>
                        <xsl:when test="$antall-kolonner eq 1">
                            <xsl:text>ein kolonne og </xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$antall-kolonner"/>
                            <xsl:text> kolonnar og </xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="$antall-rader eq 1">
                            <xsl:text>ei rad.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$antall-rader"/>
                            <xsl:text> rader</xsl:text>
                            <xsl:choose>
                                <xsl:when test="$alle-th-er-i-første-rad and $bare-th-i-første-rad">
                                    <!-- Vi har kolonneoverskrifter i tabellen -->
                                    <xsl:text>, inkludert ei rad med kolonneoverskrifter.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Her følger en tabell med </xsl:text>
                    <xsl:choose>
                        <xsl:when test="$antall-kolonner eq 1">
                            <xsl:text>én kolonne og </xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$antall-kolonner"/>
                            <xsl:text> kolonner og </xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="$antall-rader eq 1">
                            <xsl:text>én rad.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$antall-rader"/>
                            <xsl:text> rader</xsl:text>
                            <xsl:choose>
                                <xsl:when test="$alle-th-er-i-første-rad and $bare-th-i-første-rad">
                                    <!-- Vi har kolonneoverskrifter i tabellen -->
                                    <xsl:text>, inkludert én rad med kolonneoverskrifter.</xsl:text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:text>.</xsl:text>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </p>

        <!-- Så kommer selve tabellen, håndteres som alle andre elementer (men med tunnelparametre som kan plukkes opp der det passer) -->
        <xsl:next-match>
            <xsl:with-param name="alle-th-er-i-første-rad" as="xs:boolean" tunnel="yes"
                select="$alle-th-er-i-første-rad"/>
            <xsl:with-param name="bare-th-i-første-rad" as="xs:boolean"
                select="$bare-th-i-første-rad" tunnel="yes"/>
            <xsl:with-param name="antall-th-i-første-rad-er-lik-antall-kolonnner" as="xs:boolean"
                select="count(descendant::tr[1]/th) eq $antall-kolonner" tunnel="yes"/>
            <xsl:with-param name="antall-kolonner" as="xs:integer" select="$antall-kolonner"
                tunnel="yes"/>
            <xsl:with-param name="kolonneoverskrifter" as="element()+"
                select="$elementer-i-første-rad" tunnel="yes"/>
        </xsl:next-match>

        <!-- Legg inn et p-element etter tabellen -->
        <p>
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:text>End of table</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Tabell slutt</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </p>
    </xsl:template>

    <xsl:template match="table/caption">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                <xsl:with-param name="informasjon" as="xs:string">
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:value-of select="'Table heading: '"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="'Tabelloverskrift: '"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:with-param>
            </xsl:call-template>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tr[1]/th">
        <xsl:param name="alle-th-er-i-første-rad" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:param name="bare-th-i-første-rad" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:param name="antall-th-i-første-rad-er-lik-antall-kolonnner" as="xs:boolean"
            select="false()" tunnel="yes"/>


        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>

            <!-- Forsøker å bygge opp en streng med tilleggsinformasjon (og vi vet at dette er th-elementer i 1. rad -->
            <xsl:variable name="info" as="xs:string?">
                <xsl:variable name="temp" as="xs:string*">
                    <xsl:choose>
                        <xsl:when test="$alle-th-er-i-første-rad and $bare-th-i-første-rad">
                            <!-- Alle th-elementer er samlet her i første rad, så de er kolonneoverskrifter -->
                            <xsl:if
                                test="not(exists(preceding-sibling::th) or exists(following-sibling::th))">
                                <!-- Dette er første og eneste th, så vi bruker entall -->
                                <xsl:choose>
                                    <xsl:when test="$SPRÅK.en">
                                        <xsl:value-of select="'Column heading :'"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="'Kolonneoverskrift: '"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:if>
                            <xsl:if
                                test="not(exists(preceding-sibling::th)) and exists(following-sibling::th)">
                                <!-- Dette er det første av flere th-elementer, så vi bruker flertall -->
                                <xsl:choose>
                                    <xsl:when test="$SPRÅK.en">
                                        <xsl:value-of select="'Column headings :'"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="'Kolonneoverskrifter: '"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:if>
                            <!-- Og hvis det er én kolonneoverskrift per kolonne (det vil at det ikke brukes @colspan), så kan vi i tillegg nummerere dem (men bare hvis dette ikke er eneste th; da er det jo ikke noe poeng.-->
                            <xsl:if
                                test="$antall-th-i-første-rad-er-lik-antall-kolonnner and (exists(preceding-sibling::th) or exists(following-sibling::th))">
                                <xsl:choose>
                                    <xsl:when test="$SPRÅK.en">
                                        <xsl:value-of
                                            select="concat('Column ', count(preceding-sibling::th) + 1, ': ')"
                                        />
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of
                                            select="concat('Kolonne ', count(preceding-sibling::th) + 1, ': ')"
                                        />
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:if>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- Alle th-elementer er IKKE samlet her i første rad, så vi kan ikke anta så mye -->
                            <xsl:if test="not(exists(preceding-sibling::element()))">
                                <!-- Men vi kan informere om at dette er første rad, og det informerer vi om hvis det er første celle i raden-->
                                <xsl:choose>
                                    <xsl:when test="$SPRÅK.en">
                                        <xsl:value-of select="'Row 1: '"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="'Rad 1: '"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:if>
                        </xsl:otherwise>
                    </xsl:choose>

                    <xsl:call-template name="håndter-colspan-og-tom-celle"/>
                </xsl:variable>
                <xsl:value-of select="string-join($temp, '')"/>
            </xsl:variable>

            <!-- Legg inn tilleggsinformasjon hvis det er noe -->
            <xsl:if test="$info ne ''">
                <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                    <xsl:with-param name="informasjon" as="xs:string" select="$info"/>
                </xsl:call-template>
            </xsl:if>

            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="th | td">
        <xsl:param name="alle-th-er-i-første-rad" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:param name="bare-th-i-første-rad" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:param name="antall-th-i-første-rad-er-lik-antall-kolonnner" as="xs:boolean"
            select="false()" tunnel="yes"/>
        <xsl:param name="kolonneoverskrifter" as="element()+" tunnel="yes"/>

        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>

            <!-- Bygge opp tilleggsinformasjon -->
            <xsl:variable name="info" as="xs:string?">
                <xsl:variable name="temp" as="xs:string*">
                    <xsl:if test="not(exists(preceding-sibling::element()))">
                        <!-- Dette er første celle i raden, så vi må annonsere raden -->
                        <xsl:variable name="radnummer" as="xs:integer">
                            <xsl:choose>
                                <xsl:when test="$alle-th-er-i-første-rad and $bare-th-i-første-rad">
                                    <!-- Første rad er overskriftsrad, så den skal vi ikke regne med -->
                                    <xsl:value-of select="count(../preceding-sibling::tr)"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <!-- Vi regner med første rad også, så vi plusser på 1 -->
                                    <xsl:value-of select="count(../preceding-sibling::tr) + 1"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:variable>
                        <xsl:choose>
                            <xsl:when test="$SPRÅK.en">
                                <xsl:value-of select="concat('Row ', $radnummer, ': ')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat('Rad ', $radnummer, ': ')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>

                    <!-- Skal vi trekke ned kolonneoverskrift? -->
                    <!-- 
                    20180423:   Kravet om ett ord i overskriften er byttet ut med et krav om maks 5 ord og maks 30 tegn
                                Lagt inn krav om at det må være mer enn én kolonne (ellers er det ikke noe poeng)
                    -->
                    <xsl:if
                        test="
                            count($kolonneoverskrifter) ge 2 (: bare hvis det er mer enn én kolonne :)
                            and $alle-th-er-i-første-rad (: bare hvis det ikke finnes andre th enn de i første rad :)
                            and $bare-th-i-første-rad (: bare hvis det ikke finnes annet enn th i første rad :)
                            and $antall-th-i-første-rad-er-lik-antall-kolonnner (: bare hvis det er én th per kolonne :)
                            and (every $e in $kolonneoverskrifter
                                satisfies count(tokenize(normalize-space($e), '\s')) le 5) (: bare hvis hver eneste kolonneoverskrift er maks fem ord ord :)
                            and (every $e in $kolonneoverskrifter
                                satisfies string-length(translate(normalize-space($e),' .,:;?+!%()=#$','')) le 30) (: bare hvis hver eneste kolonneoverskrift er maks 30 'normale' tegn :)
                            and (not(exists(@colspan)) or xs:integer(@colspan) eq 1) (: og bare hvis gjeldende celle ikke spenner over flere kolonner :)
                            ">
                        <xsl:variable name="cellenummer" as="xs:integer"
                            select="count(preceding-sibling::element()[not(@colspan)]) + xs:integer(sum(preceding-sibling::element()/@colspan)) + 1"/>
                        <xsl:value-of
                            select="concat(normalize-space($kolonneoverskrifter[position() eq $cellenummer]), ': ')"
                        />
                    </xsl:if>

                    <xsl:call-template name="håndter-colspan-og-tom-celle"/>
                </xsl:variable>
                <xsl:value-of select="string-join($temp, '')"/>
            </xsl:variable>

            <!-- Legg inn tilleggsinformasjon hvis det er noe -->
            <xsl:if test="$info ne ''">
                <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                    <xsl:with-param name="informasjon" as="xs:string" select="$info"/>
                </xsl:call-template>
            </xsl:if>

            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

    <xsl:template name="håndter-colspan-og-tom-celle">
        <xsl:param name="antall-kolonner" as="xs:integer" tunnel="yes"/>

        <!-- @colspan? -->
        <xsl:if test="@colspan">
            <xsl:variable name="fra" as="xs:integer"
                select="count(preceding-sibling::element()[not(@colspan)]) + xs:integer(sum(preceding-sibling::element()/@colspan)) + 1"/>
            <xsl:variable name="til" as="xs:integer" select="$fra + xs:integer(@colspan) - 1"/>

            <xsl:choose>
                <xsl:when test="@colspan eq '1'">
                    <!-- Uinteressant -->
                </xsl:when>
                <xsl:when test="@colspan eq string($antall-kolonner)">
                    <!-- Vi informerer ikke dersom cellen dekker alle kolonner, ettersom lytteren uansett får vite det (på grunn av annonsering av neste rad eller tabell slutt) -->
                </xsl:when>
                <xsl:when test="@colspan eq '2'">
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:value-of
                                select="concat('Cell which spans columns ', $fra, ' and ', $til, ': ')"
                            />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of
                                select="concat('Celle som spenner over kolonne ', $fra, ' og ', $til, ': ')"
                            />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:value-of
                                select="concat('Cell which spans columns ', $fra, ' to ', $til, ': ')"
                            />
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of
                                select="concat('Celle som spenner over kolonne ', $fra, ' til ', $til, ': ')"
                            />
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>

        <!-- Tom celle? -->
        <xsl:if test="normalize-space() eq ''">
            <!-- Cellen er tom, så informer om det -->
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:value-of select="'Empty cell'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'Tom celle'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>

    </xsl:template>
</xsl:stylesheet>
