<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" exclude-result-prefixes="xs m fnk"
    version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
    -->

    <!--
        Dette er en transformasjon som konverterer MathML-markup til en tekststreng med "verbal matematikk":
        Denne strengen plasseres rett etter MathML-markupen i ut-filen.
        
        Alt som ikke er i MathML-namespace overføres uten videre til ut-filen. 
        Det samme gjør altså MatML-markupen.
        Eneste endringer er altså at det genereres en tekst etter matematikken.
    -->

    <!-- Masse nyttig info her:
        https://www.tutorialspoint.com/mathml/index.htm
    -->


    <xsl:include href="funksjoner-og-matematisk-analyse.xsl"/>
    <xsl:include href="grader-og-beslektet-notasjon.xsl"/>
    <xsl:include href="indekser.xsl"/>
    <xsl:include href="piler-og-lignende.xsl"/>
    <xsl:include href="diverse-annen-matematikk.xsl"/>

    <xsl:output method="xhtml" indent="yes" encoding="UTF-8"/>

    <xsl:template match="/">
        <xsl:message>mathml-til-tekst.xsl (2019-01-18)</xsl:message>
        <xsl:apply-templates/>
    </xsl:template>

    <!-- Denne matcher alt vi ikke har noen annen template for,
        så vi mister ingenting.
    -->
    <xsl:template match="*" priority="-10">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

    <!-- Legger inn en egen materelatert css.
        Bør sannsynlgvis fjernes i forbindelse med normal produksjon.
    -->
    <xsl:template match="head">
        <xsl:copy>
            <xsl:apply-templates/>
            <link rel="stylesheet" type="text/css" href="../../mathml-test.css"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="meta[@charset]"/>

    <!-- Legger inn "NY: " foran tittelen, slik at det er lettere å se forskjell.
        Denne templaten MÅ fjernes i forbindelse med normal produksjon
    -->
    <xsl:template match="title | h1[@class eq 'title']">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:text>NY: </xsl:text>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>



    <!-- math-elementet må ha et display-attributt, med verdi "inline" eller "block" -->
    <xsl:template match="m:math[@display eq 'inline']">
        <!-- Vi prosesser MathML videre, 
            noe som egentlig betyr at den kopieres ved hjelp av fallback-templaten over.
        -->
        <xsl:next-match/>
        <!-- Og deretter generer vi verbal matematikk, og plasserer i et span-element -->
        <span class="verbal-matte">
            <xsl:call-template name="generer-verbal-matte"/>
        </span>
    </xsl:template>

    <xsl:template match="m:math[@display eq 'block']">
        <!-- Vi prosesser MathML videre, 
            noe som egentlig betyr at den kopieres ved hjelp av fallback-templaten over.
        -->
        <xsl:next-match/>
        <!-- Og deretter generer vi verbal matematikk, og plasserer i et span-element -->
        <!-- Og sørger for at tekst som opprettes plassere si fornuftig kontainer-element (må sikkert utvide etter hvert -->
        <xsl:choose>
            <xsl:when test="matches(local-name(..), '^(section)$')">
                <p class="verbal-matte">
                    <xsl:call-template name="generer-verbal-matte"/>
                </p>
            </xsl:when>
            <xsl:otherwise>
                <span class="verbal-matte">
                    <xsl:call-template name="generer-verbal-matte"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>


    <!-- Her er startpunktet for alle generering av verbal matematikk -->
    <xsl:template name="generer-verbal-matte">
        <!-- Først samler vi alt i en variabel som inneholder mange tekstnoder ...-->
        <xsl:variable name="verbal-matte" as="xs:string*">
            <!-- NBNB!!!: Merk at prosesseringen skjer i mode "verbal-matte" -->
            <xsl:apply-templates mode="verbal-matte"/>
        </xsl:variable>
        <!-- ... og deretter presenterer vi dette pent og pyntelig -->
        <xsl:value-of select="normalize-space(string-join($verbal-matte, ' '))"/>
    </xsl:template>
    
    <!-- Og her får vi informasjon om all MathML-markup som vi ikke har regler for i nevnte mode  -->
    <xsl:template match="m:*" mode="verbal-matte">
        <xsl:message>Ingen template for denne: <xsl:value-of select="local-name()"/></xsl:message>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>



    <!-- Bare noen funksjoner: -->
    <xsl:function name="fnk:tall" as="xs:string">
        <xsl:param name="tall" as="xs:integer"/>
        <xsl:choose>
            <xsl:when test="$tall eq 1">
                <xsl:text> én </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 2">
                <xsl:text> to </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 3">
                <xsl:text> tre </xsl:text>
            </xsl:when>
            <!-- og så videre -->
            <xsl:otherwise>
                <xsl:value-of select="$tall"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="fnk:ordenstall" as="xs:string">
        <xsl:param name="tall" as="xs:integer"/>
        <xsl:choose>
            <xsl:when test="$tall eq 1">
                <xsl:text> første </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 2">
                <xsl:text> andre </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 3">
                <xsl:text> tredje </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 3">
                <xsl:text> fjerde </xsl:text>
            </xsl:when>
            <!-- og så videre -->
            <xsl:otherwise>
                <xsl:value-of select="$tall"/>
                <xsl:text>. </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:stylesheet>
