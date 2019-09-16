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
            
            <term name="av">
                <translation lang="en">of</translation>
                <translation lang="nb">av</translation>
            </term>
            
            <term name="opphøyd i">
                <translation lang="en">raised to</translation>
                <translation lang="nb">opphøyd i</translation>
            </term>
            
            <term name="eksponent slutt">
                <translation lang="en">exponent end</translation>
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
                <translation lang="en">division with dividend</translation>
                <translation lang="nb">brøk med teller</translation>
            </term>
            
            <term name="og med nevner">
                <translation lang="en">and with divisor</translation>
                <translation lang="nb">og med nevner</translation>
            </term>
            
            <term name="funksjonen">
                <translation lang="en">the function</translation>
                <translation lang="nb">funksjonen</translation>
            </term>
            
            <term name="er lik">
                <translation lang="en">equals</translation>
                <translation lang="nb">er lik</translation>
            </term>
            
            <term name="minus">
                <translation lang="en">minus</translation>
                <translation lang="nb">minus</translation>
            </term>
            
            <term name="sinus">
                <translation lang="en">sine</translation>
                <translation lang="nb">sinus</translation>
            </term>
            
            <term name="til">
                <translation lang="en">to</translation>
                <translation lang="nb">til</translation>
            </term>
            
            <term name="formel">
                <translation lang="en">formula</translation>
                <translation lang="nb">formel</translation>
            </term>
            
            <term name="formel slutt">
                <translation lang="en">formula end</translation>
                <translation lang="nb">formel slutt</translation>
            </term>
            
            <term name="cosinus">
                <translation lang="en">cosine</translation>
                <translation lang="nb">cosinus</translation>
            </term>
            
            <term name="ganger">
                <translation lang="en">times</translation>
                <translation lang="nb">ganger</translation>
            </term>
            
            <term name="pluss">
                <translation lang="en">plus</translation>
                <translation lang="nb">pluss</translation>
            </term>
            
            <term name="liten">
                <translation lang="en">small</translation>
                <translation lang="nb">liten</translation>
            </term>
            
            <term name="stor">
                <translation lang="en">capital</translation>
                <translation lang="nb">stor</translation>
            </term>
            
            <term name="parentes">
                <translation lang="en">parentheses</translation>
                <translation lang="nb">parentes</translation>
            </term>
            
            <term name="parentes slutt">
                <translation lang="en">parentheses end</translation>
                <translation lang="nb">parentes slutt</translation>
            </term>
            
            <term name="omega">
                <translation lang="en">omega</translation>
                <translation lang="nb">omega</translation>
            </term>
            
            <term name="fi">
                <translation lang="en">phi</translation>
                <translation lang="nb">phi</translation>
            </term>
            
            <term name="er større eller lik">
                <translation lang="en">is bigger or equal to</translation>
                <translation lang="nb">er større eller lik</translation>
            </term>
            
            <term name="roten av">
                <translation lang="en">squared</translation>
                <translation lang="nb">roten av</translation>
            </term>
            
            <term name="kvadratroten av">
                <translation lang="en">square root of</translation>
                <translation lang="nb">kvadratroten av</translation>
            </term>
            
            <term name="kvadratrot slutt">
                <translation lang="en">square root end</translation>
                <translation lang="nb">kvadratrot slutt</translation>
            </term>
            
            <term name="tangens">
                <translation lang="en">tangent</translation>
                <translation lang="nb">tangens</translation>
            </term>
            
            <term name="arkus sinus">
                <translation lang="en">arcus sine</translation>
                <translation lang="nb">arkus sinus</translation>
            </term>
            
            <term name="arkus cosinus">
                <translation lang="en">arcus cosine</translation>
                <translation lang="nb">arkus cosinus</translation>
            </term>
            
            <term name="arkus tangens">
                <translation lang="en">arcus tangent</translation>
                <translation lang="nb">arkus tangens</translation>
            </term>
            
            <term name="hyperbolsk sinus">
                <translation lang="en">hyperbolic sine</translation>
                <translation lang="nb">hyperbolsk sinus</translation>
            </term>
            
            <term name="hyperbolsk cosinus">
                <translation lang="en">hyperbolic cosine</translation>
                <translation lang="nb">hyperbolsk cosinus</translation>
            </term>
            
            <term name="hyperbolsk tangens">
                <translation lang="en">hyperbolic tangent</translation>
                <translation lang="nb">hyperbolsk tangens</translation>
            </term>
            
            <term name="cotangens">
                <translation lang="en">cotangent</translation>
                <translation lang="nb">cotangens</translation>
            </term>
            
            <term name="secans">
                <translation lang="en">secant</translation>
                <translation lang="nb">secans</translation>
            </term>
            
            <term name="cosecans">
                <translation lang="en">cosecant</translation>
                <translation lang="nb">cosecans</translation>
            </term>
            
            <term name="arkus cotangens">
                <translation lang="en">arcus cotangent</translation>
                <translation lang="nb">arkus cotangens</translation>
            </term>
            
            <term name="arkus secans">
                <translation lang="en">arcus secant</translation>
                <translation lang="nb">arkus secans</translation>
            </term>
            
            <term name="arkus cosecans">
                <translation lang="en">arcus cosecant</translation>
                <translation lang="nb">arkus cosecans</translation>
            </term>
            
            <term name="hyperbolsk cotangens">
                <translation lang="en">hyperbolic cotangent</translation>
                <translation lang="nb">hyperbolsk cotangens</translation>
            </term>
            
            <term name="hyperbolsk secans">
                <translation lang="en">hyperbolic secant</translation>
                <translation lang="nb">hyperbolsk secans</translation>
            </term>
            
            <term name="hyperbolsk cosecans">
                <translation lang="en">hyperbolic cosecant</translation>
                <translation lang="nb">hyperbolsk cosecans</translation>
            </term>
            
            <term name="hyperbolsk arkus sinus">
                <translation lang="en">hyperbolic arcus sine</translation>
                <translation lang="nb">hyperbolsk arkus sinus</translation>
            </term>
            
            <term name="hyperbolsk arkus cosinus">
                <translation lang="en">hyperbolic arcus cosine</translation>
                <translation lang="nb">hyperbolsk arkus cosinus</translation>
            </term>
            
            <term name="hyperbolsk arkus tangens">
                <translation lang="en">hyperbolic arcus tangent</translation>
                <translation lang="nb">hyperbolsk arkus tangens</translation>
            </term>
            
            <term name="hyperbolsk arkus cotangens">
                <translation lang="en">hyperbolic arcus cotangent</translation>
                <translation lang="nb">hyperbolsk arkus cotangens</translation>
            </term>
        </dictionary>
    </xsl:variable>
</xsl:stylesheet>