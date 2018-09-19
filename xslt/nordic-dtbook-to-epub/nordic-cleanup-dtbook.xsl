<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dtbook="http://www.daisy.org/z3986/2005/dtbook/"
                xmlns="http://www.daisy.org/z3986/2005/dtbook/"
                xpath-default-namespace="http://www.daisy.org/z3986/2005/dtbook/"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" include-content-type="no"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:meta[@name='dc:Identifier']">
        <xsl:variable name="test" select="starts-with(@content, 'TEST')" as="xs:boolean"/>
        <xsl:variable name="identifier" select="replace(@content, '[^\d]', '')" as="xs:string"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="content" select="concat(if ($test) then @content else '', $identifier)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dtbook:hd">
        <xsl:variable name="ancestor-headlines" select="ancestor::*/dtbook:*[matches(local-name(),'^h\d$')]"/>
        <xsl:variable name="parent-level" select="if (count($ancestor-headlines)) then max(for $hx in $ancestor-headlines return xs:integer(replace($hx/local-name(), '[^\d]', ''))) else 1" as="xs:integer"/>
        <xsl:variable name="level" select="min((6, $parent-level + 1))" as="xs:integer"/>
        <xsl:element name="h{$level}" namespace="http://www.daisy.org/z3986/2005/dtbook/">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>
