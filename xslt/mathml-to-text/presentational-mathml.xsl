<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" 
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" 
    exclude-result-prefixes="#all"
    version="2.0">
    
    
    <!-- 
        (c) 2019 NLB
        
        Gaute Rønningen, 01.10.2019
    -->
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    
    <!-- Output encoding -->
    <xsl:output method="xhtml" indent="yes" encoding="UTF-8" include-content-type="no" exclude-result-prefixes="#all" />
    
    <!-- Should AsciiMath be included? -->
    <xsl:param name="include-asciimath" as="xs:boolean" select="false()"/>
    
    <!-- Should aria-labels be included? -->
    <xsl:param name="include-arialabels" as="xs:boolean" select="true()"/>
    
    <!-- Print a message to console -->
    <xsl:template match="/">
        <xsl:message>presentational-mathml.xsl (<xsl:value-of  select="current-dateTime()"/>)</xsl:message>
        <xsl:apply-templates/>
    </xsl:template>
    
    <!-- Match everything so we dont miss anything -->
    <xsl:template match="*" priority="-10">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    
    <xsl:template match="math">
        <div class="spoken-math">
            <math>
                <xsl:apply-templates/>
            </math>
        </div>
    </xsl:template>
    <xsl:template match="mfenced">
        <mfenced><xsl:apply-templates/></mfenced>
    </xsl:template>
    <xsl:template match="mrow">
        <mrow><xsl:apply-templates/></mrow>
    </xsl:template>
    <xsl:template match="mo">
        <mo><xsl:apply-templates/></mo>
    </xsl:template>
    <xsl:template match="mi">
        <xsl:choose>
            <xsl:when test="text()='tan'">
                <xsl:choose>
                    <xsl:when test="$include-arialabels">
                        <mi aria-label="{fnk:translate('tangent', .)}"><xsl:value-of select="text()"/></mi>
                    </xsl:when>
                    <xsl:otherwise>
                        <mi><xsl:value-of select="fnk:translate('tangent', .)"/></mi>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <mi><xsl:value-of select="."/></mi>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>