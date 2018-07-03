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
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
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
    
    <xsl:template name="create-pagebreak">
        <xsl:variable name="page-number" select="if (@title) then @title else text()"/>
        <xsl:variable name="max-page-number" select="(//div | //span)[f:types(.) = 'pagebreak'][last()]/(if (@title) then @title else text())"/>
        
        <div epub:type="pagebreak">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="title" select="$page-number"/>
            <xsl:value-of select="concat('--- ', $page-number, ' til ', $max-page-number)"/>
        </div>
    </xsl:template>
    
    <xsl:template match="div[f:types(.) = 'pagebreak']">
        <xsl:call-template name="create-pagebreak"/>
    </xsl:template>
    
    <xsl:template match="span[f:types(.) = 'pagebreak']">
        <xsl:if test="not(exists(ancestor::h1 | ancestor::h2 | ancestor::h3 | ancestor::h4 | ancestor::h5 | ancestor::h6 | ancestor::p))">
            <xsl:call-template name="create-pagebreak"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6 | p" priority="10">
        <xsl:for-each select="descendant::span[f:types(.) = 'pagebreak']">
            <xsl:call-template name="create-pagebreak"/>
        </xsl:for-each>
        
        <xsl:next-match/>
    </xsl:template>
    
    <xsl:template match="img">
        <xsl:if test="string-length(@alt) gt 0">
            <p><xsl:value-of select="@alt"/></p>
        </xsl:if>
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
