<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/" xmlns:nlb="http://www.nlb.no/2018/xml"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">
    
    <!-- 
        (c) 2018 NLB
        
        Denne transformasjonen brukes på XHTML-dokumentet i en NLBPUB-fil for å gjøre dette dokumenetet optimalt for 
        innlesing av fulltekstlydbøker.
        
        Transformasjonen gjør følgende: 
        * Fjerner irelevant metadata
        * Genererer startinformasjon (på bokmål, nynorsk eller engelsk): tittel, lydbokavtalen, info om den trykte boken og info om den tilrettelagte utgaven
        * Hvis XHTML-filen inneholder //element()[fnk:epub-type(@epub:type, 'cover')]: Ta bort opprinnelig cover, og bygg opp et nytt med standardiserte overskrifter
        * Genererer sluttinformasjon (på bokmål, nynorsk eller engelsk): tittel, lydbokavtalen, info om den trykte boken og info om den tilrettelagte utgaven
        
        * Transformasjonen generer også noen meldinger knyttet til om metadata finnes eller ikke, men hvis det blir en generell metadata test tidliger i produksjonssystemet, så kan dette fjernes.
        
        Denne transformasjonen etterfølges av en transformasjon med filen lag-synkrinseringspunkter.xsl.
        
        Per Sennels, 14.02.2018
    -->

    <xsl:include href="funksjoner.xsl"/>
    <xsl:include href="metadata.xsl"/>
    <xsl:include href="struktur-etc.xsl"/>
    <xsl:include href="fulltekst-start-og-slutt.xsl"/>
    <xsl:include href="cover.xsl"/>
    <xsl:include href="logg.xsl"/>
    <!--<xsl:include href="lag-synkroniseringspunkter.xsl"/>-->

    <xsl:output method="xhtml" indent="yes" include-content-type="no"/>

    <xsl:variable name="ID" as="xs:string" select="replace(document-uri(/),'^.+/(.+?)\.xhtml$','$1')"/>
    
    <xsl:variable name="metadata.url" as="xs:string" select="concat(replace(document-uri(.),'^(.+/Arkiv/).+$','$1'),'metadata/',$ID,'/metadata-daisy202.html')"/>

    <xsl:template match="/">
        <xsl:message>prepare-for-narration.xsl (1.0.1 / 2018-03-01)</xsl:message>
        <xsl:message><xsl:text>* ID: </xsl:text><xsl:value-of select="$ID"/></xsl:message>
        <xsl:message><xsl:text>* Henter metadata fra </xsl:text><xsl:value-of select="$metadata.url"/></xsl:message>
        
        <!-- Denne er mest for debugging. Kan kanskje fjernes på sikt, og da kan man slette filen logg.xsl -->
        <xsl:call-template name="generer-loggfil-hvis-etterspurt"/>

        <!-- Hvis metadata testes tisltrekkelig andre steder, og denne transformasjone bare skjer på bøker med tilstrekkelig metadata,
            så kan linjen under slettes, og tilhørenede templates kan fjernes. -->
        <xsl:call-template name="varsle-om-manglende-metadata-i-nlbpub"/>

        <xsl:message>* Transformerer ... </xsl:message>
        

        <xsl:message>
            <xsl:text>* Spraak: </xsl:text>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:text>English (</xsl:text>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:text>Nynorsk (</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Bokmaal (</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="fnk:hent-metadata-verdi('dc:language',true(),false())"/>
            <xsl:text>)</xsl:text>
        </xsl:message>

        <xsl:apply-templates/>

    </xsl:template>

    <xsl:template match="@* | node()" priority="-5" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="comment()">
        <!-- Tar bort alle kommentarer -->
    </xsl:template>

    <xsl:template match="meta">
        <!-- Rydder opp litt i metadata, blant annet fjerner en del som ikke lenger er nødvendige -->
        <xsl:choose>
            <xsl:when
                test="@name eq 'dc:identifier' and exists(//meta[@name eq 'nlbprod:identifier.daisy202.fulltext'])">
                <xsl:copy>
                    <xsl:copy-of select="@name"/>
                    <xsl:copy-of
                        select="//meta[@name eq 'nlbprod:identifier.daisy202.fulltext'][1]/@content"/>
                    <!--                    <xsl:attribute name="content" select="//meta[@name eq 'nlbprod:identifier.daisy202.fulltext'][1]/@content"></xsl:attribute>-->
                </xsl:copy>
            </xsl:when>
            <xsl:when test="@name eq 'nlbprod:identifier.epub'">
                <xsl:copy-of select="."/>
            </xsl:when>
            <xsl:when test="starts-with(@name, 'nlbprod:')">
                <!-- Tar bort all annen metadata som begynner med 'nlbprod:' -->
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="body">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="generer-startinformasjon"/>
            <xsl:if test="//element()[fnk:epub-type(@epub:type, 'cover')]">
                <xsl:call-template name="bygg-opp-cover"/>
            </xsl:if>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="body/section[not(following::section)]">
        <!-- Dette er aller siste section element -->
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
            <!-- Og helt på slutten av det elementet legger vi inn sluttinformasjon -->
            <xsl:call-template name="generer-sluttinformasjon"/>
        </xsl:copy>
    </xsl:template>


</xsl:stylesheet>
