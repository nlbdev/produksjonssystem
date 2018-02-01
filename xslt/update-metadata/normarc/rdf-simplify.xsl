<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:SRU="http://www.loc.gov/zing/sru/"
                xmlns:normarc="info:lc/xmlns/marcxchange-v1"
                xmlns:DIAG="http://www.loc.gov/zing/sru/diagnostics/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:schema="http://schema.org/"
                xmlns:frbr="http://purl.org/vocab/frbr/core#"
                xmlns:nlbbib="http://www.nlb.no/bibliographic"
                xmlns:nlb="http://www.nlb.no/"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:template match="@*">
        <xsl:attribute name="{local-name()}" select="."/>
    </xsl:template>
    
    <xsl:template match="text()"/>
    
    <xsl:template match="rdf:Description[rdf:type]">
        <xsl:element name="{tokenize(rdf:type/@rdf:resource,'/')[last()]}" namespace="">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="rdf:Description/rdf:type"/>
    
    <xsl:template match="*">
        <xsl:element name="{local-name()}" namespace="">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="text()[normalize-space()]">
                <xsl:attribute name="name" select="normalize-space(string-join(text()[normalize-space()],' '))"/>
            </xsl:if>
            <xsl:apply-templates select="node()"/>
        </xsl:element>
    </xsl:template>
    
</xsl:stylesheet>