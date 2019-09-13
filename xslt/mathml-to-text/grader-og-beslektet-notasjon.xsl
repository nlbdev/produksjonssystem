<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" 
    xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" 
    exclude-result-prefixes="xs m fnk"
    version="2.0">


    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
        Gaute Rønningen, 09.09.2019
    -->
    
    <!-- Imports: -->
    <xsl:import href="translations.xsl"/>
    <xsl:import href="utilities.xsl"/>
    

    <!-- Tall etterfulgt av grader tegnet    -->
    
    <xsl:template
        match="
        m:mrow[
        (count(child::element()) eq 2) (: to barn av mrow :)
        and (
                (local-name(child::element()[1]) eq 'mn') (: første barn er mn :)
                or  (: eller :)
                (
                    (local-name(child::element()[1]) eq 'mrow') (: første barn er mrow :)
                    and
                    (count(child::element()[1]/child::element()) eq 2)  (: dette mrow har to barn :)
                    and
                    (local-name(child::element()[1]/child::element()[1]) eq 'mo')   (: det første av disse er mo :)
                    and
                    (normalize-space(child::element()[1]/child::element()[1]) eq '-') (: og inneholder et minustegn :)
                    and
                    (local-name(child::element()[1]/child::element()[2]) eq 'mn')   (: og det andre av disse to barna er mn :)
                )
            )
        and (local-name(child::element()[2]) eq 'mi') (: andre barn er mi ... :)
        and (normalize-space(m:mi) eq '&#176;') (: og ... og inneholder degree symbolet :)
        ]"
        mode="verbal-matte">
        <!-- Signatur:
           <mrow>
            <mrow>
              <mo>-</mo>
              <mn>[sifre]</mn>
            </mrow>
            <mi>&#176;</mi>
           </mrow>
           
           eller
           
           <mrow>
            <mn>[sifre]</mn>
            <mi>&#176;</mi>
           </mrow>
        -->
        
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
        <xsl:choose>
            <xsl:when test="child::element()[1] castable as xs:integer">
                <xsl:choose>
                    <xsl:when test="abs(child::element()[1]) eq 1">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="fnk:translate('grad', .)" />
                        <xsl:text> </xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="fnk:translate('grader', .)" />
                        <xsl:text>, </xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fnk:translate('grader', .)" />
                <xsl:text>, </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        
    </xsl:template>
    
    <!-- Tall etterfulgt av gon tegnet (g)    -->
    
    <xsl:template
        match="
        m:msup[
        (count(child::element()) eq 2) (: to barn av msup :)
        and (
        (local-name(child::element()[1]) eq 'mn') (: første barn er mn :)
        or  (: eller :)
        (
        (local-name(child::element()[1]) eq 'mrow') (: første barn er mrow :)
        and
        (count(child::element()[1]/child::element()) eq 2)  (: dette mrow har to barn :)
        and
        (local-name(child::element()[1]/child::element()[1]) eq 'mo')   (: det første av disse er mo :)
        and
        (normalize-space(child::element()[1]/child::element()[1]) eq '-') (: og inneholder et minustegn :)
        and
        (local-name(child::element()[1]/child::element()[2]) eq 'mn')   (: og det andre av disse to barna er mn :)
        )
        )
        and (local-name(child::element()[2]) eq 'mtext') (: andre barn er mtext ... :)
        and (normalize-space(m:mtext) eq 'g') (: og ... og inneholder gon symbolet :)
        ]"
        mode="verbal-matte">
        <!-- Signatur:
            
           <msup>
            <mn>[sifre]</mn>
            <mtext>g</mtext>
           </msup>
           
            eller
            
            <msup>
                <mrow>
                    <mo>-</mo>
                    <mn>[sifre]</mn>
                </mrow>
                <mtext>g</mtext>
           </msup>


        -->
        
        <xsl:apply-templates select="child::element()[1]" mode="#current"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="fnk:translate('gon', .)" />
        <xsl:text> </xsl:text>
    </xsl:template>
    
    
</xsl:stylesheet>
