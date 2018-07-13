<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:dcterms="http://purl.org/dc/terms/"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="opf:package">
        <!-- to avoid SXXP0005 warning -->
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="dc:identifier">
        <xsl:variable name="test" select="starts-with(text(), 'TEST')" as="xs:boolean"/>
        <xsl:variable name="identifier" select="replace(text(), '[^\d]', '')" as="xs:string"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:value-of select="concat(if ($test) then 'TEST' else '', $identifier)"/>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>
