<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:f="#"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no" exclude-result-prefixes="#all"/>
    
    <xsl:template match="@* | node()" mode="#all" priority="-1">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="/*" name="main">
        <xsl:param name="nav" select="/*" as="element()" required="no"/>
        <xsl:param name="test-collection" select="()" required="no"/>
        
        <xsl:for-each select="$nav">
            <xsl:copy exclude-result-prefixes="#all">
                <xsl:apply-templates select="@* | node()">
                    <xsl:with-param name="test-collection" select="$test-collection" tunnel="yes"/>
                </xsl:apply-templates>
            </xsl:copy>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="li[contains(a/@href, '-cover.xhtml')]">
        <xsl:param name="test-collection" as="element()*" tunnel="yes"/>
        
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="a"/>
            
            <xsl:variable name="cover-href" select="substring-before(a/@href, '#')"/>
            <xsl:variable name="cover-id" select="substring-after(a/@href, '#')"/>
            <xsl:variable name="cover" select="f:document(resolve-uri($cover-href, base-uri()), $test-collection)"/>
            <xsl:variable name="cover-structure">
                <ol>
                    <xsl:apply-templates select="$cover//*[@id = $cover-id]/(* | following-sibling::*)" mode="coverfix">
                        <xsl:with-param name="cover-href" select="$cover-href" as="xs:string" tunnel="yes"/>
                    </xsl:apply-templates>
                </ol>
            </xsl:variable>
            <xsl:apply-templates select="$cover-structure" mode="remove-empty-lists"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@*" mode="coverfix"/>
    <xsl:template match="node()" mode="coverfix">
        <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:template>
    
    <xsl:template match="section | aside" mode="coverfix">
        <xsl:param name="cover-href" as="xs:string" tunnel="yes"/>
        <li>
            <xsl:variable name="headline" select="(h1, h2, h3, h4, h5, h6)[1]"/>
            <a href="{$cover-href}#{if (@id) then @id else $headline/@id}">Section</a>
            <ol>
                <xsl:apply-templates select="*" mode="#current">
                    <xsl:with-param name="href" select="$cover-href" as="xs:string" tunnel="yes"/>
                </xsl:apply-templates>
            </ol>
        </li>
    </xsl:template>
    
    <xsl:template match="ol[not(*)]" mode="remove-empty-lists"/>
    
    <xsl:function name="f:document" as="element()?">
        <xsl:param name="href" as="xs:string"/>
        <xsl:param name="test-collection" as="element()*"/>
        <xsl:choose>
            <xsl:when test="count($test-collection) gt 0">
                <xsl:sequence select="$test-collection[base-uri() = $href]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="document($href)/*"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
</xsl:stylesheet>
