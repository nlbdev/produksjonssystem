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
        
        ** Notereferansen er på formen a[@epub:type eq 'noteref']
        ** Noteteksten er et listepunkt (li-element) som er barn av et ol-element. Listepunktet (altså noten) er på formen li[@class eq 'notebody']
        ** Sideskift kan være hvilket som helst elent, så lenge det har epub:type 'pagebreak'
        
        Avvik fra dette kan medføre uventede komplikasjoner
     
    -->

    <xsl:template match="a[tokenize(@epub:type, '\s+') = 'noteref']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>

            <!-- Hvordan notereferansen håndteres er avhengig av om noten skal flyttes eller ikke og av om det er samsvar mellom referansetekst og start på noten -->

            <!-- legg inn "Note " etterfulgt av referansen -->
            <xsl:if test="not(contains(tokenize(lower-case(normalize-space(current())), '\s')[1], 'note'))">
                <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                    <xsl:with-param name="informasjon" as="xs:string" select="'Note '"/>
                </xsl:call-template>
            </xsl:if>
            
            <!-- innholdet i notereferansen -->
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- add "end of note" text -->
    <xsl:template match="*[tokenize(@epub:type, '\s+') = ('note', 'footnote', 'endnote', 'rearnote')]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="note-etter-referanse"/>
            <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                <xsl:with-param name="informasjon" as="xs:string" select="if ($SPRÅK.en) then 'End of note' else 'Note slutt'"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="fnk:is-block" as="xs:boolean">
        <xsl:param name="context" as="element()"/>
        
        <xsl:value-of select="not(fnk:is-inline($context))"/>
    </xsl:function>
    
    <xsl:function name="fnk:is-inline" as="xs:boolean">
        <xsl:param name="context" as="node()?"/>
        
        <xsl:choose>
            <xsl:when test="$context/self::element()">
                <!-- element: check tag name -->
                <xsl:value-of select="$context/local-name() = ('a', 'abbr', 'bdo', 'br', 'code', 'dfn', 'em', 'img', 'kbd', 'q', 'samp', 'span', 'strong', 'sub', 'sup') or $context/self::*[local-name()='math' and @display='inline']"/>
                
            </xsl:when>
            <xsl:when test="$context/self::text()[normalize-space()]">
                <!-- non-empty text node is always inline -->
                <xsl:value-of select="true()"/>
                
            </xsl:when>
            <xsl:when test="$context/self::text()">
                <!-- empty text node depends on surrounding context -->
                <xsl:choose>
                    <xsl:when test="normalize-space($context) = '' and exists($context/../*)">
                        <!-- if it has sibling elements, check the first sibling -->
                        <xsl:value-of select="fnk:is-inline($context/../*[1])"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- otherwise check the parent -->
                        <xsl:value-of select="fnk:is-inline($context/parent::*)"/>
                    </xsl:otherwise>
                </xsl:choose>
                
            </xsl:when>
            <xsl:when test="exists($context/parent::*)">
                <!-- for attributes, comments, processing instructions etc, check the parent (if it exists) -->
                <xsl:value-of select="fnk:is-inline($context/parent::*)"/>
                
            </xsl:when>
            <xsl:otherwise>
                <!-- default to false -->
                <xsl:value-of select="false()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

</xsl:stylesheet>
