<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:nlb="http://www.nlb.no/2018/xml" xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.nlb.no/2018/xml-elementhierarki" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Denne transformasjonen genererer en "markupoversikt" med utgangspunkt i en XHTML-fil.
        
        Denne markupoversikten består av et sett med element-elementer, for eksempel 
        
            <element>/html/body</element>
            <element>/html/body/section(frontmatter titlepage)</element>
            <element>/html/body/section(frontmatter titlepage)/h1(fulltitle)[title]</element>
            <element>/html/body/section(frontmatter titlepage)/p(z3998:author)[docauthor]</element>
            <element>/html/body/section(bodymatter chapter)</element>
            <element>/html/body/section(bodymatter chapter)/div(pagebreak)[page-normal]</element>
 
        Den komplette listen vil inneholde en oversikt over alle markupkonstruksjoner i en gitt XHTML-fil.
        
        Ved å sammenligne denne listen (for eksempel for en innkommende fil) med en annen liste (for eksempel for en referansefil), 
        så kan man finne ut av hvilke markupkonstruksjoner som finnes i den ene filen og som ikke finnes i den andre.
        
        Denne sammenligningen skjer i transformasjonen 'sammenlign-markupoverikter.xsl', se dokumentasjon i den filen.
        
        Per Sennels, 3.7.2018
    -->
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <xsl:template match="/">
        <xsl:message>generer-markupoversikt.xsl (0.1.0 / 2018-05-18)</xsl:message>
        <xsl:message>
            <xsl:text>* Genererer markupoversikt for </xsl:text>
            <xsl:value-of select="document-uri(/)"/>
        </xsl:message>

        <elementhierarki>
            <xsl:attribute name="time-stamp" select="current-dateTime()"/>
            <xsl:attribute name="basert-på" select="document-uri(/)"/>
            <xsl:for-each select="distinct-values(for $element in //element()(:[not(child::element())]:) return fnk:returner-xpath-for-element($element))">
                <element>
                    <xsl:value-of select="."/>
                </element>
            </xsl:for-each>
        </elementhierarki>
    </xsl:template>

    <xsl:function name="fnk:returner-xpath-for-element" as="xs:string">
        <xsl:param name="element" as="element()"/>

        <xsl:variable name="forelder-og-selv" as="xs:string+"
            select="
                for $fos in $element/ancestor-or-self::*
                return
                    concat(local-name($fos), fnk:returner-epub-type($fos/@epub:type), fnk:returner-klasse($fos/@class))"/>

        <xsl:value-of select="concat('/',string-join($forelder-og-selv, '/'))"/>
    </xsl:function>

    <xsl:function name="fnk:returner-epub-type" as="xs:string*">
        <xsl:param name="epub-type-attributt" as="attribute()?"/>
        
        <xsl:if test="$epub-type-attributt">
            <xsl:variable name="sorterte-typer" as="xs:string+">
                <xsl:perform-sort select="tokenize(normalize-space($epub-type-attributt), '\s')">
                    <xsl:sort/>
                </xsl:perform-sort>
            </xsl:variable>
            <xsl:value-of select="concat('(', string-join($sorterte-typer, ' '), ')')"/>
        </xsl:if>
    </xsl:function>
    
    <xsl:function name="fnk:returner-klasse" as="xs:string*">
        <xsl:param name="class-attributt" as="attribute()?"/>
        
        <xsl:if test="$class-attributt">
            <xsl:variable name="sorterte-verdier" as="xs:string+">
                <xsl:perform-sort select="tokenize(normalize-space($class-attributt), '\s')">
                    <xsl:sort/>
                </xsl:perform-sort>
            </xsl:variable>
            <xsl:value-of select="concat('[', string-join($sorterte-verdier, ' '), ']')"/>
        </xsl:if>
    </xsl:function>
</xsl:stylesheet>
