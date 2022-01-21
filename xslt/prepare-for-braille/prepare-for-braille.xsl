<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:param name="force-norwegian" select="'false'"/>
    
    <xsl:output method="xhtml" include-content-type="no" indent="no"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="title/text()">
        <xsl:value-of select="normalize-space()"/>
    </xsl:template>
    
    <xsl:template match="sub | sup">
        <xsl:next-match/> <!-- handle element as normal, this template will conditionally insert whitespace after the element -->
        
        <!-- incrementally increase the search area to improve performance (and readability) -->
        <xsl:variable name="next-text-node" select="following-sibling::node()[1] intersect following-sibling::text()[1]" as="text()*"/> <!-- check first following node -->
        <xsl:variable name="next-text-node" select="if (count($next-text-node) gt 0) then $next-text-node else             (following-sibling::text()[1] | (following-sibling::*//text()[1])[1])" as="text()*"/> <!-- check following nodes and their descendants -->
        <xsl:variable name="next-text-node" select="if (count($next-text-node) gt 0) then $next-text-node else ancestor::*/(following-sibling::text()[1] | (following-sibling::*//text()[1])[1])" as="text()*"/> <!-- check ancestors and their descendants -->
        <xsl:variable name="next-text-node" select="$next-text-node[1]" as="text()?"/> <!-- use the first text node, in case multiple was found -->
        
        <xsl:choose>
            <xsl:when test="count($next-text-node) = 0">
                <xsl:message select="concat('First following text node for ', name(), ' was not found (self::*//text() = ''', string-join(.//text(), ''), ''')')"/>
                <!-- could not foind text node => do nothing -->
            </xsl:when>
            
            <xsl:when test="matches(substring($next-text-node, 1, 1), '\s')">
                <!-- whitespace found at start of next text node => do nothing -->
            </xsl:when>
            
            <xsl:otherwise>
                <!-- insert space after element -->
                <xsl:text> </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="@xml:lang | @lang | meta[@name='dc:language']/@content">
        <xsl:choose>
            <xsl:when test=". = ('nb', 'nn', 'nob', 'nno') or $force-norwegian = 'true'">
                <xsl:attribute name="{name()}" select="'no'" exclude-result-prefixes="#all"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="." exclude-result-prefixes="#all"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
