<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://www.idpf.org/2007/opf"
                xpath-default-namespace="http://www.idpf.org/2007/opf"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xml" exclude-result-prefixes="#all"/>
    
    <xsl:param name="href" as="xs:string"/>
    <xsl:param name="media-type" as="xs:string"/>
    <xsl:param name="preferred-id" as="xs:string" select="''"/>
    
    <xsl:template match="@* | node()" exclude-result-prefixes="#all" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="manifest">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()"/>
            
            <xsl:variable name="id" as="xs:string">
                <xsl:choose>
                    <xsl:when test="$preferred-id != '' and not($preferred-id = //*/@id)">
                        <xsl:value-of select="$preferred-id"/>
                    </xsl:when>
                    <xsl:when test="not(concat('item_', count(/package/manifest/item)) = //*/@id)">
                        <xsl:value-of select="concat('item_', count(*) + 1)"/>
                    </xsl:when>
                    <xsl:when test="not(generate-id(*[last()]) = //*/@id)">
                        <xsl:value-of select="generate-id(*[last()])"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:message select="concat('Could not generate a unique id for manifest item: ', $href)" terminate="yes"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            
            <xsl:text>    </xsl:text>
            <item media-type="{$media-type}" href="{$href}" id="{$id}"/>
            <xsl:text>
    </xsl:text>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>
