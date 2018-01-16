<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:nlb="http://www.nlb.no/"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:import href="normarc/marcrel.xsl"/>
    
    <xsl:output indent="yes"/>
    
    <xsl:template match="/*">
        <xsl:for-each select="//opf:metadata">
            <head>
                <!-- Copy namespaces from @prefix -->
                <xsl:if test="ancestor-or-self::*/@prefix">
                    <xsl:analyze-string select="ancestor-or-self::*/@prefix" regex="([^\s]+:\s+[^\s]+)">
                        <xsl:matching-substring>
                            <xsl:variable name="prefix" select="substring-before(.,':')"/>
                            <xsl:variable name="namespace" select="replace(.,'^[^:]*:\s*','')"/>
                            <xsl:namespace name="{$prefix}" select="$namespace"/>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:if>
                
                <!-- Declare predefined EPUB metadata namespaces -->
                
                <xsl:for-each select="distinct-values(*/substring-before((@property, name())[1],':'))">
                    <xsl:message select="."/>
                    <xsl:variable name="prefix" select="."/>
                    <xsl:choose>
                        <xsl:when test="$prefix = 'dc'"><xsl:namespace name="{$prefix}" select="'http://purl.org/dc/elements/1.1/'"/></xsl:when>
                        <xsl:when test="$prefix = 'a11y'"><xsl:namespace name="{$prefix}" select="'http://www.idpf.org/epub/vocab/package/a11y/#'"/></xsl:when>
                        <xsl:when test="$prefix = 'dcterms'"><xsl:namespace name="{$prefix}" select="'http://purl.org/dc/terms/'"/></xsl:when>
                        <xsl:when test="$prefix = 'epubsc'"><xsl:namespace name="{$prefix}" select="'http://idpf.org/epub/vocab/sc/#'"/></xsl:when>
                        <xsl:when test="$prefix = 'marc'"><xsl:namespace name="{$prefix}" select="'http://id.loc.gov/vocabulary/'"/></xsl:when>
                        <xsl:when test="$prefix = 'media'"><xsl:namespace name="{$prefix}" select="'http://www.idpf.org/epub/vocab/overlays/#'"/></xsl:when>
                        <xsl:when test="$prefix = 'onix'"><xsl:namespace name="{$prefix}" select="'http://www.editeur.org/ONIX/book/codelists/current.html#'"/></xsl:when>
                        <xsl:when test="$prefix = 'rendition'"><xsl:namespace name="{$prefix}" select="'http://www.idpf.org/vocab/rendition/#'"/></xsl:when>
                        <xsl:when test="$prefix = 'schema'"><xsl:namespace name="{$prefix}" select="'http://schema.org/'"/></xsl:when>
                        <xsl:when test="$prefix = 'xsd'"><xsl:namespace name="{$prefix}" select="'http://www.w3.org/2001/XMLSchema#'"/></xsl:when>
                    </xsl:choose>
                </xsl:for-each>
                
                <meta charset="utf-8"/>
                <title><xsl:value-of select="dc:title[1]"/></title>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <xsl:if test="dc:description.abstract">
                    <meta name="description" content="{dc:description.abstract[1]}"/>
                </xsl:if>
                
                <xsl:text><![CDATA[
]]></xsl:text>
                
                <xsl:for-each select="node() except (dc:title[1], dc:description.abstract[1])">
                    <xsl:choose>
                        <xsl:when test="self::*">
                            <xsl:variable name="name" select="(@property, name())[1]"/>
                            <xsl:variable name="name" select="if ($name = 'dc:contributor' and @opf:role) then concat('dc:contributor.',nlb:marcrel-to-role(@opf:role)) else $name"/>
                            
                            <meta name="{$name}" content="{text()}"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:copy-of select="."/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </head>
        </xsl:for-each>
    </xsl:template>
    
</xsl:stylesheet>