<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" exclude-result-prefixes="xs m fnk"
    version="2.0">

    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
        Gaute Rønningen, 09.09.2019
    -->

    <!--
        Dette er en transformasjon som konverterer MathML-markup til en tekststreng med "verbal matematikk":
        Denne strengen plasseres rett etter MathML-markupen i ut-filen.
        
        Alt som ikke er i MathML-namespace overføres uten videre til ut-filen. 
        Det samme gjør altså MathML-markupen.
        Eneste endringer er altså at det genereres en tekst etter matematikken.
        
        Alle tekster (med oversettinger) finns i translations.xsl
        Bruk funksjonen: fnk:translate('translate this', .)
    -->

    <!-- Masse nyttig info her:
        https://www.tutorialspoint.com/mathml/index.htm
    -->

    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    <xsl:import href="utilities.xsl"/>
    
    <!-- Includes: -->
    <xsl:include href="funksjoner-og-matematisk-analyse.xsl"/>
    <xsl:include href="grader-og-beslektet-notasjon.xsl"/>
    <xsl:include href="indekser.xsl"/>
    <xsl:include href="piler-og-lignende.xsl"/>
    <xsl:include href="diverse-annen-matematikk.xsl"/>

    <xsl:output method="xhtml" indent="yes" encoding="UTF-8"/>

    <!-- Sett denne til true() hvis eventuell AsciiMath skal presenteres i utfilen, eller false() -->
    <xsl:param name="inkluder-asciimath" as="xs:boolean" select="false()"/>


    <xsl:template match="/">
        <xsl:message>mathml-til-tekst.xsl (<xsl:value-of  select="current-dateTime()"/>)</xsl:message>
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

    <xsl:template match="meta[@charset]"/>

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
        <xsl:call-template name="vis-asciimath">
            <xsl:with-param name="elementnavn" as="xs:string" select="'span'"/>
        </xsl:call-template>
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
                <xsl:call-template name="vis-asciimath">
                    <xsl:with-param name="elementnavn" as="xs:string" select="'p'"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <span class="verbal-matte">
                    <xsl:call-template name="generer-verbal-matte"/>
                </span>
                <xsl:call-template name="vis-asciimath">
                    <xsl:with-param name="elementnavn" as="xs:string" select="'span'"/>
                </xsl:call-template>
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
        <xsl:value-of select="fnk:translate('formula', .)" />
        <xsl:text> </xsl:text>
        <xsl:value-of select="normalize-space(string-join($verbal-matte, ' '))"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('formula end', .)" />
    </xsl:template>

    <!-- Vis AsciiMath hvis det er noe å vise -->
    <xsl:template name="vis-asciimath">
        <xsl:param name="elementnavn" as="xs:string" required="yes"/>
        <xsl:variable name="ascimath" as="xs:string?"
            select="normalize-space((m:semantics/m:annotation, @alttext)[normalize-space() ne ''][1])"/>
        <xsl:if test="$ascimath and $inkluder-asciimath">
            <xsl:text> </xsl:text>
            <xsl:element name="{$elementnavn}">
                <xsl:attribute name="class" select="'asciimath'"/>
                <xsl:value-of select="$ascimath"/>
            </xsl:element>
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:template>
    <!-- Og her får vi informasjon om all MathML-markup som vi ikke har regler for i nevnte mode  -->
    <xsl:template match="m:*" mode="verbal-matte">
        <xsl:message>
            <xsl:value-of select="fnk:translate('No template found', .)"/>
            <xsl:text> </xsl:text>
            <xsl:value-of select="local-name()"/>
        </xsl:message>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
</xsl:stylesheet>
