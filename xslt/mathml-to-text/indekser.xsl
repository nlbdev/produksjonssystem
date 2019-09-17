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
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    <xsl:import href="utilities.xsl"/>
    

    <!-- nedre indeks (tall) etter variabel  -->

    <xsl:template
        match="
            m:msub[
            (: alltid to barn av msub :)
            (local-name(child::element()[1]) eq 'mi') (: første barn er mi :)
            and (matches(normalize-space(child::element()[1]), '^[a-z]$', 'i') or matches(normalize-space(child::element()[1]), '^\p{IsGreek}$')) (: mi er én bokstav i området a til z (eller A-Z) eller en gresk bokstav  :)
            and (local-name(child::element()[2]) eq 'mn') (: andre barn er mn ... :)
            and matches(normalize-space(child::element()[2]), '^\d+$') (: og ... og inneholder bare sifre :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
            
           <msub>
            <mi>[én bokstav i området a-z]</mi>
            <mn>3</mn>
           </msub>
        -->

        <xsl:apply-templates select="m:mi" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with the lower index', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mn" mode="#current"/>
    </xsl:template>

    <!-- nedre indeks (variabel) etter variabel  -->

    <xsl:template
        match="
            m:msub[
            (: alltid to barn av msub :)
            (count(m:mi) eq 2) (: og begge er mi :)
            and (matches(normalize-space(m:mi[1]), '^[a-z]$', 'i') or matches(normalize-space(m:mi[1]), '^\p{IsGreek}$')) (: første mi er én bokstav i området a til z (eller A-Z) eller en gresk bokstav  :)
            and (matches(normalize-space(m:mi[2]), '^[a-z]$', 'i') or matches(normalize-space(m:mi[2]), '^\p{IsGreek}$')) (: første mi er én bokstav i området a til z (eller A-Z) eller en gresk bokstav (altså det samme som over, kan evt forandre på dette) :)
            ]"
        mode="verbal-matte">
        <!-- Signatur:
            
           <msub>
                <mi>[én bokstav i området a-z]</mi>
                <mi>[én bokstav i området a-z]</mi>
           </msub>
        -->

        <xsl:apply-templates select="m:mi[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with the lower index', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="m:mi[2]" mode="#current"/>
    </xsl:template>

    <xsl:template match="m:msubsup[
        (local-name(child::element()[1]) eq 'mi') (: første barn er mi :)
        and (matches(normalize-space(child::element()[1]), '^[a-z]$', 'i') or matches(normalize-space(child::element()[1]), '^\p{IsGreek}$')) (: mi er én bokstav i området a til z (eller A-Z) eller en gresk bokstav  :)
        and (
                (
                    (local-name(child::element()[2]) eq 'mn') (: andre barn er mn ... :)
                    and 
                    matches(normalize-space(child::element()[2]), '^\d+$') (: og ... og inneholder bare sifre :)
                )
                or
                (
                    (local-name(child::element()[2]) eq 'mi') (: eller andre barn er mi ... :)
                    and 
                    (matches(normalize-space(child::element()[2]), '^[a-z]$', 'i') or matches(normalize-space(child::element()[2]), '^\p{IsGreek}$')) (: og inneholder én bokstav i området a til z (eller A-Z) eller en gresk bokstav  :)
                )
            )
            and (local-name(child::element()[3]) eq 'mn') (: tredje barn er mn ... :)
            and matches(normalize-space(child::element()[3]), '^\d+$') (: og ... og inneholder bare sifre :)
            ]" mode="verbal-matte">
        
        <xsl:apply-templates select="m:mi[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('with the lower index', .)" />
        <xsl:text> </xsl:text>
        <xsl:apply-templates select="child::element()[2]" mode="#current"/>
        <!-- hva vi ser etter det er avhengig av det tredje barnet -->
        <xsl:choose>
            <!-- Hvis det opphøyes i to: -->
            <xsl:when test="normalize-space(child::element()[3]) eq '2'">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('squared', .)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <!-- standardform -->
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('in', .)" />
                <xsl:text> </xsl:text>
                <xsl:apply-templates select="child::*[3]" mode="#current"/>
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
