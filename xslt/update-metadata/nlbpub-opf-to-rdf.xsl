<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="#"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:schema="http://schema.org/"
                xmlns:dcterms="http://purl.org/dc/terms/"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:template match="/package">
        <xsl:apply-templates select="metadata"/>
    </xsl:template>
    
    <xsl:template match="metadata">
        <xsl:variable name="resource" select="concat('http://websok.nlb.no/cgi-bin/websok?tnr=', (dc:identifier[not(@refines)])[1]/text())"/>
        
        <xsl:variable name="result" as="element()">
            <rdf:RDF>
                <rdf:Description rdf:about="{$resource}">
                    <rdf:type rdf:resource="http://schema.org/Book"/>
                    
                    <xsl:apply-templates select="dc:* | meta[@property]"/>
                </rdf:Description>
            </rdf:RDF>
        </xsl:variable>
        
        <!-- move namespace declarations to the top -->
        <xsl:for-each select="$result">
            <xsl:copy>
                <xsl:copy-of select=".//namespace::*"/>
                <xsl:copy-of select="@*"/>
                <xsl:copy-of select="node()"/>
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="dc:* | meta">
        <xsl:variable name="namespace" select="f:namespace(., tokenize((@property, name())[1],':')[1])" as="xs:string?"/>
        
        <xsl:choose>
            <xsl:when test="$namespace">
                <xsl:element name="{(@property, name())[1]}" namespace="{$namespace}">
                    <xsl:choose>
                        <xsl:when test="@id and ../*/@refines = @id">
                            <xsl:attribute name="schema:name" select="text()"/>
                            <xsl:apply-templates select="../*[@refines = current()/@id]"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="text()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:element>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message select="concat('Unknown namespace prefix: ''', tokenize((@property, name())[1],':')[1], '''')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:function name="f:namespace" as="xs:string?">
        <xsl:param name="element" as="element()"/>
        <xsl:param name="prefix" as="xs:string"/>
        <xsl:variable name="uri" as="xs:string*">
            <xsl:sequence select="namespace-uri-for-prefix($prefix, $element)"/>
            
            <xsl:choose>
                <xsl:when test="$prefix = 'dcterms'">
                    <xsl:sequence select="'http://purl.org/dc/terms/'"/>
                </xsl:when>
                <xsl:when test="$prefix = 'schema'">
                    <xsl:sequence select="'http://schema.org/'"/>
                </xsl:when>
            </xsl:choose>
            
            <xsl:analyze-string select="$element/ancestor::package/@prefix" regex="([^\s]+):\s+([^\s]+)">
                <xsl:matching-substring>
                    <xsl:variable name="opf-prefix" select="replace(., '\s*([^\s]+):\s+([^\s]+)\s*', '$1')"/>
                    <xsl:variable name="opf-uri" select="replace(., '\s*([^\s]+):\s+([^\s]+)\s*', '$2')"/>
                    <xsl:if test="$opf-prefix = $prefix">
                        <xsl:sequence select="$opf-uri"/>
                    </xsl:if>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:value-of select="$uri[1]"/>
    </xsl:function>
    
</xsl:stylesheet>