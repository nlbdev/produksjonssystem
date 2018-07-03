<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output method="xhtml" indent="no" include-content-type="no"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h1">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx1 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h2">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx2 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h3">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx3 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h4">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx4 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h5">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx5 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="h6">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:text>xxx6 </xsl:text>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="node() except (h1, h2, h3, h4, h5, h6)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="ol[parent::section/f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            
            <li>
                <a href="#statped_merknad">xxx1 Merknad</a>
            </li>
            
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="li[ancestor::section/f:types(.) = 'toc']">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:value-of select="concat('xxx', count(ancestor-or-self::li), ' ')"/>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:function name="f:types">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type,'\s+')"/>
    </xsl:function>
    
    <xsl:function name="f:classes">
        <xsl:param name="element" as="element()"/>
        <xsl:sequence select="tokenize($element/@epub:type,'\s+')"/>
    </xsl:function>
    
</xsl:stylesheet>
