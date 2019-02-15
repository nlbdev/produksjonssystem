<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/" xmlns="http://www.daisy.org/z3986/2005/dtbook/"
    exclude-result-prefixes="#all" version="2.0">
    
    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 14.02.2018
    -->
    
    <!-- Bestem hvilket språk som gjelder. Hentes fra Bibliofil, via metadata -->
    <!-- nynorsk -->
    <!--<xsl:variable name="SPRÅK.nn" as="xs:boolean" select="(//meta[@name eq 'dc:Language'][1]/@content eq 'nn-NO')"/>-->
    <xsl:variable name="SPRÅK.nn" as="xs:boolean" select="matches(fnk:hent-metadata-verdi('dc:Language',true(),false()),'^(nn-no|nn)$','i')"/>
    <!-- engelsk, både 'en-GB' og 'en-US' -->
    <!--<xsl:variable name="SPRÅK.en" as="xs:boolean" select="(starts-with(//meta[@name eq 'dc:Language'][1]/@content,'en'))"/>-->
    <xsl:variable name="SPRÅK.en" as="xs:boolean" select="(starts-with(fnk:hent-metadata-verdi('dc:Language',true(),false()),'en'))"/>
    <!-- Og hvis det ikke er en av disse, så er det bokmål -->
    <xsl:variable name="SPRÅK.nb" as="xs:boolean" select="not($SPRÅK.nn or $SPRÅK.en)"/>
    
    <!--<xsl:variable name="språkkode" as="xs:string">
        <xsl:choose>
            <xsl:when test="$SPRÅK.en">
                <xsl:value-of select="'en'"/>
            </xsl:when>
            <xsl:when test="$SPRÅK.nn">
                <xsl:value-of select="'nn'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'nb'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>-->
    
    
    <!-- Analyserer struktur -->
    <xsl:variable name="STRUKTUR.level1" as="element()*"
        select="//body/section[contains(@epub:type, 'bodymatter')]"/>
    <xsl:variable name="STRUKTUR.level1.typer" as="xs:string*"
        select="
        distinct-values(
        for $e in $STRUKTUR.level1
        return
        normalize-space(substring-after($e/@epub:type, 'bodymatter'))
        )"/>
    <xsl:variable name="STRUKTUR.level2" as="element()*"
        select="//body/section[contains(@epub:type, 'bodymatter')]/section"/>
    <xsl:variable name="STRUKTUR.level3" as="element()*"
        select="//body/section[contains(@epub:type, 'bodymatter')]/section/section"/>
    <xsl:variable name="STRUKTUR.har-sidetall" as="xs:boolean"
        select="exists(//*[@epub:type eq 'pagebreak'])"/>
    <xsl:variable name="STRUKTUR.dybde" as="xs:integer"
        select="
        max(for $e in //section
        return
        count($e/ancestor-or-self::section))"/>
    
</xsl:stylesheet>
