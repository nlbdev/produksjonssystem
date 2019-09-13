<?xml version="1.0" encoding="UTF-8"?>
    <xsl:stylesheet 
        xmlns="http://www.w3.org/1999/xhtml"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xpath-default-namespace="http://www.w3.org/1999/xhtml"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:m="http://www.w3.org/1998/Math/MathML"
        xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner"
        exclude-result-prefixes="#all"
        version="2.0">
    
    <!-- 
        (c) 2019 NLB
        
        Gaute Rønningen, 11.09.2019
        Jostein Austvik Jacobsen, 11.09.2019
    -->
    
    <!-- 
        hvordan bruke:
            <xsl:value-of select="fnk:translate('translate', .)"/>
    -->
    <xsl:function name="fnk:translate" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:param name="context" as="node()"/>
        
        <xsl:variable name="language" select="($context/ancestor-or-self::*/@xml:lang)[last()]"/>
        
        <xsl:variable name="result" select="$dictionary/term[@name=$text]/translation[@lang=$language]/text()"/>
        <xsl:choose>
            <xsl:when test="not($result)">
                <xsl:message select="concat('Translation missing for: ', $text, ' (language=', $language, ')')"/>
                <xsl:value-of select="$text"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$dictionary/term[@name=$text]/translation[@lang=$language]/text()"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <xsl:variable name="dictionary" as="element()">
        <dictionary>
            <term name="ukjent operator">
                <translation lang="en">unknown operator</translation>
                <translation lang="nb">ukjent operator</translation>
            </term>
            
            <term name="opphøyd i">
                <translation lang="en">exalted in</translation>
                <translation lang="nb">opphøyd i</translation>
            </term>
            
            <term name="eksponent slutt">
                <translation lang="en">exponent ending</translation>
                <translation lang="nb">eksponent slutt</translation>
            </term>
            
            <term name="i">
                <translation lang="en">in</translation>
                <translation lang="nb">i</translation>
            </term>
            
            <term name="i annen">
                <translation lang="en">squared</translation>
                <translation lang="nb">i annen</translation>
            </term>
            
            <term name="Ingen mal for denne:">
                <translation lang="en">No template found for this:</translation>
                <translation lang="nb">Ingen mal for denne:</translation>
            </term>
            
            <term name="brøken">
                <translation lang="en">the fraction</translation>
                <translation lang="nb">brøken</translation>
            </term>
            
            <term name="delt på">
                <translation lang="en">divided by</translation>
                <translation lang="nb">delt på</translation>
            </term>
            
            <term name="brøk med teller">
                <translation lang="en">PLACEHOLDER</translation>
                <translation lang="nb">brøk med teller</translation>
            </term>
            
            <term name="og med nevner">
                <translation lang="en">PLACEHOLDER</translation>
                <translation lang="nb">og med nevner</translation>
            </term>
            
            
        </dictionary>
    </xsl:variable>
</xsl:stylesheet>