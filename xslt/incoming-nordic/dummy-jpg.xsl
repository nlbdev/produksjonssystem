<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:epub="http://www.idpf.org/2007/ops"
                xmlns:f="#"
                xmlns="http://www.w3.org/1999/xhtml"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="#all"
                version="2.0">
    
    <xsl:output indent="no" method="xhtml" include-content-type="no" exclude-result-prefixes="#all"/>
    
    <xsl:template match="@* | node()" mode="#all">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@src | @href | @data[parent::object] | @altimg | @longdesc">
        <xsl:choose>
            <xsl:when test="not(starts-with(., 'images/'))">
                <!-- does not reference an image in the "images" directory -->
                <xsl:next-match/>
                
            </xsl:when>
            <xsl:when test="contains(., '/cover.jpg')">
                <!-- don't delete references to the cover file -->
                <xsl:next-match/>
                
            </xsl:when>
            <xsl:when test="contains(., '#')">
                <xsl:attribute name="{name()}" select="concat('images/dummy.jpg#', substring-after(., '#'))"/>
                
            </xsl:when>
            <xsl:otherwise>
                <xsl:attribute name="{name()}" select="'images/dummy.jpg'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>
