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
            <xsl:when test="$tall eq 4">
                <xsl:text> fire </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 5">
                <xsl:text> fem </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 6">
                <xsl:text> seks </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 7">
                <xsl:text> sju </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 8">
                <xsl:text> åtte </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 9">
                <xsl:text> ni </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 10">
                <xsl:text> ti </xsl:text>
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
            <xsl:when test="$tall eq 4">
                <xsl:text> fjerde </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 5">
                <xsl:text> femte </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 6">
                <xsl:text> sjette </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 7">
                <xsl:text> sjuende </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 8">
                <xsl:text> åttende </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 9">
                <xsl:text> niende </xsl:text>
            </xsl:when>
            <xsl:when test="$tall eq 10">
                <xsl:text> tiende </xsl:text>
            </xsl:when>
            <!-- og så videre -->
            <xsl:otherwise>
                <xsl:value-of select="$tall"/>
                <xsl:text>. </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
</xsl:stylesheet>