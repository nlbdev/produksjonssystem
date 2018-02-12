<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <xsl:include href="funksjoner.xsl"/>
    <xsl:include href="metadata.xsl"/>
    <xsl:include href="struktur-etc.xsl"/>
    <xsl:include href="fulltekst-start-og-slutt.xsl"/>
    <xsl:include href="cover.xsl"/>
    <xsl:include href="logg.xsl"/>
    <xsl:include href="lag-synkroniseringspunkter.xsl"/>

    <xsl:output method="xhtml" indent="yes" include-content-type="no"/>

    
    <xsl:template match="/">
        <xsl:message>prepare-for-narration.xsl (0.9.3 / 2018-02-12)</xsl:message>

        <xsl:call-template name="generer-loggfil-hvis-etterspurt"/>

        <xsl:call-template name="varsle-om-manglende-metadata-i-nlbpub"/>

        <xsl:message>* Transformerer ... </xsl:message>

        <!--<xsl:message>TEST: <xsl:value-of select="$metadata.forventet"/></xsl:message>
        <xsl:message>Antall: <xsl:value-of select="count($metadata.forventet)"/></xsl:message>-->

        <!--        <xsl:message>Sidetall i section: <xsl:value-of select="count(//section/div[@class eq 'page-normal'])"/></xsl:message>
        <xsl:message>Sidetall i avsnitt: <xsl:value-of select="count(//section/p/span[@class eq 'page-normal'])"/></xsl:message>-->
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
            <xsl:value-of select="//meta[@name eq 'dc:language'][1]/@content"/>
            <xsl:text>)</xsl:text>
        </xsl:message>

        <xsl:apply-templates></xsl:apply-templates>
        
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
        <!-- Rydde opp litt i metadata, blant annet fjerner en del som ikke lenger er nødvendige -->
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
                <!-- Tar bort all metadata som begynner med 'nlbprod:' -->
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
