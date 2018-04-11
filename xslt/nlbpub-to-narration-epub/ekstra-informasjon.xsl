<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fnk="http://www.nlb.no/2017/functions/"
    xmlns:epub="http://www.idpf.org/2007/ops" xpath-default-namespace="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml" exclude-result-prefixes="#all" version="2.0">

    <!-- Denne attributtverdien skal brukes for alle elementer som vi oppretter for å ivareta ekstra tekst som vi genererer -->
    <xsl:variable name="attributtverdi-for-ekstra-informasjon" as="xs:string"
        select="'nlb-ekstra-informasjon'"/>

    <xsl:template name="legg-på-attributt-for-ekstra-informasjon">
        <xsl:attribute name="class" select="$attributtverdi-for-ekstra-informasjon"/>
    </xsl:template>

    <xsl:template name="lag-span-eller-p-med-ekstra-informasjon">
        <xsl:param name="informasjon" as="xs:string"/>
        <xsl:variable name="første-node-er-tekst" as="xs:boolean"
            select="descendant-or-self::text()[normalize-space(.) ne ''][1]/parent::node() is current()"/>
        <xsl:variable name="element-navn" as="xs:string">
            <xsl:choose>
                <xsl:when test="(normalize-space(.) eq '') and not(exists(child::element())) ">
                    <!-- Helt tomt element, ikke noe tekst og ikke noe barn -->
                    <xsl:value-of select="'span'"/>
                </xsl:when>
                <xsl:when
                    test="$første-node-er-tekst or matches(child::element()[1]/local-name(), '^(a|abbr|acronym|b|bdo|big|br|button|cite|code|dfn|em|i|img|input|kbd|label|map|object|q|samp|script|select|small|span|strong|sub|sup|textarea|time|tt|var)$')">
                    <xsl:value-of select="'span'"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'p'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:element name="{$element-navn}">
            <xsl:call-template name="legg-på-attributt-for-ekstra-informasjon"/>
            <xsl:value-of select="$informasjon"/>
        </xsl:element>
    </xsl:template>

</xsl:stylesheet>
