<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:f="#"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no"/>
    
    <xsl:template match="@* | node()" exclude-result-prefixes="#all" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="section[f:should-unwrap(.)]">
        <xsl:if test="exists(@id) and not(exists(descendant::*/@id)) and //@href = concat('#', @id)">
            <div>
                <xsl:copy-of select="@id"/>
            </div>
        </xsl:if>
        <xsl:apply-templates select="node()"/>
    </xsl:template>
    
    <xsl:template match="@href[starts-with(., '#') and tokenize(., '#')[2] = //section[f:should-unwrap(.)]/@id]">
        <xsl:variable name="target-section" select="//section[@id = tokenize(current(), '#')[2]]" as="element()"/>
        <xsl:variable name="target-id" select="($target-section//*/@id, $target-section/@id)[1]" as="attribute()?"/>
        <xsl:attribute name="href" select="concat('#', $target-id)"/>
    </xsl:template>
    
    <xsl:function name="f:should-unwrap" as="xs:boolean">
        <xsl:param name="section" as="element()"/>
        <xsl:value-of select="exists($section[count(*) le 2 and *[last()][self::figure]])"/>
    </xsl:function>
    
</xsl:stylesheet>