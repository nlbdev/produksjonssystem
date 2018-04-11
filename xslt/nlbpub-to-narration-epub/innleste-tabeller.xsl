<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 11.04.2018
    -->

    <!--
        Håndterer tabeller:
        
For innleste fulltekstlydbøker gjør vi følgende:
        ** Legger inn informasjon i et eget p-element før tabellen: "Tabellbeskrivelse"
        ** Legger inn informasjon i et eget p-element etter tabellen: "Tabell slutt"

Det overlates til innleseren å gi ytterligere informasjon om tabellens funksjon og oppbygning, tomme celler og lignende.

    -->

    <xsl:template match="table">

        <!-- Legg inn et p-element før tabellen -->
        <p>
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en">
                    <xsl:text>Table description</xsl:text>
                </xsl:when>
                <xsl:when test="$SPRÅK.nn">
                    <xsl:text>Tabellbeskriving</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>Tabellbeskrivelse</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </p>

        <!-- Så kommer selve tabellen, håndteres som alle andre elementer -->
        <xsl:next-match/>

        <!-- Legg inn et p-element etter tabellen -->
        <p>
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:choose>
                <xsl:when test="$SPRÅK.en"><xsl:text>End of table</xsl:text></xsl:when>
                <xsl:otherwise>
                    <xsl:text>Tabell slutt</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </p>
    </xsl:template>

</xsl:stylesheet>
