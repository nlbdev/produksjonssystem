<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- 
        (c) 2018 NLB
        
        Per Sennels, 23.04.2018
    -->
    
    <!--
        Legger til teksten 'Note ' som ekstra informasjon for elementer som har epub:type "footnote"
        
        2018-04-26: Det samme for alle elementer som har epub:type "noteref"
        
        TODO:
        
            ** Sjekke om det finnes andre attributtverdier som skal medføre st slik tekst legges inn
    -->
    <xsl:template match="*[fnk:epub-type(@epub:type,'footnote') or fnk:epub-type(@epub:type,'noteref')]">
        <xsl:copy exclude-result-prefixes="#all">
            <xsl:apply-templates select="@*"/>
            <xsl:call-template name="lag-span-eller-p-med-ekstra-informasjon">
                <xsl:with-param name="informasjon" as="xs:string" select="'Note '"/>
            </xsl:call-template>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
