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
            
            <xsl:variable name="id" select="if ($preferred-id = '' or //*/@id = $preferred-id) then generate-id() else $preferred-id" as="xs:string"/>
            
            <xsl:text>    </xsl:text>
            <item media-type="{$media-type}" href="{$href}" id="{$id}"/>
            <xsl:text>
    </xsl:text>
        </xsl:copy>
    </xsl:template>
    
</xsl:stylesheet>