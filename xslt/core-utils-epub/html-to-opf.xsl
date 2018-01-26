<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="yes"/>
    
    <xsl:template match="/opf:package">
        <xsl:call-template name="main">
            <xsl:with-param name="opf" select="."/>
            <xsl:with-param name="html" select="document(resolve-uri(opf:manifest/opf:item[@id=current()/opf:spine/opf:itemref/@idref]/@href, base-uri(.)))/html:html"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="main">
        <xsl:param name="opf" as="element()" required="yes"/>
        <xsl:param name="html" as="element()" required="yes"/>
        
        <xsl:for-each select="$opf">
            <xsl:copy exclude-result-prefixes="#all">
                <xsl:copy-of select="@* except @xml:base" exclude-result-prefixes="#all"/>
                <xsl:attribute name="unique-identifier" select="'pub-id'"/>
                
                <metadata>
                    <xsl:variable name="metadata" select="$html/html:head/*[self::html:meta or self::html:title]" as="element()*"/>
                    <dc:identifier id="pub-id">
                        <xsl:value-of select="$metadata[@name='dc:identifier']/@content"/>
                    </dc:identifier>
                    <dc:title>
                        <xsl:value-of select="$metadata[self::html:title]/text()"/>
                    </dc:title>
                    <xsl:for-each select="$metadata[@name and @content and not(@name='dc:identifier')]">
                        <xsl:choose>
                            <xsl:when test="matches(@name,'^dc:[a-z]+$')">
                                <xsl:element name="{@name}">
                                    <xsl:value-of select="@content"/>
                                </xsl:element>
                            </xsl:when>
                            <xsl:when test="@name = 'viewport'"/>
                            <xsl:otherwise>
                                <meta property="{@name}">
                                    <xsl:value-of select="@content"/>
                                </meta>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </metadata>
                
                <xsl:copy-of select="opf:manifest" exclude-result-prefixes="#all"/>
                <xsl:copy-of select="opf:spine" exclude-result-prefixes="#all"/>
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>