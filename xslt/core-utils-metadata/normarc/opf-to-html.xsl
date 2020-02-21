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
    
    <xsl:import href="marcrel.xsl"/>
    
    <xsl:output indent="no" omit-xml-declaration="yes"/>
    
    <xsl:template match="/text()"/>
    
    <xsl:template match="/*">
        <xsl:for-each select="//opf:metadata">
            <xsl:text><![CDATA[    ]]></xsl:text>
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
                
                <xsl:text><![CDATA[
        ]]></xsl:text>
                <meta charset="utf-8"/>
                <xsl:if test="dc:title[1]">
                    <xsl:call-template name="copy-meta">
                        <xsl:with-param name="meta" select="dc:title[1]"/>
                        <xsl:with-param name="rename" select="'title'"/>
                    </xsl:call-template>
                </xsl:if>
                <xsl:text><![CDATA[
        ]]></xsl:text>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <xsl:if test="opf:meta[@property='dc:description.abstract']">
                    <xsl:call-template name="copy-meta">
                        <xsl:with-param name="meta" select="opf:meta[@property='dc:description.abstract'][1]"/>
                        <xsl:with-param name="rename" select="'description'"/>
                    </xsl:call-template>
                </xsl:if>
                
                <xsl:for-each select="(* | comment()) except (dc:title[1], opf:meta[@property='dc:description.abstract'][1])">
                    <xsl:choose>
                        <xsl:when test="self::comment() and (not(preceding-sibling::*) or (preceding-sibling::text() intersect preceding-sibling::*[1]/following-sibling::text())[matches(.,'.*\n.*')])">
                            <xsl:text><![CDATA[
        
        ]]></xsl:text>
                            <xsl:copy-of select="."/>
                        </xsl:when>
                        <xsl:when test="self::*">
                            <xsl:variable name="name" select="(@property, name())[1]"/>
                            <xsl:variable name="name" select="if ($name = 'dc:contributor' and @opf:role) then concat('dc:contributor.',nlb:marcrel-to-role(@opf:role)) else $name"/>
                            
                            <xsl:call-template name="copy-meta">
                                <xsl:with-param name="meta" select="."/>
                                <xsl:with-param name="rename" select="$name"/>
                            </xsl:call-template>
                        </xsl:when>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:text><![CDATA[
    ]]></xsl:text>
            </head>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="copy-meta">
        <xsl:param name="meta" as="element()"/>
        <xsl:param name="rename" as="xs:string?"/>
        
        <xsl:variable name="name" select="if ($rename) then $rename else ($meta/@property, $meta/name())[1]"/>
        
        <xsl:text><![CDATA[
        ]]></xsl:text>
        <xsl:choose>
            <xsl:when test="$name = 'title'">
                <title>
                    <xsl:value-of select="$meta/normalize-space(text())"/>
                </title>
            </xsl:when>
            <xsl:otherwise>
                <meta name="{$name}" content="{$meta/normalize-space(text())}" />
            </xsl:otherwise>
        </xsl:choose>
        <xsl:variable name="comment" select="(if ($meta/following-sibling::*) then $meta/following-sibling::comment() intersect $meta/following-sibling::*[1]/preceding-sibling::comment() else $meta/following-sibling::comment())[1]" as="comment()?"/>
        <xsl:variable name="space" select="string-join($meta/following-sibling::text() intersect $comment/preceding-sibling::text(), '')" as="xs:string"/>
        <xsl:if test="$comment and matches($space, '^ *$')">
            <xsl:text> </xsl:text>
            <xsl:copy-of select="$comment"/>
        </xsl:if>
    </xsl:template>
    
</xsl:stylesheet>