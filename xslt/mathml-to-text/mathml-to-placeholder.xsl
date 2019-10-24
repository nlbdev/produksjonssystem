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
        Jostein Austvik Jacobsen, 01.10.2019
    -->
    
    <!-- Parameters -->
    <xsl:param name="preserve-visual-math" as="xs:boolean" select="true()"/>
    
    <!-- Output encoding -->
    <xsl:output method="xhtml" indent="no" encoding="UTF-8" include-content-type="no" exclude-result-prefixes="#all" />
    
    <!-- Print a message to console -->
    <xsl:template match="/">
        <xsl:message>mathml-to-placeholder.xsl (<xsl:value-of  select="current-dateTime()"/>)</xsl:message>
        <xsl:apply-templates/>
    </xsl:template>
    
    <!-- Match everything so we dont miss anything -->
    <xsl:template match="@* | node()" priority="-10">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Replace MathML with placeholder -->
    <!-- Block math -->
    <xsl:template match="m:math[@display eq 'block']">
        <xsl:variable name="imgsrc" select="@altimg" as="xs:string?" />
        <xsl:choose>
            <xsl:when test="$preserve-visual-math and $imgsrc">
                <figure class="image">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <img class="visual-math" src="{$imgsrc}" alt="{@alttext}"/>
                    <figcaption class="spoken-math"><xsl:value-of select="fnk:translate('placeholder', ., true())"/><xsl:text>.</xsl:text></figcaption>
                </figure>
            </xsl:when>
            <xsl:otherwise>
                <p class="spoken-math">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <xsl:value-of select="fnk:translate('placeholder', ., true())"/>
                    <xsl:text>.</xsl:text>
                </p>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Inline math -->
    <xsl:template match="m:math[@display eq 'inline']">
        <xsl:variable name="imgsrc" select="@altimg" as="xs:string?" />
        <xsl:choose>
            <xsl:when test="$preserve-visual-math and $imgsrc">
                <span class="image">
                    <xsl:copy-of select="@id | @xml:lang"/>
                    <img class="visual-math" alt="{@alttext}" src="{$imgsrc}"/>
                    <span class="spoken-math"><xsl:value-of select="fnk:translate('placeholder', ., false())"/></span>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <span class="spoken-math">
                    <xsl:copy-of select="@id | @xml:lang" />
                    <xsl:value-of select="fnk:translate('placeholder', ., false())"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- If display attribute is not set, terminate -->
    <xsl:template match="m:math">
        <xsl:message terminate="yes">No display attribute found, terminating.</xsl:message>
    </xsl:template>
    
    <!-- Translation function -->
    <xsl:function name="fnk:translate" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:param name="context" as="node()"/>
        <xsl:param name="capitalize" as="xs:boolean"/>
        
        <xsl:variable name="language" select="($context/ancestor-or-self::*/@xml:lang)[last()]" as="xs:string?"/>
        <xsl:variable name="translated" as="xs:string">
            <xsl:choose>
                <xsl:when test="$language != ''">
                    <xsl:variable name="language" select="if ($language = 'no') then 'nn' else $language"/>
                    <xsl:variable name="result" select="$dictionary/term[@name=$text]/translation[@lang=$language]/text()" as="xs:string?"/>
                    <xsl:if test="not($result)">
                        <xsl:message terminate="yes">No translation found for language=<xsl:value-of select="$language"/>, terminating.</xsl:message>
                    </xsl:if>
                    <xsl:value-of select="$dictionary/term[@name=$text]/translation[@lang=$language]/text()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message terminate="yes">No language attribute found, terminating.</xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- Capitalize first letter -->
        <xsl:choose>
            <xsl:when test="$capitalize">
                <xsl:value-of select="concat(upper-case(substring($translated,1,1)), substring($translated, 2), ' '[not(last())])"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$translated"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <!-- Translation dictionary -->
    <xsl:variable name="dictionary" as="element()">
        <dictionary>
            <term name="placeholder">
                <translation lang="en">mathematical formula</translation>
                <translation lang="nb">matematisk formel</translation>
                <translation lang="nn">matematisk formel</translation>
            </term>
        </dictionary>
    </xsl:variable>
</xsl:stylesheet>