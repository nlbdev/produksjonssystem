<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 07.06.2018
    -->

    <!--
        Noteteksten skal flyttes hvis og bare hvis:
            innholdet består av bare tekst, eventuelt kombinert med et sett med inline-elementer (span[@class eq' pagebreak'] er ett av disse)
            eller
            innholdet består av ett eller flere p-elementer, der innholdet til disse består av bare tekst, eventuelt kombinert med et sett med inline-elementer (span[@class eq' pagebreak'] er ett av disse)
            
        Behandling av notereferansen:
            HVIS noteteksten skal flyttes:
                Sjekk om noteteksten starter med samme tekst som notereferansen, etterfult av mellomrom og stor bokstav:
                    HVIS JA: Plasser teksten "Note " før noteteksten
                    HVIS NEI: Plasser teksten "Note " før teksten i notereferansen, og legg deretter inn noteteksten (men uten eventuelle sidetall)
                Legg inn teksten "Note slutt" (og tilsvarende på nynorsk/engelsk)
                
        Behandling av liste som inneholder notetekster
            HVIS ingen av notene skal flyttes: Prosesser som vanlig
            HVIS alle notene skal flyttes:
                Legg inn et p-element med en passende tekst med informasjon om at notene blir lest der referansen er
                Hent ut eventuelle sidetall fra listen, og plasser disse i et eget p-element
                Ignorer listen
            HVIS noen av notene skal flyttes:
                Legg inn et p-element med en passende tekst med informasjon om at enkelt av notene blir lest der referansen er
                Prosesser listen, med de notetekstene som ikke skal flyttes 
                Hent ut eventuelle sidetall fra listen (også fra notetekst som ikke skal flyttes), og plasser disse i et eget p-element

        ***********************************
            
        Antar følgende:
        
        ** Notereferansen er på formen a[@class eq 'noteref']
        ** Noteteksten er et listepunkt (li-element) som er barn av et ol-element. Listepunktet (altså noten) er på formen li[@class eq 'notebody']
        ** Sideskift kan være hvilket som helst elent, så lenge det har epub:type 'pagebreak'
        
        Avvik fra dette kan medføre uventede komplikasjoner
     
    -->

    <xsl:template match="a[@class eq 'noteref']">
        <xsl:variable name="noten" as="element()"
            select="//*[@id eq substring-after(current()/@href, '#')]"/>

        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>

            <!-- Hvordan notereferansen håndteres er avhengig av om noten skal flyttes eller ikke og av om det er samsvar mellom referansetekst og start på noten -->

            <!-- Rydde opp i, og forenkle dette -->
            <xsl:choose>
                <xsl:when
                    test="
                        fnk:noten-skal-flyttes($noten)
                        and matches(
                        normalize-space(string($noten)),
                        concat('^', normalize-space(current()), '\s\p{Lu}')
                        )">
                    <!-- Noten skal flyttes, og det er samavar, så legg inn "Note ", men dropp notereferansen, ettersom noten begynner med samme tegn -->
                    <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                        <xsl:with-param name="informasjon" as="xs:string" select="'Note '"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <!-- Ikke flytting eller ikke samsvar, så legg inn "Note " etterfulgt av referanse -->
                    <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                        <xsl:with-param name="informasjon" as="xs:string" select="'Note '"/>
                    </xsl:call-template>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>

            <!-- Sjekker om noten skal flyttes til rette etter referansen -->
            <xsl:if test="fnk:noten-skal-flyttes($noten)">
                <!-- Prosesser noten her, men i en spesiell mode for å få vekk uønsket markup og uønskede elementer -->
                <xsl:apply-templates select="$noten" mode="note-etter-referanse"/>
                <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                    <xsl:with-param name="informasjon" as="xs:string">
                        <xsl:choose>
                            <xsl:when test="$SPRÅK.en">
                                <xsl:text>End of note</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>Note slutt</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:if>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="ol[li[@class eq 'notebody']]">
        <xsl:choose>
            <xsl:when
                test="
                    every $li in li[@class eq 'notebody']
                        satisfies not(fnk:noten-skal-flyttes($li))">
                <!-- Ingen av notene skal flyttes til referansen, så prosesser som vanlig -->
<!--                <xsl:message>A: Ingen flyttes</xsl:message>-->
                <xsl:next-match/>
            </xsl:when>
            <xsl:when
                test="
                    every $li in li
                        satisfies ($li[@class eq 'notebody'] and fnk:noten-skal-flyttes($li))">
                <!-- Listen består bare av noter, og alle notene skal flyttes til referansene, så vi trenger ikke listen, men beholder sidetallene, hvis de finnes. Men først; legg inn passende informasjon: -->
<!--                <xsl:message>B: Alle flyttes</xsl:message>-->
                <p>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>Notes are read where they appear in the text.</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.nn">
                            <xsl:text>Notane er lesne der dei opptrer i teksten.</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Notene er lest der de opptrer i teksten.</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </p>
                <xsl:if test="exists(descendant::*[fnk:epub-type(@epub:type, 'pagebreak')])">
                    <p>
                        <xsl:copy-of select="descendant::*[fnk:epub-type(@epub:type, 'pagebreak')]"
                        />
                    </p>
                </xsl:if>

            </xsl:when>
            <xsl:otherwise>
                <!-- Bare noen av listepunktene er noter, eller bare noen av notene skal flyttes, så må prosessere listen, men bare de notepunktene som ikke skal flyttes.
                    Alle sidetallene hentes ut og plasseres i eget avsnitt etter listen. 
                    Listepunkter må prosesseres slik at de ikke tar med sidetall.
                    Men først litt info:
                -->
<!--                <xsl:message>C: Noen flyttes</xsl:message>-->
                <p>
                    <xsl:choose>
                        <xsl:when test="$SPRÅK.en">
                            <xsl:text>Notes are read where they appear in the text, except:</xsl:text>
                        </xsl:when>
                        <xsl:when test="$SPRÅK.nn">
                            <xsl:text>Notane er lesne der dei opptrer i teksten, bortsett frå:</xsl:text>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:text>Notene er lest der de opptrer i teksten, bortsett fra:</xsl:text>
                        </xsl:otherwise>
                    </xsl:choose>
                </p>
                <xsl:apply-templates select="." mode="liste-med-noter"/>
                <xsl:if test="exists(descendant::*[fnk:epub-type(@epub:type, 'pagebreak')])">
                    <p>
                        <xsl:copy-of select="descendant::*[fnk:epub-type(@epub:type, 'pagebreak')]"
                        />
                    </p>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="li[@class eq 'notebody'][fnk:noten-skal-flyttes(.)]" mode="liste-med-noter">
        <!-- Dette matcher noter som skal flyttes til etter referansen, så ignorer dette elementet -->
    </xsl:template>
    
    <!-- Tar bort sideskift fra noten. Denne moden brukes bare dersom det er noter som er flyttet -->
    <xsl:template match="*[fnk:epub-type(@epub:type, 'pagebreak')]" mode="liste-med-noter"/>


    <xsl:template match="p | li[@class eq 'notebody']" mode="note-etter-referanse">
        <!-- Skal ikke ha med disse elementene når noten plasseres etter referansen, men jobb videre med barn -->
        <xsl:apply-templates mode="#current"/>
    </xsl:template>

    <!-- Tar bort sideskift fra noten når den plasseres etter referansen -->
    <xsl:template match="*[fnk:epub-type(@epub:type, 'pagebreak')]" mode="note-etter-referanse"/>

    <xsl:function name="fnk:noten-skal-flyttes" as="xs:boolean">
        <xsl:param name="noten" as="element()"/>

        <xsl:choose>
            <xsl:when
                test="
                    every $child in $noten/descendant::element()
                        satisfies matches(local-name($child), '^(em|strong|sup|sub|i|b|abbr|acronym|code|dfn|span)$')">
                <!-- Bare inline-elementer -->
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:when
                test="
                    every $child in $noten/child::element()
                        satisfies ((local-name($child) eq 'p') and (every $child-of-p in $child/descendant::element()
                            satisfies matches(local-name($child-of-p), '^(em|strong|sup|sub|i|b|abbr|acronym|code|dfn|span)$')))">
                <!-- Alle barn i noten er p-elementer, og disse inneholder på sin side bare tillatte inline-elementer -->
                <xsl:value-of select="true()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="fnk:noten-har-p-som-barn" as="xs:boolean">
        <xsl:param name="noten" as="element()"/>

        <xsl:value-of
            select="
                every $child in $noten/child::element()
                    satisfies local-name($child) eq 'p'"
        />
    </xsl:function>

</xsl:stylesheet>
