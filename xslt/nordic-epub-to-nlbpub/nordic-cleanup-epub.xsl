<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:html="http://www.w3.org/1999/xhtml"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no"/>
    
    <xsl:variable name="urls" select="document('url-fix.xml')/*/*" as="element()*"/>
    
    <xsl:template match="@* | node()">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- fix URLs with spaces -->
    <xsl:template match="html:a[@href]" xpath-default-namespace="">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* except @href"/>
            <xsl:variable name="fix" select="($urls[original/text() = normalize-space(current()/@href)])[1]/fixed/text()" as="xs:string?"/>
            <xsl:attribute name="href" select="if ($fix) then $fix else @href"/>
            <xsl:choose>
                <xsl:when test="boolean($fix) and count(node()) = 1 and normalize-space(text()) = normalize-space(@href)">
                    <xsl:value-of select="$fix"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="node()"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="$fix">
                <xsl:message select="concat('Lenken &quot;', @href, '&quot; ble erstattet med &quot;', $fix, '&quot;.')"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>
