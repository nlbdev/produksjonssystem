<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns:opf="http://www.idpf.org/2007/opf"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no"/>
    
    <xsl:template match="/opf:package">
        <xsl:call-template name="main">
            <xsl:with-param name="opf" select="."/>
            <xsl:with-param name="html" select="document(resolve-uri(opf:manifest/opf:item[@id=current()/opf:spine/opf:itemref/@idref]/@href, base-uri(.)))/html:html"/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="main">
        <xsl:param name="opf" as="node()+" required="yes"/>
        <xsl:param name="html" as="node()+" required="yes"/>
        
        <xsl:param name="opf-root" as="element()" select="$opf[self::*]"/>
        <xsl:param name="html-root" as="element()" select="$html[self::*]"/>
        
        <xsl:for-each select="$opf-root">
            <xsl:text>
</xsl:text>
            <xsl:copy exclude-result-prefixes="#all">
                <xsl:copy-of select="@* except @xml:base" exclude-result-prefixes="#all"/>
                <xsl:attribute name="unique-identifier" select="'pub-id'"/>
                
                <xsl:variable name="metadata" select="$html-root/html:head/node()" as="node()*"/>
                <xsl:text>
    </xsl:text>
                <metadata>
                    <xsl:for-each select="$metadata">
                        <xsl:choose>
                            <xsl:when test="not(self::*)">
                                <!-- whitespace and comments -->
                                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
                            </xsl:when>
                            
                            <xsl:when test="self::html:title">
                                <dc:title>
                                    <xsl:value-of select="."/>
                                </dc:title>
                            </xsl:when>
                            
                            <xsl:when test="not(self::html:meta)">
                                <!-- ignore -->
                            </xsl:when>
                            
                            <xsl:when test="@name = 'viewport'">
                                <!-- discard -->
                            </xsl:when>
                            
                            <xsl:when test="@name = 'dc:identifier'">
                                <dc:identifier id="pub-id">
                                    <xsl:value-of select="@content"/>
                                </dc:identifier>
                            </xsl:when>
                            
                            <xsl:when test="@name = 'description'">
                                <meta property="dc:description.abstract">
                                    <xsl:value-of select="@content"/>
                                </meta>
                            </xsl:when>
                            
                            <xsl:when test="matches(@name, '^dc:[a-z]+$') and exists(@content)">
                                <xsl:element name="{@name}">
                                    <xsl:value-of select="@content"/>
                                </xsl:element>
                            </xsl:when>
                            
                            <xsl:when test="exists(@name) and exists(@content)">
                                <meta property="{@name}">
                                    <xsl:value-of select="@content"/>
                                </meta>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:for-each>
                    <xsl:text>
    </xsl:text>
                </metadata>
                
                <xsl:apply-templates select="opf:manifest">
                    <xsl:with-param name="identifier" select="$metadata[@name='dc:identifier']/string(@content)" as="xs:string" tunnel="yes"/>
                </xsl:apply-templates>
                
                <xsl:text>
    </xsl:text>
                <xsl:copy-of select="opf:spine" exclude-result-prefixes="#all"/>
                <xsl:text>
</xsl:text>
            </xsl:copy>
            <xsl:text>
</xsl:text>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="opf:manifest">
        <xsl:text>
    </xsl:text>
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
            <xsl:apply-templates select="opf:item"/>
            <xsl:text>
    </xsl:text>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="opf:item">
        <xsl:param name="identifier" as="xs:string" tunnel="yes"/>
        <xsl:text>
        </xsl:text>
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:copy-of select="@*" exclude-result-prefixes="#all"/>
            <xsl:if test="../../opf:spine/opf:itemref/@idref = @id">
                <xsl:attribute name="href" select="concat(replace(@href, '[^/]+$', ''), $identifier, '.xhtml')"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>