<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns:m="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fnk="http://www.nlb.no/2017/xml/funksjoner" exclude-result-prefixes="xs m fnk"
    version="2.0">


    <!-- 
        (c) 2019 NLB
        
        Per Sennels, 21.01.2019
    -->
    

    <!-- Ekvivalens -->
    <!-- Koder: &#8660;
                &#x21d4;
                &hArr;
    -->
    <xsl:template match="m:mo[normalize-space(.) eq '&#8660;'][exists(preceding-sibling::element()) and exists(following-sibling::element())]" mode="verbal-matte">
        <!-- Signatur:
            
           [minst ett element]
            <mo>&#8660;</mo>
           [minst ett element]
        -->
        <xsl:text> er ekvivalent med </xsl:text>
        
    </xsl:template>

</xsl:stylesheet>
