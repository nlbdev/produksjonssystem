<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" exclude-result-prefixes="xs m fnk"
    version="2.0">
    
    <!-- 
        (c) 2019 NLB
        
        Gaute Rønningen, 09.09.2019
    -->
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    
    <!-- Funksjoner: -->
    <xsl:function name="fnk:tall" as="xs:string">
        <xsl:param name="tall" as="xs:integer"/>
        <xsl:param name="content" as="node()"/>
        <xsl:choose>
            <xsl:when test="$tall eq 1">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('én', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 2">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('to', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 3">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('tre', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 4">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('fire', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 5">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('fem', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 6">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('seks', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 7">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('sju', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 8">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('åtte', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 9">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('ni', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 10">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('ti', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <!-- og så videre -->
            <xsl:otherwise>
                <xsl:value-of select="$tall"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:function name="fnk:ordenstall" as="xs:string">
        <xsl:param name="tall" as="xs:integer"/>
        <xsl:param name="content" as="node()"/>
        <xsl:choose>
            <xsl:when test="$tall eq 1">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('første', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 2">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('andre', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 3">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('tredje', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 4">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('fjerde', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 5">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('femte', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 6">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('sjette', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 7">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('sjuende', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 8">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('åttende', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 9">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('niende', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 10">
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('tiende', $content)" />
                <xsl:text> </xsl:text>
            </xsl:when>
            <!-- og så videre -->
            <xsl:otherwise>
                <xsl:value-of select="$tall"/>
                <xsl:text>. </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:stylesheet>