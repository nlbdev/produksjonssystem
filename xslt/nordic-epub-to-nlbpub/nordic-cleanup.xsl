<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- remove header (remnant from DTBook doctitle/docauthor) -->
    <xsl:template match="body/header"/>
    
    <!-- make sure that there are id attributes on all headlines -->
    <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="not(@id)">
                <xsl:attribute name="id" select="generate-id()"/>
            </xsl:if>
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="html:meta[@name='dc:identifier']">
        <xsl:variable name="test" select="starts-with(@content, 'TEST')" as="xs:boolean"/>
        <xsl:variable name="identifier" select="replace(@content, '[^\d]', '')" as="xs:string"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="content" select="concat(if ($test) then 'TEST' else '', $identifier)"/>
        </xsl:copy>
    </xsl:template>
    
    
    <xsl:template match="html:meta[@name='dtb:uid']"/>
    
</xsl:stylesheet>
