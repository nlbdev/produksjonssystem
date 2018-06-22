<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:epub="http://www.idpf.org/2007/ops"
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="#all"
    version="2.0">
    
    <xsl:output method="xhtml" indent="no" include-content-type="no"/>
    
    <xsl:param name="modified" as="xs:string?"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- root element should start on a new line (not on the same line as the doctype) -->
    <xsl:template match="html[not(preceding-sibling::text()[contains(.,'&#xA;')])]">
        <xsl:text><![CDATA[
]]></xsl:text>
        <xsl:next-match/>
    </xsl:template>
    
    <!-- remove information that is unneccessary or unwanted in the result that is distributed -->
    <xsl:template match="head/comment()"/>
    <xsl:template match="meta[@name='nordic:supplier']"/>
    <xsl:template match="meta[starts-with(@name,'nlbprod:')]" priority="0.5">
        <xsl:if test="starts-with(@name, 'nlbprod:isbn') or starts-with(@name,'nlbprod:identifier')">
            <xsl:copy-of select="." exclude-result-prefixes="#all"/>
        </xsl:if>
    </xsl:template>
    
    <!-- update modification time -->
    <xsl:template match="head">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            <xsl:text><![CDATA[
        ]]></xsl:text>
            <meta name="dcterms:modified" content="{if ($modified) then $modified else format-dateTime(adjust-dateTime-to-timezone(current-dateTime(),xs:dayTimeDuration('PT0H')),'[Y0000]-[M00]-[D00]T[H00]:[m00]:[s00]Z')}"/>
            <xsl:text><![CDATA[
    ]]></xsl:text>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="meta[@name='dcterms:modified']"/>
    
</xsl:stylesheet>